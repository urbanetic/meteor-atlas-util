Package.describe({
  name: 'urbanetic:atlas-util',
  summary: 'A wrapper with utilities for using Atlas in Meteor.',
  version: '0.1.5',
  git: 'https://github.com/Urbanetic/meteor-atlas-util.git'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@0.9.0');
  api.use(['coffeescript', 'underscore', 'aramk:requirejs@2.1.15', 'aramk:utility@0.3.0',
    'aramk:q@1.0.1', 'urbanetic:atlas@0.7.0-beta', 'urbanetic:atlas-cesium@0.7.0-beta'],
    ['client', 'server']);
  api.use(['deps', 'templating', 'jquery'], 'client');
  api.export([
    'AtlasConverter', 'AtlasManager', 'WKT'
  ], ['client', 'server']);
  api.addFiles([
    'src/AtlasConverter.coffee', 'src/AtlasManager.coffee', 'src/WKT.coffee'
  ], ['client', 'server']);
});
