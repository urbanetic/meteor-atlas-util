describe 'GeometryUtils', ->

  it 'exists', (test) ->
    test.isTrue GeometryUtils?, 'GeometryUtils not initialized in test environment'

  it 'can calculate WKT area', (test) ->
    wktStr = 'POLYGON((144.97151547 -37.81612227,144.97140824 -37.81615372,144.97130225 -37.81592632,144.97140946 -37.81589489,144.97151547 -37.81612227))'
    area = GeometryUtils.getWktArea(wktStr)
    test.isTrue(271 < area < 272)
    test.equal area, GeometryUtils.getArea(wktStr)

  it 'can calculate GeoJSON area', (test) ->
    geoJson = '{"type":"Polygon","coordinates":[[[144.964279515,-37.82957824],[144.964326617,-37.82942246],[144.965326473,-37.829612903],[144.965123699,-37.830283723],[144.96500799,-37.830317298],[144.964279515,-37.82957824]]]}'
    area = GeometryUtils.getGeoJsonArea(JSON.parse(geoJson))
    test.isTrue(4992 < area < 4993)
    test.equal area, GeometryUtils.getArea(geoJson)
