GeometryUtils =

  # Deferred promises to prevent multiple requests for area for the same model interfering when they
  # try to create collections with the same ID.
  _areaDfs: {}

  getModelArea: (model) ->
    id = model._id
    df = @_areaDfs[id]
    if df
      return df.promise
    df = Q.defer()
    @_areaDfs[id] = df
    df.promise.fin =>
      delete @_areaDfs[id]

    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      @hasWktGeometry(model).then Meteor.bindEnvironment (isWKT) =>
        if isWKT
          promise = @getWktArea(geom_2d)
        else
          # Create a temporary geometry and check the area.
          promise = @buildGeometryFromFile(geom_2d, {collectionId: id, show: false}).then(
            Meteor.bindEnvironment (geometry) =>
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
    requirejs ['atlas/model/GeoPoint'], Meteor.bindEnvironment (GeoPoint) =>
      Files.downloadJson(fileId).then Meteor.bindEnvironment (result) =>
        df.resolve(@buildGeometryFromC3ml(result, args))
    df.promise

  buildGeometryFromC3ml: (doc, args) ->
    args = _.extend({
      show: true
      groupSelect: true
    }, args)
    collectionId = args.collectionId
    unless collectionId?
      return Q.reject('No collection ID provided.')
    df = Q.defer()
    requirejs ['atlas/model/GeoPoint'], Meteor.bindEnvironment (GeoPoint) ->
      unless doc
        df.resolve(null)
        return
      # Modify the ID of c3ml entities to allow reusing them for multiple collections.
      c3mls = _.map doc.c3mls, (c3ml) ->
        c3ml.id = collectionId + ':' + c3ml.id
        c3ml.show = args.show
        c3ml
      # Ignore all collections in the c3ml, since they don't affect visualisation.
      c3mls = _.filter c3mls, (c3ml) -> AtlasConverter.sanitizeType(c3ml.type) != 'collection'
      AtlasManager.renderEntities(c3mls).then(
        (c3mlEntities) ->
          ids = _.map c3mlEntities, (c3mlEntity) -> c3mlEntity.getId()
          collectionArgs = {children: ids}
          style = args.style
          if style? then collectionArgs.style = style
          groupSelect = args.groupSelect
          if groupSelect? then collectionArgs.groupSelect = groupSelect
          df.resolve(AtlasManager.createCollection(collectionId, collectionArgs))
        (err) ->
          Logger.error('Error when rendering entities', err)
          df.reject(err)
      )
    df.promise

  hasWktGeometry: (model) ->
    df = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      WKT.getWKT Meteor.bindEnvironment (wkt) -> df.resolve(wkt.isWKT(geom_2d))
    else
      df.resolve(false)
    df.promise

  getWktArea: (wktStr) ->
    df = Q.defer()
    WKT.getWKT Meteor.bindEnvironment (wkt) ->
      # TODO(aramk) This is inaccurate - use UTM 
      geometry = wkt.openLayersGeometryFromWKT(wktStr)
      df.resolve(geometry.getGeodesicArea())
    df.promise

  toUtmVertices: (vertexedEntity) ->
    _.map vertexedEntity.getVertices(), (point) -> point.toUtm().coord

  getWktOrC3mls: (geom_2d) ->
    df = Q.defer()
    WKT.getWKT bindMeteor (wkt) =>
      isWKT = wkt.isWKT(geom_2d)
      if isWKT
        df.resolve(geom_2d)
      else
        df.resolve(Files.downloadJson(geom_2d))
    df.promise

  # @param {atlas.model.GeoPoint} origin - A GeoPoint coordinate for the origin of the measurement.
  # @param {atlas.model.Vertex} offset - A UTM coordinate measuring the offset from the given
  #     origin.
  # @returns {Promise.<Object>} results - A promise containing the UTM and GeoPoint coordinates.
  # @returns {Object} results.utmOrigin
  # @returns {atlas.model.Vertex} results.utmTargetCoord
  # @returns {atlas.model.GeoPoint} results.geoTarget
  # @returns {atlas.model.GeoPoint} results.geoDiff
  getUtmOffsetGeoPoint: (origin, offset) ->
    df = Q.defer()
    requirejs [
      'atlas/model/GeoPoint'
      'atlas/model/Vertex'
      'utm-converter'
    ], (GeoPoint, Vertex, UtmConverter) ->
      converter = new UtmConverter()
      utmOrigin = converter.toUtm(coord: origin)
      utmOriginCoord = new Vertex(utmOrigin.coord)
      utmTargetCoord = utmOriginCoord.translate(offset)
      geoTarget = GeoPoint.fromUtm(_.defaults(coord: utmTargetCoord, utmOrigin))
      geoDiff = geoTarget.subtract(origin)
      df.resolve
        utmOrigin: utmOrigin
        utmTargetCoord: utmTargetCoord
        geoTarget: geoTarget
        geoDiff: geoDiff
    df.promise
