requirejs [
  'atlas/core/Atlas'
], (Atlas) ->
  atlas = new Atlas()
  AtlasManager.setAtlas(atlas)
  Logger.info('Created Atlas')
