/* global angular, bngApi */
// BeamNG 0.40 ships AngularJS 1.5.8. Re-render after interpolated range
// bounds settle, otherwise Chromium can initially clamp the thumb to 0 or 1.
angular.module('beamng.apps').directive('beamngWeatherRange', function () {
  return {
    require: 'ngModel',
    link: function (scope, element, attributes, controller) {
      ['min', 'max', 'step'].forEach(function (name) {
        attributes.$observe(name, function () { controller.$render(); });
      });
    }
  };
});
angular.module('beamng.apps').directive('beamngWeatherHashk014', function () {
  'use strict';
  return {
    restrict: 'E', replace: true,
    templateUrl: '/ui/modules/apps/BeamngWeatherHashk014/app.html',
    link: function (scope) {
      var prefix = 'extensions.beamngWeather_hashk014';
      var labels = {waiting: 'Charge une carte pour voir la pluie.', raining: 'Pluie en cours', stopped: 'Pluie arrêtée', unavailable: 'Effet indisponible : voir le diagnostic.'};
      var qualityNames = ['low', 'medium', 'high', 'ultra'];
      var booleanFields = ['collisions', 'wind', 'lighting'];
      scope.weather = null;
      scope.form = {};
      scope.edit = {key: null};
      scope.advanced = false;
      scope.controls = [
        {key: 'intensity', label: 'Intensité', min: 0, max: 1, step: 0.01, unit: 'percent'},
        {key: 'dropScale', label: 'Taille des gouttes', min: 0.5, max: 2, step: 0.05, unit: 'factor'},
        {key: 'fallSpeed', label: 'Vitesse de chute', min: 0.4, max: 1.8, step: 0.05, unit: 'factor'},
        {key: 'turbulence', label: 'Turbulence', min: 0, max: 1, step: 0.01, unit: 'percent'},
        {key: 'variability', label: 'Variations de densité', min: 0, max: 0.6, step: 0.01, unit: 'percent'},
        {key: 'contrast', label: 'Visibilité des gouttes', min: 0.35, max: 1.5, step: 0.05, unit: 'factor'},
        {key: 'volume', label: 'Étendue de la pluie', min: 0.65, max: 1.6, step: 0.05, unit: 'factor'},
        {key: 'transition', label: 'Transition entre intensités', min: 0, max: 5, step: 0.1, unit: 'seconds'}
      ];
      function command(method, value) {
        var argument = arguments.length > 1 ? bngApi.serializeToLua(value) : '';
        bngApi.engineLua('if ' + prefix + ' then ' + prefix + '.' + method + '(' + argument + ') end');
      }
      scope.$on('BeamngWeatherHashk014State', function (_, state) {
        if (!state) return;
        scope.$evalAsync(function () {
          scope.weather = state;
          scope.statusText = labels[state.status] || state.status;
          scope.controls.forEach(function (control) {
            if (scope.edit.key !== control.key) scope.form[control.key] = state[control.key];
          });
          booleanFields.concat(['quality']).forEach(function (key) { scope.form[key] = state[key]; });
          var active = (state.presets || []).filter(function (preset) { return preset.id === state.preset; })[0];
          scope.presetDescription = active ? active.description : 'Tes réglages personnels';
        });
      });
      scope.format = function (control) {
        var value = Number(scope.form[control.key]);
        if (!isFinite(value)) return '…';
        if (control.unit === 'percent') return Math.round(value * 100) + ' %';
        return value.toFixed(control.unit === 'seconds' ? 1 : 2) + (control.unit === 'seconds' ? ' s' : ' ×');
      };
      scope.apply = function (key) {
        var payload = {};
        var control = scope.controls.filter(function (item) { return item.key === key; })[0];
        if (control) {
          var value = Number(scope.form[key]);
          if (!isFinite(value)) return;
          payload[key] = Math.max(control.min, Math.min(control.max, value));
        } else if (key === 'quality') {
          if (qualityNames.indexOf(scope.form.quality) < 0) return;
          payload.quality = scope.form.quality;
        } else if (booleanFields.indexOf(key) >= 0) {
          payload[key] = !!scope.form[key];
        } else return;
        command('configure', payload);
      };
      scope.endEdit = function () { scope.edit.key = null; command('requestState'); };
      scope.toggle = function () { if (scope.weather) command('setEnabled', !scope.weather.enabled); };
      scope.preset = function (id) {
        if (scope.weather && scope.weather.presets.some(function (preset) { return preset.id === id; })) command('applyPreset', id);
      };
      function validSlot(slot) { return Number.isInteger(slot) && slot >= 1 && slot <= 3; }
      scope.saveSlot = function (slot) { if (validSlot(slot)) command('savePersonalPreset', slot); };
      scope.loadSlot = function (slot) { if (validSlot(slot)) command('loadPersonalPreset', slot); };
      scope.deleteSlot = function (slot) { if (validSlot(slot)) command('deletePersonalPreset', slot); };
      command('requestState');
    }
  };
});
