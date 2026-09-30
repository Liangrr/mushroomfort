from pathlib import Path
from PIL import Image
import json, numpy as np
ROOT=Path(__file__).resolve().parents[1]
count=0;total=0
for kind in ('prismback','harrier','broodmother'):
 p=ROOT/'assets/template/late_enemies'/kind;d=json.loads((p/'metadata.json').read_text())
 cell=tuple(int(v) for v in d['cell']);anchor=tuple(float(v) for v in d['anchor']);columns=int(d['columns']);frames=int(d['frames'])
 assert cell==(384,384) and frames==24 and 0<anchor[0]<cell[0] and 0<anchor[1]<cell[1]
 for direction in ('SE','SW','NW','NE'):
  image=Image.open(p/f'{direction}.webp').convert('RGBA');assert max(image.size)<=4096
  hashes=set()
  for index in range(frames):
   x=(index%columns)*cell[0];y=(index//columns)*cell[1];frame=image.crop((x,y,x+cell[0],y+cell[1]));a=np.array(frame)
   assert (a[:,:,3]>16).sum()>1000,(kind,direction,index,'empty')
   assert max(a[0,:,3].max(),a[-1,:,3].max(),a[:,0,3].max(),a[:,-1,3].max())<24,(kind,direction,index,'edge alpha')
   assert (a[:,:,3]==0).mean()>.2,(kind,direction,index,'no real alpha')
   hashes.add(frame.tobytes());count+=1
  assert len(hashes)>=20,(kind,direction,'static/duplicated motion')
  total+=(p/f'{direction}.webp').stat().st_size
 assert (p/'ability.ogg').stat().st_size>1000
 print('LATE_ASSET_PASS',kind,'four genuine directional pages, 96 nonempty alpha-safe frames')
print('LATE_ASSET_TOTAL frames=',count,'compressed_bytes=',total)
