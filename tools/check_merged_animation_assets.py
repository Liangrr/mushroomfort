from pathlib import Path
from PIL import Image
import json,numpy as np
ROOT=Path(__file__).resolve().parents[1];R=ROOT/'assets/template/merged_animations_hd';reports=[];total_bytes=0
for key in ['fire_frost','fire_storm','fire_earth','frost_storm','frost_earth','storm_earth']:
 meta=json.loads((R/f'{key}.json').read_text());w,h=meta['cell'];capacity=meta['frames_per_page'];columns=meta['columns'];trim=meta['trim_rect']
 assert meta['source_resolution']==[1280,720] and meta['source_scale']==1.0
 assert meta['fps']==12 and meta['frame_count']==48 and meta['foundation_locked']
 pages=[Image.open(ROOT/p['path'].removeprefix('res://')).convert('RGBA') for p in meta['pages']]
 assert all(max(p.size)<=4096 for p in pages)
 for p,d in zip(pages,meta['pages']):assert list(p.size)==d['size'];total_bytes+=p.width*p.height*4
 unique=[]
 for index in range(meta['unique_frames']):
  page=index//capacity;slot=index%capacity;x=(slot%columns)*w;y=(slot//columns)*h
  unique.append(np.asarray(pages[page].crop((x,y,x+w,y+h))))
 first=unique[meta['frame_map']['idle'][0]]
 assert np.array_equal(first,unique[meta['frame_map']['cast'][0]])
 # All foundation pixels remain in their fixed source coordinates despite trimming.
 foundation_y=588-trim[1];baseline=first[foundation_y:];mask=baseline[:,:,3]>100
 assert np.count_nonzero(mask)>1000
 for action in ['idle','cast']:
  indices=meta['frame_map'][action];assert len(indices)==48 and all(0<=i<len(unique) for i in indices)
  frames=[unique[i] for i in indices]
  diffs=[int(np.max(np.abs(f[foundation_y:].astype(int)-baseline.astype(int))[mask])) for f in frames]
  assert max(diffs)<=2,(key,action,max(diffs))
  assert all(np.count_nonzero(f[:,:,3]==0)>w*h*.1 for f in frames)
  assert all(np.max(f[:,[0,-1],3])<5 for f in frames),(key,action,'horizontal clipping')
  assert all(np.max(f[[0,-1],:,3])<5 for f in frames),(key,action,'vertical clipping')
  assert all(not np.array_equal(frames[i],frames[(i+1)%48]) for i in range(48)),(key,action,'duplicate hold')
  reports.append({'key':key,'action':action,'frames':len(frames),'foundation_delta':max(diffs)})
 # Exact static reference placement in the neutral pose; no invented pixels or upscaling.
 reference=Image.new('RGBA',(960,720));reference.alpha_composite(Image.open(ROOT/'assets/template/merged_guardians'/f'{key}.webp').convert('RGBA'),(288,180))
 assert np.array_equal(first,np.asarray(reference.crop(trim))),(key,'neutral source mismatch')
 print('MERGED_HD_GUARDIAN_PASS',key,'cell',w,h,'pages',len(pages),'unique',len(unique))
print('MERGED_ASSETS_PASS',len(reports),'actions; native source detail; <=4096 pages; alpha; fixed bases; exact neutral pose; no duplicated holds; rgba_MiB',round(total_bytes/1024**2,2))
