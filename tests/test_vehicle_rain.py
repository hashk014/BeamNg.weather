"""Synthetic 3D integration, using the native GPU/mesh API shapes; no GPU rendering."""
import unittest
import json
from pathlib import Path
from lupa.luajit21 import LuaRuntime
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'mod/lua'


class VehicleRainTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().moduleRoot=LUA.as_posix()
        self.lua.globals().testSurfaceMaterials=self.lua.table_from(json.loads((ROOT/'mod/art/beamng_weather_hashk014/surfaces.materials.json').read_text()),recursive=True)
        self.lua.execute('package.path=moduleRoot.."/?.lua;"..package.path')
        self.lua.execute((ROOT/'tests/engine_stub.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT/'tests/vehicle_stub.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
          g=require("ge/extensions/beamngWeather/surfaceMath")
          effects=require("ge/extensions/beamngWeather/vehicleRain")
          config=require("ge/extensions/beamngWeather/model").defaults()
          config.quality="low"; config.intensity=1; config.transition=0
          function advance(n) for i=1,n do effects.update(config,0.05,1) end end
        ''')

    def run_lua(self,code):
        self.lua.execute(code)

    def test_gpu_detection_all_panes_excludes_interior_and_lamps_and_frees_snapshot(self):
        self.run_lua('''
          advance(40)
          local state=effects.getState()
          assert(state.available and state.panels==5 and not state.warning)
          assert(not g.glassName("pickup_wipers","glass_invisible"))
          assert(not g.glassName("pickup_glass_trim","pickup_glass"))
          assert(state.glassDrops>0 and state.guardRadius>0 and scans==1 and freed==1)
          advance(140)
          for _,name in ipairs({"test_windshield","test_backlight","test_window_left","test_window_right","test_sunroof"}) do
            assert(effects.getState().wetPanels[name] and effects.getState().wetPanels[name]>0,name)
          end
          assert(scans==1 and freed==1)
        ''')

    def test_near_particles_exclude_cabin_and_do_not_change_physics(self):
        self.run_lua('''
          advance(30)
          local state=effects.getState()
          assert(state.nearDrops>0 and state.reservedDrops<=300)
          local part=registry.beamngWeather_hashk014_nearDropsMesh.mesh
          local box={lo=g.v(-1,-1,0.35),hi=g.v(1,1,2)}
          for i=1,#part.verts,4 do
            local center=g.mul(g.add(g.add(part.verts[i],part.verts[i+1]),g.add(part.verts[i+2],part.verts[i+3])),0.25)
            assert(not g.contains(center,box,0.09))
          end
          assert(registry.beamngWeather_hashk014_nearDropsMesh.collisionType=="None")
          assert(registry.beamngWeather_hashk014_glassDropsMesh.collisionType=="None")
          assert(vehicle.velocity.y==0 and registry.mapRain.numDrops==7)
        ''')

    def test_real_materials_override_inherited_glass_label_and_mixed_mesh_names(self):
        self.run_lua('''
          local original=GPUMesh.bng_getGPUMesh
          GPUMesh.bng_getGPUMesh=function()
            local m=original()
            -- A named windshield has body material; a generic shell contains glass.
            m:flexmeshes(0).materialId=1
            m:flexmeshes(1).meshName="test_combined_shell"
            -- Window hardware and interior/invisible materials must not count.
            m:flexmeshes(2).meshName="test_windowhandle"
            m:flexmeshes(3).materialId=2
            m:flexmeshes(4).materialId=3
            return m
          end
          advance(100)
          local state=effects.getState()
          assert(state.available and state.panels==1 and state.glassTriangles==2)
          assert(state.glassDrops>0 and state.wetPanels.test_combined_shell)
          assert(not g.glassName("pickup_desert_window_net_L"))
          assert(not g.glassName("pickup_foglightglass_R"))
          assert(not g.glassName("pickup_rollcage_windowbush"))
          assert(not g.glassName("pickup_windowswitch_R"))
        ''')

    def test_shared_primitive_ranges_do_not_hit_triangle_limit(self):
        self.run_lua('''
          local original=GPUMesh.bng_getGPUMesh
          GPUMesh.bng_getGPUMesh=function()
            local m=original();local f=m:flexmeshes(0)
            local read=f.primitivesGet
            f.primitivesCount=16000
            f.primitivesGet=function(self,out)
              read(self,out)
              for i=1,15999 do out[i]=out[0] end
              return true
            end
            return m
          end
          advance(40)
          local state=effects.getState()
          assert(state.available and state.panels==5 and state.glassTriangles==10)
          assert(not state.sampled and not state.warning and state.glassDrops>0)
          assert(scans==1 and freed==1)
        ''')

    def test_high_detail_glass_keeps_all_panes_with_bounded_sampling(self):
        self.run_lua('''
          local positions,idx={},{}
          local function quad(a,b,c,d)
            local base=#positions
            for _,p in ipairs({a,b,c,d}) do positions[#positions+1]=p end
            for _,v in ipairs({0,1,2,0,2,3}) do idx[#idx+1]=base+v end
          end
          for x=0,159 do for z=0,99 do
            local left,right=-1+x/80,-1+(x+1)/80
            local bottom,top=1+z/100,1+(z+1)/100
            quad(g.v(left,1,bottom),g.v(right,1,bottom),g.v(right,1,top),g.v(left,1,top))
          end end
          local sideStart=#idx
          quad(g.v(1,-1,1),g.v(1,1,1),g.v(1,1,2),g.v(1,-1,2))
          GPUMesh.bng_getGPUMesh=function()
            scans=scans+1
            local m={verticesCount=#positions,indicesCount=#idx,flexmeshesCount=2,dataIsReady=true}
            function m:verticesGet(out)
              for i,p in ipairs(positions) do out[(i-1)*3]=p.x;out[(i-1)*3+1]=p.y;out[(i-1)*3+2]=p.z end
              return true
            end
            function m:indicesGet(out) for i,v in ipairs(idx) do out[i-1]=v end;return true end
            function m:flexmeshes(i)
              return {meshName=i==0 and "dense_windshield" or "small_window",primitivesCount=1,
                primitivesGet=function(_,out)
                  out[0].startIndex=i==0 and 0 or sideStart
                  out[0].indexCount=i==0 and sideStart or 6
                  out[0].materialId=0;return true
                end}
            end
            function m:free() freed=freed+1 end
            return m
          end
          advance(40)
          local state=effects.getState()
          assert(state.available and state.sampled and state.panels==2)
          assert(state.glassTriangles<=30000 and state.glassTriangles>29000)
          assert(state.glassDrops>0 and state.wetPanels.dense_windshield)
          assert(state.wetPanels.small_window and state.guardRadius>0)
          assert(scans==1 and freed==1)
        ''')

    def test_repeated_triangles_in_different_ranges_are_not_counted_twice(self):
        self.run_lua('''
          local original=GPUMesh.bng_getGPUMesh
          GPUMesh.bng_getGPUMesh=function()
            local m=original();local read=m.indicesGet
            m.indicesGet=function(self,out)
              read(self,out)
              for i=0,5 do out[i+6]=out[i] end
              return true
            end
            return m
          end
          advance(30)
          local state=effects.getState()
          assert(state.available and state.panels==4 and state.glassTriangles==8)
          assert(state.glassDrops>0 and not state.warning)
        ''')

    def test_unavailable_material_table_keeps_mesh_name_fallback(self):
        self.run_lua('''
          vehicle.getMaterialNames=nil
          advance(30)
          assert(effects.getState().panels==5 and effects.getState().glassDrops>0)
        ''')

    def test_tunnel_stops_new_glass_drops_and_near_air_rain(self):
        self.run_lua('''
          roof=true; advance(50)
          local state=effects.getState()
          assert(state.available and state.glassDrops==0)
          local function noRainBelowRoof()
            local part=registry.beamngWeather_hashk014_nearDropsMesh.mesh
            if part then
              for i=1,#part.verts,4 do
                local z=(part.verts[i].z+part.verts[i+1].z+part.verts[i+2].z+part.verts[i+3].z)/4
                assert(z>4)
              end
            end
          end
          noRainBelowRoof()
          roof=false;advance(50)
          assert(effects.getState().glassDrops>0 and effects.getState().nearDrops>0)
          roof=true;advance(360)
          assert(effects.getState().glassDrops==0)
          noRainBelowRoof()
        ''')

    def test_speed_direction_changes_impact_flux_and_surface_flow(self):
        self.run_lua('''
          local front,back=g.v(0,1,0),g.v(0,-1,0)
          local forward,reverse=g.v(0,-25,-9),g.v(0,25,-9)
          assert(g.flux(front,forward)>g.flux(back,forward))
          assert(g.flux(back,reverse)>g.flux(front,reverse))
          local side=g.v(1,0,0)
          local a=g.flow(side,g.v(0,0,-9.81),forward,0.003)
          local b=g.flow(side,g.v(0,0,-9.81),reverse,0.003)
          assert(a.y<0 and b.y>0 and a.z<0 and b.z<0)
          local stationary=g.flow(side,g.v(0,0,-9.81),g.v(),0.003)
          assert(g.length(a)>g.length(stationary))
        ''')

    def test_pause_switches_and_cleanup(self):
        self.run_lua('''
          advance(30)
          local before=effects.getState().glassDrops
          for i=1,20 do effects.update(config,0,1) end
          assert(effects.getState().glassDrops==before)
          config.glassDrops=false;advance(1)
          assert(effects.getState().glassDrops==0 and effects.getState().guardRadius>0)
          config.cabinProtection=false;advance(1)
          assert(effects.getState().guardRadius==0 and not registry.beamngWeather_hashk014_surfaces)
          config.glassDrops=true;config.cabinProtection=true;advance(2)
          effects.invalidate(vehicle:getID())
          assert(not registry.beamngWeather_hashk014_surfaces)
          advance(2);assert(effects.getState().available)
          config.enabled=false;advance(1)
          assert(effects.getState().guardRadius==0 and not registry.beamngWeather_hashk014_surfaces)
        ''')

    def test_async_snapshot_timeout_and_bad_mesh_leave_native_rain_unmasked(self):
        self.run_lua('''
          meshReady=false;advance(110)
          assert(effects.getState().warning and effects.getState().guardRadius==0)
          assert(freed>=1)
          effects.clear();meshReady=true
          local old=GPUMesh.bng_getGPUMesh
          GPUMesh.bng_getGPUMesh=function() local m=old();m.verticesGet=function() error("injected failure") end;return m end
          advance(10)
          assert(effects.getState().warning:find("failed") and effects.getState().guardRadius==0)
          assert(freed==scans)
        ''')

    def test_camera_teleport_disables_guard_and_rebuilds_when_returning(self):
        self.run_lua('''
          advance(2);assert(effects.getState().guardRadius>0)
          cameraPosition=g.v(200,200,10);advance(1)
          assert(effects.getState().guardRadius==0 and not registry.beamngWeather_hashk014_surfaces)
          cameraPosition=g.v(10,20,1.5);advance(2)
          assert(effects.getState().guardRadius>0 and registry.beamngWeather_hashk014_surfaces)
          effects.clear();assert(freed==scans)
        ''')

    def test_glass_follows_pose_between_mesh_updates_while_air_stays_in_world_space(self):
        self.run_lua('''
          advance(20)
          local glass=registry.beamngWeather_hashk014_glassDropsMesh
          local air=registry.beamngWeather_hashk014_nearDropsMesh
          local oldAirX=air.position.x
          local builds=glass.builds
          vehicle.pos=g.v(11,20,0);cameraPosition=g.v(11,20,1.5)
          effects.update(config,0,1)
          assert(glass.position.x==11 and glass.builds==builds)
          assert(air.position.x==oldAirX)
          local frame=g.frame(g.v(1,0,0),g.v(0,0,1))
          local p=g.v(2,3,4)
          assert(g.length(g.sub(g.localVector(g.worldVector(p,frame),frame),p))<0.00001)
        ''')

    def test_window_assets_have_alpha_fade_and_normal_variation(self):
        folder=ROOT/'mod/art/beamng_weather_hashk014'
        with Image.open(folder/'glass_drop.color.png') as im:
            self.assertEqual(im.size,(256,256))
            self.assertGreater(im.getchannel('A').getextrema()[1],100)
            self.assertLess(im.crop((192,192,256,256)).getchannel('A').getextrema()[1],im.crop((0,0,64,64)).getchannel('A').getextrema()[1])
        with Image.open(folder/'glass_drop.normal.png') as im:
            self.assertGreater(im.getchannel('R').getextrema()[1]-im.getchannel('R').getextrema()[0],150)

    def test_material_names_survive_mesh_creation_reset_and_cleanup(self):
        self.run_lua('''
          for cycle=1,3 do
            advance(30)
            local glass=registry.beamngWeather_hashk014_glassDropsMesh
            local air=registry.beamngWeather_hashk014_nearDropsMesh
            assert(glass and air and glass.mesh and air.mesh)
            for _,mesh in ipairs({glass,air}) do
              local material=registry[mesh.mesh.material]
              assert(material:getClassName()=="Material" and material.name~=mesh.name)
              assert(material.definition.translucent and not material.definition.translucentZWrite)
            end
            effects.clear()
            assert(not registry.beamngWeather_hashk014_glassDropsMesh)
            assert(registry.beamngWeather_hashk014_glassDrops:getClassName()=="Material")
          end
        ''')

    def test_missing_material_stops_surface_meshes_before_guard_or_fallback_rectangles(self):
        self.run_lua('''
          failSurfaceMaterials=true
          advance(3)
          local state=effects.getState()
          assert(state.warning:find("Rain material unavailable"))
          assert(state.guardRadius==0 and state.glassDrops==0)
          assert(not registry.beamngWeather_hashk014_glassDropsMesh)
          assert(not registry.beamngWeather_hashk014_surfaces)
          failSurfaceMaterials=false
          advance(100)
          assert(effects.getState().glassDrops>0 and effects.getState().guardRadius>0)
        ''')


if __name__=='__main__':
    unittest.main()
