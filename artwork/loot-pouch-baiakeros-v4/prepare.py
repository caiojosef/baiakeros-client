from colorsys import rgb_to_hsv,hsv_to_rgb
from PIL import Image
from pathlib import Path
orig=Image.open(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros\backup-original\loot_pouch_original_frame.png').convert('RGBA')
out=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros-v4')
base=Image.new('RGBA',(32,32),(0,0,0,0))
for y in range(32):
 for x in range(32):
  r,g,b,a=orig.getpixel((x,y))
  if a<128:continue
  h,s,v=rgb_to_hsv(r/255,g/255,b/255)
  # Recolor the original red cloth while retaining its exact shading and pixel boundaries.
  if s>0.26 and (h<0.065 or h>0.94):
   h=0.625 if y<17 else 0.70
   s=min(0.96,max(0.60,s*0.90))
   v=min(0.96,max(0.13,v*1.12))
   r,g,b=[round(c*255) for c in hsv_to_rgb(h,s,v)]
  # Gold tie, contour and all other features remain original.
  base.putpixel((x,y),(r,g,b,255))
base.save(out/'gold_pouch_baiakeros_clean_base.png')
# Broad luminous sweep across the same static pouch; no frame deforms its silhouette.
paths=[[],[(3,24),(4,23),(5,23),(6,22),(7,21),(8,21)],[(8,21),(9,20),(10,20),(11,19),(12,18),(13,18)],[(13,18),(14,17),(15,16),(16,16),(17,15),(18,14)],[(18,14),(19,13),(20,13),(21,12),(22,11),(23,11)],[(23,11),(24,10),(25,9),(26,9),(27,8)]]
frames=[]
for i,path in enumerate(paths):
 f=base.copy()
 for j,(x,y) in enumerate(path):
  f.putpixel((x,y),(185,240,255,255))
  if y+1<32 and j%2==0:f.putpixel((x,y+1),(65,150,255,255))
 if path:
  x,y=path[-1]
  for dx,dy,color in [(0,-1,(255,246,170,255)),(1,0,(255,218,100,255)),(1,-1,(255,246,170,255))]:
   xx,yy=x+dx,y+dy
   if 0<=xx<32 and 0<=yy<32:f.putpixel((xx,yy),color)
 f.save(out/f'gold_pouch_baiakeros_frame_{i+1}.png');frames.append(f)
strip=Image.new('RGBA',(192,32),(0,0,0,0))
for i,f in enumerate(frames):strip.alpha_composite(f,(i*32,0))
strip.save(out/'gold_pouch_baiakeros_strip_6x32.png')
frames[0].save(out/'gold_pouch_baiakeros_preview.gif',save_all=True,append_images=frames[1:],duration=[3000,250,250,250,250,400],loop=0,disposal=2)
print('original',orig.getchannel('A').getbbox(),'clean',base.getchannel('A').getbbox())
print('white pixels',sum(1 for r,g,b,a in base.getdata() if a and min(r,g,b)>200))
