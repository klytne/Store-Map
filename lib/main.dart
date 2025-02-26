import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'src/store.dart';
import 'src/path_point.dart';
import 'src/load_path_points.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';


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
  final Set<Polyline> _polylines = {}; // Store the vehicle path
  List<PathPoint> _pathPoints = [];
  GoogleMapController? _mapController;
  BitmapDescriptor? pinLocationIcon;

  @override
  void initState() {
    super.initState();
    _setCustomMapPin().then((_) => _loadPathAndStores()); // Ensure icon is loaded first
  }

  // Load the custom store icon
  Future<void> _setCustomMapPin() async {
    pinLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 1.0),
      'assets/store.png',
    );
  }

  // Loading store locations
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

  // Load path data and display store locations
  Future<void> _loadPathAndStores() async {
    final stores = await loadStores();
    final pathPoints = await loadPathPoints();

    setState(() {
      _pathPoints = pathPoints;

      // Add path as a polyline
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('vehicle_path'),
          points:
              pathPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          color: Colors.blue,
          width: 5,
        ),
      );

      // Add markers at stores
      _markers.clear();
      for (final store in stores) {
        _markers[store.name] = Marker(
          markerId: MarkerId(store.name),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(title: store.name),
           icon: pinLocationIcon ?? BitmapDescriptor.defaultMarker,
        );
      }

      // Load vehicle path markers
      for (final point in pathPoints.whereIndexed(
        (index, p) => index % 10 == 0,
      )) {
        _markers['${point.latitude}-${point.longitude}'] = Marker(
          markerId: MarkerId('${point.latitude}-${point.longitude}'),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(
            title: formatDateTime(point.dateTime),
            snippet: 'Speed: ${point.speed} km/h, Heading: ${point.heading}°',
          ),
        );
      }
    });

    // Set the initial camera position
    final initialPosition = await _calculateInitialPosition(stores);
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(initialPosition));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Vehicle Path')),
        body: GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            bearing: 30,
            zoom: 2,
          ),
          markers: _markers.values.toSet(),
          polylines: _polylines,
        ),
      ),
    );
  }
}
