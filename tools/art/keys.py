"""API keys for the art tools, read at call time and never written anywhere.

A key lives in the macOS login keychain under the service named in SERVICES (the account is
$USER). The user stores it once, typing it at the prompt so it never reaches a file or the
shell history:

    security add-generic-password -a "$USER" -s pixellab-api-key -w

An environment variable of the same tool (PIXELLAB_API_KEY) overrides the keychain, for a
machine without one. Nothing here prints, logs, or returns a key except to the caller that puts
it in a request header; tools/hooks/pre-commit refuses a commit whose staged diff contains one.
"""

import os
import subprocess

SERVICES = {
    "pixellab": "pixellab-api-key",
    "retrodiffusion": "retrodiffusion-api-key",
}


class KeyMissing(RuntimeError):
    pass


def env_name(tool: str) -> str:
    return tool.upper() + "_API_KEY"


def key(tool: str) -> str:
    from_env = os.environ.get(env_name(tool), "").strip()
    if from_env:
        return from_env
    service = SERVICES[tool]
    result = subprocess.run(
        ["security", "find-generic-password", "-a", os.environ.get("USER", ""), "-s", service, "-w"],
        capture_output=True, text=True)
    value = result.stdout.strip()
    if result.returncode != 0 or not value:
        raise KeyMissing(
            f"no {tool} key: run  security add-generic-password -a \"$USER\" -s {service} -w"
            f"  (or set {env_name(tool)})")
    return value
