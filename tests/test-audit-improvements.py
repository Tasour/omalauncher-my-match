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

    # I03 - French copy uses the accented word.
    check("I03 French typography", 'team:"équipe"' in text and 'team:"equipe"' not in text)

    # I04 - the standings visibility toggle survives a restart.
    check("I04 showTables persisted", bool(re.search(r"state showTables=true\s+persist", text)))

    # I05 - the tile list is bounded, the full screen keeps everything.
    check("I05 tile bounded", "let upTile=" in text and "for g in upTile key g.id" in text and "for g in upShow key g.id" not in text)

    # I06 - a first launch without teams does not fetch every standings table.
    first_scope = "TABLES=\"eng.1 esp.1 ger.1 ita.1 fra.1 uefa.champions uefa.europa uefa.europa.conf\""
    check("I06 standings first launch", first_scope in text and 'TABLES="$TABLESALL"' not in text)

    # I07 - source budgets cover the modelled worst case.
    check("I07 scheds timeout", '""")every 24h json timeout 240s' in text)
    check("I07 standings timeout", 'source standings=cmd("bash -c ${sh(standingsScript)}")every 6h json timeout 180s' in text)
    check("I07 teamsDb timeout", '""")every 168h json timeout 600s' in text and '-fsm 5 -o "$d/$f"' in text)

    # I08 - every heavy source exposes status and the UI shows source health.
    def source_block(name):
        start = re.search(rf"^source {name}=", text, re.M)
        if not start:
            return ""
        nxt = re.search(r"\n(?:source|let|state|on|at|every|when|screen|component)\b", text[start.end():])
        end = start.end() + (nxt.start() if nxt else len(text) - start.end())
        return text[start.start():end]

    status_names = ["seasonAll", "scheds", "standings", "teamsDb", "extra", "liveM", "knock", "nextup", "histfull"]
    missing_status = [name for name in status_names if " status" not in source_block(name)]
    check("I08 source status", not missing_status, ", ".join(missing_status))
    check("I08 health visible", all(token in text for token in ["let healthTxt", "S.degraded", "S.health", "healthLine"]))

    # I09 - the spinner no longer wakes the widget every second while idle.
    check("I09 conditional spinner tick", "every 1s" not in text and "at spinAt{" in text and "spinAt=now+1" in text)

    if FAILED:
        print(f"FAILED: {', '.join(FAILED)}")
        return 1
    print("ALL AUDIT IMPROVEMENT CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
