#!/usr/bin/env python3
"""Static guards for the improvements derived from the 2026-10-28 audit.

These tests complement the behavioural fixtures in test-games.sh. They are
intentionally cheap and offline: each improvement must leave a trace that can
be checked without a phone or network.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
WIDGET = ROOT / "widget" / "my-match.optimized.owl"
FAILED = []


def check(name, condition, detail=""):
    if condition:
        print(f"PASS {name}")
    else:
        print(f"FAIL {name}{': ' + detail if detail else ''}")
        FAILED.append(name)


def main():
    text = WIDGET.read_text(encoding="utf-8")

    # I01 - every runtime curl is HTTPS-only, bounded and non-redirecting.
    curl_lines = [
        line for line in text.splitlines()
        if "curl " in line and not line.lstrip().startswith("#")
    ]
    required = ("--proto '=https'", "--max-redirs 0", "--max-filesize", "--connect-timeout")
    bad = [line.strip() for line in curl_lines if not all(flag in line for flag in required)]
    check("I01 curl hardening", not bad and bool(curl_lines), f"{len(bad)} ligne(s) non durcie(s)")

    if FAILED:
        print(f"FAILED: {', '.join(FAILED)}")
        return 1
    print("ALL AUDIT IMPROVEMENT CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
