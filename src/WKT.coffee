WKT =

  getWKT: (callback) ->
    requirejs ['atlas/util/WKT'], (WKT) -> callback(WKT.getInstance())

  polygonFromVertices: (vertices, callback) ->
    @getWKT (wkt) ->
      polygon = wkt.openLayersPolygonFromGeoPoints(vertices)
      wktString = wkt.parser.extractGeometry(polygon)
      callback(wktString)

  polylineFromVertices: (vertices, callback) ->
    @getWKT (wkt) ->
      polyline = wkt.openLayersPolylineFromGeoPoints(vertices)
      wktString = wkt.parser.extractGeometry(polyline)
      callback(wktString)

  pointFromGeoPoint: (geoPoint, callback) ->
    @getWKT (wkt) ->
      wktString = wkt.wktFromGeoPoint(geoPoint)
      callback(wktString)

  featureToWkt: (feature, callback) ->
    displayMode = feature.getDisplayMode()
    if displayMode == 'polygon'
      wktMethod = @polygonFromVertices
    else if displayMode == 'line'
      wktMethod = @polylineFromVertices
    else
      df = Q.defer()
      df.resolve(null)
      return df.promise
    wktMethod.call(@, feature.getVertices(), callback)

  fromFile: (fileId, args) ->
    df = Q.defer()
    Assets.toC3ml(fileId, args).then(
      (result) ->
        wktResults = {}
        wktDfs = []
        _.each result.c3mls, (c3ml) ->
          if AtlasConverter.sanitizeType(c3ml.type) != 'polygon'
            return
          id = c3ml.id
          wktDf = WKT.fromC3ml(c3ml).then (wkt) ->
            wktResults[id] = wkt
          wktDfs.push(wktDf)
        Q.all(wktDfs).then ->
          df.resolve(wktResults)
      (err) -> df.reject(err)
    )
    df.promise

  fromC3ml: (c3ml) ->
    df = Q.defer()
    requirejs [
      'atlas/model/GeoPoint'
      'atlas/model/Vertex'
    ], (GeoPoint, Vertex) =>
      try
        type = AtlasConverter.sanitizeType(c3ml.type)
        method = null
        arg = null
        if type == 'polygon'
          rings = []
          rings.push createCoords(c3ml.coordinates, Vertex)
          _.each c3ml.holes, (hole) -> rings.push createCoords(hole, Vertex)
          @getWKT (wkt) -> df.resolve wkt.wktFromVerticesAndHoles(rings)
        else if type == 'line'
          method = @polylineFromVertices
          arg = getCoords(c3ml, GeoPoint)
        else if type == 'point'
          method = @pointFromGeoPoint
          arg = getCoords(c3ml, GeoPoint)[0]
        else
          df.resolve(null)
          return
        if method then method.call @, arg, (wkt) -> df.resolve(wkt)
      catch e
        Logger.error('Error when parsing C3ML into WKT', e, e.stack)
        df.resolve(null)
    df.promise

getCoords = (c3ml, GeoPoint) ->
  coords = c3ml.coordinates
  return null if coords.length == 0
  createCoords(coords, GeoPoint)

createCoords = (coords, Constructor) -> _.map coords, (coord) -> new Constructor(coord)
