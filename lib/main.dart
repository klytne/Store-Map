import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'src/store.dart';
import 'src/path_point.dart';
import 'src/load_path_points.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

String formatDateTime(DateTime dt) {
  return DateFormat('yyyy-MM-dd – kk:mm').format(dt);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Map<String, Marker> _markers = {};

  // Loading & Displaying Store Locations
  Future<List<Store>> loadStores() async {
    final rawCsv = await rootBundle.loadString('assets/storesCopy.csv');
    List<List<dynamic>> csvTable = const CsvToListConverter(
      fieldDelimiter: ';', // Use semicolon as delimiter
    ).convert(rawCsv);

    // Skip the first row
    List<Store> stores =
        csvTable.skip(1).map((row) {
          // convert to a Store object
          return Store(
            name: row[0].toString().trim(),
            latitude: double.parse(row[1].toString().trim()),
            longitude: double.parse(row[2].toString().trim()),
          );
        }).toList();

    return stores;
  }

  // Calculates the average latitude and longitude of the stores
  // and then sets initial camera position
  Future<CameraPosition> _calculateInitialPosition(List<Store> stores) async {
    double totalLat = 0, totalLng = 0;
    for (var store in stores) {
      totalLat += store.latitude;
      totalLng += store.longitude;
    }
    final count = stores.length;
    final centerLat = totalLat / count;
    final centerLng = totalLng / count;

    return CameraPosition(
      target: LatLng(centerLat, centerLng),
      zoom: 10, // Adjust zoom level as need
    );
  }

  // Displaying Markers on the Map
  Future<void> _onMapCreated(GoogleMapController controller) async {
    final stores = await loadStores();

    setState(() {
      _markers.clear();
      for (final store in stores) {
        final marker = Marker(
          markerId: MarkerId(store.name),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(title: store.name),
        );
        _markers[store.name] = marker;
      }
    });

    // Move the camera to focus on store locations
    final initialPosition = await _calculateInitialPosition(stores);
    controller.animateCamera(CameraUpdate.newCameraPosition(initialPosition));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Store Locations')),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 2,
          ),
          markers: _markers.values.toSet(),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<PathPoint> _pathPoints = [];

  @override
  void initState() {
    super.initState();
    _loadAndDisplayPath();
  }

  //  Loading and Displaying Path Data
  Future<void> _loadAndDisplayPath() async {
    final points = await loadPathPoints();
    setState(() {
      _pathPoints = points;

      // Create polyline from all points
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('path'),
          points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          color: Colors.blue,
          width: 5,
        ),
      );

      // Add markers at each point with details
      for (final point in points) {
        _markers.add(
          Marker(
            markerId: MarkerId('${point.latitude}-${point.longitude}'),
            position: LatLng(point.latitude, point.longitude),
            infoWindow: InfoWindow(
              title: formatDateTime(point.dateTime),
              snippet: 'Speed: ${point.speed} km/h, Heading: ${point.heading}°',
            ),
          ),
        );
      }
    });

    // Adjust camera to first point
    if (points.isNotEmpty) {
      final firstPoint = points.first;
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(firstPoint.latitude, firstPoint.longitude),
          14,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Path Display")),
      body: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 2,
        ),
        polylines: _polylines,
        markers: _markers,
      ),
    );
  }
}
