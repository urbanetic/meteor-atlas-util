getGeoPoint = (callback) ->
  requirejs ['atlas/model/GeoPoint'], (GeoPoint) ->
    callback(GeoPoint)

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
          if c3ml.type != 'polygon'
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
    getGeoPoint (GeoPoint) =>
      type = c3ml.type
      method = null
      if type == 'polygon'
        method = @polygonFromVertices
      else if type == 'line'
        method = @polylineFromVertices
      else
        df.reject('c3ml must be polygon, not ' + type)
        return
      coords = _.map c3ml.coordinates, (coord) ->
        new GeoPoint(longitude: coord.x, latitude: coord.y)
      if coords.length == 0
        df.resolve(null)
      else
        method.call(@, coords, (wkt) -> df.resolve(wkt))
    df.promise
