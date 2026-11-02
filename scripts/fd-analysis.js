#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const home = os.homedir();
const fdPath = path.join(home, '.cache', 'espn-fd.json');
const outPath = path.join(home, '.cache', 'espn-fd-analysis.json');
const syncPath = path.join(home, '.config', 'omalauncher', 'widgets', 'fd-sync.py');

const readJson = p => {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (_) { return null; }
};
const round = (v, d = 2) => {
  const f = 10 ** d;
  return Math.round((Number(v) || 0) * f) / f;
};
const sum = (xs, f) => xs.reduce((a, x) => a + (Number(f(x)) || 0), 0);
const mean = (xs, f) => xs.length ? sum(xs, f) / xs.length : 0;
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const poisson = (lambda, k) => Math.exp(-lambda) * lambda ** k / (() => {
  let r = 1;
  for (let i = 2; i <= k; i++) r *= i;
  return r;
})();
const xpts = (h, a) => {
  let hw = 0, dw = 0;
  for (let i = 0; i <= 8; i++) {
    for (let j = 0; j <= 8; j++) {
      const p = poisson(h, i) * poisson(a, j);
      if (i > j) hw += p;
      else if (i === j) dw += p;
    }
  }
  return 3 * hw + dw;
};
const percentile = (values, value) => {
  const xs = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (!xs.length) return 50;
  const below = xs.filter(x => x < value).length;
  const equal = xs.filter(x => x === value).length;
  return Math.round(100 * (below + equal / 2) / xs.length);
};
const result = m => m.gf > m.ga ? 'V' : m.gf < m.ga ? 'D' : 'N';

const US_LEAGUES = { 'eng.1': 'EPL', 'esp.1': 'La_liga', 'ger.1': 'Bundesliga', 'ita.1': 'Serie_A', 'fra.1': 'Ligue_1' };
const US_ALIASES = {
  'borussia m gladbach': 'BMG',
  'rasenballsport leipzig': 'RBL',
  'parma calcio 1913': 'PAR'
};
const US_CACHE = path.join(home, '.cache', 'understat');
const foldTeam = s => String(s || '')
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .toLowerCase().replace(/[^a-z0-9 ]/g, ' ')
  .replace(/\s+/g, ' ').trim();

function fetchUnderstat(league, year) {
  const p = path.join(US_CACHE, `${league}-${year}.json`);
  let cached = readJson(p);
  try {
    if (cached && Date.now() / 1000 - fs.statSync(p).mtimeMs / 1000 < 12 * 3600) return cached;
  } catch (_) {}
  try {
    fs.mkdirSync(US_CACHE, { recursive: true });
    const txt = execFileSync('curl', [
      '-fsSL', '--compressed', '--max-time', '30',
      '-A', 'Mozilla/5.0',
      '-H', 'X-Requested-With: XMLHttpRequest',
      '-H', `Referer: https://understat.com/league/${league}/${year}`,
      `https://understat.com/getLeagueData/${league}/${year}`
    ], { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, timeout: 40000 });
    fs.writeFileSync(p, txt);
    return JSON.parse(txt);
  } catch (_) {
    return cached;
  }
}

function loadUnderstat(raw) {
  const start = parseInt(String(raw.season || '').slice(0, 4), 10) ||
    (new Date().getMonth() >= 7 ? new Date().getFullYear() : new Date().getFullYear() - 1);
  const index = new Map();
  for (const [name, t] of Object.entries(raw.by_name || {})) {
    if (t && t.abbr) index.set(foldTeam(name), t.abbr);
  }
  for (const t of Object.values(raw.teams || {})) {
    if (!t || !t.abbr) continue;
    index.set(foldTeam(t.name), t.abbr);
    index.set(foldTeam(t.abbr), t.abbr);
  }
  for (const [name, abbr] of Object.entries(US_ALIASES)) index.set(foldTeam(name), abbr);
  const series = {};
  for (const [lg, usLg] of Object.entries(US_LEAGUES)) {
    for (const year of [start, start - 1]) {
      const data = fetchUnderstat(usLg, year);
      if (!data || !data.teams) continue;
      for (const ut of Object.values(data.teams)) {
        const abbr = index.get(foldTeam(ut.title));
        if (!abbr || !raw.teams[abbr]) continue;
        for (const h of (ut.history || [])) {
          const d = String(h.date || '').slice(0, 10);
          if (!d) continue;
          const game = {
            d,
            gf: Number(h.scored) || 0,
            ga: Number(h.missed) || 0,
            xg: Number(h.xG) || 0,
            xga: Number(h.xGA) || 0,
            home: h.h_a === 'h',
            r: h.result === 'w' ? 'V' : h.result === 'l' ? 'D' : 'N'
          };
          if (!series[abbr]) series[abbr] = new Map();
          series[abbr].set(d, game);
        }
      }
    }
  }
  const out = {};
  for (const [abbr, games] of Object.entries(series)) {
    out[abbr] = Array.from(games.values()).sort((a, b) => a.d.localeCompare(b.d));
  }
  return out;
}

function crossings(points, key) {
  const out = [];
  let prev = null;
  points.forEach((p, i) => {
    if (i < 4) return;
    const v = key(p);
    if (prev != null && Math.abs(v) > 0.03 && Math.abs(prev) > 0.03 && Math.sign(v) !== Math.sign(prev)) {
      out.push({ i, d: p.d, dir: v > prev ? 'up' : 'down' });
    }
    prev = v;
  });
  return out;
}

function signalFor(m) {
  if (m.xgd5 <= -0.45 && m.gd5 < m.xgd5 - 0.15) return { label: 'Alerte crise', tone: 'bad' };
  if (m.xgd5 <= -0.35) return { label: 'Tendance négative', tone: 'warn' };
  if (m.gd5 < m.xgd5 - 0.30) return { label: 'Sous-performance', tone: 'warn' };
  if (m.gd5 > m.xgd5 + 0.30) return { label: 'Surperformance', tone: 'good' };
  if (m.xgd5 >= 0.35 && m.gd5 >= 0) return { label: 'Solide', tone: 'good' };
  return { label: 'Stable', tone: 'neutral' };
}

let raw = readJson(fdPath);
const hasSeries = raw && raw.teams && Object.values(raw.teams).some(t => t && Array.isArray(t.series) && t.series.length);
const fresh = hasSeries && (Date.now() / 1000 - (Number(raw.updated) || 0) < 12 * 3600);
if (!fresh) {
  try {
    execFileSync('python3', [syncPath], { stdio: 'ignore', timeout: 90000 });
  } catch (_) {}
  raw = readJson(fdPath) || raw;
}
if (!raw || !raw.teams) process.exit(0);

const understat = loadUnderstat(raw);
const teams = Object.values(raw.teams).filter(t => t && t.abbr && Array.isArray(t.series) && t.series.length);
for (const t of teams) {
  const us = understat[t.abbr];
  if (us && us.length) {
    const fdByDate = new Map(t.series.map(m => [m.d, m]));
    t.series = us.map(m => {
      const f = fdByDate.get(m.d) || {};
      return { ...m, opp: f.opp || '', opp_abbr: f.opp_abbr || '', sh: f.sh || 0, sot: f.sot || 0, cards: f.cards || 0 };
    });
    t.src = 'Understat';
  } else {
    t.src = 'Football-Data';
  }
}
const metrics = {};
for (const t of teams) {
  const s = t.series.slice().sort((a, b) => String(a.d).localeCompare(String(b.d)));
  const g = s.slice(-5);
  const sh = mean(g, x => x.sh);
  const sot = mean(g, x => x.sot);
  metrics[t.abbr] = {
    xg5: mean(g, x => x.xg),
    xga5: mean(g, x => x.xga),
    gd5: mean(g, x => x.gf - x.ga),
    xgd5: mean(g, x => x.xg) - mean(g, x => x.xga),
    xpts5: mean(g, x => xpts(x.xg, x.xga)),
    goals5: mean(g, x => x.gf),
    fin5: sum(g, x => x.gf - x.xg),
    sh5: sh,
    sot5: sot,
    sotPct: sh ? 100 * sot / sh : 0,
    cards5: mean(g, x => x.cards),
    xgPerShot: sh ? mean(g, x => x.xg) / sh : 0,
    form: g.slice().reverse().map(result).join(''),
    games5: g.length,
    n: s.length
  };
}

const out = {
  updated: Math.floor(Date.now() / 1000),
  season: raw.season || null,
  teams: {},
  by_name: {},
  scatter: [],
  meta: {}
};

for (const t of teams) {
  const s = t.series.slice().sort((a, b) => String(a.d).localeCompare(String(b.d)));
  const m = metrics[t.abbr];
  const g = s.slice(-5);
  const prev = s.slice(-10, -5);
  const prevXgd = prev.length >= 3 ? mean(prev, x => x.xg) - mean(prev, x => x.xga) : null;
  const trend = prevXgd == null ? null : m.xgd5 - prevXgd;

  const rolls = s.slice(-20).map((match, index, recent) => {
    const w = recent.slice(Math.max(0, index - 4), index + 1);
    return {
      d: match.d,
      o: match.opp_abbr || match.opp || '',
      r: result(match),
      gd: round(mean(w, x => x.gf - x.ga)),
      xd: round(mean(w, x => x.xg) - mean(w, x => x.xga)),
      xg: round(mean(w, x => x.xg)),
      xa: round(mean(w, x => x.xga))
    };
  });
  const gapCrosses = crossings(rolls, p => p.gd - p.xd);
  const zeroCrosses = crossings(rolls, p => p.xd);
  const lastCross = gapCrosses.length ? gapCrosses[gapCrosses.length - 1] : null;
  const lastZeroCross = zeroCrosses.length ? zeroCrosses[zeroCrosses.length - 1] : null;
  const back = rolls.length > 5 ? rolls[rolls.length - 6] : rolls[0];
  const trendXgd = back ? m.xgd5 - back.xd : null;
  const trendGd = back ? m.gd5 - back.gd : null;
  const signal = signalFor(m);

  const peers = teams.filter(p => p.lg === t.lg && p.n >= 3);
  const refs = peers.length >= 5 ? peers : teams;
  const values = key => refs.map(p => metrics[p.abbr][key]);

  out.teams[t.abbr] = {
    abbr: t.abbr,
    name: t.name,
    lg: t.lg,
    n: m.n,
    xg5: round(m.xg5),
    xga5: round(m.xga5),
    gd5: round(m.gd5),
    xgd5: round(m.xgd5),
    gap5: round(m.gd5 - m.xgd5),
    xpts5: round(m.xpts5),
    goals5: round(m.goals5),
    fin5: round(m.fin5),
    sh5: round(m.sh5),
    sot5: round(m.sot5),
    sotPct: round(m.sotPct, 1),
    cards5: round(m.cards5),
    xgPerShot: round(m.xgPerShot, 3),
    form: m.form,
    trend: trend == null ? null : round(trend),
    trendXgd: trendXgd == null ? null : round(trendXgd),
    trendGd: trendGd == null ? null : round(trendGd),
    seriesN: Math.min(s.length, 20),
    src: t.src,
    signal: signal.label,
    tone: signal.tone,
    crossings: gapCrosses,
    lastCross,
    zeroCrossings: zeroCrosses,
    lastZeroCross,
    rolls,
    axes: {
      att: percentile(values('xg5'), m.xg5),
      def: 100 - percentile(values('xga5'), m.xga5),
      vol: percentile(values('sh5'), m.sh5),
      acc: percentile(values('sotPct'), m.sotPct),
      fin: percentile(values('fin5'), m.fin5),
      xpts: percentile(values('xpts5'), m.xpts5)
    }
  };

  out.scatter.push({
    a: t.abbr,
    n: t.name,
    l: t.lg,
    x: round(m.xg5),
    y: round(m.xga5)
  });
}

const xgMax = Math.max(1, ...out.scatter.map(p => p.x));
const xgaMax = Math.max(1, ...out.scatter.map(p => p.y));
out.meta = {
  xgMax: round(xgMax + 0.15),
  xgaMax: round(xgaMax + 0.15),
  teams: out.scatter.length
};

for (const [name, t] of Object.entries(raw.by_name || {})) {
  if (t && out.teams[t.abbr]) out.by_name[name] = t.abbr;
}

const tmp = outPath + '.tmp';
fs.writeFileSync(tmp, JSON.stringify(out));
fs.renameSync(tmp, outPath);
console.log(JSON.stringify({ teams: out.scatter.length, season: out.season }));
