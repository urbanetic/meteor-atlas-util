# AMD modules.
AtlasWKT = Style = Color = null

class AtlasConverter

  toGeoEntityArgs: (args) ->
    vertices = args.vertices
    elevation = args.elevation ? 0
    zIndex = args.zIndex
    geometry =
      elevation: elevation
      zIndex: zIndex

    # Style
    style = args.style
    if style then geometry.style = args.style
    
    delete args.vertices
    delete args.elevation
    delete args.zIndex
    delete args.style
    
    geoEntity = _.extend({
      type: 'feature'
      show: true
    }, args)

    # Vertices
    wkt = AtlasWKT.getInstance()
    if wkt.isWKT(vertices)
      isPolygon = wkt.isPolygon(vertices)
      isLine = wkt.isLine(vertices)
      isPoint = wkt.isPoint(vertices)
    else
      try
        geoJson = if Types.isString(vertices) then JSON.parse(vertices) else vertices
        type = geoJson.type
        isPolygon = type == 'Polygon'
        isMultiPolygon = type == 'MultiPolygon'
        isLine = type == 'LineString' || type == 'MultiLineString'
        isPoint = type == 'Point'
        if isPolygon
          vertices = geoJson.coordinates[0]
          holes = geoJson.coordinates.slice(1)
        else if type == 'MultiLineString'
          vertices = vertices[0]
        else
          vertices = geoJson.coordinates

    if isMultiPolygon
      children = _.map vertices, (coordinates) =>
        newArgs = {vertices: {type: 'Polygon', coordinates: coordinates}}
        @toGeoEntityArgs(Setter.merge(Setter.clone(args), newArgs))
      return children
    else if isPolygon
      height = args.height ? 10
      geoEntity.polygon = geometry
      geoEntity.displayMode ?= if height > 0 || elevation > 0 then 'extrusion' else 'footprint'
      geometry.vertices = vertices
      geometry.holes = holes if holes?
      geometry.height = height
    else if isLine
      geoEntity.line = geometry
      geometry.width = args.width ? 10
      geometry.vertices = vertices
      geoEntity.displayMode = 'line'
      # Height can be set on features only if the form is a polygon.
      delete geoEntity.height
    else if isPoint
      geoEntity.point = geometry
      geometry.position = vertices
      geoEntity.displayMode = 'point'
    
    return geoEntity

  toAtlasStyleArgs: (color, opacity, prefix) ->
    styleArgs = {}
    styleArgs[prefix + 'Color'] = new Color(color)
    if opacity != undefined
      styleArgs[prefix + 'Color'].alpha = opacity
    styleArgs

  toColor: (color) -> new Color(color)

  # TODO(aramk) Remove once c3ml color is refactored.
  colorFromC3mlColor: (color) ->
    if Types.isArray(color)
      new Color(color[0] / 255, color[1] / 255, color[2] / 255, color[3] / 255)
    else
      new Color(color)

_.extend(AtlasConverter, {

  _instance: null
  _readyDf: null

  ready: ->
    return @_readyDf.promise if @_readyDf?
    df = @_readyDf = Q.defer()
    # Load requirements when requesting instance.
    requirejs [
      'atlas/util/WKT'
      'atlas/material/Style'
      'atlas/material/Color'
    ], (_WKT, _Style, _Color) ->
      AtlasWKT = _WKT
      Style = _Style
      Color = _Color
      df.resolve()
    df.promise

  newInstance: -> @ready().then -> new AtlasConverter()

  getInstance: ->
    @ready().then =>
      unless @_instance
        @_instance = new AtlasConverter()
      @_instance

  sanitizeType: (type) -> type?.toLowerCase()

})
