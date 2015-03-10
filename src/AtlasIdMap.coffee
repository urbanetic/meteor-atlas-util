AtlasIdMap =
  nextIndex: 1
  appIds: {}
  atlasIds: {}
  getAtlasId: (appId) ->
    atlasId = @atlasIds[appId]
    return atlasId if atlasId?
    atlasId = @nextIndex++
    @atlasIds[appId] = atlasId
    @appIds[atlasId] = appId
  getAppId: (atlasId) ->
    @appIds[atlasId]
