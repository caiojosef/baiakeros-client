from __future__ import annotations
import hashlib,json,lzma,shutil,struct,sys
from pathlib import Path
from PIL import Image
CLIENT=Path(r'D:\otserv\otclient-main\data\things\1525'); ART=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros-v2')
PREV=ART/'backup-previous-black-gold';SERVER=Path(r'\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data\items\appearances.dat')
PB=Path(r'D:\otserv\Update 15.30\Echo Raid\official-assets');sys.path[:0]=[str(PB/'pydeps'),str(PB)];import appearances_pb2 as ap
CAT=CLIENT/'catalog-content.json';catalog=json.loads(CAT.read_text(encoding='utf-8-sig'));APP=next(CLIENT/e['file'] for e in catalog if e.get('type')=='appearances')
PREV.mkdir(parents=True,exist_ok=True)
for src,name in [(CAT,'catalog-content.json'),(APP,APP.name),(SERVER,'server-appearances.dat')]:
 if not (PREV/name).exists():shutil.copy2(src,PREV/name)
for e in catalog:
 if e.get('baiakeros_asset')=='loot_pouch' and (CLIENT/e['file']).exists():
  if not (PREV/e['file']).exists():shutil.copy2(CLIENT/e['file'],PREV/e['file'])
canvas=Image.new('RGBA',(384,384),(255,0,255,255))
for i in range(6):
 f=Image.open(ART/f'loot_pouch_baiakeros_v2_frame_{i+1}.png').convert('RGBA');bg=Image.new('RGBA',(32,32),(255,0,255,255));p=bg.load();s=f.load()
 for y in range(32):
  for x in range(32):p[x,y]=(255,0,255,255) if s[x,y][3]<128 else (*s[x,y][:3],255)
 canvas.paste(bg,(i*32,0))
bmp_path=ART/'loot-pouch-baiakeros-v2-sheet.bmp';canvas.save(bmp_path,format='BMP');bmp=bmp_path.read_bytes()
filters=[{'id':lzma.FILTER_LZMA1,'dict_size':33554432,'lc':3,'lp':0,'pb':2}];payload=bytes([93])+struct.pack('<I',33554432)+struct.pack('<Q',len(bmp))+lzma.compress(bmp,format=lzma.FORMAT_RAW,filters=filters)
def vi(n):
 o=bytearray()
 while True:
  b=n&127;n>>=7
  if n:o.append(b|128)
  else:o.append(b);return bytes(o)
wrapped=b'\0'*24+bytes.fromhex('700afa8024')+vi(len(payload))+payload;name='sprites-'+hashlib.sha256(wrapped).hexdigest()+'.bmp.lzma';(CLIENT/name).write_bytes(wrapped)
ids=list(range(300734,300740));dur=[(3500,6000),(160,160),(160,160),(160,160),(160,160),(260,260)]
def patch(path):
 d=ap.Appearances();d.ParseFromString(path.read_bytes());o=next(x for x in d.object if x.id==23721);si=o.frame_group[0].sprite_info;del si.sprite_id[:];si.sprite_id.extend(ids);a=si.animation;a.default_start_phase=0;a.synchronized=False;a.random_start_phase=False;a.loop_type=ap.ANIMATION_LOOP_TYPE_INFINITE;a.loop_count=0;del a.sprite_phase[:]
 for lo,hi in dur:p=a.sprite_phase.add();p.duration_min=lo;p.duration_max=hi
 o.flags.animate_always=True;path.write_bytes(d.SerializeToString())
patch(APP);patch(SERVER)
old=[e for e in catalog if e.get('baiakeros_asset')=='loot_pouch']
catalog=[e for e in catalog if e.get('baiakeros_asset')!='loot_pouch'];catalog.append({'type':'sprite','file':name,'spritetype':0,'firstspriteid':ids[0],'lastspriteid':ids[-1],'area':0,'baiakeros_asset':'loot_pouch'})
CAT.write_text(json.dumps(catalog,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
for e in old:
 p=CLIENT/e['file']
 if p.exists():p.unlink()
manifest={'item_id':23721,'sprite_ids':ids,'rest_pause_ms':[3500,6000],'effect_duration_ms':900,'sheet':name,'previous_backup':str(PREV)};(ART/'installation.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8');print(json.dumps(manifest,indent=2))
