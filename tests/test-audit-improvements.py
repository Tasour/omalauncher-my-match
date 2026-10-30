#!/usr/bin/env python3
"""Static guards for the improvements derived from the 2026-10-28 audit.

These tests complement the behavioural fixtures in test-games.sh. They are
intentionally cheap and offline: each improvement must leave a trace that can
be checked without a phone or network.
"""
from pathlib import Path
import os
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

    # I02 - measurement scripts take the host from OMA_BASE or a local file,
    # validate it, and never interpolate it into a shell command.
    private_ip = re.compile(r"\b(?:192\.168|10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b")
    suffixes = {".sh", ".owl", ".md", ".html", ".py", ".yml", ".yaml"}
    text_files = [path for path in ROOT.rglob("*")
                  if path.is_file() and path.suffix in suffixes and ".git" not in path.parts]
    ip_hits = [str(path.relative_to(ROOT)) for path in text_files
               if private_ip.search(path.read_text(encoding="utf-8", errors="ignore"))]
    check("I02 LAN IP removed", not ip_hits, ", ".join(ip_hits))

    host_scripts = [ROOT / "scripts" / name for name in (
        "fix-v59.sh", "guest-ab-measure.sh", "guest-ab-wrapper.sh", "guest-update-widget.sh")]
    host_widgets = [ROOT / "widget" / name for name in (
        "ab-measure.owl", "ab-wrapper.owl", "fix-v59.owl")]
    host_aware = host_scripts + host_widgets
    validation = "grep -Ex '^https?://[A-Za-z0-9._:-]+$'"
    check("I02 host override", len(host_aware) == 7,
          f"{len(host_aware)} fichier(s) OMA_BASE")
    check("I02 host validation",
          all(validation in path.read_text(encoding="utf-8") for path in host_aware))
    check("I02 no command injection",
          all('nohup sh -c \'curl -fsSL "$1/scripts/' in path.read_text(encoding="utf-8")
          for path in host_widgets))
    html = (ROOT / "scripts" / "guest-ab.html").read_text(encoding="utf-8")
    check("I02 guest command carries host", "OMA_BASE='${location.origin}'" in html)

    # I03 - French copy uses the accented word.
    check("I03 French typography", 'team:"équipe"' in text and 'team:"equipe"' not in text)

    # I04 - the standings visibility toggle survives a restart.
    check("I04 showTables persisted", bool(re.search(r"state showTables=(?:true|false)\s+persist", text)))

    # I05 - the tile list is bounded, the full screen keeps everything.
    check("I05 tile bounded",
          "tileRows=compactMode?5" in text
          and "let upTile=count(upShow)<=tileRows?upShow:upShow.take(tileRows)" in text
          and "for g in upTile key g.id" in text
          and "for g in upShow key g.id" not in text)
    check("I05 hidden count shown", '" +"+(count(upShow)-count(upTile))' in text)

    # I06 - a first launch without teams does not fetch every standings table.
    first_scope = "TABLES=\"eng.1 esp.1 ger.1 ita.1 fra.1 uefa.champions uefa.europa uefa.europa.conf\""
    check("I06 standings first launch", first_scope in text and 'TABLES="$TABLESALL"' not in text)

    # I07 - source budgets cover the modelled worst case.
    check("I07 scheds timeout",
          "source scheds=cmd(" in text and 'every 24h json timeout 300s status' in text)
    check("I07 standings timeout",
          'source standings=cmd("bash -c ${sh(standingsScript)}")every 6h json timeout 300s status' in text)
    check("I07 teamsDb timeout",
          'every 168h json timeout 900s status' in text and '--connect-timeout 3 -fsm 6 -o "$dltmp"' in text)

    check("I11 multi-league teams",
          "leagues: $lgs" in text and "t.leagues" in text
          and "on teamsDb first" in text and "league:(db.find" in text
          and "(teamsDb.out??[]).filter(d=>d.key==" in text)

    # I11 - rivals and history follow the selected team's league, not a whitelist.
    check("I11 no rival whitelist", "rivLgs" not in text and '"fifa.friendly"' in text)
    def has(name, token):
        start = re.search(rf"^source {name}=", text, re.M)
        if not start:
            return False
        nxt = re.search(r"\n(?:source|let|state|on|at|every|when|screen|component)\b", text[start.end():])
        end = start.end() + (nxt.start() if nxt else len(text) - start.end())
        return token in text[start.start():end]
    check("I11 dynamic league lists",
          all(has(name, "WANTLG") and has(name, "ALLLG") for name in ("extra", "nextup", "histfull")))
    check("I11 league tags", text.count('"ned.1"') >= 3 and text.count("printf 'NED'") >= 3)
    check("I11 supported list",
          "let supportedLeagues=" in text and text.count("ALLLG=") >= 3
          and "supportedLeagues.any(x=>x==l)" in text)
    check("I11 rivals next excludes my teams",
          "!(g.squads??[]).any(s=>favAbbrs.any(a=>a==s))" in text)

    check("I11 selected team keeps all results",
          'team!="ALL"?pastA.sortBy(g=>g.at)' in text and "let shown1=baseF" in text)

    # I12 - aggregate caches carry schema/version/TTL/expiry metadata.
    check("I12 cache metadata helpers",
          text.count("cvalid()") >= 6 and text.count("cmark ") >= 10 and 'cstale "$cache"' in text)
    check("I12 cache expiry", '"exp":%s' in text and "cstale ~/.cache/espn-extra.json" in text)
    check("I12 games and season caches",
          "CACHE=~/.cache/espn-games.json" in text and 'cmark "$CACHE" 604800' in text
          and 'cmark "$cache" 2592000' in text)

    # I13 - crests download to a private temp file under a per-file lock.
    check("I13 atomic crest downloads",
          '-o "$d/$f"' not in text and text.count('mkdir "$dlock"') == 7
          and text.count('mv "$dltmp" "$d/$f"') == 7 and ".*.lock' -mmin +15" in text)

    # I14 - exponential retries, Retry-After and a little per-source jitter.
    retry_lines = [line for line in text.splitlines() if "--retry " in line]
    active_retries = [line for line in retry_lines if "--retry 0" not in line]
    check("I14 retry backoff",
          len(active_retries) >= 9
          and all("--retry-delay 0" in line and "--retry-connrefused" in line for line in active_retries)
          and text.count("--retry-max-time") >= len(active_retries))
    check("I14 request jitter", text.count("od -An -N1 -tu1 /dev/urandom") == 9)

    # I15 - live polling only carries the heavy script while a match window is open.
    live_idx = text.find("let liveWin=")
    check("I15 conditional live source",
          live_idx > 0 and text.find("source now=clock", 0, live_idx) > 0
          and "let liveCmd=liveWin?" in text and "source liveM=cmd(liveCmd)" in text
          and "source liveIdx=file(" in text and "now-10800" in text
          and '"printf ' in text and '\\"items\\":[],\\"at\\":0' in text)

    # I16 - ESPN round numbers win over the estimate.
    check("I16 ESPN rounds preferred", 'let rdt=rd!=""?rd:' in text and 'get(rounds,g.id,"")' in text)
    # I17 - postponed/cancelled matches are kept and named.
    check("I17 match status wording",
          'postponed:"reporté"' in text and 'let special=contains(gdet' in text
          and 'g.at>now-7200||contains(lower(g.detail' in text)
    check("I17 two-leg aggregate",
          "aggH:" in text and "aggDone:" in text and "S.agg+" in text and 'agg:"cumul "' in text)

    # I19 - tables compose only when asked for (persisted choice).
    check("I19 tables on demand", "state showTables=false persist" in text)
    # I20 - crest images carry an accessible name.
    check("I20 crest labels", text.count("label:name") >= 3 and 'component Crest(' in text and 'component BannerLogo(' in text)
    # I21 - live and zones carry text, not only colour.
    check("I21 live and zone text", "isLive?S.liveWord" in text and 'tm.zlabel??""' in text)
    # I22 - readable typographic floor.
    check("I22 typographic floor", 'uiSize=="S"?12' in text and "fontSize:10;" not in text)
    # I23 - score and round widths follow the font size.
    check("I23 dynamic widths", 'width:max(18,len((hm.score' in text and 'width:max(30,fz*2)' in text)
    # I24 - the tile minimum fits the header and five teams.
    check("I24 tile minimum", "minSize:5x4" in text)
    # I25 - one membership scan; base derives from allMine.
    check("I25 single membership predicate",
          text.count("let allMine=") == 1
          and 'let baseRaw=team=="ALL"?allMine' in text
          and "let base=todayOnly?baseRaw.filter" in text)
    # I26 - stable list keys.
    check("I26 stable keys",
          "for t in myTeams key t.key{" in text
          and 'key (tm.abbr??"")+":"+((tm.rank??0)+"")' in text)
    # I31 - language follows the phone; display size stays persisted.
    check("I31 language and settings",
          'state lang=startsWith(lower(lang()),"fr")' in text and 'state uiSize="M"persist' in text)
    # I32/I33 - legal notice and measurement report exist.
    check("I32 license and data notice",
          (ROOT / "LICENSE").exists() and (ROOT / "docs" / "data-notice.md").exists())
    check("I33 measurement report", (ROOT / "docs" / "measurements-v5.10.0.md").exists())

    # PROD-04/PRIV-02: attribution and local-data controls in the settings UI.
    check("I32 about and privacy UI",
          "S.about" in text and 'copy("my-match v5.13.0' in text
          and 'run("rm -rf ~/.cache/espn-*")' in text and "state clearAsk=false" in text)

    # I30 - a development extractor dumps every embedded script.
    dump = ROOT / "scripts" / "dump-widget-scripts.sh"
    dump_text = dump.read_text(encoding="utf-8") if dump.exists() else ""
    check("I30 script extractor",
          dump.exists() and os.access(dump, os.X_OK)
          and all(name in dump_text for name in ("scheds", "teamsDb", "histfull")))

    # N07 - the hero card shows the last head-to-head form.
    check("N07 head-to-head",
          "HID=" in text and "h2h: (([.seasonseries" in text
          and "heroH2H" in text and '"H2H · "' in text)

    check("match centre", "state showDetail=false" in text and "S.detail" in text and "heroH2HObj.info" in text and "S.statsT" in text and "S.timeline" in text and "S.lineupsT" in text and "S.newsT" in text)

    check("H2H instant cache", "source h2hNow=file(" in text and "heroH2HObj" in text and "heroMatch.id?h2hNow" in text)

    check("prefetch source", "let prefetchScript=" in text and "source prefetch=" in text and "prefetchArg" in text)

    check("banner logos high-res",
          "B=~/.cache/espn-logos/banner" in text and "w=160&h=160" in text
          and "dims_ok()" in text and "-ge 160" in text
          and 'cp "$d/$f" "$B/$f"' in text
          and "banner/${logo}" in text and "HL=" in text and "AL=" in text
          and "source bannerLogos" in text)

    # F16-F20: reliability, data and calendar.
    check("F16 prewarm", "state prewarmOn=false persist" in text and "at prewarmAt{" in text and "prewarmAt=now+86400" in text and "S.prewarm" in text)
    check("F17 dedupe matches", "values(groupBy(allRaw" in text and "map(a=>first(a))" in text)
    check("F18 AET/PEN tag", "let extraTag=" in text and '"AET"' in text and 'text:extraTag==""?rdt2' in text)
    check("F19 calendar strip", "let cal=range(7)" in text and "for c in cal" in text)
    check("F20 last H2H result", "heroH2HLast" in text and "h2h.last" in text and '"last H2H:' in text)

    # F11-F15: sharing and personalisation.
    check("F11 copy match", "let heroShare=" in text and "S.copyMatch" in text and "copy(heroShare)" in text)
    check("F12 copy teams", "S.copyTeams" in text and "copy(toJson(myTeams))" in text)
    check("F13 team accent", "hsl(hash(t.abbr)*360" in text)
    check("F14 colour-blind", "state cbMode=false persist" in text and "wide||cbMode" in text and "S.cb" in text)
    check("F15 per-match reveal", "state revealed=[]persist" in text and "!revealed.any" in text and "revealed+[g.id]" in text)

    # F06-F10: display controls.
    check("F06 matchday mode", "state matchdayMode=false persist" in text and "matchdayMode&&matchday" in text and "S.matchday" in text)
    check("F07 compact mode", "state compactMode=false persist" in text and "compactMode?5" in text and "S.compact" in text)
    check("F08 today filter", "state todayOnly=false persist" in text and "todayOnly?baseRaw.filter" in text and "S.todayOnly" in text)
    check("F09 show odds", "state showOdds=true persist" in text and "showOdds&&heroMatch" in text and "S.showOdds" in text)
    check("F10 show form", "state showForm=true persist" in text and "if showForm{BannerForm" in text and "S.showForm" in text)

    # F01-F05: notification controls.
    check("F01 reminder lead", "state leadH=12 persist" in text and "leadH*3600" in text and "S.lead" in text)
    check("F02 quiet hours", "state quietOn=false persist" in text and "quietNow=quietOn" in text and "!quietNow" in text)
    check("F03 daily digest", "state digestOn=false persist" in text and "at digestAt{" in text and "S.dailyTitle" in text and "digestAt=now+86400" in text)
    check("F04 weekly digest", "state weeklyOn=false persist" in text and "S.weekTitle" in text and '=="Mon"' in text)
    check("F05 reset reminders", "S.resetRem" in text and "nextDone=[];kickDone=[]" in text)

    # N01 - goal alerts compare the live source's previous and current scores.
    check("N01 goal flash",
          "on liveM{" in text and 'notify("⚽ "' in text
          and "int(g.home.score" in text and "!spoiler" in text and "allMine.any" in text)

    # N04 - spoiler-free mode hides current scores and result chips.
    check("N04 anti-spoiler",
          "state spoiler=false persist" in text and "let hide=spoiler&&" in text
          and 'text:hide?"–":' in text and "S.spoiler" in text)

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
    check("I08 health visible", all(token in text for token in ["let healthTxt", "let healthShort", "S.degraded", "S.health", "healthLine"]))
    check("I08 error branches", all(token in text for token in ["let gamesErr", "let extraErr", "let nextErr", "S.sourceErr"]))
    check("I08 readers use status.out",
          all(f"{name}.out" in text for name in status_names)
          and "(standings??[])" not in text and "(extra??[])" not in text)
    check("I08 partial failures",
          "let seasonAllErr" in text
          and "count(rivalsTile)==0&&(extraErr||nextErr)" in text
          and "count(euroList)==0&&(extraErr||nextErr||histErr)" in text)

    # I09 - the spinner no longer wakes the widget every second while idle.
    check("I09 conditional spinner tick", "every 1s" not in text and "at spinAt{if spinning{elapsed=elapsed+1;spinAt=spinAt+1}" in text)

    # I10 - one portable offline harness, plus a ready GitHub Actions template.
    ci = ROOT / "scripts" / "ci.sh"
    ci_text = ci.read_text(encoding="utf-8") if ci.exists() else ""
    check("I10 portable CI harness",
          ci.exists() and os.access(ci, os.X_OK) and ("./tests/run.sh" in ci_text or "./tests/run-all.sh" in ci_text))
    workflow = ROOT / ".github" / "workflows" / "ci.yml"
    template = ROOT / "docs" / "ci-workflow.yml"
    template_text = template.read_text(encoding="utf-8") if template.exists() else ""
    check("I10 GitHub Actions template",
          not workflow.exists() and "pull_request" in template_text and "make test" in template_text)

    if FAILED:
        print(f"FAILED: {', '.join(FAILED)}")
        return 1
    print("ALL AUDIT IMPROVEMENT CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
