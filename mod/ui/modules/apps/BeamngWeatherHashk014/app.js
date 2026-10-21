/* global angular, bngApi */
angular.module('beamng.apps').directive('beamngWeatherHashk014', function () {
  'use strict';
  return {
    restrict: 'E',
    replace: true,
    templateUrl: '/ui/modules/apps/BeamngWeatherHashk014/app.html',
    link: function (scope) {
      var prefix = 'extensions.beamngWeather_hashk014';
      scope.weather = null;
      scope.form = {intensity: 65, quality: 'medium', collisions: true};
      var labels = {
        waiting: 'Charge une carte pour voir la pluie.',
        raining: 'Pluie en cours',
        stopped: 'Pluie arrêtée',
        unavailable: 'Pluie indisponible. Consulte la console du jeu.'
      };
      scope.$on('BeamngWeatherHashk014State', function (_, state) {
        if (!state) return;
        scope.$evalAsync(function () {
          scope.weather = state;
          scope.statusText = labels[state.status] || state.status;
          if (!scope.editing) {
            scope.form.intensity = Math.round(state.intensity * 100);
            scope.form.quality = state.quality;
            scope.form.collisions = state.collisions;
          }
        });
      });
      function command(expression) {
        bngApi.engineLua('if ' + prefix + ' then ' + prefix + expression + ' end');
      }
      scope.toggle = function () {
        if (scope.weather) command('.setEnabled(' + (!scope.weather.enabled) + ')');
      };
      scope.apply = function () {
        var value = Number(scope.form.intensity);
        var quality = ['low', 'medium', 'high'].indexOf(scope.form.quality) >= 0 ? scope.form.quality : 'medium';
        if (!isFinite(value)) value = 65;
        value = Math.max(0, Math.min(100, value)) / 100;
        command('.configure({intensity=' + value + ',quality="' + quality + '",collisions=' + (!!scope.form.collisions) + '})');
        scope.editing = false;
      };
      command('.requestState()');
    }
  };
});
