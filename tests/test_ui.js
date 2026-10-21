const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const commands = [];
const handlers = {};
const scope = {$on: (event, callback) => { handlers[event] = callback; }, $evalAsync: callback => callback()};
let directive;
vm.runInNewContext(fs.readFileSync('mod/ui/modules/apps/BeamngWeatherHashk014/app.js', 'utf8'), {
  angular: {module: () => ({directive: (name, factory) => { directive = factory(); }})},
  bngApi: {engineLua: code => commands.push(code)}
});
directive.link(scope);
assert.match(commands.pop(), /requestState/);
handlers.BeamngWeatherHashk014State(null, {enabled: true, intensity: 0.65, quality: 'medium', collisions: true, status: 'raining'});
assert.equal(scope.form.intensity, 65);
scope.toggle();
assert.match(commands.pop(), /setEnabled\(false\)/);
scope.form.intensity = 999;
scope.form.quality = 'bad";evil()';
scope.apply();
assert.match(commands.pop(), /intensity=1,quality="medium",collisions=true/);
scope.form.intensity = NaN;
scope.apply();
assert.match(commands.pop(), /intensity=0.65/);
console.log('UI bridge: state, toggle, bounds and command escaping passed');

