"""Lifecycle checks in LuaJIT 2.1 / Lua 5.1, with a mocked engine boundary."""
from pathlib import Path
import json
import unittest
import zipfile
import struct
from io import BytesIO
from PIL import Image
from lupa.luajit21 import LuaRuntime
from tools.build import build, MOD

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mod/lua/ge/extensions/beamngWeather/hashk014.lua"
GAME_ACTIONS = Path(r"C:\Program Files (x86)\Steam\steamapps\common\BeamNG.drive\lua\ge\extensions\ui\pause\actions.lua")


class RainTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().moduleRoot = (MOD / "lua").as_posix()
        self.lua.execute('package.path = moduleRoot .. "/?.lua;" .. package.path')
        data = json.loads((MOD / "art/beamng_weather_hashk014/rain.datablocks.json").read_text())
        self.lua.globals().testDatablocks = self.lua.table_from(data, recursive=True)
        self.lua.execute((ROOT / "tests/engine_stub.lua").read_text(encoding="utf-8"))
        self.mod = self.lua.execute(SOURCE.read_text(encoding="utf-8"))
        self.lua.globals().extension = self.mod
        self.mod.onExtensionLoaded()

    def run_lua(self, source):
        self.lua.execute(source)

    def test_pause_menu_registration_is_idempotent_and_unloads_only_own_entry(self):
        self.run_lua('''
          assert(extension.dependencies[1] == "ui_pause_actions")
          local button=pauseButtons.beamngWeather_hashk014
          assert(button.tabId=="mods" and button.label=="BeamNg.weather")
          assert(button.componentName=="/ui/ui-vue/mods/beamng_weather_hashk014/RainSettings.vue")
          pauseButtons.other_mod={id="other_mod",tabId="mods"}
          extension.onExtensionLoaded()
          local count=0
          for _ in pairs(pauseButtons) do count=count+1 end
          assert(count==2)
          extension.onExtensionUnloaded()
          assert(pauseButtons.beamngWeather_hashk014==nil and pauseButtons.other_mod)
        ''')
        self.assertTrue((MOD / "ui/ui-vue/mods/beamng_weather_hashk014/RainSettings.vue").is_file())

    @unittest.skipUnless(GAME_ACTIONS.is_file(), "Local BeamNG pause API integration requires installed game files")
    def test_integration_with_actual_beamng_pause_actions_module(self):
        self.run_lua('''
          package.preload["ge/extensions/ui/gridSelectorUtils/buttonModule"]=function()
            return {create=function() return {} end}
          end
          _tr=function(key) return key=="ui.dashboard.mods" and "Mods" or key end
        ''')
        actions = self.lua.execute(GAME_ACTIONS.read_text(encoding="utf-8"))
        self.lua.globals().ui_pause_actions = actions
        self.run_lua('''
          extension.onExtensionLoaded()
          extension.onExtensionLoaded()
          local tabs=ui_pause_actions.getVisibleModTabs()
          assert(#tabs==1 and tabs[1].label=="Mods" and tabs[1].tabId=="mod:mods")
          assert(#tabs[1].buttons==1)
          assert(tabs[1].buttons[1].componentName=="/ui/ui-vue/mods/beamng_weather_hashk014/RainSettings.vue")
          ui_pause_actions.registerModButton({id="other_mod",tabId="mods",label="Other mod"})
          extension.onExtensionUnloaded()
          tabs=ui_pause_actions.getVisibleModTabs()
          assert(#tabs==1 and #tabs[1].buttons==1 and tabs[1].buttons[1].id=="other_mod")
        ''')

    def test_automatic_rain_and_camera_follow_without_map_mutation(self):
        self.run_lua('''
          extension.onUpdate(1)
          assert(extension.getState().status == "raining")
          assert(rainObjectCount() == 3)
          assert(extension.getState().activeDrops > 0)
          assert(extension.getState().activeDrops <= 6000)
          assert(registry.beamngWeather_hashk014_runtime.canSave == false)
          assert(registry.beamngWeather_hashk014_fine.position == cameraPosition)
          assert(registry.beamngWeather_hashk014_fine.followCam)
          assert(registry.mapRain.numDrops == 7)
          assert(registry.beamngWeather_hashk014_shader_v2.DXVertexShaderFile == "shaders/beamng_weather_hashk014/rainV.hlsl")
          assert(registry.beamngWeather_hashk014_shader_v2.DXPixelShaderFile == "shaders/beamng_weather_hashk014/rainP.hlsl")
          extension.onUpdate(10)
          assert(rainObjectCount() == 3)
        ''')

    def test_off_zero_resume_and_budget(self):
        self.run_lua('''
          extension.onUpdate(1)
          extension.setEnabled(false)
          assert(rainObjectCount() == 0)
          assert(extension.getState().status == "stopped")
          extension.setEnabled(true)
          extension.configure({quality="high", intensity=1, collisions=false, transition=0, variability=0})
          assert(extension.getState().activeDrops == 12000)
          assert(not registry.beamngWeather_hashk014_fine.doCollision)
          extension.setIntensity(0)
          assert(rainObjectCount() == 0)
          extension.setIntensity(0.5)
          assert(extension.getState().activeDrops == 6000)
        ''')

    def test_invalid_settings_are_bounded(self):
        self.run_lua('''
          extension.configure({intensity=100, quality="bad", enabled="false"})
          assert(extension.getState().intensity == 1)
          assert(extension.getState().quality == "medium")
          assert(extension.getState().enabled)
          extension.setIntensity(-5)
          assert(extension.getState().intensity == 0)
          extension.setIntensity(0/0)
          extension.setIntensity(math.huge)
          extension.configure(false)
          assert(extension.getState().intensity == 0)
        ''')

    def test_menu_then_map_change_then_reload(self):
        self.run_lua('''
          mission = ""
          extension.onUpdate(1)
          assert(rainObjectCount() == 0)
          assert(extension.getState().status == "waiting")
          mission = "levels/gridmap_v2/main.level.json"
          extension.onClientStartMission()
          extension.onUpdate(1)
          assert(rainObjectCount() == 3)
          extension.onClientEndMission()
          extension.onUpdate(1)
          assert(rainObjectCount() == 0)
          extension.onClientStartMission()
          extension.onUpdate(1)
          local data = extension.onSerialize()
          assert(rainObjectCount() == 0)
          extension.onDeserialized(data)
          extension.onUpdate(1)
          assert(rainObjectCount() == 3)
          extension.onExtensionUnloaded()
          assert(rainObjectCount() == 0)
        ''')

    def test_missing_datablocks_recover_and_log_once(self):
        self.run_lua('''
          failDatablocks = true
          extension.onUpdate(1)
          extension.onUpdate(1)
          assert(extension.getState().status == "unavailable")
          assert(rainObjectCount() == 0)
          assert(#logs == 2) -- startup plus one error
          failDatablocks = false
          extension.onUpdate(1)
          assert(extension.getState().status == "raining")
        ''')

    def test_partial_creation_failure_rolls_back(self):
        self.run_lua('''
          failLayer = "_distant"
          extension.onUpdate(1)
          assert(extension.getState().status == "unavailable")
          assert(rainObjectCount() == 0)
          assert(not registry.beamngWeather_hashk014_runtime)
          failLayer = nil
          extension.onUpdate(1)
          assert(rainObjectCount() == 3)
        ''')

    def test_deleted_layer_is_recovered(self):
        self.run_lua('''
          extension.onUpdate(1)
          registry.beamngWeather_hashk014_fine:delete()
          extension.onUpdate(1)
          assert(rainObjectCount() == 3)
        ''')

    def test_mod_deactivation_only_unloads_this_mod(self):
        self.run_lua('''
          extension.onUpdate(1)
          extension.onModDeactivated({modname="another_mod"})
          assert(rainObjectCount() == 3)
          extension.onModDeactivated({modname="beamng_weather_hashk014"})
          assert(unloaded == "beamngWeather_hashk014")
          assert(rainObjectCount() == 0)
        ''')

    def test_saved_settings_survive_a_fresh_extension(self):
        self.run_lua('extension.configure({enabled=false, quality="low", intensity=0.3})')
        self.mod.onExtensionUnloaded()
        self.mod = self.lua.execute(SOURCE.read_text(encoding="utf-8"))
        self.mod.onExtensionLoaded()
        self.assertFalse(self.mod.getState().enabled)
        self.assertEqual(self.mod.getState().quality, "low")
        self.assertEqual(self.mod.getState().intensity, 0.3)

    def test_all_presets_are_distinct_and_preserve_performance_settings(self):
        self.run_lua('''
          extension.configure({quality="ultra", collisions=false, transition=0})
          local seen = {}
          for _, p in ipairs(extension.getState().presets) do
            assert(extension.applyPreset(p.id))
            local state = extension.getState()
            assert(state.preset == p.id and state.enabled)
            assert(state.quality == "ultra" and not state.collisions)
            assert(rainObjectCount() == 3)
            assert(not seen[state.intensity])
            seen[state.intensity] = true
            assert(registry.beamngWeather_hashk014_body.maxSpeed > registry.beamngWeather_hashk014_body.minSpeed)
          end
          assert(not extension.applyPreset('missing'))
          extension.configure({fallSpeed=1.37})
          assert(extension.getState().preset == "custom")
        ''')

    def test_personal_slots_roundtrip_and_survive_restart(self):
        self.run_lua('''
          extension.applyPreset("drizzle")
          extension.configure({dropScale=1.5})
          assert(extension.savePersonalPreset(1))
          assert(not extension.savePersonalPreset(4))
          assert(not extension.savePersonalPreset(0/0))
          assert(not extension.loadPersonalPreset(2))
          extension.applyPreset("downpour")
          extension.configure({quality="low"})
          assert(extension.loadPersonalPreset(1))
          local state = extension.getState()
          assert(state.dropScale == 1.5 and state.intensity == 0.26)
          assert(state.quality == "low" and state.preset == "personal1")
        ''')
        self.mod.onExtensionUnloaded()
        self.mod = self.lua.execute(SOURCE.read_text(encoding="utf-8"))
        self.lua.globals().extension = self.mod
        self.mod.onExtensionLoaded()
        self.run_lua('''
          assert(extension.getState().personalPresets[1].saved)
          assert(extension.loadPersonalPreset(1))
          assert(extension.getState().dropScale == 1.5)
          assert(extension.deletePersonalPreset(1))
          assert(not extension.getState().personalPresets[1].saved)
          assert(not extension.loadPersonalPreset(1))
        ''')

    def test_density_transitions_pause_and_no_frame_spawning(self):
        self.run_lua('''
          extension.configure({intensity=1, transition=2, variability=0})
          assert(extension.getState().activeDrops == 0)
          for i=1,20 do extension.onUpdate(0.1,0.1) end
          local count = extension.getState().activeDrops
          assert(count > 5600 and count < 6000)
          extension.onUpdate(1,0)
          assert(extension.getState().activeDrops == count)
          extension.configure({intensity=0.25})
          assert(extension.getState().activeDrops == count)
          for i=1,30 do extension.onUpdate(0.1,0.1) end
          assert(extension.getState().activeDrops < count)
          assert(rainObjectCount() == 3)
          extension.setEnabled(false)
          assert(rainObjectCount() == 0)
        ''')

    def test_legacy_config_migration_and_unknown_settings_ignored(self):
        self.mod.onExtensionUnloaded()
        self.run_lua('savedConfig={enabled=false, intensity=0.4, quality="high", collisions=false, friction=0.01}')
        self.mod = self.lua.execute(SOURCE.read_text(encoding="utf-8"))
        self.lua.globals().extension = self.mod
        self.mod.onExtensionLoaded()
        self.run_lua('''
          local state = extension.getState()
          assert(not state.enabled and state.intensity == 0.4 and state.quality == "high")
          assert(state.dropScale == 1 and state.friction == nil)
          extension.configure({dropScale=100, fallSpeed=-10, turbulence=0/0, contrast=math.huge})
          state=extension.getState()
          assert(state.dropScale==2 and state.fallSpeed==0.4 and state.turbulence==0.12 and state.contrast==0.9)
        ''')

    def test_no_surface_effects_and_native_camera_motion(self):
        self.run_lua('''
          extension.onUpdate(1)
          for _, name in ipairs({"fine", "body", "distant"}) do
            local obj=registry["beamngWeather_hashk014_"..name]
            assert(not obj.animateSplashes and not obj.reflect)
            assert(obj.followCam and obj.rotateWithCamVel and not obj.useTrueBillboards)
            assert(obj.useLighting and obj.hitVehicles)
            assert(obj.canSave == false)
          end
          assert(registry.mapRain.numDrops == 7)
        ''')

    def test_budget_is_respected_through_density_variations(self):
        self.run_lua('''
          for _, quality in ipairs({"low","medium","high","ultra"}) do
            extension.configure({quality=quality, transition=0, intensity=1, variability=0.6})
            for i=1,100 do
              extension.onUpdate(0.1,0.1)
              local state=extension.getState()
              local sum=registry.beamngWeather_hashk014_fine.numDrops+registry.beamngWeather_hashk014_body.numDrops+registry.beamngWeather_hashk014_distant.numDrops
              assert(state.activeDrops<=state.maxDrops and state.activeDrops==sum)
            end
          end
        ''')

    def test_ui_requests_acknowledge_applied_state_and_reject_unknown_commands(self):
        self.run_lua('''
          local reply=extension.uiRequest("applyPreset", "downpour")
          assert(reply.ok and reply.state.preset=="downpour")
          reply=extension.uiRequest("configure", {cloudMode="manual",cloudCoverage=0.4})
          assert(reply.ok and reply.state.cloudCoverage==0.4 and reply.state.clouds.available)
          assert(not extension.uiRequest("loadPersonalPreset", 3).ok)
          assert(not extension.uiRequest("onExtensionUnloaded").ok)
          assert(extension.uiRequest("getState").ok)
        ''')

    def test_native_cloud_modes_and_restoration(self):
        self.run_lua('''
          extension.onUpdate(1)
          assert(math.abs(registry.mapClouds.coverage-(2.4+0.6*extension.getState().intensity))<0.0001)
          assert(registry.mapClouds.windSpeed==4)
          extension.configure({cloudMode="manual", cloudCoverage=0.45})
          assert(math.abs(registry.mapClouds.coverage-1.35)<0.0001)
          extension.configure({cloudMode="map"})
          assert(registry.mapClouds.coverage==0.2)
          extension.configure({cloudMode="auto"})
          extension.setEnabled(false)
          assert(registry.mapClouds.coverage==0.2)
          extension.setEnabled(true)
          extension.setIntensity(0)
          assert(registry.mapClouds.coverage==0.2)
          extension.setIntensity(0.5)
          extension.onSerialize()
          assert(registry.mapClouds.coverage==0.2)
          extension.onUpdate(1)
          extension.onExtensionUnloaded()
          assert(registry.mapClouds.coverage==0.2)
        ''')

    def test_clouds_use_full_native_range_with_normalized_ui_values(self):
        self.run_lua('''
          for _, preset in ipairs(extension.getState().presets) do
            extension.applyPreset(preset.id)
            local state=extension.getState()
            assert(registry.mapClouds.coverage>=2.4 and registry.mapClouds.coverage<=3)
            assert(math.abs(state.clouds.coverage*3-state.clouds.nativeCoverage)<0.0001)
            assert(state.clouds.coverage>=0.8 and state.clouds.coverage<=1)
          end
          extension.applyPreset("downpour")
          assert(registry.mapClouds.coverage==3)
          extension.configure({cloudMode="manual",cloudCoverage=0})
          assert(registry.mapClouds.coverage==0)
          extension.configure({cloudCoverage=0.5})
          assert(registry.mapClouds.coverage==1.5)
          extension.configure({cloudCoverage=999})
          assert(registry.mapClouds.coverage==3 and extension.getState().cloudCoverage==1)
          extension.setEnabled(false)
          assert(registry.mapClouds.coverage==0.2)
        ''')

    def test_clouds_respect_external_edits_locks_and_missing_layers(self):
        self.run_lua('''
          extension.onUpdate(1)
          registry.mapClouds.coverage=0.35
          extension.onUpdate(1)
          extension.setEnabled(false)
          assert(registry.mapClouds.coverage==0.35)
          extension.setEnabled(true)
          registry.mapClouds.coverage=0.1
          extension.setEnabled(false)
          assert(registry.mapClouds.coverage==0.1)
          cloudChangesAllowed=false
          extension.setEnabled(true)
          assert(extension.getState().status=="raining")
          assert(extension.getState().clouds.warning:find("locked"))
          assert(registry.mapClouds.coverage==0.1)
          cloudChangesAllowed=true
          registry.mapClouds:delete()
          extension.onUpdate(1)
          assert(extension.getState().status=="raining" and not extension.getState().clouds.available)
          assert(extension.getState().clouds.warning:find("no supported"))
        ''')

    def test_clouds_multi_layer_map_swap_and_saved_profile(self):
        self.run_lua('''
          local extra=createObject("CloudLayer")
          extra.coverage=0.4; extra:registerObject("extraClouds")
          extension.configure({cloudMode="manual",cloudCoverage=0.9})
          assert(math.abs(extra.coverage-2.7)<0.0001 and extension.getState().clouds.count==2)
          extension.savePersonalPreset(1)
          extension.configure({cloudMode="map"})
          assert(extra.coverage==0.4)
          extension.loadPersonalPreset(1)
          assert(extension.getState().cloudMode=="manual" and math.abs(extra.coverage-2.7)<0.0001)
          extension.onClientEndMission()
          assert(extra.coverage==0.4 and registry.mapClouds.coverage==0.2)
          mission="levels/other/main.level.json"
          registry.mapClouds.coverage=0.12
          extension.onClientStartMission(); extension.onUpdate(1)
          extension.setEnabled(false)
          assert(registry.mapClouds.coverage==0.12)
        ''')


class PackageTests(unittest.TestCase):
    def test_dds_assets_are_complete_and_original_atlases_have_variants(self):
        data = json.loads((MOD / "art/beamng_weather_hashk014/rain.datablocks.json").read_text())
        for entry in data.values():
            self.assertEqual(entry["dropsPerSide"], 4)
            raw = (MOD / entry["dropTexture"]).read_bytes()
            self.assertEqual(raw[:4], b"DDS ")
            header = struct.unpack("<31I", raw[4:128])
            self.assertEqual((header[2], header[3], header[6]), (512, 512, 10))
            self.assertEqual(raw[84:88], b"DXT5")
            self.assertEqual(len(raw), 128 + sum(max(1, (max(1,512>>m)+3)//4)**2*16 for m in range(10)))
            with Image.open(BytesIO(raw)) as image:
                alphas = image.convert("RGBA").getchannel("A").tobytes()
            self.assertGreater(max(alphas), 30)
            tiles = set()
            for cy in range(4):
                for cx in range(4):
                    tile = b"".join(alphas[(cy*128+y)*512+cx*128:(cy*128+y)*512+(cx+1)*128] for y in range(128))
                    self.assertTrue(all(v==0 for v in tile[:128]+tile[-128:]))
                    tiles.add(tile)
            self.assertEqual(len(tiles), 16)
            empty = (MOD / entry["splashTexture"]).read_bytes()
            self.assertTrue(all(b==0 for b in empty[128:]))

    def test_installable_zip_has_exact_source_content_and_safe_paths(self):
        path = build()
        first = path.read_bytes()
        self.assertEqual(first, build().read_bytes())
        with zipfile.ZipFile(path) as archive:
            self.assertIn("scripts/beamngWeather_hashk014/modScript.lua", archive.namelist())
            self.assertIn("lua/ge/extensions/beamngWeather/hashk014.lua", archive.namelist())
            for name in archive.namelist():
                self.assertFalse(name.startswith(("/", "mod/")))
                self.assertNotIn("..", Path(name).parts)
                self.assertEqual(archive.read(name), (MOD / name).read_bytes())

    def test_ui_metadata_and_bootstrap(self):
        data = json.loads((MOD / "ui/modules/apps/BeamngWeatherHashk014/app.json").read_text())
        self.assertEqual(data["directive"], "beamngWeatherHashk014")
        self.assertTrue((MOD / "ui/modules/apps/BeamngWeatherHashk014/app.png").is_file())
        self.lua = LuaRuntime()
        self.lua.globals().extensionRoot = (MOD / "lua/ge/extensions").as_posix()
        self.lua.globals().moduleRoot = (MOD / "lua").as_posix()
        self.lua.execute('''
          package.path = extensionRoot .. "/?.lua;" .. moduleRoot .. "/?.lua;" .. package.path
          setExtensionUnloadMode=function(n,m) assert(m=="manual"); marked=n end
          extensions={load=function(n)
            assert(marked==n)
            local path=n:gsub("__", "#"):gsub("_", "/"):gsub("#", "_")
            local loaded=require(path)
            assert(type(loaded.onExtensionLoaded)=="function")
          end}
        ''')
        self.lua.execute((MOD / "scripts/beamngWeather_hashk014/modScript.lua").read_text())


if __name__ == "__main__":
    unittest.main()
