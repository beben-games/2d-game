#!/usr/bin/env python3
"""The PixelLab REST client of the art pipeline (https://api.pixellab.ai/v2).

    tools/art/pixellab.py balance    the plan, the generations left this period, the USD credits

Every response is JSON; errors name the status and the endpoint, never the key.
"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import keys  # noqa: E402

BASE = "https://api.pixellab.ai/v2"


class ApiError(RuntimeError):
    def __init__(self, message: str, code: int):
        super().__init__(message)
        self.code = code


def request_bytes(method: str, path: str, body: dict | None = None) -> bytes:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    # Unredirected: a redirect to file storage never carries the key.
    req.add_unredirected_header("Authorization", "Bearer " + keys.key("pixellab"))
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:500]
        raise ApiError(f"{method} {path}: HTTP {error.code}: {detail}", error.code) from None


def request(method: str, path: str, body: dict | None = None) -> dict:
    return json.loads(request_bytes(method, path, body))


def balance() -> dict:
    return request("GET", "/balance")


def main(argv: list[str]) -> int:
    if argv[:1] != ["balance"]:
        print(__doc__.strip())
        return 2
    try:
        reply = balance()
    except (keys.KeyMissing, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 1
    sub = reply.get("subscription", {})
    print(f"plan: {sub.get('plan')} ({sub.get('status')})")
    print(f"generations: {sub.get('generations')} of {sub.get('total')} left this period")
    print(f"credits: ${reply.get('credits', {}).get('usd')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
