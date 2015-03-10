atlas = atlasDf = null
global = @

resetAtlas = ->
  atlas = null
  atlasDf = Q.defer()
resetAtlas()

AtlasManager =

  getAtlas: -> atlasDf.promise

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
    id = entityArgs.id = AtlasIdMap.getAtlasId(id)
    atlas.publish 'entity/create', entityArgs
    entity = @getEntity(id)
    entity

  renderEntities: (entityArgs) ->
    _.each entityArgs, (entityArg) =>
      @_sanitizeEntity(entityArg)
    entities = null
    _.each entityArgs, (entityArg) -> entityArg.id = AtlasIdMap.getAtlasId(entityArg.id)
    atlas.publish 'entity/create/bulk', {
      features: entityArgs
      callback: (ids) ->
        entities = atlas._managers.entity.getByIds(ids)
    }
    entities

  createCollection: (id, args) ->
    @getAtlas().then (atlas) ->
      atlas.getManager('entity').createCollection(id, args)

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
    _.map atlas._managers.selection.getSelectionIds(), (id) -> AtlasIdMap.getAppId(id)

  getSelectedFeatureIds: ->
    _.filter @getSelectedEntityIds(), (id) => @getEntity(id).getForm?

  getSelectedLots: -> _.filter @getSelectedFeatureIds(), (id) -> Lots.findOne(id)

  getEntitiesByIds: (ids) -> _.map ids, (id) => @getEntity(id)

  getEntitiesAt: (point) -> atlas._managers.entity.getAt(point)

  showEntity: (id) ->
    # Don't attempt to render entities on the server since there's no view.
    return if Meteor.isServer
    isVisible = @getEntity(id).isVisible()
    atlas.publish 'entity/show', {id: AtlasIdMap.getAtlasId(id)}
    !isVisible

  hideEntity: (id) ->
    # Don't attempt to render entities on the server since there's no view.
    return if Meteor.isServer
    isVisible = @getEntity(id).isVisible()
    atlas.publish 'entity/hide', {id: AtlasIdMap.getAtlasId(id)}
    isVisible

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
        return Q.reject('No entities to zoom into.')
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

  selectEntities: (ids) ->
    ids = _.map ids, (id) -> AtlasIdMap.getAtlasId(id)
    atlas.publish('entity/select', {ids: ids})

  deselectEntities: (ids) ->
    ids = _.map ids, (id) -> AtlasIdMap.getAtlasId(id)
    atlas.publish('entity/deselect', {ids: ids})

  deselectAllEntities: -> atlas._managers.selection.clearSelection()

  setSelection: (ids) ->
    @deselectAllEntities()
    @selectEntities(ids)
