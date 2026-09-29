#!/usr/bin/env python3
"""Runs a batch of PixelLab calls from a job file, inside the session's allowance.

    tools/art/gen.py plan art/jobs/<batch>.json     the calls, their estimates, the allowance; no call
    tools/art/gen.py run  art/jobs/<batch>.json     spends: posts, polls, saves, logs

A job file: {"concept": "C1", "calls": [{"id", "endpoint", "estimate", "body"}, ...]}; a call with
"hold": "<why>" is listed and skipped. The body is
the endpoint's JSON. An image input is never inline: it is {"ref": "<id>"} ({"ref", "as": "sized"} for an endpoint that
wants {base64, width, height}; {"ref", "as": "reference", "usage": "..."} for {image, size,
usage_description}), resolved from
art/refs/refs.json only when the user approved that reference (docs/ART.md, "References are the
user's"); a mask, or the subject being extended (a file the pipeline made under art/raw or
art/work), is {"file": path, "kind": "mask" | "subject"} ("as": "sized" wraps it as {image, size}), not a
reference; a base64 image or an unknown or unapproved ref in a body refuses the whole batch, and so
does a Pro call (PRO_WITH_REFS) with no approved ref and no "no_refs_reason" beside its body.

Each call's outputs go to art/raw/<concept>/<id>/ (the images, request.json without image data,
response.json without image data); art/ledger.jsonl gets a line per call as soon as the job id is
known and another when it completes, so a rerun resumes: a completed call is skipped, a submitted
one is polled again, never re-posted; a failed one (not charged) is posted again. Every pending job is posted before any is waited on, so they
run side by side.
"""

import base64
import datetime as dt
import hashlib
import io
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import budget  # noqa: E402
import keys  # noqa: E402
import pixellab  # noqa: E402

ROOT = HERE.parent.parent
REFS = ROOT / "art" / "refs" / "refs.json"
LEDGER = ROOT / "art" / "ledger.jsonl"
RAW = ROOT / "art" / "raw"
# The Pro endpoints that take steering images. A call to one either carries approved refs (a set of
# one kind, the user's own images, identity and edits) or its job says why not (`no_refs_reason`),
# so the choice is written down (docs/ART.md, "References where they earn their place").
PRO_WITH_REFS = {
    "/create-character-pro", "/generate-image-v2", "/generate-with-style-v2", "/create-tiles-pro",
    "/create-1-direction-object", "/create-8-direction-object", "/edit-images-v2", "/inpaint-v3",
    "/animate-with-text-v2", "/generate-8-rotations-v2", "/transfer-outfit-v2", "/create-ui-asset",
}
POLL_SECONDS = 6
SLOT_WAIT_SECONDS = 20
POLL_LIMIT_SECONDS = 900


class Refused(RuntimeError):
    pass


def now() -> str:
    return dt.datetime.now().isoformat(timespec="seconds")


def load_refs() -> dict:
    if not REFS.exists():
        return {}
    return {ref["id"]: ref for ref in json.loads(REFS.read_text())["refs"]}


def resolve_images(value, refs: dict, used: list):
    """The body with every {"ref": id} replaced by its approved image; refuses inline images."""
    if isinstance(value, dict):
        if "file" in value and set(value) <= {"file", "kind", "as"}:
            # A mask, or the subject being extended or edited (our own generated piece): these steer
            # no style, so they are not references (docs/ART.md); only files the pipeline made.
            path = (ROOT / value["file"]).resolve()
            if value["kind"] not in ("mask", "subject") or not any(
                    path.is_relative_to(ROOT / d) for d in ("art/raw", "art/work")):
                raise Refused(f"{value['file']}: only a mask or a subject made by the pipeline goes in as a file")
            used.append(f"{value['kind']}:{value['file']}")
            image = {"type": "base64", "base64": base64.b64encode(path.read_bytes()).decode(), "format": "png"}
            if value.get("as") == "sized":  # inpaint-v3: {image, size}
                width, height = Image.open(path).size
                return {"image": image, "size": {"width": width, "height": height}}
            return image
        if "ref" in value and set(value) <= {"ref", "as", "usage"}:
            ref = refs.get(value["ref"])
            if ref is None or not ref.get("approved"):
                raise Refused(f"reference {value['ref']!r} is not approved in {REFS.relative_to(ROOT)}")
            data = (ROOT / ref["file"]).read_bytes()
            if hashlib.sha256(data).hexdigest() != ref["sha256"]:
                raise Refused(f"reference {value['ref']!r} changed since the user approved it")
            used.append(ref["id"])
            encoded = base64.b64encode(data).decode()
            width, height = Image.open(io.BytesIO(data)).size
            if value.get("as") == "sized":  # Pro tiles' style_images: {base64, width, height}
                return {"base64": encoded, "width": width, "height": height}
            if value.get("as") == "reference":  # Pro images: {image, size, usage_description}
                wrapped = {"image": {"type": "base64", "base64": encoded, "format": "png"},
                           "size": {"width": width, "height": height}}
                if value.get("usage"):
                    wrapped["usage_description"] = value["usage"]
                return wrapped
            return {"type": "base64", "base64": encoded, "format": "png"}
        if value.get("type") == "base64" or "base64" in value:
            raise Refused("an inline image in a body: images go in as approved refs only")
        return {k: resolve_images(v, refs, used) for k, v in value.items()}
    if isinstance(value, list):
        return [resolve_images(v, refs, used) for v in value]
    if isinstance(value, str) and value.startswith("data:image"):
        raise Refused("an inline image in a body: images go in as approved refs only")
    return value


def strip_images(value):
    if isinstance(value, dict):
        if value.get("type") == "base64" or "base64" in value:
            return {"image": "<omitted>"}
        return {k: strip_images(v) for k, v in value.items()}
    if isinstance(value, list):
        return [strip_images(v) for v in value]
    if isinstance(value, str) and value.startswith("data:image"):
        return "<omitted>"
    return value


def collect_images(value, found: list):
    if isinstance(value, dict):
        if value.get("type") == "base64" or ("base64" in value and isinstance(value["base64"], str)):
            found.append(value["base64"])
            return
        for v in value.values():
            collect_images(v, found)
    elif isinstance(value, list):
        for v in value:
            collect_images(v, found)
    elif isinstance(value, str) and value.startswith("data:image"):
        found.append(value)


def decode(data: str) -> bytes:
    return base64.b64decode(data.split(",", 1)[1] if data.startswith("data:") else data)


def fetch_public(url: str) -> bytes:
    """A file URL from a response (storage, not the API): fetched without the key."""
    host = urllib.parse.urlparse(url).hostname or ""
    if host == "api.pixellab.ai":
        raise Refused("an API URL where a storage URL was expected")
    # The storage refuses Python's default User-Agent (HTTP 403); the files are public.
    request = urllib.request.Request(url, headers={"User-Agent": "arena-art-pipeline/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def ledger_state() -> dict:
    state = {}
    if LEDGER.exists():
        for line in LEDGER.read_text().splitlines():
            entry = json.loads(line)
            state[(entry["concept"], entry["id"])] = entry
    return state


def log(entry: dict):
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a") as f:
        f.write(json.dumps(entry, sort_keys=True) + "\n")


def patiently(action, what: str, network: bool = True):
    """Runs an API action through a dropped connection (retried) or a full queue (HTTP 429: the
    plan's concurrent job slots are taken) or a busy character (HTTP 423: an animation still
    generating); waits, up to POLL_LIMIT_SECONDS. A post
    passes network=False: a dropped post may have reached the server, and a second would be charged."""
    waited = 0
    while True:
        try:
            return action()
        except pixellab.ApiError as error:
            if error.code not in (423, 429) or waited >= POLL_LIMIT_SECONDS:
                raise
            print(f"  {what}: {'busy (423)' if error.code == 423 else 'the job slots are full'}, waiting", flush=True)
        except urllib.error.HTTPError:
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
            if not network or waited >= POLL_LIMIT_SECONDS:
                raise RuntimeError(f"{what}: {error}") from None
            print(f"  {what}: connection lost ({error}), retrying", flush=True)
        time.sleep(SLOT_WAIT_SECONDS)
        waited += SLOT_WAIT_SECONDS


def poll(job_id: str) -> dict:
    waited = 0
    while waited < POLL_LIMIT_SECONDS:
        job = patiently(lambda: pixellab.request("GET", f"/background-jobs/{job_id}"), f"job {job_id}")
        if job.get("status") in ("completed", "failed"):
            return job
        time.sleep(POLL_SECONDS)
        waited += POLL_SECONDS
    raise RuntimeError(f"job {job_id} still processing after {POLL_LIMIT_SECONDS} s; rerun to resume")


def collect_urls(value, found: list, key: str = ""):
    """(name, url) pairs: the name is the link's key when it has one (a direction, tile_3)."""
    if isinstance(value, dict):
        for k, v in value.items():
            collect_urls(v, found, k)
    elif isinstance(value, list):
        for v in value:
            collect_urls(v, found)
    elif isinstance(value, str) and value.startswith("https://") and ".png" in value:
        found.append((key, value))


# A result stored under its own id is fetched from its own endpoint once the job completes.
DETAILS = {"tileset_id": "/tilesets/{}", "tile_id": "/tiles-pro/{}"}


def save_outputs(out: Path, call: dict, reply: dict, jobs: list[dict]) -> list[str]:
    sources = [reply] + [job.get("last_response") or {} for job in jobs]
    for key, path in DETAILS.items():
        if reply.get(key):
            detail = pixellab.request("GET", path.format(reply[key]))
            (out / "detail.json").write_text(json.dumps(strip_images(detail), indent=2))
            sources.append(detail)
    images, urls = [], []
    for source in sources:
        # A template animation returns its frames twice: raw (80 to 100 colours) and reduced
        # (about 30, the pixel art); only the reduced set is kept.
        if isinstance(source, dict) and source.get("quantized_images"):
            source = {k: v for k, v in source.items() if k != "images"}
        collect_images(source, images)
        collect_urls(source, urls)
    saved = []
    for n, data in enumerate(images):
        name = f"{n:02d}.png"
        (out / name).write_bytes(decode(data))
        saved.append(name)
    # Storage links repeat the inline images (and are private, HTTP 403); fetched only when a result
    # has no inline image (Pro tiles' storage_urls).
    for n, (key, url) in enumerate(dict.fromkeys(urls) if not images else [], start=len(images)):
        name = f"{key}.png" if key.replace("-", "").isalpha() else f"{n:02d}.png"
        try:
            (out / name).write_bytes(fetch_public(url))
            saved.append(name)
        except urllib.error.HTTPError as error:
            print(f"  {call['id']}: {url[-60:]}: HTTP {error.code}, skipped", flush=True)
    character_id = reply.get("character_id") or next(
        ((j.get("last_response") or {}).get("character_id") for j in jobs
         if (j.get("last_response") or {}).get("character_id")), None)
    if not character_id and call["endpoint"] == "/animate-character":
        character_id = call["body"]["character_id"]
    if character_id:
        blob = pixellab.request_bytes("GET", f"/characters/{character_id}/zip")
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            archive.extractall(out / "character")
        saved.append("character/")
    return saved


def usage_of(reply: dict, jobs: list[dict]) -> dict | None:
    """The generations charged: the jobs' usage summed (an animation is a job a direction)."""
    usages = [job.get("usage") for job in jobs if job.get("usage")] or ([reply["usage"]] if reply.get("usage") else [])
    if not usages:
        return None
    if all(u.get("type") == "generations" for u in usages):
        return {"type": "generations", "generations": sum(u.get("generations") or 0 for u in usages)}
    return usages[0] if len(usages) == 1 else {"parts": usages}


def job_ids_of(reply: dict) -> list[str]:
    return list(reply.get("background_job_ids") or []) or ([reply["background_job_id"]] if reply.get("background_job_id") else [])


def call_record(concept: str, call: dict, used: list) -> dict:
    return {
        "concept": concept, "id": call["id"], "endpoint": call["endpoint"], "refs": used,
        "params_sha256": hashlib.sha256(json.dumps(call["body"], sort_keys=True).encode()).hexdigest()[:16],
        "estimate": call.get("estimate"),
    }


def submit(concept: str, call: dict, refs: dict, state: dict, patient: bool = False) -> None:
    """Posts a call not yet posted; a job's id goes to the ledger before anything waits on it."""
    previous = state.get((concept, call["id"]))
    if previous and previous.get("status") != "failed" and (previous.get("status") == "completed" or previous.get("job_ids") or previous.get("job_id")):
        return
    out = RAW / concept / call["id"]
    out.mkdir(parents=True, exist_ok=True)
    used: list[str] = []
    body = resolve_images(call["body"], refs, used)
    (out / "request.json").write_text(json.dumps({"endpoint": call["endpoint"], "body": call["body"]}, indent=2))
    reply = patiently(lambda: pixellab.request("POST", call["endpoint"], body), call["id"], network=False) if patient \
        else pixellab.request("POST", call["endpoint"], body)
    job_ids = job_ids_of(reply)
    entry = {**call_record(concept, call, used), "time": now(), "status": "submitted" if job_ids else "returned",
             "job_ids": job_ids, "character_id": reply.get("character_id"), "reply": strip_images(reply)}
    log(entry)
    # A synchronous reply carries its images: keep them for finish(), never in the ledger.
    state[(concept, call["id"])] = {**entry, "reply": reply}


def finish(concept: str, call: dict, state: dict) -> None:
    entry = state.get((concept, call["id"]))
    if entry and entry.get("status") == "completed":
        print(f"  {call['id']}: done before, skipped")
        return
    out = RAW / concept / call["id"]
    reply = entry.get("reply") or {}
    job_ids = entry.get("job_ids") or ([entry["job_id"]] if entry.get("job_id") else [])
    jobs = [poll(job_id) for job_id in job_ids]
    record = {k: entry[k] for k in ("concept", "id", "endpoint", "refs", "params_sha256", "estimate")}
    (out / "response.json").write_text(json.dumps({"reply": strip_images(reply), "jobs": strip_images(jobs)}, indent=2))
    failed = [job for job in jobs if job.get("status") == "failed"]
    if failed:
        log({**record, "time": now(), "status": "failed", "job_ids": job_ids, "usage": usage_of(reply, jobs)})
        print(f"  {call['id']}: FAILED ({json.dumps(strip_images(failed[0].get('last_response')))[:300]})")
        return
    saved = patiently(lambda: save_outputs(out, call, reply, jobs), call["id"])
    left = patiently(pixellab.balance, "balance")["subscription"]["generations"]
    log({**record, "time": now(), "status": "completed", "job_ids": job_ids,
         "character_id": reply.get("character_id"), "usage": usage_of(reply, jobs), "saved": saved,
         "balance_after": left})
    print(f"  {call['id']}: {len(saved)} file(s), usage {usage_of(reply, jobs)}, {left:.0f} left")


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] not in ("plan", "run"):
        print(__doc__.strip())
        return 2
    batch = json.loads(Path(argv[1]).read_text())
    concept, calls = batch["concept"], batch["calls"]
    refs, state = load_refs(), ledger_state()
    try:
        for call in calls:
            used: list[str] = []
            resolve_images(call["body"], refs, used)
            if call["endpoint"] in PRO_WITH_REFS and not any(":" not in u for u in used) and not call.get("no_refs_reason"):
                raise Refused(f"{call['id']}: a Pro call without approved references needs a no_refs_reason")
    except Refused as error:
        print(f"refused: {error}", file=sys.stderr)
        return 1
    pending = [c for c in calls if state.get((concept, c["id"]), {}).get("status") != "completed" and not c.get("hold")]
    estimate = sum(c.get("estimate", 0) for c in pending)
    try:
        sub = pixellab.balance()["subscription"]
    except (keys.KeyMissing, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 1
    config = json.loads(budget.CONFIG.read_text())
    pace = budget.pacing(float(sub["total"]), float(sub["generations"]), dt.date.today(), config)
    for c in calls:
        mark = f"held: {c['hold']}" if c.get("hold") else "done" if c not in pending else f"~{c.get('estimate', 0)}"
        print(f"  {c['id']:<28} {c['endpoint']:<24} {mark}")
    print(f"{concept}: {len(pending)} call(s) to make, estimate {estimate}; "
          f"this session may spend {pace['allowance']:.0f} ({pace['left']:.0f} left)")
    if argv[0] == "plan":
        return 0
    if estimate > pace["allowance"]:
        print("refused: the estimate is over the session's allowance", file=sys.stderr)
        return 1
    # Every job is posted first so they run side by side, then each is collected in order. A
    # refusal from the API (a concurrency cap) stops the posting; finish() posts what is left.
    for call in pending:
        try:
            submit(concept, call, refs, state)
        except RuntimeError as error:
            print(f"  posting paused at {call['id']}: {error}", file=sys.stderr)
            break
    errors = 0
    for call in pending:
        try:
            if (concept, call["id"]) not in state or state[(concept, call["id"])].get("status") == "failed":
                submit(concept, call, refs, state, patient=True)
            finish(concept, call, state)
        except (Refused, RuntimeError, urllib.error.URLError) as error:
            print(f"  {call['id']}: {error}", file=sys.stderr)
            errors += 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
