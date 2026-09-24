from PIL import Image
from pathlib import Path
src=Image.open(r'C:\Users\eucaio\.codex\generated_images\01a09f58-2809-7f43-b71c-8cb8ecf79d25\exec-24474170-00f1-44f0-9c56-c5a5f58fcca4.png').convert('RGB')
orig=Image.open(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros\backup-original\loot_pouch_original_frame.png').convert('RGBA')
out=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros-v3')
body=src.crop((165,160,1130,1050)).resize((30,28),Image.Resampling.NEAREST)
base=Image.new('RGBA',(32,32),(0,0,0,0))
mask=orig.getchannel('A')
for y in range(2,30):
 for x in range(1,31):
  if mask.getpixel((x,y))>=128:
   r,g,b=body.getpixel((x-1,y-2));base.putpixel((x,y),(r,g,b,255))
base.save(out/'gold_pouch_baiakeros_base.png')
frames=[]
trail=[[],[(3,24),(5,23),(7,22),(9,21)],[(8,21),(10,20),(12,19),(14,18)],[(13,17),(15,16),(17,15),(19,14)],[(18,13),(20,12),(22,11),(24,10)],[(25,9),(27,8)]]
for idx,points in enumerate(trail):
 frame=base.copy()
 for j,(x,y) in enumerate(points):
  frame.putpixel((x,y),(145,222,255,255))
  if j==len(points)-1 and x+1<32:frame.putpixel((x+1,y),(242,232,168,255))
 frame.save(out/f'gold_pouch_baiakeros_frame_{idx+1}.png');frames.append(frame)
strip=Image.new('RGBA',(192,32),(0,0,0,0))
for i,frame in enumerate(frames):strip.alpha_composite(frame,(32*i,0))
strip.save(out/'gold_pouch_baiakeros_strip_6x32.png')
frames[0].save(out/'gold_pouch_baiakeros_preview.gif',save_all=True,append_images=frames[1:],duration=[4000,160,160,160,160,300],loop=0,disposal=2)
print('base bounds',base.getchannel('A').getbbox(),'frames',len(frames))
