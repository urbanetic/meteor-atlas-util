Package.describe({
  name: 'urbanetic:atlas-util',
  summary: 'A wrapper with utilities for using Atlas in Meteor.',
  version: '0.1.0',
  git: 'https://github.com/Urbanetic/meteor-atlas-util.git'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@0.9.0');
  api.use(['coffeescript', 'underscore', 'aramk:requirejs', 'aramk:q', 'urbanetic:atlas',
    'urbanetic:atlas-cesium'], ['client', 'server']);
  api.use(['deps', 'templating', 'jquery'], 'client');
  api.export([
    'AtlasConverter', 'AtlasManager', 'WKT'
  ], ['client', 'server']);
  api.addFiles([
    'src/AtlasConverter.coffee', 'src/AtlasManager.coffee', 'src/WKT.coffee'
  ], ['client', 'server']);
});
