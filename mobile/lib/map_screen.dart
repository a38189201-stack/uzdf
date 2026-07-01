import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'glass_widgets.dart';
import 'api_service.dart';
import 'app_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Polygon> _polygons = {};
  bool _isLoading = true;
  bool _isLocationPermissionGranted = false;

  bool _isWeatherPanelOpen = false;
  bool _isWeatherLoaded = false;
  Map<String, dynamic>? _weatherData;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Tashkent coordinates
  static const LatLng _initialCenter = LatLng(41.2995, 69.2401);

  // Dark Map Style JSON
  // ignore: unused_field
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
    _checkLocationPermission();
    _loadZones();
    // Auto-load weather data on init (no XP reward, just data)
    _loadWeatherSilent();
  }

  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        if (mounted) {
          setState(() {
            _isLocationPermissionGranted = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking location permission: $e');
    }
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
        'temp': '$tempBase°C',
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
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        Color badgeColor = Colors.red;
        if (type == 'GREEN') badgeColor = Colors.green;
        if (type == 'YELLOW') badgeColor = Colors.amber;

        return GlassContainer(
          borderRadius: 22,
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
                        color: colorScheme.onSurface,
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
                  Icon(Icons.height, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Макс. высота полета: $maxAltitude м',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GlassButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Карта зон БПЛА', style: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _isLoading = true);
              _loadZones();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
              : ValueListenableBuilder<bool>(
                  valueListenable: AppState().isDarkMode,
                  builder: (context, isDark, _) {
                    return GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _initialCenter,
                        zoom: 11.5,
                      ),
                      style: isDark ? _darkMapStyle : '[]',
                      polygons: _polygons,
                      myLocationEnabled: _isLocationPermissionGranted,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    );
                  },
                ),

          // Weather floating button over map
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'weatherBtn',
              backgroundColor: _isWeatherPanelOpen
                  ? colorScheme.primary
                  : colorScheme.surface,
              foregroundColor: _isWeatherPanelOpen
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
              onPressed: () {
                HapticFeedback.lightImpact();
                _toggleWeatherPanel();
              },
              child: const Icon(Icons.cloud_outlined),
            ),
          ),

          // Legend bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 68 + 24 + 16,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegend(const Color(0xFFFF1744), 'Запрещено'),
                      _buildLegend(const Color(0xFFFFC400), 'Ограничено'),
                      _buildLegend(const Color(0xFF00E676), 'Разрешено'),
                    ],
                  ),
                ),
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
                return GlassContainer(
                  borderRadius: 22,
                  padding: EdgeInsets.zero,
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
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: colorScheme.onSurfaceVariant,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isWeatherPanelOpen = false);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ташкент, Узбекистан',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      if (!_isWeatherLoaded || _weatherData == null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: colorScheme.primary),
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
                            _buildWeatherCard('Температура', _weatherData!['temp'], Icons.thermostat, Colors.orange),
                            _buildWeatherCard('Ветер', _weatherData!['wind'], Icons.air, Colors.blue),
                            _buildWeatherCard('Влажность', _weatherData!['humidity'], Icons.water_drop, Colors.cyan),
                            _buildWeatherCard('Видимость', _weatherData!['visibility'], Icons.visibility, Colors.purple),
                            _buildWeatherCard('Давление', _weatherData!['pressure'], Icons.compress, Colors.teal),
                            _buildWeatherCard('K-Индекс', 'Kp ${_weatherData!['kIndex']}', Icons.gps_off, Colors.redAccent),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Flight suitability score
                        GlassContainer(
                          padding: const EdgeInsets.all(14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              Icon(Icons.flight_takeoff, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Пригодность для БПЛА',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
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
                                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
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

  Widget _buildWeatherCard(String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassContainer(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
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
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    final colorScheme = Theme.of(context).colorScheme;
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
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}