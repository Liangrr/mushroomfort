#!/usr/bin/env python3
"""Check final walking atlases; pixel metrics supplement native visual acceptance."""
from pathlib import Path
from PIL import Image
import numpy as np,json
root=Path(__file__).resolve().parents[1]
for kind in ['goblin','orc','troll']:
 path=root/f'assets/template/EnemyAnimations/{kind}_walk.webp'
 atlas=Image.open(path).convert('RGBA')
 frames=[np.asarray(atlas.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256)),dtype=np.float32)/255 for i in range(48)]
 assert len({frame.tobytes() for frame in frames})==48,(kind,'duplicate frame')
 for frame in frames:
  ys,_=np.where(frame[:,:,3]>.3)
  assert int(ys.max())==224,(kind,'unstable ground contact')
 a=np.stack(frames);a[:,:,:,:3]*=a[:,:,:,3:4]
 union=np.max(a[:,:,:,3],axis=0)>.05
 delta=np.mean(np.abs(np.roll(a,-1,axis=0)-a)[:,union],axis=(1,2))
 assert delta.min()>1e-5,(kind,'loop hold')
 assert delta[-1]<np.median(delta)*1.6,(kind,'disproportionate seam')
 meta=json.loads(path.with_suffix('.json').read_text())
 assert meta['frame_count']==48 and meta['anchor']==[128,224]
 print(f'{kind}: 48 unique frames; contact y224; seam/median={delta[-1]/np.median(delta):.3f}')
print('WALK_ATLAS_CONTRACTS_PASS')
