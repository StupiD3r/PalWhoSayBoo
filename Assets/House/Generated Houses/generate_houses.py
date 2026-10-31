import json, math, struct, sys, zlib, random
from pathlib import Path

OUT = Path(__file__).parent
MATS = {
 'weathered_log': (0.25,0.19,0.13,1), 'log_light': (0.38,0.29,0.19,1),
 'beam': (0.20,0.14,0.09,1), 'beam_light': (0.34,0.25,0.16,1),
 'roof': (0.28,0.27,0.23,1), 'roof_light': (0.39,0.36,0.30,1),
 'dark_opening': (0.075,0.065,0.052,1), 'door': (0.19,0.12,0.075,1),
 'stone': (0.34,0.33,0.29,1), 'glass': (0.12,0.20,0.20,1),
 'metal': (0.23,0.22,0.19,1), 'ground_wood': (0.29,0.21,0.13,1)
}

def make_png(path, roof=False, size=512):
 # Seamless weathered timber color texture made with the Python standard library.
 # Long grain runs across each board; the repeated board seams wrap cleanly.
 rng=random.Random(9047 if roof else 4103)
 rows=32
 plank_h=size//rows
 bases=[rng.randint(155,205) if roof else rng.randint(155,210) for _ in range(rows)]
 knots=[]
 for _ in range(12): knots.append((rng.randrange(size),rng.randrange(size),rng.randint(7,20),rng.randint(2,6)))
 raw=bytearray()
 for y in range(size):
  raw.append(0)
  plank=y//plank_h; ly=y%plank_h
  for x in range(size):
   # Periodic grain waves prevent a visible seam at the texture edges.
   grain=(8*math.sin(2*math.pi*(x/size*7 + plank*.19)) + 5*math.sin(2*math.pi*(x/size*19 + ly*.027 + plank*.43)) + 3*math.sin(2*math.pi*(x/size*43 + ly*.061)))
   fine=2*math.sin(2*math.pi*(x/size*97 + ly*.11))
   seam=-43 if ly<2 or ly>plank_h-3 else 0
   value=bases[plank]+grain+fine+seam
   # Small dark checks and knots add the age and roughness visible in the reference.
   for kx,ky,rx,ry in knots:
    dx=min((x-kx)%size,(kx-x)%size); dy=min((y-ky)%size,(ky-y)%size)
    if (dx/rx)**2+(dy/ry)**2<1: value-=18
   fleck=(((x*37+y*17+(x*y)%53)%19)-9)*0.72
   value=max(55,min(235,int(value+fleck)))
   if roof:
    rgb=(value, int(value*.98), int(value*.91))
   else:
    rgb=(int(value*.96), int(value*.88), int(value*.75))
   raw.extend(rgb)
 def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b'')
 path.write_bytes(png)
class Model:
 def __init__(self,name): self.name=name; self.groups={k:[] for k in MATS}
 def tri(self,a,b,c,mat,out=None):
  a,b,c=[tuple(map(float,p)) for p in (a,b,c)]
  u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
  n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
  if out is not None and sum(n[i]*out[i] for i in range(3))<0: b,c=c,b; n=[-x for x in n]
  l=math.sqrt(sum(x*x for x in n)) or 1; n=[x/l for x in n]
  self.groups[mat].append((a,n)); self.groups[mat].append((b,n)); self.groups[mat].append((c,n))
 def quad(self,a,b,c,d,mat,out): self.tri(a,b,c,mat,out); self.tri(a,c,d,mat,out)
 def box(self,center,size,mat):
  x,y,z=center; sx,sy,sz=[v/2 for v in size]
  p=[(x-sx,y-sy,z-sz),(x+sx,y-sy,z-sz),(x+sx,y+sy,z-sz),(x-sx,y+sy,z-sz),(x-sx,y-sy,z+sz),(x+sx,y-sy,z+sz),(x+sx,y+sy,z+sz),(x-sx,y+sy,z+sz)]
  faces=[((0,3,2,1),(0,0,-1)),((4,5,6,7),(0,0,1)),((0,4,7,3),(-1,0,0)),((1,2,6,5),(1,0,0)),((0,1,5,4),(0,-1,0)),((3,7,6,2),(0,1,0))]
  for ids,n in faces:self.quad(*(p[i] for i in ids),mat,n)
 def beam(self,a,b,w,d,mat):
  a=tuple(a); b=tuple(b); axis=[b[i]-a[i] for i in range(3)]; l=math.sqrt(sum(v*v for v in axis)); axis=[v/l for v in axis]
  ref=[0,1,0] if abs(axis[1])<.9 else [1,0,0]
  u=[axis[1]*ref[2]-axis[2]*ref[1],axis[2]*ref[0]-axis[0]*ref[2],axis[0]*ref[1]-axis[1]*ref[0]]; ul=math.sqrt(sum(x*x for x in u)); u=[x/ul*w/2 for x in u]
  v=[axis[1]*u[2]-axis[2]*u[1],axis[2]*u[0]-axis[0]*u[2],axis[0]*u[1]-axis[1]*u[0]]; vl=math.sqrt(sum(x*x for x in v)); v=[x/vl*d/2 for x in v]
  pts=[]
  for p in (a,b):
   for su,sv in ((-1,-1),(1,-1),(1,1),(-1,1)):pts.append(tuple(p[i]+su*u[i]+sv*v[i] for i in range(3)))
  mid=tuple((a[i]+b[i])/2 for i in range(3))
  for k in range(4):
   n=tuple((pts[k][i]+pts[(k+1)%4][i]+pts[(k+1)%4+4][i]+pts[k+4][i])/4-mid[i] for i in range(3))
   self.quad(pts[k],pts[(k+1)%4],pts[(k+1)%4+4],pts[k+4],mat,n)
  self.quad(*pts[:4],mat,tuple(-x for x in axis)); self.quad(*pts[4:],mat,axis)
 def cylinder(self,a,b,r,mat,segments=8):
  axis=[b[i]-a[i] for i in range(3)]; l=math.sqrt(sum(x*x for x in axis)); axis=[x/l for x in axis]
  ref=[0,1,0] if abs(axis[1])<.9 else [1,0,0]
  u=[axis[1]*ref[2]-axis[2]*ref[1],axis[2]*ref[0]-axis[0]*ref[2],axis[0]*ref[1]-axis[1]*ref[0]]; q=math.sqrt(sum(x*x for x in u)); u=[x/q for x in u]
  v=[axis[1]*u[2]-axis[2]*u[1],axis[2]*u[0]-axis[0]*u[2],axis[0]*u[1]-axis[1]*u[0]]
  rings=[]
  for p in (a,b): rings.append([tuple(p[j]+r*(u[j]*math.cos(2*math.pi*k/segments)+v[j]*math.sin(2*math.pi*k/segments)) for j in range(3)) for k in range(segments)])
  mid=tuple((a[i]+b[i])/2 for i in range(3))
  for k in range(segments):
   c=tuple((rings[0][k][i]+rings[0][(k+1)%segments][i]+rings[1][k][i]+rings[1][(k+1)%segments][i])/4 for i in range(3)); out=tuple(c[i]-mid[i] for i in range(3))
   self.quad(rings[0][k],rings[0][(k+1)%segments],rings[1][(k+1)%segments],rings[1][k],mat,out)
  for k in range(1,segments-1): self.tri(a,rings[0][k+1],rings[0][k],mat,tuple(-x for x in axis)); self.tri(b,rings[1][k],rings[1][k+1],mat,axis)
 def roof_prism(self,top,drop,mat):
  bot=[(p[0],p[1]-drop,p[2]) for p in top]
  center=tuple(sum(p[i] for p in top)/len(top) for i in range(3))
  # top face normal points generally upward
  self.quad(*top,mat,(0,1,0))
  for i in range(len(top)): 
   j=(i+1)%len(top); mid=tuple((top[i][k]+top[j][k]+bot[i][k]+bot[j][k])/4-center[k] for k in range(3)); self.quad(top[i],top[j],bot[j],bot[i],mat,mid)
 def export(self,path):
  blob=bytearray(); views=[]; accessors=[]; primitives=[]
  def add_view(data,target=None):
   while len(blob)%4:blob.append(0)
   off=len(blob); blob.extend(data); vi=len(views); view={'buffer':0,'byteOffset':off,'byteLength':len(data)}
   if target is not None:view['target']=target
   views.append(view); return vi
  wood_path=OUT/'weathered_wood_albedo.png'; roof_path=OUT/'weathered_roof_albedo.png'
  if not wood_path.exists():make_png(wood_path,False)
  if not roof_path.exists():make_png(roof_path,True)
  wood_image=add_view(wood_path.read_bytes()); roof_image=add_view(roof_path.read_bytes())
  images=[{'bufferView':wood_image,'mimeType':'image/png','name':'Weathered_Wood_Albedo'},{'bufferView':roof_image,'mimeType':'image/png','name':'Weathered_Roof_Albedo'}]
  textures=[{'source':0,'sampler':0},{'source':1,'sampler':0}]
  for mat,verts in self.groups.items():
   if not verts: continue
   pos=b''.join(struct.pack('<3f',*v[0]) for v in verts); nor=b''.join(struct.pack('<3f',*v[1]) for v in verts); ids=b''.join(struct.pack('<I',i) for i in range(len(verts)))
   uvdata=[]
   for p,n in verts:
    if mat.startswith('roof'):
     uvdata.extend((p[2]*.42,p[0]*.42))
    elif abs(n[0])>=abs(n[1]) and abs(n[0])>=abs(n[2]):
     uvdata.extend((p[2]*.48,p[1]*.48))
    elif abs(n[2])>=abs(n[0]) and abs(n[2])>=abs(n[1]):
     uvdata.extend((p[0]*.48,p[1]*.48))
    else:
     uvdata.extend((p[0]*.48,p[2]*.48))
   uv=b''.join(struct.pack('<2f',uvdata[i],uvdata[i+1]) for i in range(0,len(uvdata),2))
   posid=len(accessors); pv=add_view(pos,34962); xs=[v[0] for v in verts]; mins=[min(v[i] for v in xs) for i in range(3)]; maxs=[max(v[i] for v in xs) for i in range(3)]; accessors.append({'bufferView':pv,'componentType':5126,'count':len(verts),'type':'VEC3','min':mins,'max':maxs})
   norid=len(accessors); nv=add_view(nor,34962); accessors.append({'bufferView':nv,'componentType':5126,'count':len(verts),'type':'VEC3'})
   uvid=len(accessors); uvv=add_view(uv,34962); accessors.append({'bufferView':uvv,'componentType':5126,'count':len(verts),'type':'VEC2'})
   iid=len(accessors); iv=add_view(ids,34963); accessors.append({'bufferView':iv,'componentType':5125,'count':len(verts),'type':'SCALAR','min':[0],'max':[len(verts)-1]})
   primitives.append({'attributes':{'POSITION':posid,'NORMAL':norid,'TEXCOORD_0':uvid},'indices':iid,'material':list(MATS).index(mat),'mode':4})
  materials=[]
  for k,v in MATS.items():
   pbr={'baseColorFactor':list(v),'metallicFactor':0.0,'roughnessFactor':0.92}
   if k in ('weathered_log','log_light','beam','beam_light','door','ground_wood'):pbr['baseColorTexture']={'index':0}
   elif k in ('roof','roof_light'):pbr['baseColorTexture']={'index':1}
   materials.append({'name':k,'pbrMetallicRoughness':pbr,'doubleSided':True})
  gltf={'asset':{'version':'2.0','generator':'Codex procedural low-poly house builder'},'scene':0,'scenes':[{'nodes':[0]}], 'nodes':[{'name':self.name,'mesh':0}], 'meshes':[{'name':self.name,'primitives':primitives}], 'materials':materials,'textures':textures,'images':images,'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}], 'buffers':[{'byteLength':len(blob)}], 'bufferViews':views,'accessors':accessors}
  js=json.dumps(gltf,separators=(',',':')).encode('utf8'); js+=b' '*((4-len(js)%4)%4)
  while len(blob)%4:blob.append(0)
  total=12+8+len(js)+8+len(blob)
  with open(path,'wb') as f: f.write(b'glTF'+struct.pack('<II',2,total)+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob)

def cabin(name, shed=False, frame=False):
 m=Model(name)
 if frame:
  # open market/work shelter with plank platform and a simple timber frame
  m.box((0,.16,0),(4.4,.30,3.6),'ground_wood')
  for x in (-1.9,1.9):
   for z in (-1.5,1.5): m.beam((x,.3,z),(x,2.9,z),.18,.18,'beam')
  m.beam((-2.25,2.9,-1.7),(2.25,2.9,-1.7),.18,.18,'beam_light'); m.beam((-2.25,2.9,1.7),(2.25,2.9,1.7),.18,.18,'beam_light')
  m.beam((0,3.7,-1.7),(0,3.7,1.7),.2,.2,'beam')
  for z in (-1.6,1.6):
   m.beam((-2.2,2.9,z),(0,3.7,z),.14,.14,'beam_light'); m.beam((0,3.7,z),(2.2,2.9,z),.14,.14,'beam_light')
  for x in (-1.2,-.4,.4,1.2): m.beam((x,3.0,-1.9),(x,3.65,0),.10,.10,'beam')
  m.roof_prism([(-2.35,2.95,-1.9),(0,3.78,-1.9),(0,3.78,1.9),(-2.35,2.95,1.9)],.12,'roof')
  m.roof_prism([(0,3.78,-1.9),(2.35,2.95,-1.9),(2.35,2.95,1.9),(0,3.78,1.9)],.12,'roof_light')
  return m
 w=3.8 if shed else 4.2; d=3.2 if shed else 3.8; wallh=2.45
 # dark timber wall mass, elevated sill and stone blocks
 m.box((0,.20,0),(w+.15,.4,d+.15),'stone')
 m.box((0,.47,0),(w,.14,d),'ground_wood')
 m.box((0,.47+wallh/2,0),(w,wallh,d),'weathered_log')
 # horizontal log courses visible on all sides
 for y in [.65,.94,1.23,1.52,1.81,2.10,2.39,2.68,2.88]:
  for z in (-d/2-.05,d/2+.05): m.beam((-w/2,y,z),(w/2,y,z),.15,.15,'log_light' if int(y*10)%2 else 'weathered_log')
  for x in (-w/2-.05,w/2+.05): m.beam((x,y,-d/2),(x,y,d/2),.15,.15,'log_light' if int(y*10)%2 else 'weathered_log')
 # corner posts and timber framing
 for x in (-w/2,w/2):
  for z in (-d/2,d/2): m.beam((x,.45,z),(x,3.05,z),.22,.22,'beam_light')
 # gable house pitched roof or lean-to roof
 eave=2.95; ridge=4.15
 if not shed:
  for z in (-d/2-.18,d/2+.18):
   m.beam((-w/2-.18,eave,z),(0,ridge,z),.16,.16,'beam_light');m.beam((0,ridge,z),(w/2+.18,eave,z),.16,.16,'beam_light')
  m.roof_prism([(-w/2-.32,eave,-d/2-.28),(0,ridge,-d/2-.28),(0,ridge,d/2+.28),(-w/2-.32,eave,d/2+.28)],.18,'roof')
  m.roof_prism([(0,ridge,-d/2-.28),(w/2+.32,eave,-d/2-.28),(w/2+.32,eave,d/2+.28),(0,ridge,d/2+.28)],.18,'roof_light')
  m.beam((0,ridge+.06,-d/2-.25),(0,ridge+.06,d/2+.25),.16,.16,'beam')
 else:
  m.roof_prism([(-w/2-.35,3.15,-d/2-.25),(w/2+.35,2.65,-d/2-.25),(w/2+.35,2.65,d/2+.25),(-w/2-.35,3.15,d/2+.25)],.16,'roof')
 # door on front (-z), vertical planks and frame
 m.box((0,1.24,-d/2-.09),(.95,1.75,.13),'door')
 for x in (-.53,.53):m.beam((x,.4,-d/2-.15),(x,2.18,-d/2-.15),.12,.12,'beam_light')
 m.beam((-.58,2.2,-d/2-.15),(.58,2.2,-d/2-.15),.14,.12,'beam_light')
 for x in (-.28,0,.28):m.beam((x,.42,-d/2-.17),(x,2.05,-d/2-.17),.035,.035,'log_light')
 m.box((.32,1.2,-d/2-.20),(.07,.07,.06),'metal')
 # front and side windows
 for x in (-1.25,1.25):
  m.box((x,1.72,-d/2-.09),(.58,.62,.12),'dark_opening');m.box((x,1.72,-d/2-.17),(.48,.48,.08),'glass')
  for dx in (-.31,.31):m.beam((x+dx,1.36,-d/2-.19),(x+dx,2.08,-d/2-.19),.07,.07,'beam_light')
  for yy in (1.35,2.09):m.beam((x-.34,yy,-d/2-.19),(x+.34,yy,-d/2-.19),.07,.07,'beam_light')
 # side framing boards create half-timber rhythm
 for z in (-d/2+.45,0,d/2-.45):
  for x in (-w/2-.10,w/2+.10):m.beam((x,.55,z),(x,2.95,z),.12,.12,'beam')
 # porch canopy / supports
 if not shed:
  for x in (-1.25,1.25):m.beam((x,.3,-d/2-.55),(x,2.55,-d/2-.55),.14,.14,'beam_light')
  m.beam((-1.35,2.55,-d/2-.55),(1.35,2.55,-d/2-.55),.14,.14,'beam')
  m.roof_prism([(-1.55,2.7,-d/2-1.15),(1.55,2.7,-d/2-1.15),(1.4,3.25,-d/2+.05),(-1.4,3.25,-d/2+.05)],.12,'roof_light')
 return m

def hex_house():
 m=Model('Medieval_Hexagonal_Roof_House')
 R=2.35; N=6; angles=[math.radians(-90+i*60) for i in range(N)]
 ring=[(R*math.cos(a),R*math.sin(a)) for a in angles]
 # stone footing and six log courses
 m.cylinder((0,.12,0),(0,.42,0),R+.12,'stone',6)
 for y in [.55,.82,1.09,1.36,1.63,1.90,2.17,2.44,2.71]:
  for i in range(N):
   x1,z1=ring[i];x2,z2=ring[(i+1)%N]
   m.cylinder((x1,y,z1),(x2,y,z2),.13,'log_light' if int(y*10)%2 else 'weathered_log',8)
 # heavier upright corner timbers
 for x,z in ring:m.beam((x,.38,z),(x,3.02,z),.20,.20,'beam_light')
 # front door placed at z negative face, centered
 m.box((0,1.25,-2.15),(.92,1.85,.14),'door')
 for x in (-.52,.52):m.beam((x,.38,-2.24),(x,2.25,-2.24),.13,.13,'beam_light')
 m.beam((-.58,2.28,-2.24),(.58,2.28,-2.24),.14,.14,'beam_light')
 for x in (-.25,0,.25):m.beam((x,.42,-2.26),(x,2.14,-2.26),.035,.035,'log_light')
 m.box((.31,1.23,-2.32),(.07,.07,.06),'metal')
 # windows on alternate outward faces; pane fitted slightly out from wall
 for ang in (math.radians(-30),math.radians(30),math.radians(150),math.radians(210)):
  nx,nz=math.cos(ang),math.sin(ang); cx,cz=nx*2.12,nz*2.12
  m.box((cx,1.76,cz),(.58,.68,.10),'dark_opening')
  m.box((cx+nx*.07,1.76,cz+nz*.07),(.43,.50,.06),'glass')
  for dx in (-.32,.32):m.beam((cx+dx,1.38,cz),(cx+dx,2.14,cz),.07,.07,'beam_light')
  for yy in (1.37,2.15):m.beam((cx-.35,yy,cz),(cx+.35,yy,cz),.07,.07,'beam_light')
 # Broad lower hex roof: eaves to raised inner ring (six roof panels)
 outer=[(3.12*math.cos(a),2.98,3.12*math.sin(a)) for a in angles]
 inner=[(1.38*math.cos(a),4.15,1.38*math.sin(a)) for a in angles]
 for i in range(N):
  j=(i+1)%N; m.quad(outer[i],outer[j],inner[j],inner[i],'roof',(0,1,0))
  # thick eave fascia and rafter on each spoke
  m.beam(outer[i],outer[j],.16,.16,'beam_light')
  m.beam(outer[i],inner[i],.12,.12,'beam')
 # Upper spire: tall timber cone with eight polygonal panels and small finial cap
 top=(0,7.15,0); lower=[(1.42*math.cos(a),4.15,1.42*math.sin(a)) for a in [2*math.pi*i/8 for i in range(8)]]
 for i in range(8):
  j=(i+1)%8; m.tri(lower[i],lower[j],top,'roof_light' if i%2 else 'roof',(0,1,0))
  m.beam(lower[i],top,.075,.075,'beam_light')
 # cap / little peak
 capbase=[(.43*math.cos(2*math.pi*i/8),7.08,.43*math.sin(2*math.pi*i/8)) for i in range(8)]; cap=(0,7.82,0)
 for i in range(8):m.tri(capbase[i],capbase[(i+1)%8],cap,'weathered_log',(0,1,0))
 # front porch with timber posts and small gabled cover
 for x in (-.9,.9):m.beam((x,.35,-2.45),(x,2.62,-2.45),.16,.16,'beam_light')
 m.beam((-.98,2.62,-2.45),(.98,2.62,-2.45),.14,.14,'beam')
 m.beam((-.98,2.65,-2.50),(0,3.35,-2.50),.12,.12,'beam_light');m.beam((0,3.35,-2.50),(.98,2.65,-2.50),.12,.12,'beam_light')
 m.roof_prism([(-1.15,2.73,-2.95),(0,3.45,-2.95),(0,3.45,-2.22),(-1.15,2.73,-2.22)],.12,'roof')
 m.roof_prism([(0,3.45,-2.95),(1.15,2.73,-2.95),(1.15,2.73,-2.22),(0,3.45,-2.22)],.12,'roof_light')
 return m

models=[
 ('wooden_forest_gable_house.glb',cabin('Wooden_Forest_Gable_House')),
 ('wooden_forest_lean_to_house.glb',cabin('Wooden_Forest_Lean_To_House',shed=True)),
 ('wooden_forest_open_timber_shelter.glb',cabin('Wooden_Forest_Open_Timber_Shelter',frame=True)),
 ('medieval_hexagonal_roof_house.glb',hex_house()),
]
for filename,model in models:
 model.export(OUT/filename)
 print(filename, (OUT/filename).stat().st_size)
