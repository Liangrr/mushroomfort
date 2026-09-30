from pathlib import Path
from PIL import Image,ImageDraw
import cv2,numpy as np,json,shutil,argparse
parser=argparse.ArgumentParser(description="Repair approved enemy walking atlases from their pre-audit originals")
parser.add_argument('--source-dir',type=Path,required=True,help='Directory containing original goblin_walk.webp, orc_walk.webp and troll_walk.webp atlases')
parser.add_argument('--output',type=Path,default=Path('/tmp/fablewood-walk-repair'))
args=parser.parse_args();R=Path(__file__).resolve().parents[1];O=args.output;O.mkdir(parents=True,exist_ok=True)
(O/'originals').mkdir(exist_ok=True)
CHOICES={'goblin':(5,20,.9),'orc':(14,34,.8),'troll':(13,30,.7)}
grid_y,grid_x=np.mgrid[:256,:256].astype(np.float32)
def premult(im):
 a=np.asarray(im,dtype=np.float32)/255;a[:,:,:3]*=a[:,:,3:4];return a
def straight(a):
 a=a.copy();a[:,:,:3]/=np.maximum(a[:,:,3:4],1e-6)
 return Image.fromarray(np.uint8(np.clip(a,0,1)*255),'RGBA')
def contact(im):
 a=np.asarray(im);ys,xs=np.where(a[:,:,3]>76)
 return int(ys.max())
def grounded(im):
 pixels=np.asarray(im).copy()
 count,labels,stats,_=cv2.connectedComponentsWithStats((pixels[:,:,3]>20).astype(np.uint8),8)
 if count>1:
  main=1+int(np.argmax(stats[1:,cv2.CC_STAT_AREA]))
  near=cv2.dilate((labels==main).astype(np.uint8),np.ones((7,7),np.uint8))
  pixels[:,:,3]*=near
  im=Image.fromarray(pixels,'RGBA')
 dy=224-contact(im)
 return im.transform((256,256),Image.Transform.AFFINE,(1,0,0,0,1,-dy),Image.Resampling.BICUBIC)
def optical(a,b):
 def grey(v):
  # Use opaque silhouette edges as well as interior detail for the flow field.
  x=np.clip(v[:,:,:3]+(1-v[:,:,3:4])*.45,0,1)
  return cv2.cvtColor(np.uint8(x*255),cv2.COLOR_RGB2GRAY)
 ga,gb=grey(a),grey(b)
 args=(None,.5,3,19,4,5,1.2,0)
 return cv2.calcOpticalFlowFarneback(ga,gb,*args),cv2.calcOpticalFlowFarneback(gb,ga,*args)
def tween(a,b,flow,t):
 if t<1e-6:return a.copy()
 f,r=flow
 aa=cv2.remap(a,grid_x-t*f[:,:,0],grid_y-t*f[:,:,1],cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 bb=cv2.remap(b,grid_x-(1-t)*r[:,:,0],grid_y-(1-t)*r[:,:,1],cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 result=aa*(1-t)+bb*t
 # Newly revealed feet/cape edges have no counterpart in the other frame.
 # Select the nearer observation there instead of painting two ghosts.
 occluded=np.abs(aa[:,:,3]-bb[:,:,3])>.12
 result[occluded]=(aa if t<.5 else bb)[occluded]
 return result
reports=[]
for kind,(start,end,old_cadence) in CHOICES.items():
 path=R/f'assets/template/EnemyAnimations/{kind}_walk.webp';backup=O/'originals'/path.name
 if not backup.exists():shutil.copy2(args.source_dir/path.name,backup)
 atlas=Image.open(backup).convert('RGBA')
 source=[grounded(atlas.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256))) for i in range(48)]
 # Exclude the matching end pose: the sequence must advance across the seam.
 sequence=[premult(source[i]) for i in range(start,end)]
 flows=[optical(a,sequence[(i+1)%len(sequence)]) for i,a in enumerate(sequence)]
 frames=[]
 for k in range(48):
  at=k*len(sequence)/48;i=int(at);t=at-i
  frames.append(grounded(straight(tween(sequence[i],sequence[(i+1)%len(sequence)],flows[i],t))))
 output=Image.new('RGBA',(2048,1536))
 for i,im in enumerate(frames):output.alpha_composite(im,((i%8)*256,(i//8)*256))
 output.save(path,lossless=True,method=4)
 values=np.stack([premult(im) for im in frames]);union=np.max(values[:,:,:,3],axis=0)>.05
 delta=np.mean(np.abs(np.roll(values,-1,axis=0)-values)[:,union],axis=(1,2))
 assert len({im.tobytes() for im in frames})==48
 assert np.min(delta)>0 and all(contact(im)==224 for im in frames)
 metadata_path=path.with_suffix('.json');metadata=json.loads(metadata_path.read_text())
 if not (O/'originals'/metadata_path.name).exists():shutil.copy2(metadata_path,O/'originals'/metadata_path.name)
 cadence=old_cadence*48/(end-start)
 metadata.update({'loop_repair':'interior full gait; cyclic optical-flow resampling; no repeated end pose','source_frame_interval':[start,end],'source_interval_end_exclusive':True,'ground_contact_y':224,'cycles_per_tile':cadence,'authoring_tool':'tools/repair_enemy_walk_cycles.py'})
 metadata_path.write_text(json.dumps(metadata,indent=2)+'\n')
 report={'enemy':kind,'source_interval':[start,end],'cycles_per_tile':cadence,'median_delta':float(np.median(delta)),'seam_delta':float(delta[-1]),'max_delta':float(delta.max()),'unique_frames':48,'ground_contact':[224,224]}
 reports.append(report);print(json.dumps(report),flush=True)
 strip=Image.new('RGB',(1024,560),'#20242c');d=ImageDraw.Draw(strip)
 for j,k in enumerate([0,8,16,24,40,46,47,0]):
  x=(j%4)*256;y=(j//4)*280
  if j%2:d.rectangle((x,y,x+255,y+279),fill='#eee8dc')
  strip.paste(frames[k],(x,y+20),frames[k]);d.text((x+8,y+4),f'{kind} frame {k}',fill='#bb8c38')
 strip.save(O/f'{kind}_repaired.jpg',quality=95)
(O/'repair_metrics.json').write_text(json.dumps(reports,indent=2)+'\n')
