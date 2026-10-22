-- Original geometry and droplet motion, independent of engine objects.
local M = {}
function M.v(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
function M.add(a,b) return M.v(a.x+b.x,a.y+b.y,a.z+b.z) end
function M.sub(a,b) return M.v(a.x-b.x,a.y-b.y,a.z-b.z) end
function M.mul(a,s) return M.v(a.x*s,a.y*s,a.z*s) end
function M.dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
function M.cross(a,b) return M.v(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) end
function M.length(a) return math.sqrt(M.dot(a,a)) end
function M.unit(a) local n=M.length(a); return n>1e-9 and M.mul(a,1/n) or M.v(0,0,1) end
function M.project(a,n) return M.sub(a,M.mul(n,M.dot(a,n))) end
function M.excludedGlass(name)
  name=(name or ""):lower()
  return name:find("_int$") or name:find("_int_") or name:find("_in$") or name:find("interior") or name:find("dmg") or name:find("broken")
    or name:find("mirror") or name:find("headlight") or name:find("taillight") or name:find("lamp")
    or name:find("foglight") or name:find("rooflight") or name:find("spotlight") or name:find("lightglass")
    or name:find("signal") or name:find("invisible") or name:find("wiper") or name:find("seal") or name:find("trim")
    or name:find("handle") or name:find("switch") or name:find("windowbush") or name:find("window_net") or name:find("windownet")
end
function M.glassName(name, material)
  name=(name or ""):lower()
  if M.excludedGlass(name) then return false end
  local label=name.." "..(material or ""):lower()
  return label:find("glass")~=nil or label:find("windshield")~=nil or label:find("windscreen")~=nil
    or label:find("window")~=nil or label:find("backlight")~=nil or label:find("sunroof")~=nil
end
function M.frame(forward,up)
  local f=M.unit(forward)
  local r=M.unit(M.cross(f,up))
  return {right=r,forward=f,up=M.unit(M.cross(r,f))}
end
function M.localVector(p,f) return M.v(M.dot(p,f.right),M.dot(p,f.forward),M.dot(p,f.up)) end
-- GPUMesh supplies glTF coordinates: (BeamNG x, BeamNG z, -BeamNG y).
-- ProceduralMesh and vehicle/camera vectors use BeamNG's Z-up coordinates.
function M.fromGpuVertex(x,y,z) return M.v(x,-z,y) end
function M.worldVector(p,f) return M.add(M.add(M.mul(f.right,p.x),M.mul(f.forward,p.y)),M.mul(f.up,p.z)) end
function M.bounds(points)
  local lo,hi=M.v(math.huge,math.huge,math.huge),M.v(-math.huge,-math.huge,-math.huge)
  for _,p in ipairs(points) do for _,k in ipairs({"x","y","z"}) do lo[k]=math.min(lo[k],p[k]);hi[k]=math.max(hi[k],p[k]) end end
  return {lo=lo,hi=hi}
end
function M.contains(p,b,pad)
  pad=pad or 0
  return p.x>=b.lo.x-pad and p.x<=b.hi.x+pad and p.y>=b.lo.y-pad and p.y<=b.hi.y+pad and p.z>=b.lo.z-pad and p.z<=b.hi.z+pad
end
function M.guardRadius(cameraLocal,b)
  local r=0
  for _,x in ipairs({b.lo.x,b.hi.x}) do for _,y in ipairs({b.lo.y,b.hi.y}) do for _,z in ipairs({b.lo.z,b.hi.z}) do
    r=math.max(r,M.length(M.sub(cameraLocal,M.v(x,y,z))))
  end end end
  -- Also cover the finite size of native rain quads at the guard boundary.
  return r+0.9
end
function M.triangle(a,b,c,panel)
  local normal=M.cross(M.sub(b,a),M.sub(c,a))
  local area=M.length(normal)*0.5
  if area<1e-7 then return nil end
  return {a=a,b=b,c=c,n=M.unit(normal),area=area,panel=panel}
end
function M.barycentric(p,t)
  local e1,e2,d=M.sub(t.b,t.a),M.sub(t.c,t.a),M.sub(p,t.a)
  local aa,ab,bb=M.dot(e1,e1),M.dot(e1,e2),M.dot(e2,e2)
  local den=aa*bb-ab*ab
  if math.abs(den)<1e-12 then return nil end
  local v=(bb*M.dot(d,e1)-ab*M.dot(d,e2))/den
  local w=(aa*M.dot(d,e2)-ab*M.dot(d,e1))/den
  return {1-v-w,v,w}
end
function M.point(t,b) return M.add(M.add(M.mul(t.a,b[1]),M.mul(t.b,b[2])),M.mul(t.c,b[3])) end
function M.flow(normal,gravity,air,size)
  -- Small beads cling to glass. Larger beads creep under gravity and air shear;
  -- terminal speed prevents motorway airflow from moving them centimetres per tick.
  local mobility=math.max(0,math.min(1,(size-0.0024)/0.0046))
  local gravityFlow=M.mul(M.project(gravity,normal),0.00015+0.0025*mobility)
  local tangent=M.project(air,normal)
  local speed=M.length(tangent)
  local shear=math.max(0,speed-6)*(0.0002+0.0014*mobility)
  local flow=M.add(gravityFlow,M.mul(M.unit(tangent),shear))
  local length=M.length(flow)
  local terminal=0.018+0.062*mobility
  return length>terminal and M.mul(flow,terminal/length) or flow
end
function M.smoothFlow(previous,target,normal,dt)
  local blend=1-math.exp(-math.max(0,dt)/0.18)
  return M.project(M.add(previous,M.mul(M.sub(target,previous),blend)),normal)
end
function M.flux(normal,incoming) return math.max(0,-M.dot(normal,incoming)) end
function M.part(material) return {verts={},normals={},uvs={},faces={},material=material} end
function M.quad(part,center,right,up,normal,tile)
  local v,n,u=#part.verts,#part.normals,#part.uvs
  part.normals[n+1]=normal
  local cell=tile or 0
  local x,y=(cell%4)/4,math.floor(cell/4)/4
  local positions={M.sub(M.sub(center,right),up),M.add(M.sub(center,up),right),M.add(M.add(center,right),up),M.add(M.sub(center,right),up)}
  local uv={{x,y+0.25},{x+0.25,y+0.25},{x+0.25,y},{x,y}}
  for i=1,4 do part.verts[v+i]=positions[i];part.uvs[u+i]={u=uv[i][1],v=uv[i][2]} end
  -- ProceduralMesh uses clockwise front faces. Material is two-sided for glass.
  for _,i in ipairs({0,2,1,0,3,2}) do part.faces[#part.faces+1]={v=v+i,n=n,u=u+i} end
end
return M
