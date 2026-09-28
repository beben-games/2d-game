#!/usr/bin/env python3
"""The PixelLab allowance against the billing period: what this art session may spend.

    tools/art/budget.py            the live balance (one free API call) and the pacing
    tools/art/budget.py --left N   the pacing for N generations left, no API call

The period renews on art/budget.json's `renewal_day`. The burn line is the share of the
allowance the period's elapsed days would spend at an even pace; a session may spend up to the
line `lead_days` ahead, so a gap between sessions is caught up and nothing is dumped on day one.
From `sink_days` before the renewal the whole balance is spendable (the sink: it expires).
"""

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
CONFIG = HERE.parent.parent / "art" / "budget.json"


def add_month(day: dt.date, renewal_day: int) -> dt.date:
    year, month = (day.year + 1, 1) if day.month == 12 else (day.year, day.month + 1)
    return dt.date(year, month, min(renewal_day, 28))


def period(today: dt.date, renewal_day: int) -> tuple[dt.date, dt.date]:
    this_month = dt.date(today.year, today.month, min(renewal_day, 28))
    if today >= this_month:
        return this_month, add_month(this_month, renewal_day)
    previous = dt.date(today.year - 1, 12, 1) if today.month == 1 else dt.date(today.year, today.month - 1, 1)
    start = dt.date(previous.year, previous.month, min(renewal_day, 28))
    return start, this_month


def pacing(total: float, left: float, today: dt.date, config: dict) -> dict:
    start, end = period(today, config["renewal_day"])
    days = (end - start).days
    elapsed = (today - start).days + 1
    spent = total - left
    line = total * min(elapsed, days) / days
    ahead = total * min(elapsed + config["lead_days"], days) / days
    sink_opens = end - dt.timedelta(days=config["sink_days"])
    in_sink = today >= sink_opens
    allowance = left if in_sink else max(0.0, min(left, ahead - spent))
    return {
        "start": start, "end": end, "day": elapsed, "days": days, "spent": spent, "left": left,
        "total": total, "line": line, "allowance": allowance, "sink_opens": sink_opens,
        "in_sink": in_sink,
        "split": {name: round(total * share) for name, share in config["split"].items()},
    }


def report(p: dict) -> str:
    split = ", ".join(f"{name} {amount}" for name, amount in p["split"].items())
    lines = [
        f"period {p['start']} to {p['end']} (renews), day {p['day']} of {p['days']}",
        f"left {p['left']:.0f} of {p['total']:.0f} (spent {p['spent']:.0f}; the even-pace line today is {p['line']:.0f})",
        f"this session may spend up to {p['allowance']:.0f}",
        ("the sink is open: everything left expires at the renewal" if p["in_sink"]
            else f"the sink opens {p['sink_opens']}"),
        f"split of the period: {split}",
    ]
    if not p["in_sink"] and p["spent"] < p["line"] - p["total"] * 7 / p["days"]:
        lines.append("behind the line by more than a week: schedule art sessions")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--left", type=float, help="generations left (skips the API call)")
    parser.add_argument("--total", type=float, default=5000.0, help="the period's total with --left")
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today())
    args = parser.parse_args(argv)
    config = json.loads(CONFIG.read_text())
    if args.left is not None:
        total, left = args.total, args.left
    else:
        import keys
        import pixellab
        try:
            sub = pixellab.balance()["subscription"]
        except (keys.KeyMissing, RuntimeError) as error:
            print(error, file=sys.stderr)
            return 1
        total, left = float(sub["total"]), float(sub["generations"])
    print(report(pacing(total, left, args.today, config)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
