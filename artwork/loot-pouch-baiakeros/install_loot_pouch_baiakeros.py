from __future__ import annotations
import hashlib, json, lzma, shutil, struct, sys
from pathlib import Path
from PIL import Image
CLIENT=Path(r'D:\otserv\otclient-main\data\things\1525')
ART=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros')
BACKUP=ART/'backup-original'
SERVER=Path(r'\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data\items\appearances.dat')
PBROOT=Path(r'D:\otserv\Update 15.30\Echo Raid\official-assets')
sys.path[:0]=[str(PBROOT/'pydeps'),str(PBROOT)]
import appearances_pb2 as ap
ITEM_ID=23721
NEW_IDS=[300734,300735,300736,300737]
DURATIONS=[240,150,190,180]
CATALOG=CLIENT/'catalog-content.json'
client_catalog=json.loads(CATALOG.read_text(encoding='utf-8-sig'))
client_appearance=next(CLIENT/e['file'] for e in client_catalog if e.get('type')=='appearances')
BACKUP.mkdir(parents=True,exist_ok=True)
for src,name in [(CATALOG,'catalog-content.json'),(client_appearance,client_appearance.name),(SERVER,'server-appearances.dat')]:
    dst=BACKUP/name
    if not dst.exists(): shutil.copy2(src,dst)
# Preserve source/current sprite and generated frames.
orig=ART.parent/'loot-pouch-reference'/'00_sprite_212383.png'
if orig.exists() and not (BACKUP/'loot_pouch_original_frame.png').exists(): shutil.copy2(orig,BACKUP/'loot_pouch_original_frame.png')
# Build a standard 384x384 32-bit BMP sheet. Unused pixels are Tibia transparency magenta.
canvas=Image.new('RGBA',(384,384),(255,0,255,255))
for i in range(4):
    frame=Image.open(ART/f'loot_pouch_baiakeros_frame_{i+1}.png').convert('RGBA')
    bg=Image.new('RGBA',frame.size,(255,0,255,255)); bg.alpha_composite(frame)
    # Convert transparent pixels to magic magenta while keeping item pixels opaque.
    p=bg.load(); srcp=frame.load()
    for y in range(32):
        for x in range(32):
            if srcp[x,y][3] < 128: p[x,y]=(255,0,255,255)
            else: p[x,y]=(*srcp[x,y][:3],255)
    canvas.paste(bg,(i*32,0))
tmpbmp=ART/'loot-pouch-baiakeros-sheet.bmp'
canvas.save(tmpbmp,format='BMP')
bmp=tmpbmp.read_bytes()
# Raw LZMA wrapper matching CipSoft catalog sheets: 24 zero bytes, 5-byte marker,
# varint length, LZMA1 properties + raw compressed bytes.
prop=93; dict_size=33554432; lc=3; lp=0; pb=2
filters=[{'id':lzma.FILTER_LZMA1,'dict_size':dict_size,'lc':lc,'lp':lp,'pb':pb}]
packed_payload=lzma.compress(bmp,format=lzma.FORMAT_RAW,filters=filters)
props=bytes([prop])+struct.pack('<I',dict_size)+struct.pack('<Q',len(bmp))
remaining=props+packed_payload
def varint(n):
    out=bytearray()
    while True:
        b=n&0x7f;n>>=7
        if n: out.append(b|0x80)
        else: out.append(b);return bytes(out)
wrapped=b'\0'*24+bytes.fromhex('700afa8024')+varint(len(remaining))+remaining
filename=f'sprites-{hashlib.sha256(wrapped).hexdigest()}.bmp.lzma'
(CLIENT/filename).write_bytes(wrapped)
# Patch client and server appearances while retaining every flag and item property.
def patch(path):
    data=ap.Appearances(); data.ParseFromString(path.read_bytes())
    obj=next((o for o in data.object if o.id==ITEM_ID),None)
    if obj is None: raise RuntimeError(f'item {ITEM_ID} missing in {path}')
    info=obj.frame_group[0].sprite_info
    del info.sprite_id[:]; info.sprite_id.extend(NEW_IDS)
    anim=info.animation
    anim.default_start_phase=0; anim.synchronized=True; anim.random_start_phase=False
    anim.loop_type=ap.ANIMATION_LOOP_TYPE_INFINITE; anim.loop_count=0
    del anim.sprite_phase[:]
    for ms in DURATIONS:
        phase=anim.sprite_phase.add(); phase.duration_min=ms; phase.duration_max=ms
    obj.flags.animate_always=True
    path.write_bytes(data.SerializeToString())
    return obj.name,list(info.sprite_id)
client_result=patch(client_appearance)
server_result=patch(SERVER)
# Replace only a prior custom Baiakeros sheet entry; never touch official ranges.
client_catalog=[e for e in client_catalog if not (e.get('type')=='sprite' and e.get('baiakeros_asset')=='loot_pouch')]
client_catalog.append({'type':'sprite','file':filename,'spritetype':0,'firstspriteid':NEW_IDS[0],'lastspriteid':NEW_IDS[-1],'area':0,'baiakeros_asset':'loot_pouch'})
CATALOG.write_text(json.dumps(client_catalog,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
manifest={'item_id':ITEM_ID,'sprite_ids':NEW_IDS,'durations_ms':DURATIONS,'sheet':filename,'client_appearance':client_appearance.name,'backup':str(BACKUP)}
(ART/'installation.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2));print('client',client_result,'server',server_result)
