/// Google Maps JSON styling for the commercial map.
///
/// Styling is a free Maps SDK feature: it only changes how the base map is
/// drawn, so it costs nothing extra. The goal here is to quiet the default
/// basemap — business pins, transit icons and road shields all compete with
/// the client markers — while keeping the landmarks a field commercial
/// actually navigates by (parks, schools, road names).
///
/// Styles only apply to [MapType.normal]; satellite, hybrid and terrain
/// imagery ignore them, so pass `null` for those.
const String kDaycoMapStyle = '''
[
  {
    "featureType": "poi.business",
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "poi.attraction",
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "transit",
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#f6c667" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#e8b24f" }]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#ffffff" }]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#fbfbfb" }]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#bfe1f0" }]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#f3f5f3" }]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [{ "color": "#dceccd" }]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#5a646e" }]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{ "color": "#ffffff" }, { "weight": 2 }]
  }
]
''';
