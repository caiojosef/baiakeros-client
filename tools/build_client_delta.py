#!/usr/bin/env python3
"""Build a verified updater delta while retaining immutable earlier package URLs."""
from pathlib import Path
import argparse,json,hashlib,lzma,re,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from build_client_update import pack_one,write_json

parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,required=True)
parser.add_argument('--baseline',type=Path,required=True)
parser.add_argument('--destination',type=Path,required=True)
parser.add_argument('--revision',type=int,required=True)
parser.add_argument('--executable',type=Path,required=True)
args=parser.parse_args()
source=args.source.resolve();dest=args.destination.resolve();dest.mkdir(parents=True,exist_ok=True)
client=json.loads((args.baseline/'client.windows.json').read_text(encoding='utf-8'))
assets=json.loads((args.baseline/'assets.windows.json').read_text(encoding='utf-8'))
assert client['revision']==assets['version'] and args.revision==client['revision']+1
git_paths=subprocess.check_output(['git','ls-files','-z'],cwd=source).decode().split('\0')
runtime=set(p for p in git_paths if p.startswith(('data/','mods/','modules/')) and (source/p).is_file())
root_names={file['localfile'] for file in client['files']}
assert root_names=={'cacert.pem','config.ini','environment.lua','init.lua','otclientrc.lua','otclient.exe'}
production=(source/'environment.production.lua').read_bytes()
assert b'https://www.baiakeros.com/login.php' in production and b'localhost' not in production and b'127.0.0.1' not in production
init=(source/'init.lua').read_text(encoding='utf-8')
init,n=re.subn(r'(?m)^CLIENT_UPDATE_REVISION\s*=\s*\d+\s*$',f'CLIENT_UPDATE_REVISION = {args.revision}',init)
assert n==1
special={'environment.lua':production,'init.lua':init.encode('utf-8'),'otclient.exe':args.executable.read_bytes()}
# Keep the public startup configuration and rc script: local user settings never enter a release.
preserved_roots={'config.ini','otclientrc.lua'}
jobs=[];kept=[];manifests={}
for kind,manifest in [('client',client),('assets',assets)]:
 baseline={entry['localfile']:entry for entry in manifest['files']}
 names=set(baseline) | (runtime if kind=='assets' else set())
 result={};manifests[kind]=result
 for name in sorted(names):
  previous=baseline.get(name)
  if name in preserved_roots or (name not in special and not (source/name).is_file()):
   assert previous is not None
   result[name]=previous;kept.append(name);continue
  raw=special[name] if name in special else (source/name).read_bytes()
  digest=hashlib.sha256(raw).hexdigest()
  if previous and digest==previous['unpackedhash']:
   result[name]=previous;kept.append(name);continue
  jobs.append((kind,name,raw))
def build(job):
 kind,name,raw=job
 entry=pack_one(source/name,name,dest/'packages',f'r{args.revision}/{name}.lzma',raw)
 return kind,name,entry
with ThreadPoolExecutor(max_workers=4) as pool:
 for kind,name,entry in pool.map(build,jobs):manifests[kind][name]=entry
client['revision']=args.revision;client['files']=list(manifests['client'].values())
assets['version']=args.revision;assets['files']=list(manifests['assets'].values())
for filename,manifest in [('client.windows.json',client),('assets.windows.json',assets)]:write_json(dest/filename,manifest)
report={'revision':args.revision,'previousRevision':args.revision-1,'changedFiles':len(jobs),'preservedFiles':len(kept),
 'changedPaths':[name for _,name,_ in jobs],'uploadBytes':sum(manifests[kind][name]['packedsize'] for kind,name,_ in jobs),
 'executableSha256':hashlib.sha256(special['otclient.exe']).hexdigest(),'standardRuntimePaths':True,'verified':True}
write_json(dest/'delta-report.json',report)
print(json.dumps(report,indent=2))
