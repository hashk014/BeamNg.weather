const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('mod/ui/ui-vue/mods/beamng_weather_hashk014/RainSettings.vue', 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1]
  .replace(/^import .*$/gm, '').replace('export default', 'const component =');
const calls = [], mounted = [], unmounted = [], handlers = {};
let fail = false;
const state = {
  enabled: true, status: 'raining', preset: 'shower', intensity: 0.72, dropScale: 1,
  fallSpeed: 1.05, turbulence: 0.15, variability: 0.2, contrast: 0.95, volume: 1,
  cloudMode: 'auto', cloudCoverage: 0.85, clouds: {available:true,coverage:0.944,nativeCoverage:2.832},
  transition: 1.5, quality: 'medium', collisions: true, wind: true, lighting: true,
  activeDrops: 4320, maxDrops: 6000, presets: [{id:'shower',name:'Shower',description:'Rain shower'}],
  personalPresets: [{slot:1,saved:false},{slot:2,saved:false},{slot:3,saved:false}]
};
// No mod functions exist in the game's static signature registry.
const signatures = {extensions: {}};
let nativeRun;
const bridgeFile = 'C:/Program Files (x86)/Steam/steamapps/common/BeamNG.drive/ui/ui-vue/src/bridge/libs/Lua.js';
if (fs.existsSync(bridgeFile)) {
  const bridgeContext = {LuaFunctionSignatures:signatures, Any:value=>value, Integer:Math.trunc, Optional:value=>value, console};
  vm.createContext(bridgeContext);
  const bridgeScript=fs.readFileSync(bridgeFile,'utf8').replace(/^import .*$/gm,'').replace(/^export (?:default .*|\{.*\})$/gm,'').replace(/^export /gm,'');
  vm.runInContext(bridgeScript+'\nglobalThis.nativeRun=run; globalThis.provide=setBridgeProvider;',bridgeContext);
  bridgeContext.provide(() => ({api:{serializeToLua:JSON.stringify,engineLua(code, callback) {
    assert.match(code,/^extensions\.beamngWeather_hashk014\.uiRequest\(/);
    callback({ok:true,state});
  }}}));
  nativeRun=bridgeContext.nativeRun;
  console.log('Using actual installed BeamNG generic Lua bridge (no mod signature registered)');
}
const endpoint = async (path, args, options) => {
  assert.equal(path, 'extensions.beamngWeather_hashk014.uiRequest');
  assert.equal(typeof options, 'object');
  const [method, value] = args;
  if (fail) throw Error('offline');
  if (method !== 'getState') calls.push({method, value});
  return nativeRun ? nativeRun(path,args,options) : {ok:true, state};
};
const context = {
  ref: value => ({value}), reactive: value => value,
  computed: getter => ({get value() { return getter(); }}),
  onMounted: callback => mounted.push(callback), onUnmounted: callback => unmounted.push(callback),
  run: endpoint, setTimeout, clearTimeout,
  lua: signatures,
  useEvents: () => ({on(name, callback) { handlers[name]=callback; unmounted.push(() => delete handlers[name]); }})
};
vm.createContext(context);
vm.runInContext(script + '\n globalThis.component = component;', context);
const ui = context.component.setup();
(async () => {
  await mounted[0]();
  assert.equal(ui.state.value, state);
  assert.equal(ui.controls.length, 8);
  assert.equal(ui.statusText.value, 'Raining');
  assert.equal(ui.presetDescription.value, 'Rain shower');
  ui.form.intensity=9;
  await ui.apply('intensity');
  assert.equal(calls.pop().value.intensity, 1);
  ui.form.intensity=NaN;
  ui.form.quality='invalid';
  await ui.apply('intensity'); await ui.apply('quality'); await ui.apply('unknown');
  assert.equal(calls.length, 0);
  await ui.selectPreset('shower');
  assert.equal(calls.pop().method, 'applyPreset');
  await ui.selectPreset('unknown');
  assert.equal(calls.length, 0);
  await ui.toggle();
  assert.equal(calls.pop().value, false);
  await ui.saveSlot(1); await ui.loadSlot(1); await ui.deleteSlot(1);
  assert.equal(calls.pop().method, 'deletePersonalPreset');
  assert.equal(calls.pop().method, 'loadPersonalPreset');
  assert.equal(calls.pop().method, 'savePersonalPreset');
  await ui.saveSlot(4); await ui.loadSlot(1.1); await ui.deleteSlot('1');
  assert.equal(calls.length, 0);
  ui.editingKey.value='intensity'; ui.form.intensity=0.9;
  handlers.BeamngWeatherHashk014State(state);
  assert.equal(ui.form.intensity, 0.9);
  ui.editingKey.value=null; handlers.BeamngWeatherHashk014State(state);
  assert.equal(ui.format(ui.controls[0]), '72%');
  assert.equal(ui.choiceLabel('quality'), 'Balanced / 6,000');
  ui.toggleChoice('cloudMode'); assert.equal(ui.openChoice.value,'cloudMode');
  // Periodic state updates must leave the visible choice list open.
  handlers.BeamngWeatherHashk014State(state);
  assert.equal(ui.openChoice.value,'cloudMode');
  ui.toggleChoice('quality'); assert.equal(ui.openChoice.value,'quality');
  await ui.choose('quality','ultra'); assert.equal(calls.pop().value.quality,'ultra');
  assert.equal(ui.openChoice.value,null);
  ui.toggleChoice('quality'); ui.toggleChoice('quality'); assert.equal(ui.openChoice.value,null);
  await ui.choose('cloudMode','manual'); assert.equal(calls.pop().value.cloudMode,'manual');
  await ui.choose('quality','invalid'); await ui.choose('unknown','manual'); ui.toggleChoice('unknown');
  assert.equal(calls.length,0);
  assert.equal(ui.openChoice.value,null);
  assert.doesNotMatch(source, /<select\b/, 'Pause controls must not use native popup selects');
  assert.match(source, /v-if="openChoice === 'cloudMode'"/);
  assert.match(source, /v-if="openChoice === 'quality'"/);
  ui.form.cloudMode='manual'; await ui.apply('cloudMode'); assert.equal(calls.pop().value.cloudMode,'manual');
  ui.form.cloudCoverage=2; await ui.apply('cloudCoverage'); assert.equal(calls.pop().value.cloudCoverage,1);
  fail=true; await ui.refresh(); assert.match(ui.error.value, /offline/);
  await ui.toggle(); assert.match(ui.error.value, /offline/);
  fail=false; await ui.refresh(); assert.equal(ui.error.value, '');
  for (const callback of unmounted) callback();
  assert.equal(handlers.BeamngWeatherHashk014State, undefined);
  state.intensity=0.1;
  await ui.refresh();
  assert.equal(ui.form.intensity, 0.72, 'Disposed panels must not receive late responses');
  console.log('Pause UI: state sync, controls, presets, slots, errors and lifecycle passed');
})().catch(error => { console.error(error); process.exitCode=1; });
