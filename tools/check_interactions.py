"""Replay real projected pointer input through the curved Rive surface."""
import json, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RIVE=shutil.which('rive') or str(Path.home()/'.rive/bin/rive')
cases={
 'selection':(['--pointer=click@400,432','--advance=6','--pointer=click@699,648','--advance=40'],lambda d:d['pattern']==1 and d['palette']==5),
 'curved-scroll':(['--pointer=drag@400,490>400,335:18','--advance=60'],lambda d:d['scrollY'] < -30 and d['pattern']==0),
 'scroll-home':(['--pointer=drag@400,490>400,335:18','--advance=60','--pointer=click@180,265','--advance=10'],lambda d:abs(d['scrollY'])<1),
 'controls':(['--pointer=click@540,710','--pointer=click@540,742','--pointer=click@746,718','--advance=20'],lambda d:d['scale']>2.5 and d['speed']>1.4 and d['paused']),
 'flat-hit':(['--data=flat=true','--advance=180','--pointer=click@400,333','--advance=6'],lambda d:d['pattern']==1),
 'unfold-while-scrolling':(['--pointer=click@330,858','--advance=8','--pointer=drag@400,470>400,320:14','--advance=60'],lambda d:d['flat'] and d['scrollY'] < -30 and d['pattern']==0),
 'lift-corner':(['--pointer=down@330,858','--pointer=move@330,786','--advance=20'],lambda d:abs(d['pull']-.4)<.001 and not d['flat'] and d['pattern']==0),
 'entry-focus-delete':(['--pointer=click@410,830','--key=backspace','--advance=2'],lambda d:d['mark']==''),
 'orbit-reset':(['--pointer=drag@1050,180>1170,210:18','--advance=20','--key=r','--advance=30'],lambda d:abs(d['orbitYaw'])<.001 and abs(d['orbitPitch'])<.001),
 'phone-selection':(['--viewport=430x932','--pointer=click@161,530','--advance=20'],lambda d:d['pattern']==1),
 'small-phone':(['--viewport=375x812','--pointer=click@169,547','--pointer=drag@210,480>210,400:18','--advance=30'],lambda d:d['palette']==2 and d['scrollY']<-20 and d['pattern']==0),
 'tilted-selection':(['--pointer=move@1500,120','--advance=180','--pointer=click@400,432','--advance=20'],lambda d:d['pattern']==1),
 'interrupted-selection':(['--pointer=click@400,432','--advance=2','--pointer=click@400,350','--advance=2','--pointer=click@400,432','--advance=30'],lambda d:d['pattern']==1),
 'reduced-motion':(['--key=m','--pointer=move@1500,120','--advance=90','--pointer=click@400,432','--advance=1'],lambda d:d['reduceMotion'] and d['pattern']==1),
}
results=[]
for name,(args,check) in cases.items():
 path=ROOT/'build'/f'check-{name}.json'
 r=subprocess.run([RIVE,'.','--advance=60',*args,'--data-dump='+str(path)],cwd=ROOT,capture_output=True,text=True)
 assert r.returncode==0,r.stdout+r.stderr
 data=json.loads(path.read_text());d={p['name']:p['value'] for p in data['viewModel']['properties']}
 assert check(d),(name,d)
 print('PASS',name,flush=True);results.append(name)
(ROOT/'build'/'interaction-results.json').write_text(json.dumps({'passed':results,'count':len(results)},indent=2)+'\n')
