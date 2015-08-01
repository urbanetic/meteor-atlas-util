atlas = atlasDf = null
global = @

resetAtlas = ->
  try
    atlas?.destroy()
  catch err
    Logger.error('Error when removing Atlas', err, {notify: false})
  atlas = null
  delete global.atlas
  if atlasDf then atlasDf.reject('Atlas reset')
  atlasDf = Q.defer()

resetAtlas()

AtlasManager =

  getAtlas: -> atlasDf.promise

  hasAtlas: -> atlas?

  setAtlas: (_instance) ->
    if atlas
      throw new Error('Atlas is already set - remove it first.')
    atlas = _instance
    # Add a reference to the window for debugging.
    global.atlas = atlas
    atlasDf.resolve(atlas)

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
    id = AtlasIdMap.getAtlasId(id)
    return false unless id?
    atlas.publish 'entity/show', id: id
    @getEntity(id)?.isVisible() ? false

  hideEntity: (id) ->
    # Don't attempt to render entities on the server since there's no view.
    return false if Meteor.isServer
    id = AtlasIdMap.getAtlasId(id)
    return false unless id?
    atlas.publish 'entity/hide', id: id
    !@getEntity(id)?.isVisible() ? false

  zoomTo: (args) -> atlas.publish 'camera/zoomTo', args

  zoomToEntities: (ids) ->
    geoEntityIds = []
    _.each ids, (id) =>
      geoEntity = @getEntity(id)
      if geoEntity? then geoEntityIds.push geoEntity.getId()
    unless geoEntityIds.length > 0
      return Q.reject('No entities to zoom into.')
    df = Q.defer()
    atlas.publish 'camera/zoomTo',
      ids: ids
      callback: (promise) ->
        console.log('promise', promise)
        df.resolve(promise)
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

  selectEntities: (ids, args) ->
    args = Setter.merge {ids: AtlasIdMap.getAtlasIds(ids), keepSelection: true}, args
    atlas.publish 'entity/select', args

  deselectEntities: (ids, args) ->
    args = Setter.merge {ids: AtlasIdMap.getAtlasIds(ids), keepSelection: true}, args
    atlas.publish 'entity/deselect', args

  deselectAllEntities: (args) -> atlas.publish 'entity/deselect/all', args

  setSelection: (ids, args) ->
    @deselectAllEntities(args)
    @selectEntities(ids, args)

  setSelectionEnabled: (enable, args) ->
    unless enable then @deselectAllEntities(args)
    atlas._managers.selection.setEnabled(enable)
