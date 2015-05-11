bindMeteor = Meteor.bindEnvironment.bind(Meteor)

@GeometryUtils =

  # Deferred promises to prevent multiple requests for area for the same model interfering when they
  # try to create collections with the same ID.
  _areaDfs: {}

  getModelArea: (model) ->
    df = @_areaDfs[model._id]
    if df
      return df.promise
    df = Q.defer()
    @_areaDfs[model._id] = df
    df.promise.fin =>
      delete @_areaDfs[model._id]

    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      @hasWktGeometry(model).then bindMeteor (isWKT) =>
        if isWKT
          promise = @getWktArea(geom_2d)
        else
          # Create a temporary geometry and check the area.
          promise = @buildGeometryFromFile(geom_2d, {show: false}).then(
            bindMeteor (geometry) =>
              area = geometry.getArea()
              geometry.remove()
              df.resolve(area)
            df.reject
          )
        promise.then(df.resolve, df.reject)
    else
      df.resolve(null)
    df.promise

  buildGeometryFromFile: (fileId, args) ->
    args = _.extend({
      collectionId: fileId
      show: true
    }, args)
    collectionId = args.collectionId
    df = Q.defer()
    requirejs ['atlas/model/GeoPoint'], bindMeteor (GeoPoint) ->
      Files.downloadJson(fileId).then bindMeteor (result) ->
        unless result
          df.resolve(null)
          return
        # Modify the ID of c3ml entities to allow reusing them for multiple collections.
        c3mls = _.map result.c3mls, (c3ml) ->
          c3ml.id = collectionId + ':' + c3ml.id
          c3ml.show = args.show
          c3ml
        # Ignore all collections in the c3ml, since they don't affect visualisation.
        c3mls = _.filter c3mls, (c3ml) -> AtlasConverter.sanitizeType(c3ml.type) != 'collection'
        try
          c3mlEntities = AtlasManager.renderEntities(c3mls)
        catch e
          Logger.error('Error when rendering entities', e)
        ids = _.map c3mlEntities, (c3mlEntity) -> c3mlEntity.getId()
        AtlasManager.createCollection(collectionId, {children: ids}).then(df.resolve, df.reject)
    df.promise

  hasWktGeometry: (model) ->
    df = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      WKT.getWKT (wkt) -> df.resolve(wkt.isWKT(geom_2d))
    else
      df.resolve(false)
    df.promise

  getWktArea: (wktStr) ->
    df = Q.defer()
    WKT.getWKT bindMeteor (wkt) ->
      # TODO(aramk) This is inaccurate - use UTM 
      geometry = wkt.openLayersGeometryFromWKT(wktStr)
      df.resolve(geometry.getGeodesicArea())
    df.promise

  toUtmVertices: (vertexedEntity) ->
    _.map vertexedEntity.getVertices(), (point) -> point.toUtm().coord

