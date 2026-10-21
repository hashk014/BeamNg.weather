const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const commands = [], payloads = [], handlers = {};
const scope = {$on: (event, callback) => { handlers[event] = callback; }, $evalAsync: callback => callback()};
let directive;
function serialize(value) {
  payloads.push(value);
  if (typeof value === 'object') return '{' + Object.keys(value).map(k => k + '=' + JSON.stringify(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
vm.runInNewContext(fs.readFileSync('mod/ui/modules/apps/BeamngWeatherHashk014/app.js', 'utf8'), {
  angular: {module: () => ({directive: (name, factory) => { if (name === 'beamngWeatherHashk014') directive = factory(); }})},
  bngApi: {engineLua: code => commands.push(code), serializeToLua: serialize}
});
directive.link(scope);
assert.match(commands.pop(), /requestState/);
const state = {enabled: true, intensity: 0.65, dropScale: 1, fallSpeed: 1, quality: 'medium', collisions: true, wind: true, lighting: true, status: 'raining', preset: 'shower', presets: [{id: 'shower', description: 'Rain shower'}]};
const receive = () => handlers.BeamngWeatherHashk014State(null, state);
receive();
assert.equal(scope.form.intensity, 0.65);
assert.equal(scope.presetDescription, 'Rain shower');
scope.toggle();
assert.match(commands.pop(), /setEnabled\(false\)/);
scope.form.intensity = 999;
scope.apply('intensity');
assert.equal(payloads.pop().intensity, 1);
assert.match(commands.pop(), /configure\(\{intensity=1\}\)/);
scope.form.intensity = NaN;
scope.apply('intensity');
assert.equal(commands.length, 0);
scope.form.quality = 'bad";evil()';
scope.apply('quality');
scope.apply('unknown');
assert.equal(commands.length, 0);
scope.preset('shower');
assert.match(commands.pop(), /applyPreset\("shower"\)/);
scope.preset('bad";evil()');
assert.equal(commands.length, 0);
scope.saveSlot(1); scope.loadSlot(1); scope.deleteSlot(1);
assert.match(commands.pop(), /deletePersonalPreset\(1\)/);
assert.match(commands.pop(), /loadPersonalPreset\(1\)/);
assert.match(commands.pop(), /savePersonalPreset\(1\)/);
scope.saveSlot(4); scope.loadSlot(1.1); scope.deleteSlot('1');
assert.equal(commands.length, 0);
scope.edit.key = 'intensity'; scope.form.intensity = 0.9;
receive();
assert.equal(scope.form.intensity, 0.9, 'Incoming state must not move the slider under the cursor');
scope.endEdit(); receive();
assert.equal(scope.form.intensity, 0.65);
assert.equal(scope.format(scope.controls[0]), '65%');
console.log('UI: presets, slots, bounds, serialization and slider editing passed');
