from __future__ import annotations
import hashlib,json,lzma,shutil,struct,sys
from pathlib import Path
from PIL import Image
CLIENT=Path(r'D:\otserv\otclient-main\data\things\1525')
ART=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros-v3')
BACK=ART/'backup-previous-installed';BACK.mkdir(exist_ok=True)
SERVER=Path(r'\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data\items\appearances.dat')
PB=Path(r'D:\otserv\Update 15.30\Echo Raid\official-assets');sys.path[:0]=[str(PB/'pydeps'),str(PB)]
import appearances_pb2 as ap
CAT=CLIENT/'catalog-content.json';catalog=json.loads(CAT.read_text(encoding='utf-8-sig'))
APP=next(CLIENT/e['file'] for e in catalog if e.get('type')=='appearances')
for p,name in [(CAT,'catalog-content.json'),(APP,APP.name),(SERVER,'server-appearances.dat')]:
 q=BACK/name
 if not q.exists():shutil.copy2(p,q)
old=[e for e in catalog if e.get('baiakeros_asset')=='loot_pouch']
for e in old:
 p=CLIENT/e['file'];q=BACK/p.name
 if p.exists() and not q.exists():shutil.copy2(p,q)
canvas=Image.new('RGBA',(384,384),(255,0,255,255))
for i in range(6):
 f=Image.open(ART/f'gold_pouch_baiakeros_frame_{i+1}.png').convert('RGBA')
 bg=Image.new('RGBA',(32,32),(255,0,255,255));p=bg.load();s=f.load()
 for y in range(32):
  for x in range(32):p[x,y]=(255,0,255,255) if s[x,y][3]<128 else (*s[x,y][:3],255)
 canvas.paste(bg,(i*32,0))
bmp=ART/'gold_pouch_baiakeros_sheet.bmp';canvas.save(bmp,format='BMP');raw=bmp.read_bytes()
filters=[{'id':lzma.FILTER_LZMA1,'dict_size':33554432,'lc':3,'lp':0,'pb':2}]
payload=bytes([93])+struct.pack('<I',33554432)+struct.pack('<Q',len(raw))+lzma.compress(raw,format=lzma.FORMAT_RAW,filters=filters)
def varint(n):
 out=bytearray()
 while True:
  b=n&127;n>>=7
  if n:out.append(b|128)
  else:out.append(b);return bytes(out)
wrapped=b'\0'*24+bytes.fromhex('700afa8024')+varint(len(payload))+payload
name='sprites-'+hashlib.sha256(wrapped).hexdigest()+'.bmp.lzma';(CLIENT/name).write_bytes(wrapped)
ids=list(range(300734,300740));durations=[(3500,6000),(160,160),(160,160),(160,160),(160,160),(300,300)]
def patch(path):
 data=ap.Appearances();data.ParseFromString(path.read_bytes());obj=next(o for o in data.object if o.id==23721)
 info=obj.frame_group[0].sprite_info;del info.sprite_id[:];info.sprite_id.extend(ids)
 anim=info.animation;anim.default_start_phase=0;anim.synchronized=False;anim.random_start_phase=False;anim.loop_type=ap.ANIMATION_LOOP_TYPE_INFINITE;anim.loop_count=0;del anim.sprite_phase[:]
 for low,high in durations:
  phase=anim.sprite_phase.add();phase.duration_min=low;phase.duration_max=high
 obj.flags.animate_always=True;path.write_bytes(data.SerializeToString())
patch(APP);patch(SERVER)
catalog=[e for e in catalog if e.get('baiakeros_asset')!='loot_pouch']
catalog.append({'type':'sprite','file':name,'spritetype':0,'firstspriteid':ids[0],'lastspriteid':ids[-1],'area':0,'baiakeros_asset':'loot_pouch'})
CAT.write_text(json.dumps(catalog,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
for e in old:
 p=CLIENT/e['file']
 if p.exists():p.unlink()
manifest={'item_id':23721,'sprite_ids':ids,'sheet':name,'rest_pause_ms':[3500,6000],'backup':str(BACK)}
(ART/'installation.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
