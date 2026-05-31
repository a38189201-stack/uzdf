import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Polygon> _polygons = {};
  bool _isLoading = true;

  bool _isWeatherPanelOpen = false;
  bool _isWeatherLoaded = false;
  Map<String, dynamic>? _weatherData;

  // Tashkent coordinates
  static const LatLng _initialCenter = LatLng(41.2995, 69.2401);

  // Dark Map Style JSON
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9e9e9e"
        }
      ]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#151515"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#1c1c1c"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#2c2c2c"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8a8a8a"
        }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#373737"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3c3c3c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#0d0d0d"
        }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadZones();
    // Auto-load weather data on init (no XP reward, just data)
    _loadWeatherSilent();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await ApiService.fetchZones();
      final Set<Polygon> tempPolygons = {};

      for (var z in zones) {
        final id = z['id']?.toString() ?? UniqueKey().toString();
        final name = z['name'] ?? 'Зона без названия';
        final type = z['type']?.toString().toUpperCase() ?? 'RED';
        final maxAlt = z['maxAltitude']?.toString() ?? '0';

        var rawCoords = z['coordinates'];
        if (rawCoords is String) {
          try {
            rawCoords = jsonDecode(rawCoords);
          } catch (_) {}
        }

        final points = _parseCoordinates(rawCoords);
        if (points.isNotEmpty) {
          Color fillColor;
          Color strokeColor;

          if (type == 'GREEN') {
            fillColor = Colors.green.withValues(alpha: 0.3);
            strokeColor = Colors.green;
          } else if (type == 'YELLOW') {
            fillColor = Colors.amber.withValues(alpha: 0.3);
            strokeColor = Colors.amber;
          } else {
            fillColor = Colors.red.withValues(alpha: 0.3);
            strokeColor = Colors.red;
          }

          tempPolygons.add(
            Polygon(
              polygonId: PolygonId(id),
              points: points,
              fillColor: fillColor,
              strokeColor: strokeColor,
              strokeWidth: 2,
              consumeTapEvents: true,
              zIndex: (10000 - (_getBoundsArea(points) * 100000).toInt()).clamp(0, 10000),
              onTap: () {
                _showZoneDetails(name, type, maxAlt);
              },
            ),
          );
        }
      }

      setState(() {
        _polygons.clear();
        _polygons.addAll(tempPolygons);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading zones for map: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load weather silently without XP reward — just populates the panel
  Future<void> _loadWeatherSilent() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // Simulate real weather data (Tashkent) – replace with real API call if needed
    final now = DateTime.now();
    final hour = now.hour;
    final tempBase = hour >= 8 && hour <= 18 ? 28 : 18;
    final windSpeed = 2.5 + (hour % 5) * 0.4;
    final humidity = 35 + (hour % 10) * 3;
    final visibility = 9.5 - (hour % 3) * 0.5;
    final pressure = 1013 + (hour % 7);
    final kIndex = windSpeed < 5 && visibility > 8 ? 2 : (windSpeed < 8 ? 4 : 6);
    String verdict;
    Color verdictColor;
    if (kIndex <= 3) {
      verdict = '🟢 Отличные условия для полетов';
      verdictColor = Colors.green;
    } else if (kIndex <= 5) {
      verdict = '🟡 Умеренные условия — соблюдайте осторожность';
      verdictColor = Colors.amber;
    } else {
      verdict = '🔴 Неблагоприятные условия — полеты не рекомендуются';
      verdictColor = Colors.red;
    }
    setState(() {
      _isWeatherLoaded = true;
      _weatherData = {
        'temp': '${tempBase}°C',
        'humidity': '$humidity%',
        'wind': '${windSpeed.toStringAsFixed(1)} м/с',
        'windDirection': 'СВ',
        'visibility': '${visibility.toStringAsFixed(1)} км',
        'pressure': '$pressure гПа',
        'kIndex': kIndex,
        'verdict': verdict,
        'verdictColor': verdictColor,
      };
    });
  }

  List<LatLng> _parseCoordinates(dynamic raw) {
    List<LatLng> points = [];
    if (raw == null) return points;

    if (raw is List && raw.isNotEmpty && raw.first is List && raw.first.first is List) {
      raw = raw.first;
    }

    if (raw is List) {
      for (var item in raw) {
        if (item is List && item.length >= 2) {
          try {
            double lng = double.parse(item[0].toString());
            double lat = double.parse(item[1].toString());
            points.add(LatLng(lat, lng));
          } catch (_) {}
        }
      }
    }
    return points;
  }

  double _getBoundsArea(List<LatLng> points) {
    if (points.isEmpty) return 0.0;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return (maxLat - minLat) * (maxLng - minLng);
  }

  void _showZoneDetails(String name, String type, String maxAltitude) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0A0D1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        Color badgeColor = Colors.red;
        if (type == 'GREEN') badgeColor = Colors.green;
        if (type == 'YELLOW') badgeColor = Colors.amber;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      type,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.height, color: Color(0xFF0066FF)),
                  const SizedBox(width: 8),
                  Text(
                    'Макс. высота полета: $maxAltitude м',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Понятно', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleWeatherPanel() {
    setState(() {
      _isWeatherPanelOpen = !_isWeatherPanelOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта зон БПЛА', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadZones();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
              : GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _initialCenter,
                    zoom: 11.5,
                  ),
                  polygons: _polygons,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  style: isDark ? _darkMapStyle : '[]',
                ),

          // Floating Controls (Weather toggle)
          Positioned(
            right: 16,
            bottom: 106,
            child: FloatingActionButton.small(
              heroTag: 'weatherBtn',
              backgroundColor: _isWeatherPanelOpen
                  ? const Color(0xFF0066FF)
                  : (isDark ? const Color(0xFF0A0D1A) : Colors.white),
              foregroundColor: _isWeatherPanelOpen
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
              onPressed: _toggleWeatherPanel,
              child: const Icon(Icons.cloud_outlined),
            ),
          ),

          // Legend bar
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegend(Colors.red, 'Запрещено', isDark),
                  _buildLegend(Colors.amber, 'Ограничено', isDark),
                  _buildLegend(Colors.green, 'Разрешено', isDark),
                ],
              ),
            ),
          ),

          // Weather DraggableScrollableSheet
          if (_isWeatherPanelOpen)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.35,
              maxChildSize: 0.75,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A0D1A) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -4)),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Погода & Безопасность',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.grey,
                            onPressed: () => setState(() => _isWeatherPanelOpen = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ташкент, Узбекистан',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      if (!_isWeatherLoaded || _weatherData == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Color(0xFF0066FF)),
                          ),
                        )
                      else ...[
                        // Verdict banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (_weatherData!['verdictColor'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (_weatherData!['verdictColor'] as Color).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _weatherData!['verdict'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _weatherData!['verdictColor'] as Color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Weather grid
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildWeatherCard('Температура', _weatherData!['temp'], Icons.thermostat, Colors.orange, isDark),
                            _buildWeatherCard('Ветер', _weatherData!['wind'], Icons.air, Colors.blue, isDark),
                            _buildWeatherCard('Влажность', _weatherData!['humidity'], Icons.water_drop, Colors.cyan, isDark),
                            _buildWeatherCard('Видимость', _weatherData!['visibility'], Icons.visibility, Colors.purple, isDark),
                            _buildWeatherCard('Давление', _weatherData!['pressure'], Icons.compress, Colors.teal, isDark),
                            _buildWeatherCard('K-Индекс', 'Kp ${_weatherData!['kIndex']}', Icons.gps_off, Colors.redAccent, isDark),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Flight suitability score
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0A1A30) : const Color(0xFFF0F6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flight_takeoff, color: Color(0xFF0066FF)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Пригодность для БПЛА',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _weatherData!['kIndex'] <= 3
                                          ? 'Все категории БПЛА — ДА'
                                          : _weatherData!['kIndex'] <= 5
                                              ? 'Только опытные пилоты'
                                              : 'Полеты не рекомендованы',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1628) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}