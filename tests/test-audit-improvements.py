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
    check("I05 tile compact",
          "upTile=compactMode||(matchdayMode&&matchday)?upShow.sortBy(g=>g.at).take(5):upShow.sortBy(g=>g.at)" in text
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
          "let shown1=baseF" in text and "count(pastA)<=5?pastA" in text)

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
    check("I19 tables toggle", "state showTables=true persist" in text and "onTap:showTables=!showTables" in text)
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
          "S.apropos" in text and 'copy("my-match v5.16.0' in text
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

    check("match centre", "state showDetail=false" in text and "S.preview" in text and "heroH2HObj.info" in text and "S.statsT" in text and "S.timeline" in text and "S.lineupsT" in text and "S.newsT" in text)

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
    check("F06 matchday mode", "state matchdayMode=false" in text and "matchdayMode&&matchday" in text and "S.matchday" in text)
    check("F07 compact mode", "state compactMode=false" in text and "compactMode||(matchdayMode&&matchday)?upShow.sortBy(g=>g.at).take(5)" in text and "S.compact" in text)
    check("F08 today filter", "state todayOnly=false" in text and "todayOnly?baseRaw.filter" in text and "S.todayOnly" in text)
    check("F09 show odds", "state showOdds=true persist" in text and "showOdds&&heroMatch" in text and "S.showOdds" in text)
    check("F10 show form", "state showForm=true persist" in text and "if showForm{BannerForm" in text and "S.showForm" in text)

    # Pre-match page.
    check("Pre-match page", "component MatchPage" in text and "if showDetail{MatchPage{}}else{" in text and "previewTabs" in text)
    check("Pre-match opens from banner", 'onTap:{showDetail=true;previewTab="overview";screen()}' in text)
    check("Pre-match overview", "previewPPG" in text and "previewProjection" in text and "previewKeys" in text and "previewNext" in text)
    check("Pre-match tabs", 'previewTab=="odds"' in text and 'previewTab=="stats"' in text and 'previewTab=="h2h"' in text and 'previewTab=="squads"' in text and 'previewTab=="news"' in text and 'previewTab=="travel"' in text)

    # National cups: data, tags and stages.
    for cup in ("eng.fa", "eng.league_cup", "esp.copa_del_rey", "ger.dfb_pokal", "ita.coppa_italia"):
        check(f"National cup {cup}", f'"{cup}"' in text)
    check("National cup tags", 'printf \'FA\'' in text and 'printf \'CDR\'' in text and 'printf \'DFB\'' in text and 'printf \'CI\'' in text)
    check("National cup stages", '"qualifying-round":"Tour préliminaire"' in text and '"fourth-round":"4e tour"' in text)

    # Cup brackets: national cups and knockout fallback.
    check("CDF bracket data", '"fra.coupe_de_france"' in text and "stage: (.season.slug" in text and text.count("stage: (.season.slug") >= 5)
    check("CDF bracket view", "let cupStages=" in text and "for st in cupStages" in text and "S.bracket" in text)
    check("UCL bracket fallback", "knockAll=values(groupBy(flatten([knock.out??[],all.filter" in text and 'cupRoundIds.any(r=>r==(g.stage??""))' in text)
    check("CDF round labels", '"round-of-64":"32es de finale"' in text and '"round-of-32":"16es de finale"' in text)

    # Lot 8: data.
    check("DN25 archive export", "let archiveTxt=" in text and "copy(archiveTxt)" in text and "S.exportT" in text)
    check("DN23 leaders", "leaders: ([" in text and "S.leadersT" in text and "heroH2HObj.leaders" in text)
    check("DN22 injuries", "injuries: ([" in text and "S.injuriesT" in text and "heroH2HObj.injuries" in text)

    # Lot 9: travel / low data.
    check("AT20 travel pack", "let travelTxt=" in text and "copy(travelTxt)" in text and "S.travel" in text)
    check("AT18 offline age", "let offlineTxt=" in text and "S.offline" in text and "fmtAgo(lastAt,now)" in text)
    check("AT22 low data", "state lowData=false persist" in text and "lowData?-1" in text and "S.lowData" in text)

    # Lot 10: finishing.
    check("HF23 banter", "let banterTxt=" in text and "copy(banterTxt)" in text)
    check("HF24 config import", "state importRaw" in text and "parseJson(importRaw)" in text and "S.importT" in text)
    check("AT25 retry per source", "for h in healthList" in text and "Button{text:S.retry;color:soft;onTap:refresh()}" in text)

    # Lot 7: personalisation.
    check("HF01 per-club mute", "state muteTeams=[] persist" in text and "S.alertsByClub" in text and text.count("!muteTeams.any") >= 7)
    check("N15 explicit rivals", "state rivalsCsv=" in text and "let rivalsList=split" in text and "count(rivalsList)>0" in text)
    check("HF25 team colours", "state teamColors=true persist" in text and "teamColors?hsl" in text)

    # Lot 6: match context.
    check("HF rest days", "let previewRest=" in text and '"repos ":"rest "' in text)
    check("DN08 home/away form", "let previewHeroHomeForm=" in text and "let previewHeroAwayForm=" in text and 'formHomeShort' in text)

    # Lot 5: casual/setup and pause.
    check("CU02 trust line", "S.trust" in text and "Données ESPN" in text)
    check("CU03 picker retry", "S.retry" in text and "Button{text:S.retry;color:soft;onTap:refresh()" in text)
    check("CU04 search hint", "S.searchHint" in text and "onTap:query=\"\"" in text)
    check("CU15 pause alerts", "state pauseUntil=0 persist" in text and "S.pauseAlerts" in text and text.count("now>pauseUntil") >= 6)

    # Lot 4: accessibility quick wins.
    check("AT03 high contrast", "state hcMode=false persist" in text and "hcMode?foreground" in text and "S.hc" in text)
    check("AT12 relative dates", "let dayRel=" in text and "S.dayToday" in text and "S.dayTomorrow" in text)
    check("AT07 arrow labels", "Button{text:S.prev;width:56;padding:6" in text and "S.nextBtn" in text)
    check("AT10 tab targets", "Button{text:m.short;weight:1;padding:6" in text)

    # Lot 3: richer live alerts from scoreboard details.
    check("HF02 goal scorer", 'plays: [($c.details' in text and "g1.who" in text and 'notify("⚽ "' in text)
    check("HF03 HT/FT", 'S.half+" · "' in text and 'S.full+" · "' in text and "ht!=null&&!quietNow&&!spoiler" in text and "count(ft)>0&&!ftQuiet&&!spoiler" in text)
    check("HF04 red card", "S.redCard" in text and "redM" in text and "p.red" in text)

    # Standings and fixtures must be visible after the filter-era upgrades.
    check("standings/fixtures migration",
          "state uiSchema=0 persist" in text and "when uiSchema<1" in text
          and "showTables=true;todayOnly=false;daySel=\"\"" in text)
    check("tile mode chip",
          "compactMode||matchdayMode" in text
          and "{compactMode=false;matchdayMode=false}" in text
          and "(compactMode?S.compact:S.matchday)" in text)

    check("tile all upcoming",
          "upTile=compactMode||(matchdayMode&&matchday)?upShow.sortBy(g=>g.at).take(5):upShow.sortBy(g=>g.at)" in text
          and "take(5).sortBy(g=>g.at)" in text
          and 'S.recent+(count(pastA)>count(pastTake)' in text
          and "tileRows" not in text)

    check("tile chronological",
          text.find("for g in pastTake key g.id") != -1
          and text.find("for g in upTile key g.id") != -1
          and text.find("for g in pastTake key g.id") < text.find("for g in upTile key g.id"))

    check("fixtures block under hero",
          "for g in upShow.take(8)" in text and "S.upcomingHdr" in text)

    # Regression: a day/today filter must never silently hide every fixture.
    check("fixtures filter fallback",
          "state todayOnly=false\n" in text and 'state daySel=""' in text
          and "let filterOn=todayOnly||daySel!=\"\"" in text
          and ':(daySel!=""?baseRaw.filter' in text
          and text.count('{todayOnly=false;daySel=""}') >= 2
          and 'S.noMatchDay+" · "+S.clearFilter' in text)

    # Simulated user needs — Lot 1.
    check("DN05 full H2H list", "h2hAll" in text and "heroH2HObj.h2h" in text and "list??[]" in text)
    check("DN16 no-vig", "let noVig=" in text and "noVigTxt" in text)
    check("DN17 odds movement", "let moveH=" in text and "moveTxt" in text and "▼" in text)
    check("DN24 news ticker", "heroH2HObj.news[0].h" in text and "S.newsT" in text)

    check("CU18 plain status", 'fail:"Scores peut-être en retard"' in text and 'sourceErr:"Source indisponible"' in text)
    check("CU23 day filter", 'state daySel=""' in text and "key c.k" in text and "daySel==c.k" in text and '==daySel)' in text)
    check("AT19 fiche freshness", "fmtAgo(heroH2HObj.ts,now)" in text and "S.preview" in text)
    check("HF08 tile live chip", "let liveBadge=" in text and '"● "+S.liveWord' in text and 'if liveBadge!=""' in text and "S.next+" not in text)

    # Ergonomics: settings is a dedicated view with sections and a compact header.
    check("ergonomic settings",
          "S.general" in text and "S.affichage" in text and "S.rappels" in text
          and "S.partage" in text and "S.donnees" in text and "S.apropos" in text
          and "statusTxt" in text and "Button{text:showSettings?S.close:S.settings" in text
          and text.count("if !showSettings{") >= 2)
    check("fiche link in hero", 'onTap:{showDetail=true;previewTab="overview";screen()}' in text and "S.preview" in text)

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
