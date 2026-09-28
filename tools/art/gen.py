#!/usr/bin/env python3
"""Runs a batch of PixelLab calls from a job file, inside the session's allowance.

    tools/art/gen.py plan art/jobs/<batch>.json     the calls, their estimates, the allowance; no call
    tools/art/gen.py run  art/jobs/<batch>.json     spends: posts, polls, saves, logs

A job file: {"concept": "C1", "calls": [{"id", "endpoint", "estimate", "body"}, ...]}. The body is
the endpoint's JSON. An image input is never inline: it is {"ref": "<id>"}, resolved from
art/refs/refs.json only when the user approved that reference (docs/ART.md, "References are the
user's"); a base64 image or an unknown or unapproved ref in a body refuses the whole batch, and so
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
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import budget  # noqa: E402
import keys  # noqa: E402
import pixellab  # noqa: E402

ROOT = HERE.parent.parent
REFS = ROOT / "art" / "refs" / "refs.json"
LEDGER = ROOT / "art" / "ledger.jsonl"
RAW = ROOT / "art" / "raw"
# The Pro endpoints that take steering images: the references are what the twentyfold price buys,
# so a call to one carries approved refs, or its job says why not (`no_refs_reason`: the first look
# of a style, before anything is approved).
PRO_WITH_REFS = {
    "/create-character-pro", "/generate-image-v2", "/generate-with-style-v2", "/create-tiles-pro",
    "/create-1-direction-object", "/create-8-direction-object", "/edit-images-v2", "/inpaint-v3",
    "/animate-with-text-v2", "/generate-8-rotations-v2", "/transfer-outfit-v2", "/create-ui-asset",
}
POLL_SECONDS = 6
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
        if set(value) == {"ref"}:
            ref = refs.get(value["ref"])
            if ref is None or not ref.get("approved"):
                raise Refused(f"reference {value['ref']!r} is not approved in {REFS.relative_to(ROOT)}")
            data = (ROOT / ref["file"]).read_bytes()
            if hashlib.sha256(data).hexdigest() != ref["sha256"]:
                raise Refused(f"reference {value['ref']!r} changed since the user approved it")
            used.append(ref["id"])
            return {"type": "base64", "base64": base64.b64encode(data).decode(), "format": "png"}
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
    with urllib.request.urlopen(url, timeout=60) as response:
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


def poll(job_id: str) -> dict:
    waited = 0
    while waited < POLL_LIMIT_SECONDS:
        job = pixellab.request("GET", f"/background-jobs/{job_id}")
        if job.get("status") in ("completed", "failed"):
            return job
        time.sleep(POLL_SECONDS)
        waited += POLL_SECONDS
    raise RuntimeError(f"job {job_id} still processing after {POLL_LIMIT_SECONDS} s; rerun to resume")


def save_outputs(out: Path, reply: dict, job: dict | None) -> list[str]:
    images = []
    collect_images(reply, images)
    if job:
        collect_images(job.get("last_response") or {}, images)
    saved = []
    for n, data in enumerate(images):
        name = f"{n:02d}.png"
        (out / name).write_bytes(decode(data))
        saved.append(name)
    character_id = reply.get("character_id") or ((job or {}).get("last_response") or {}).get("character_id")
    if character_id:
        blob = pixellab.request_bytes("GET", f"/characters/{character_id}/zip")
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            archive.extractall(out / "character")
        saved.append("character/")
    return saved


def usage_of(reply: dict, job: dict | None) -> dict | None:
    return (job or {}).get("usage") or reply.get("usage")


def call_record(concept: str, call: dict, used: list) -> dict:
    return {
        "concept": concept, "id": call["id"], "endpoint": call["endpoint"], "refs": used,
        "params_sha256": hashlib.sha256(json.dumps(call["body"], sort_keys=True).encode()).hexdigest()[:16],
        "estimate": call.get("estimate"),
    }


def submit(concept: str, call: dict, refs: dict, state: dict) -> None:
    """Posts a call not yet posted; a job's id goes to the ledger before anything waits on it."""
    previous = state.get((concept, call["id"]))
    if previous and previous.get("status") != "failed" and (previous.get("status") == "completed" or previous.get("job_id")):
        return
    out = RAW / concept / call["id"]
    out.mkdir(parents=True, exist_ok=True)
    used: list[str] = []
    body = resolve_images(call["body"], refs, used)
    (out / "request.json").write_text(json.dumps({"endpoint": call["endpoint"], "body": call["body"]}, indent=2))
    reply = pixellab.request("POST", call["endpoint"], body)
    job_id = reply.get("background_job_id")
    entry = {**call_record(concept, call, used), "time": now(), "status": "submitted" if job_id else "returned",
             "job_id": job_id, "character_id": reply.get("character_id"), "reply": strip_images(reply)}
    log(entry)
    # A synchronous reply carries its images: keep them for finish(), never in the ledger.
    state[(concept, call["id"])] = {**entry, "reply": reply}


def finish(concept: str, call: dict, state: dict) -> None:
    entry = state.get((concept, call["id"]))
    if entry and entry.get("status") == "completed":
        print(f"  {call['id']}: done before, skipped")
        return
    out = RAW / concept / call["id"]
    reply, job_id = entry.get("reply") or {}, entry.get("job_id")
    job = poll(job_id) if job_id else None
    record = {k: entry[k] for k in ("concept", "id", "endpoint", "refs", "params_sha256", "estimate")}
    (out / "response.json").write_text(json.dumps({"reply": strip_images(reply), "job": strip_images(job)}, indent=2))
    if job and job.get("status") == "failed":
        log({**record, "time": now(), "status": "failed", "job_id": job_id, "usage": usage_of(reply, job)})
        print(f"  {call['id']}: FAILED ({json.dumps(strip_images(job.get('last_response')))[:300]})")
        return
    saved = save_outputs(out, reply, job)
    left = pixellab.balance()["subscription"]["generations"]
    log({**record, "time": now(), "status": "completed", "job_id": job_id,
         "character_id": reply.get("character_id"), "usage": usage_of(reply, job), "saved": saved,
         "balance_after": left})
    print(f"  {call['id']}: {len(saved)} file(s), usage {usage_of(reply, job)}, {left:.0f} left")


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
            if call["endpoint"] in PRO_WITH_REFS and not used and not call.get("no_refs_reason"):
                raise Refused(f"{call['id']}: a Pro call without approved references needs a no_refs_reason")
    except Refused as error:
        print(f"refused: {error}", file=sys.stderr)
        return 1
    pending = [c for c in calls if state.get((concept, c["id"]), {}).get("status") != "completed"]
    estimate = sum(c.get("estimate", 0) for c in pending)
    try:
        sub = pixellab.balance()["subscription"]
    except (keys.KeyMissing, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 1
    config = json.loads(budget.CONFIG.read_text())
    pace = budget.pacing(float(sub["total"]), float(sub["generations"]), dt.date.today(), config)
    for c in calls:
        mark = "done" if c not in pending else f"~{c.get('estimate', 0)}"
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
    for call in pending:
        try:
            if (concept, call["id"]) not in state:
                submit(concept, call, refs, state)
            finish(concept, call, state)
        except (Refused, RuntimeError) as error:
            print(f"  {call['id']}: {error}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
