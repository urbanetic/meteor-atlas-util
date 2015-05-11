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
      callback: (promise) ->
        promise.then(
          (ids) -> df.resolve(atlas._managers.entity.getByIds(ids))
          df.reject
        )
    df.promise

  createCollection: (id, args) -> atlas.getManager('entity').createCollection(id, args)

  unrenderEntity: (id) -> atlas.publish 'entity/remove', {id: AtlasIdMap.getAtlasId(id)}

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
      someGeoEntity = null
      geoEntityIds = []
      _.each ids, (id) =>
        geoEntity = @getEntity(id)
        if geoEntity?
          unless someGeoEntity
            someGeoEntity = geoEntity
          geoEntityIds.push(geoEntity.getId())
      unless someGeoEntity?
        df.reject('No entities to zoom into.')
        return
      # TODO(aramk) Use dependency injection to prevent the need for passing manually.
      deps = someGeoEntity._bindDependencies({})
      collection = new Collection('collection-project-zoom', {entities: geoEntityIds}, deps)
      boundingBox = collection.getBoundingBox()
      if boundingBox
        boundingBox.scale(1.5)
        camera.zoomTo({
          rectangle: boundingBox
        })
      # Remove temporary collection but retain the entities contained within by removing them
      # from the collection first.
      _.each geoEntityIds, (id) ->
        collection.removeEntity(id)
      collection.remove()
      # Return whether the camera had a position to move to.
      if boundingBox?
        df.resolve(true)
      else
        df.reject('No bounding box could be formed from entities for zooming.')
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

  draw: (args) -> atlas.publish('entity/draw', args)

  stopDraw: (args) -> atlas.publish('entity/draw/stop', args)

  edit: (args) -> atlas.publish('edit/enable', args)

  stopEdit: -> atlas.publish('edit/disable')

  selectEntities: (ids) -> atlas.publish('entity/select', {ids: AtlasIdMap.getAtlasIds(ids)})

  deselectEntities: (ids) -> atlas.publish('entity/deselect', {ids: AtlasIdMap.getAtlasIds(ids)})

  deselectAllEntities: -> atlas._managers.selection.clearSelection()

  setSelection: (ids) ->
    @deselectAllEntities()
    @selectEntities(ids)
