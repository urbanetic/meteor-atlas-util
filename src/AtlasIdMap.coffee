AtlasIdMap =

  # Some Atlas providers cannot accept all variations of IDs, so this should module should be
  # enabled and used with them. Usually this module is not required.
  enabled: false
  nextIndex: 1
  appIds: {}
  atlasIds: {}

  getAtlasId: (appId) ->
    return appId unless @enabled
    atlasId = @atlasIds[appId]
    return atlasId if atlasId?
    atlasId = @nextIndex++
    @atlasIds[appId] = atlasId
    @appIds[atlasId] = appId

  getAppId: (atlasId) ->
    return atlasId unless @enabled
    @appIds[atlasId]

  getAtlasIds: (appIds) -> _.map appIds, (id) => @getAtlasId(id)

  getAppIds: (atlasIds) ->
    ids = []
    _.each atlasIds, (id) =>
      id = @getAppId(id)
      ids.push(id) if id?
    ids

