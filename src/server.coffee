Meteor.startup ->
  return if AtlasManager.hasAtlas()
  Logger.info('Creating Atlas...')
  requirejs [
    'atlas/core/Atlas'
  ], (Atlas) ->
    atlas = new Atlas
      managers:
        overlay: false
    AtlasManager.setAtlas(atlas)
    Logger.info('Created Atlas')
