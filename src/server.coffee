requirejs([
  'atlas/core/Atlas'
], (Atlas) ->
  console.log('Creating Atlas...')
  atlas = new Atlas()
  AtlasManager.setAtlas(atlas)
)
