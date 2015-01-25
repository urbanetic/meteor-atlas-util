atlas = atlasDf = null

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
    window.atlas = atlas

  removeAtlas: -> resetAtlas()

  renderEntity: (entityArgs) ->
    _.defaults entityArgs,
      show: true
    id = entityArgs.id
    unless id?
      throw new Error('Rendered entity must have ID.')
    atlas.publish 'entity/create/bulk', {features: [entityArgs]}
    entity = @getEntity(id)
    entity

  renderEntities: (entityArgs) ->
    _.each entityArgs, (entityArg) ->
      _.defaults entityArg,
        show: true
    entities = null
    atlas.publish 'entity/create/bulk', {
      features: entityArgs
      callback: (ids) ->
        entities = atlas._managers.entity.getByIds(ids)
    }
    entities

  unrenderEntity: (id) -> atlas.publish 'entity/remove', {id: id}

  getEntity: (id) -> atlas._managers.entity.getById(id)

  getEntities: -> atlas._managers.entity.getEntities()

  getEntitiesAsJson: -> _.map @getEntities(), (entity) -> entity.toJson()

  getFeatures: -> atlas._managers.entity.getFeatures()

  getSelectedEntityIds: -> atlas._managers.selection.getSelectionIds()

  getSelectedFeatureIds: ->
    _.filter @getSelectedEntityIds(), (id) -> atlas._managers.entity.getById(id).getForm?

  getSelectedLots: -> _.filter @getSelectedFeatureIds(), (id) -> Lots.findOne(id)

  getEntitiesByIds: (ids) -> atlas._managers.entity.getByIds(ids)

  getEntitiesAt: (point) -> atlas._managers.entity.getAt(point)

  showEntity: (id) -> atlas.publish 'entity/show', {id: id}

  hideEntity: (id) -> atlas.publish 'entity/hide', {id: id}

  zoomTo: (args) -> atlas.publish 'camera/zoomTo', args

  zoomToEntities: (ids) ->
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
          geoEntityIds.push(id)
      unless someGeoEntity?
        console.error('No entities to zoom into.')
        return
      # TODO(aramk) Use dependency injection to prevent the need for passing manually.
      deps = someGeoEntity._bindDependencies({})
      collection = new Collection('collection-project-zoom', {entities: geoEntityIds}, deps)
      boundingBox = collection.getBoundingBox().scale(1.5)
      camera.zoomTo({
        rectangle: boundingBox
      });
      # Remove temporary collection but retain the entities contained within by removing them
      # from the collection first.
      _.each geoEntityIds, (id) ->
        collection.removeEntity(id)
      collection.remove()

  getCurrentCamera: (args) -> atlas.publish('camera/current', args)

  getDisplayModes: ->
    df = Q.defer()
    requirejs ['atlas/model/Feature'], (Feature) ->
      items = _.map Feature.DisplayMode, (value, id) ->
        {label: Strings.toTitleCase(value), value: value}
      df.resolve(items)
    df.promise

  draw: (args) -> atlas.publish('entity/draw', args)

  stopDraw: (args) -> atlas.publish('entity/draw/stop', args)

  edit: (args) -> atlas.publish('edit/enable', args)

  stopEdit: -> atlas.publish('edit/disable')

  selectEntities: (ids) -> atlas.publish('entity/select', {ids: ids})

  deselectEntities: (ids) -> atlas.publish('entity/deselect', {ids: ids})

  deselectAllEntities: -> atlas._managers.selection.clearSelection()

  setSelection: (ids) ->
    @deselectAllEntities()
    @selectEntities(ids)
