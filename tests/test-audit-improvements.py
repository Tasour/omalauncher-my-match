#!/usr/bin/env python3
"""Static guards for the improvements derived from the 2026-10-28 audit.

These tests complement the behavioural fixtures in test-games.sh. They are
intentionally cheap and offline: each improvement must leave a trace that can
be checked without a phone or network.
"""
from pathlib import Path
import re
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

    # I02 - measurement scripts take the host from OMA_BASE or a local file.
    private_ip = re.compile(r"\b(?:192\.168|10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b")
    host_files = [*sorted((ROOT / "scripts").glob("*.sh")), *sorted((ROOT / "widget").glob("*.owl"))]
    ip_hits = [str(p.relative_to(ROOT)) for p in host_files if private_ip.search(p.read_text(encoding="utf-8", errors="ignore"))]
    host_aware = [p for p in host_files if "OMA_BASE" in p.read_text(encoding="utf-8", errors="ignore")]
    check("I02 LAN IP removed", not ip_hits, ", ".join(ip_hits))
    check("I02 host override", len(host_aware) >= 4, f"{len(host_aware)} script(s) OMA_BASE")

    if FAILED:
        print(f"FAILED: {', '.join(FAILED)}")
        return 1
    print("ALL AUDIT IMPROVEMENT CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
