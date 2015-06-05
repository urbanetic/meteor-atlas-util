atlas = atlasDf = null
global = @

resetAtlas = ->
  atlas = null
  if atlasDf
    atlasDf.reject('Reset atlas')
  atlasDf = Q.defer()
resetAtlas()

AtlasManager =

  getAtlas: -> atlasDf.promise

  hasAtlas: -> atlas?

  setAtlas: (_instance) ->
    if atlas
      throw new Error('Atlas is already set - remove it first.')
    atlas = _instance
    atlasDf.resolve(atlas)
    # Add a reference to the window for debugging.
    global.atlas = atlas

  removeAtlas: -> resetAtlas()

  _sanitizeEntity: (entityArgs) ->
    # Don't attempt to render entities on the server since there's no view.
    if Meteor.isServer
      entityArgs.show = false
    else
      _.defaults entityArgs,
        show: true

  renderEntity: (entityArgs) ->
    @_sanitizeEntity(entityArgs)
    id = entityArgs.id
    unless id?
      throw new Error('Rendered entity must have ID.')
    entityArgs.id = AtlasIdMap.getAtlasId(id)
    atlas.publish 'entity/create', entityArgs
    entity = @getEntity(id)
    entity

  renderEntities: (entityArgs) ->
    df = Q.defer()
    _.each entityArgs, (entityArg) =>
      @_sanitizeEntity(entityArg)
      entityArg.id = AtlasIdMap.getAtlasId(entityArg.id)
    atlas.publish 'entity/create/bulk',
      features: entityArgs
      callbackPromise: true
      callback: (promise) ->
        entitiesPromise = promise.then (ids) -> atlas._managers.entity.getByIds(ids)
        # Allows notifying of progress through the original promise.
        df.resolve(entitiesPromise)
    df.promise

  createCollection: (id, args) ->
    # TODO(aramk) Calling @_sanitizeEntity(args) sets `show` to false and this prevents any children
    # from being added to the collection.
    # args = @_sanitizeEntity(args)
    atlas.getManager('entity').createCollection(id, args)

  unrenderEntity: (id) -> @getEntity(id)?.remove()

  getEntity: (id) -> atlas._managers.entity.getById(AtlasIdMap.getAtlasId(id))

  getEntities: -> atlas._managers.entity.getEntities()

  getEntitiesAsJson: (ids, deep) ->
    entities = ids && @getEntitiesByIds(ids) || @getEntities()
    deep ?= true
    if deep
      _.each entities, (entity) ->
        _.each entity.getRecursiveChildren(), (child) ->
          entities.push(child)
    _.map entities, (entity) -> entity.toJson()

  getFeature: (id) -> atlas._managers.entity._getFeaturesByIds([id])[0]

  getFeatures: -> atlas._managers.entity.getFeatures()

  getSelectedEntityIds: ->
    ids = []
    _.each atlas._managers.selection.getSelectionIds(), (id) ->
      id = AtlasIdMap.getAppId(id)
      ids.push(id) if id?
    ids

  getSelectedFeatureIds: ->
    _.filter @getSelectedEntityIds(), (id) => @getEntity(id).getForm?

  getEntitiesByIds: (ids) -> _.map ids, (id) => @getEntity(id)

  getEntitiesAt: (point) -> atlas._managers.entity.getAt(point)

  resolveModelId: (id) ->
    # When clicking on children of a GeoEntity collection, take the prefix as the ID of the
    # underlying Entity.
    reChildEntityId = /(^[^:]+):[^:]+$/
    idParts = id.match(reChildEntityId)
    if idParts
      id = idParts[1]
    id = id.replace(/polygon$/, '')
    id = id.replace(/mesh$/, '')
    AtlasIdMap.getAppId(id)

  showEntity: (id) ->
    # Don't attempt to render entities on the server since there's no view.
    return false if Meteor.isServer
    atlas.publish 'entity/show', {id: AtlasIdMap.getAtlasId(id)}
    @getEntity(id).isVisible()

  hideEntity: (id) ->
    # Don't attempt to render entities on the server since there's no view.
    return false if Meteor.isServer
    atlas.publish 'entity/hide', {id: AtlasIdMap.getAtlasId(id)}
    !@getEntity(id).isVisible()

  zoomTo: (args) -> atlas.publish 'camera/zoomTo', args

  zoomToEntities: (ids) ->
    df = Q.defer()
    cameraManager = atlas._managers.camera
    camera = cameraManager.getCurrentCamera()
    requirejs ['atlas/model/Collection'], (Collection) =>
      geoEntityIds = []
      _.each ids, (id) =>
        geoEntity = @getEntity(id)
        if geoEntity? then geoEntityIds.push(geoEntity.getId())
      unless geoEntityIds.length > 0
        df.reject('No entities to zoom into.')
        return
      collection = @createCollection('collection-project-zoom', {entities: geoEntityIds})
      readyPromise = collection.ready()
      readyPromise.then ->
        # For more than 300 entities, use the centroids for better performance.
        boundingBox = collection.getBoundingBox
          useCentroid: geoEntityIds.length > 300
        if boundingBox
          boundingBox.scale(1.5)
          camera.zoomTo
            rectangle: boundingBox
        # Remove temporary collection but retain the entities contained within by removing them
        # from the collection first.
        _.each geoEntityIds, (id) -> collection.removeEntity(id)
        collection.remove()
        # Return whether the camera had a position to move to.
        if boundingBox?
          df.resolve(true)
        else
          df.reject('No bounding box could be formed from entities for zooming.')
      readyPromise.fail(df.reject)
    df.promise

  getCurrentCamera: (args) -> atlas.publish('camera/current', args)

  zoomIn: (args) -> atlas.publish('camera/zoomIn', args)

  zoomOut: (args) -> atlas.publish('camera/zoomOut', args)

  getDisplayModes: ->
    df = Q.defer()
    requirejs ['atlas/model/Feature'], (Feature) ->
      items = _.map Feature.DisplayMode, (value, id) ->
        {label: Strings.toTitleCase(value), value: value}
      df.resolve(items)
    df.promise

  setDisplayMode: (displayMode, args) ->
    @getAtlas().then (atlas) ->
      args = _.extend({displayMode: displayMode}, args)
      atlas.publish('entity/display-mode', args)

  startDraw: (args) -> atlas.publish('entity/draw', args)

  stopDraw: (args) -> atlas.publish('entity/draw/stop', args)

  edit: (args) -> atlas.publish('edit/enable', args)

  stopEdit: -> atlas.publish('edit/disable')

  selectEntities: (ids) -> atlas.publish('entity/select', {ids: AtlasIdMap.getAtlasIds(ids)})

  deselectEntities: (ids) -> atlas.publish('entity/deselect', {ids: AtlasIdMap.getAtlasIds(ids)})

  deselectAllEntities: -> atlas._managers.selection.clearSelection()

  setSelection: (ids) ->
    @deselectAllEntities()
    @selectEntities(ids)
