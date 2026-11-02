import csv, json, os, re, sys, unicodedata, urllib.request, datetime, difflib, math
from pathlib import Path
home=Path.home(); cache=home/'.cache/fd'; cache.mkdir(parents=True,exist_ok=True)
teams=[]
for fn in ['espn-extra.json','espn-games.json']:
    try:
        for m in json.loads((home/'.cache'/fn).read_text()):
            for side in ('home','away'):
                t=m.get(side)
                if t and t.get('abbr'):
                    teams.append({'name':t.get('name') or t['abbr'],'short':t.get('name') or t['abbr'],'display':t.get('name') or t['abbr'],'abbr':t['abbr'],'league':m.get('league'),'leagues':[m.get('league')]})
    except Exception:
        pass
LEAGUES={'eng.1':'E0','esp.1':'SP1','ger.1':'D1','ita.1':'I1','fra.1':'F1','fra.2':'F2'}
now=datetime.datetime.now(); sy=now.year if now.month>=8 else now.year-1; code=f'{sy%100:02d}{(sy+1)%100:02d}'
def norm(s):
    s=unicodedata.normalize('NFKD',s or '').encode('ascii','ignore').decode().lower()
    s=re.sub(r'[^a-z0-9 ]',' ',s); s=re.sub(r'\b(fc|cf|ac|afc|sc|club|football|the)\b',' ',s)
    return re.sub(r'\s+',' ',s).strip()
manual={
 'paris sg':'PSG','paris saint germain':'PSG','man city':'MNC','man united':'MUN','nott m forest':'NFO','nottm forest':'NFO','sheffield utd':'SHU','sheffield united':'SHU','newcastle utd':'NEW','tottenham':'TOT','wolves':'WOL','brighton':'BHA','west ham':'WHU','west brom':'WBA','crystal palace':'CRY','man united':'MUN','man utd':'MUN','bayern munich':'BAY','bayern':'BAY','fc bayern':'BAY','ath madrid':'ATM','ath bilbao':'ATH','real madrid':'RMA','sociedad':'RSO','sp gijon':'SPG','sporting gijon':'SPG','bayern munich':'FCB','borussia dortmund':'BVB','m gladbach':'BMG','b monchengladbach':'BMG','ein Frankfurt':'SGE','eintracht frankfurt':'SGE','leverkusen':'B04','ac milan':'MIL','inter':'INT','internazionale':'INT','juventus':'JUV','roma':'ROMA','lazio':'LAZ','napoli':'NAP','paris fc':'PAR','st etienne':'ASSE','saint etienne':'ASSE','marseille':'OM','lyon':'LYON','lille':'LIL','monaco':'MON','nice':'NIC','rennes':'REN','lens':'LEN','nantes':'NAN','strasbourg':'STR','toulouse':'TOU','brest':'BRE','auxerre':'AUX','angers':'ANG','le havre':'HAC','reims':'REI','montpellier':'MON','grenoble':'GRE','metz':'METZ','lorient':'LOR','paris':'PSG',
}
def team_map(lg):
    cand=[t for t in teams if lg in (t.get('leagues') or [t.get('league')])]
    by={}
    for t in cand:
        for k in (t.get('name'),t.get('short'),t.get('display')):
            if k: by.setdefault(norm(k),t)
    return cand,by
def pick(name,lg,cand,by):
    n=norm(name)
    if n in manual:
        a=manual[n]; found=[t for t in cand if t.get('abbr')==a]
        if found: return found[0]
    if n in by: return by[n]
    # common manual alias on token
    for mk,ma in manual.items():
        if n==norm(mk):
            found=[t for t in cand if t.get('abbr')==ma]
            if found: return found[0]
    names=[(norm(t.get('name') or ''),t) for t in cand]
    close=difflib.get_close_matches(n,[x for x,_ in names],n=1,cutoff=0.62)
    if close:
        for nn,t in names:
            if nn==close[0]: return t
    return None
def num(x):
    try:return float(str(x).strip())
    except:return None
def poisson(lam,k):
    return math.exp(-lam)*lam**k/math.factorial(k)
def xpts(h,a):
    hw=dw=aw=0.0
    for i in range(0,9):
        pi=poisson(h,i)
        for j in range(0,9):
            p=pi*poisson(a,j)
            if i>j:hw+=p
            elif i==j:dw+=p
            else:aw+=p
    return round(3*hw+dw,2)
out={'updated':int(now.timestamp()),'season':f'{sy}/{str(sy+1)[-2:]}','teams':{}}
seasons=[code, f'{(sy-1)%100:02d}{sy%100:02d}']
for lg,div in LEAGUES.items():
    cand,by=team_map(lg)
    rows={}
    for season in seasons:
        url=f'https://www.football-data.co.uk/mmz4281/{season}/{div}.csv'
        f=cache/f'{season}-{div}.csv'
        if not f.exists() or now.timestamp()-f.stat().st_mtime>172800:
            try:
                req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
                f.write_bytes(urllib.request.urlopen(req,timeout=20).read())
            except Exception as e:
                print('fetch failed',season,div,e,file=sys.stderr); continue
        with f.open(newline='',encoding='utf-8-sig') as fh:
            for r in csv.DictReader(fh):
                hg=num(r.get('HxG')); ag=num(r.get('AxG'))
                if hg is None or ag is None: continue
                h=pick(r.get('HomeTeam',''),lg,cand,by); a=pick(r.get('AwayTeam',''),lg,cand,by)
                if not h or not a: continue
                try:
                    d=datetime.datetime.strptime(r.get('Date',''),'%d/%m/%Y').date()
                except: continue
                sides=(
                    (h,a,hg,ag,num(r.get('FTHG')),num(r.get('FTAG')),True,num(r.get('HS')),num(r.get('HST')),num(r.get('HC')),num(r.get('HY')),num(r.get('HR'))),
                    (a,h,ag,hg,num(r.get('FTAG')),num(r.get('FTHG')),False,num(r.get('AS')),num(r.get('AST')),num(r.get('AC')),num(r.get('AY')),num(r.get('AR'))),
                )
                for t,opp,xf,xa,gf,ga,is_home,sh,sot,co,ye,rd in sides:
                    game={'d':d.isoformat(),'opp':opp.get('name'),'opp_abbr':opp.get('abbr'),'home':is_home,'gf':gf or 0,'ga':ga or 0,'xg':xf,'xga':xa,'sh':sh or 0,'sot':sot or 0,'corners':co or 0,'cards':(ye or 0)+2*(rd or 0)}
                    rows.setdefault(t['abbr'],{'abbr':t['abbr'],'name':t.get('name'),'lg':lg,'games':[]})['games'].append(game)
    for ab,t in rows.items():
        gs=sorted(t['games'],key=lambda x:x['d'])
        l5=gs[-5:]
        if not l5: continue
        out['teams'][ab]={'abbr':ab,'name':t['name'],'lg':lg,'n':len(gs),'xg5':round(sum(x['xg'] for x in l5)/len(l5),2),'xga5':round(sum(x['xga'] for x in l5)/len(l5),2),'xpts5':round(sum(xpts(x['xg'],x['xga']) for x in l5)/len(l5),2),'fin5':round(sum((x['gf'] or 0)-x['xg'] for x in l5),2),'series':gs[-20:]}
out['teams']={k:v for k,v in out['teams'].items() if v['n']>=3}
out['by_name']={ (v.get('name') or '').lower(): v for v in out['teams'].values() }
def fold(s):
    return ''.join(c for c in unicodedata.normalize('NFKD',s or '') if not unicodedata.combining(c)).lower()
aliases={
 'brighton':['brighton & hove albion','brighton and hove albion'],
 'c palace':['crystal palace'],
 'coventry':['coventry city'],
 'hull':['hull city'],
 'ipswich':['ipswich town'],
 'leeds':['leeds united'],
 'man city':['manchester city'],
 'man utd':['manchester united','man united'],
 'newcastle':['newcastle united','newcastle utd'],
 'nottm forest':['nottingham forest',"nott'm forest"],
 'spurs':['tottenham','tottenham hotspur'],
 'alavés':['alaves','deportivo alavés','deportivo alaves'],
 'athletic':['athletic bilbao','athletic club'],
 'atlético':['atletico','atlético madrid','atletico madrid','atleti'],
 'betis':['real betis'],
 'celta vigo':['celta'],
 'espanyol':['rcd espanyol'],
 'málaga':['malaga'],
 'real sociedad':['sociedad'],
 'le havre ac':['le havre','havre'],
 'lens':['rc lens'],
 'lille':['losc','lille osc'],
 'marseille':['olympique marseille','olympique de marseille','om'],
 'nice':['ogc nice'],
 'olympique lyonnais':['lyon','ol','olympique lyon'],
 'psg':['paris saint-germain','paris saint germain','paris sg'],
 'rennes':['stade rennais','stade rennais fc'],
 'strasbourg':['rc strasbourg','rc strasbourg alsace'],
 'toulouse':['toulouse fc'],
 'clermont foot':['clermont'],
 'dijon fco':['dijon'],
 'grenoble':['grenoble foot 38'],
 'guingamp':['ea guingamp'],
 'nancy':['as nancy','as nancy lorraine'],
 'nantes':['fc nantes'],
 'red star fc':['red star'],
 'reims':['stade de reims'],
 'sochaux':['fc sochaux'],
 'st. étienne':['saint-étienne','saint etienne','as saint-étienne','asse'],
 'stade laval':['laval'],
 'bayern':['bayern munich','bayern münchen','fc bayern','fc bayern munich'],
 'bremen':['werder bremen'],
 'dortmund':['borussia dortmund','bvb'],
 'frankfurt':['eintracht frankfurt','eintracht'],
 'gladbach':['borussia monchengladbach','borussia mönchengladbach','m gladbach','b monchengladbach'],
 'hamburg':['hamburger sv'],
 'leverkusen':['bayer leverkusen'],
 'mainz':['mainz 05'],
 'rb leipzig':['leipzig'],
 'schalke':['schalke 04'],
 'stuttgart':['vfb stuttgart'],
 'union berlin':['1. fc union berlin','fc union berlin'],
 'as roma':['roma'],
 'inter milan':['inter','internazionale'],
 'milan':['ac milan'],
 'juventus':['juve'],
 'lazio':['ss lazio'],
 'napoli':['ssc napoli'],
}
for key,names in aliases.items():
    t=out['by_name'].get(key)
    if not t: continue
    for a in names:
        out['by_name'].setdefault(a,t)
        out['by_name'].setdefault(fold(a),t)
for m in list(out['by_name'].values()):
    if m.get('name'): out['by_name'].setdefault(fold(m['name']),m)
out['by_name'].setdefault('atletico','atletico madrid')
(home/'.cache/espn-fd.json').write_text(json.dumps(out,separators=(',',':')))
print(json.dumps({'teams':len(out['teams']),'season':out['season']}))
