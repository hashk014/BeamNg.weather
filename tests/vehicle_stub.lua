-- Actual documented GPU-mesh and ProceduralMesh API shape, synthetic geometry.
local g=require("ge/extensions/beamngWeather/surfaceMath")
package.preload.cdefGpuMesh=function()
  require("ffi").cdef("typedef struct {uint32_t startIndex;uint32_t indexCount;uint32_t materialId;} gpuPrimitive_t;")
end
function vec3(x,y,z)
  if type(x)=="table" then return {x=x.x,y=x.y,z=x.z} end
  return {x=x or 0,y=y or 0,z=z or 0}
end
cameraPosition=vec3(10,20,1.5)
function quat()
  local q={x=0,y=0,z=0,w=1}
  function q:inversed() return quat() end
  return setmetatable(q,{__mul=function() return quat() end})
end
core_camera.getQuat=function() return setmetatable({}, {__mul=function(_,v) return v end}) end
vehicle=createObject("BeamNGVehicle")
vehicle:registerObject("testVehicle")
vehicle.pos=vec3(10,20,0)
vehicle.velocity=vec3(0,0,0)
function vehicle:getPosition() return self.pos end
function vehicle:getVelocity() return self.velocity end
function vehicle:getDirectionVector() return vec3(0,1,0) end
function vehicle:getDirectionVectorUp() return vec3(0,0,1) end
function vehicle:getRefNodeRotation() return quat() end
function vehicle:getMaterialNames() return {"test_glass","test_body","test_glass_int","glass_invisible"} end
function getPlayerVehicle() return vehicle end
vehicleData={vdata={flexbodies={}}}
core_vehicle_manager={getVehicleData=function() return vehicleData end}
local originalCreate=createObject
function createObject(class)
  local o=originalCreate(class)
  if class=="ProceduralMesh" then
    function o:setPosRot(x,y,z,qx,qy,qz,qw) self.position=vec3(x,y,z);self.rotation={qx,qy,qz,qw} end
    function o:createMesh(lods)
      assert(self.collisionType=="None", "Visual meshes must not add physical colliders")
      self.mesh=lods[1][1]
      local material=registry[self.mesh.material]
      assert(material and material:getClassName()=="Material","Mesh material must resolve to a Material")
      for _,f in ipairs(self.mesh.faces) do
        assert(f.v>=0 and f.v<#self.mesh.verts and f.n>=0 and f.n<#self.mesh.normals and f.u>=0 and f.u<#self.mesh.uvs)
      end
      self.builds=(self.builds or 0)+1
    end
  end
  return o
end
local originalLoad=loadJsonMaterialsFile
function loadJsonMaterialsFile(path)
  if path:find("surfaces.materials",1,true) then
    if failSurfaceMaterials then return end
    for name,data in pairs(testSurfaceMaterials) do
      if not registry[name] then
        local material=createObject(data.class)
        material.definition=data
        material:registerObject(name)
      end
    end
    return
  end
  originalLoad(path)
end
roof=false
rayCalls=0
function castRayStatic(pos,dir,length)
  rayCalls=rayCalls+1
  if dir.z<0 then return roof and pos.z-4 or pos.z end
  return roof and 2 or length
end
local vertices,indices,flex={}, {}, {}
local function pane(name,a,b,c,d)
  local vi,ii=#vertices,#indices
  for _,p in ipairs({a,b,c,d}) do vertices[#vertices+1]=p end
  for _,i in ipairs({0,1,2,0,2,3}) do indices[#indices+1]=vi+i end
  local f={meshName=name,primitivesCount=1}
  function f:primitivesGet(out) out[0].startIndex=ii;out[0].indexCount=6;out[0].materialId=self.materialId or 0;return true end
  flex[#flex+1]=f
  vehicleData.vdata.flexbodies[#flex]={mesh=name,deformMaterialBase="test_glass"}
end
pane("test_windshield",g.v(-1,1,1),g.v(1,1,1),g.v(1,0.7,2),g.v(-1,0.7,2))
pane("test_backlight",g.v(1,-1,1),g.v(-1,-1,1),g.v(-1,-0.7,2),g.v(1,-0.7,2))
pane("test_window_left",g.v(-1,-0.8,1),g.v(-1,0.8,1),g.v(-1,0.7,2),g.v(-1,-0.7,2))
pane("test_window_right",g.v(1,0.8,1),g.v(1,-0.8,1),g.v(1,-0.7,2),g.v(1,0.7,2))
pane("test_sunroof",g.v(-0.6,-0.5,2),g.v(0.6,-0.5,2),g.v(0.6,0.5,2),g.v(-0.6,0.5,2))
-- These must not be mistaken for an exterior pane.
pane("test_windshield_int",g.v(-1,1,1),g.v(1,1,1),g.v(1,1,2),g.v(-1,1,2))
pane("test_headlight",g.v(-1,2,0.2),g.v(1,2,0.2),g.v(1,2,0.5),g.v(-1,2,0.5))
scans,freed=0,0
meshReady=true
GPUMesh={bng_getGPUMesh=function()
  scans=scans+1
  local m={verticesCount=#vertices,indicesCount=#indices,flexmeshesCount=#flex,dataIsReady=meshReady}
  function m:verticesGet(out) for i,p in ipairs(vertices) do out[(i-1)*3]=p.x;out[(i-1)*3+1]=p.y;out[(i-1)*3+2]=p.z end;return true end
  function m:indicesGet(out) for i,v in ipairs(indices) do out[i-1]=v end;return true end
  function m:flexmeshes(i) return flex[i+1] end
  function m:free() assert(not self.freed);self.freed=true;freed=freed+1 end
  return m
end}
math.randomseed(14)
