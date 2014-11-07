# AMD modules.
WKT = Style = Colour = null

class AtlasConverter

  toGeoEntityArgs: (args) ->
    geoEntity = _.extend({
      show: true
    }, args)
    vertices = args.vertices
    height = args.height ? 20
    width = args.width ? 10
    elevation = args.elevation ? 0
    zIndex = args.zIndex
    fillColor = args.fillColor
    borderColour = args.borderColor
    # TODO(aramk) Enable opacity in atlas-cesium.
    opacity = args.opacity
    borderOpacity = args.borderOpacity ? 1
    geometry =
      vertices: vertices
      elevation: elevation
      height: height
      width: width
      zIndex: zIndex

    # Vertices
    wkt = WKT.getInstance()
    if wkt.isPolygon(vertices)
      geoEntity.polygon = geometry
      geoEntity.displayMode ?= if height > 0 || elevation > 0 then 'extrusion' else 'footprint'
    else if wkt.isLineString vertices
      geoEntity.line = geometry
    else if vertices != null
      console.warn('Unknown type of vertices', args)

    # Style
    styleArgs = {}
    if fillColor
      _.extend(styleArgs, this.toAtlasStyleArgs(fillColor, opacity, 'fill'))
    if borderColour
      _.extend(styleArgs, this.toAtlasStyleArgs(borderColour, borderOpacity, 'border'))
    defaultStyle = Style.getDefault()
    geometry.style = new Style(_.defaults(styleArgs, {
      fillColour: defaultStyle.getFillColour()
      borderColour: defaultStyle.getBorderColour()
      borderWidth: defaultStyle.getBorderWidth()
    }))
    geoEntity

  toAtlasStyleArgs: (colour, opacity, prefix) ->
    styleArgs = {}
    styleArgs[prefix + 'Colour'] = new Colour(colour)
    if opacity != undefined
      styleArgs[prefix + 'Colour'].alpha = opacity
    styleArgs

  toColor: (color) -> new Colour(color)

  # TODO(aramk) Remove once c3ml color is refactored.
  colorFromC3mlColor: (color) ->
    if Types.isArray(color)
      new Colour(color[0] / 255, color[1] / 255, color[2] / 255, color[3] / 255)
    else
      new Colour(color)

_.extend(AtlasConverter, {

  _instance: null

  ready: ->
    df = Q.defer()
    # Load requirements when requesting instance.
    requirejs [
      'atlas/util/WKT'
      'atlas/model/Style'
      'atlas/model/Colour'
    ], (_WKT, _Style, _Colour) ->
      WKT = _WKT
      Style = _Style
      Colour = _Colour
      df.resolve()
    df.promise

  newInstance: -> @ready().then -> new AtlasConverter()

  getInstance: ->
    @ready().then =>
      unless @_instance
        @_instance = new AtlasConverter()
      @_instance

})
