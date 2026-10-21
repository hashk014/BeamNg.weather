"""Lifecycle checks in LuaJIT 2.1 / Lua 5.1, with a mocked engine boundary."""
from pathlib import Path
import json
import unittest
import zipfile
from lupa.luajit21 import LuaRuntime
from tools.build import build, MOD

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mod/lua/ge/extensions/beamngWeather/hashk014.lua"


class RainTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / "tests/engine_stub.lua").read_text(encoding="utf-8"))
        self.mod = self.lua.execute(SOURCE.read_text(encoding="utf-8"))
        self.lua.globals().extension = self.mod
        self.mod.onExtensionLoaded()

    def run_lua(self, source):
        self.lua.execute(source)

    def test_automatic_rain_and_camera_follow_without_map_mutation(self):
        self.run_lua('''
          extension.onUpdate(1)
          assert(extension.getState().status == "raining")
          assert(rainObjectCount() == 2)
          assert(registry.beamngWeather_hashk014_drops.numDrops + registry.beamngWeather_hashk014_coverage.numDrops == 1820)
          assert(registry.beamngWeather_hashk014_runtime.canSave == false)
          extension.onPreRender()
          assert(registry.beamngWeather_hashk014_drops.position == cameraPosition)
          assert(registry.mapRain.numDrops == 7)
          extension.onUpdate(10)
          assert(rainObjectCount() == 2)
        ''')

    def test_off_zero_resume_and_budget(self):
        self.run_lua('''
          extension.onUpdate(1)
          extension.setEnabled(false)
          assert(rainObjectCount() == 0)
          assert(extension.getState().status == "stopped")
          extension.setEnabled(true)
          extension.configure({quality="high", intensity=1, collisions=false})
          assert(extension.getState().activeDrops == 5000)
          assert(not registry.beamngWeather_hashk014_drops.doCollision)
          extension.setIntensity(0)
          assert(rainObjectCount() == 0)
          extension.setIntensity(0.5)
          assert(extension.getState().activeDrops == 2500)
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
          assert(rainObjectCount() == 2)
          extension.onClientEndMission()
          extension.onUpdate(1)
          assert(rainObjectCount() == 0)
          extension.onClientStartMission()
          extension.onUpdate(1)
          local data = extension.onSerialize()
          assert(rainObjectCount() == 0)
          extension.onDeserialized(data)
          extension.onUpdate(1)
          assert(rainObjectCount() == 2)
          extension.onExtensionUnloaded()
          assert(rainObjectCount() == 0)
        ''')

    def test_missing_datablocks_recover_and_log_once(self):
        self.run_lua('''
          registry.rain_drop = nil
          extension.onUpdate(1)
          extension.onUpdate(1)
          assert(extension.getState().status == "unavailable")
          assert(rainObjectCount() == 0)
          assert(#logs == 2) -- startup plus one error
          registry.rain_drop = {class="PrecipitationData"}
          extension.onUpdate(1)
          assert(extension.getState().status == "raining")
        ''')

    def test_partial_creation_failure_rolls_back(self):
        self.run_lua('''
          failLayer = "_coverage"
          extension.onUpdate(1)
          assert(extension.getState().status == "unavailable")
          assert(rainObjectCount() == 0)
          assert(not registry.beamngWeather_hashk014_runtime)
          failLayer = nil
          extension.onUpdate(1)
          assert(rainObjectCount() == 2)
        ''')

    def test_deleted_layer_is_recovered(self):
        self.run_lua('''
          extension.onUpdate(1)
          registry.beamngWeather_hashk014_drops:delete()
          extension.onUpdate(1)
          assert(rainObjectCount() == 2)
        ''')

    def test_mod_deactivation_only_unloads_this_mod(self):
        self.run_lua('''
          extension.onUpdate(1)
          extension.onModDeactivated({modname="another_mod"})
          assert(rainObjectCount() == 2)
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


class PackageTests(unittest.TestCase):
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
        self.lua.execute('''
          package.path = extensionRoot .. "/?.lua;" .. package.path
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
