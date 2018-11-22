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
      isWKT = @hasWktGeometry(model)
      if isWKT
        df.resolve @getWktArea(geom_2d)
      else
        # Create a temporary geometry and check the area.
        @buildGeometryFromFile(geom_2d, {collectionId: id, show: false}).then(
          Meteor.bindEnvironment (geometry) =>
            area = geometry.getArea()
            geometry.remove()
            df.resolve(area)
          df.reject
        )
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
    Files.downloadJson(fileId).then(
      Meteor.bindEnvironment (result) => df.resolve(@buildGeometryFromC3ml(result, args))
      df.reject
    )
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
        df.resolve AtlasManager.createCollection(collectionId, collectionArgs)
      (err) ->
        Logger.error('Error when rendering entities', err)
        df.reject(err)
    )
    df.promise

  toUtmVertices: (vertexedEntity) ->
    _.map vertexedEntity.getVertices(), (point) -> point.toUtm().coord

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

_.extend GeometryUtils,

  hasWktGeometry: (model) ->
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d then wkt.isWKT(geom_2d) else false

  getArea: (str) ->
    return null if !str

    if wkt.isWKT(str)
      return @getWktArea(str)
    else
      return @getGeoJsonArea @_parseJsonMaybe(str)

  getWktArea: (wktStr) -> @getCoordsArea wkt.geoPointsFromWKT(wktStr)

  getGeoJsonArea: (geometry) ->
    type = geometry.type
    coords = geometry.coordinates
    if type == 'Polygon'
      @getGeoJsonPolygonCoordsArea(coords)
    else if type == 'MultiPolygon'
      area = 0
      _.each coords, (polys) => area += @getGeoJsonPolygonCoordsArea(polys)
      area

  getGeoJsonPolygonCoordsArea: (polys) ->
    area = 0
    area += @getCoordsArea(polys[0])
    _.each polys.slice(1), (coords) =>
      area -= @getCoordsArea(coords)
    area

  getCoordsArea: (coords) ->
    coords = _.map coords, (coord) -> new GeoPoint(coord).toUtm().coord
    geometry = wkt.openLayersPolygonFromVertices(coords)
    geometry.getArea()

  getWktCentroid: (wktStr) -> wkt.openLayersGeometryFromWKT(wktStr)?.getCentroid()

  getWktOrC3mls: (geom_2d) ->
    isWKT = wkt.isWKT(geom_2d)
    if isWKT then geom_2d else Files.downloadJson(geom_2d)

  pointsFromFootprint: (strOrObj) ->
    if wkt.isWKT(strOrObj)
      wkt.geoPointsFromWKT(strOrObj)
    else
      geometry = @_parseJsonMaybe(strOrObj)
      innerCoords = coords = geometry.coordinates
      if Types.isArray(coords) and Types.isArray(coords[0]) and Types.isArray(coords[0][0])
        innerCoords = coords[0]
      Objects.traverseValues innerCoords, (value, key, obj) ->
        return if Types.isNumber(value)
        if Types.isArray(value) and Types.isNumber(value[0])
          obj[key] = new GeoPoint(value)
      coords

  # Returns a GeoJSON polygon from the given GeoPoint array.
  #  * `points` - An array of points in GeoJSON.
  #  * `options.closePoints` - Whether to close the points of the polygon. Defaults to true.
  geoJsonPolygonFromPoints: (points, options) ->
    coords = _.map points, (point) -> point.toArray()
    # Remove elevation if possible to save space.
    hasNoElevation = _.all coords, (coord) -> coord[2] == 0
    if hasNoElevation then _.each coords, (coord) -> coord.pop()
    # Ensure polygon is closed.
    if !options? or options.closePoints
      unless _.isEqual _.first(coords), _.last(coords)
        coords.push _.first(coords)
    {type: 'Polygon', coordinates: [coords]}

  _parseJsonMaybe: (strOrObj) ->
    if Types.isObjectLiteral(strOrObj)
      return strOrObj
    else
      try
        JSON.parse(strOrObj)
      catch err
        Logger.error('Error parsing JSON', err)
        throw err

wkt = null
WKT.getWKT (_wkt) -> wkt = _wkt

GeoPoint = null
Vertex = null
UtmConverter = null
requirejs [
  'atlas/model/GeoPoint'
  'atlas/model/Vertex'
  'utm-converter'
], (_GeoPoint, _Vertex, _UtmConverter) ->
  GeoPoint = _GeoPoint
  Vertex = _Vertex
  UtmConverter = _UtmConverter
