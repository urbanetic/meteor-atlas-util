Package.describe({
  name: 'urbanetic:atlas-util',
  summary: 'A wrapper with utilities for using Atlas in Meteor.',
  version: '0.3.0',
  git: 'https://github.com/Urbanetic/meteor-atlas-util.git'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@1.2.0.1');
  api.use([
    'coffeescript',
    'underscore',
    'aramk:requirejs@2.1.15',
    'aramk:q@1.0.1',
    'urbanetic:atlas@0.8.1',
    'urbanetic:utility@1.2.0'
  ], ['client', 'server']);
  api.use([
    'urbanetic:atlas-cesium@0.8.1'
  ], ['client', 'server'], {weak: true});
  api.use(['deps',
    'less',
    'templating',
    'jquery'
  ], 'client');
  api.export([
    'AtlasIdMap',
    'AtlasConverter',
    'AtlasManager',
    'GeometryUtils',
    'WKT'
  ], ['client', 'server']);
  api.addFiles([
    'src/AtlasIdMap.coffee',
    'src/AtlasConverter.coffee',
    'src/AtlasManager.coffee',
    'src/WKT.coffee',
    'src/GeometryUtils.coffee'
  ], ['client', 'server']);
  api.addFiles([
    'src/atlas.less'
  ], 'client');
  api.addFiles([
    'src/server.coffee'
  ], 'server');
});

Package.onTest(function (api) {
  api.use([
    'coffeescript',
    'tinytest',
    'test-helpers',

    'urbanetic:utility',
    'peterellisjones:describe',
    'urbanetic:atlas-util'
  ]);

  api.addFiles([
    'tests/GeometryUtilsSpec.coffee'
  ]);

});
