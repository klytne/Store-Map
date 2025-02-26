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
import 'package:geolocator/geolocator.dart';

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

  // Variables for the info card
  String closestStoreName = "Loading...";
  double maxSpeed = 0.0;
  double totalDistance = 0.0;
  String firstCloseTimestamp = "N/A";

  @override
  void initState() {
    super.initState();
    _setCustomMapPin().then(
      (_) => _loadPathAndStores(),
    ); // Ensure icon is loaded first
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

    double minDistance = double.infinity;
    Store? closestStore;
    DateTime? firstCloseTime;

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

      // Find the closest store to the path
      for (final store in stores) {
        for (final point in pathPoints) {
          double distance = Geolocator.distanceBetween(
            store.latitude,
            store.longitude,
            point.latitude,
            point.longitude,
          );
          if (distance < minDistance) {
            minDistance = distance;
            closestStore = store;
          }
        }
      }

      // Find the highest speed recorded
      maxSpeed = pathPoints.map((p) => p.speed).reduce((a, b) => a > b ? a : b);

      // Find when the vehicle first came close to the closest store
      if (closestStore != null) {
        for (final point in pathPoints) {
          double distance = Geolocator.distanceBetween(
            closestStore!.latitude,
            closestStore!.longitude,
            point.latitude,
            point.longitude,
          );
          if (distance <= 50) {
            // 50 meters threshold
            firstCloseTime ??= point.dateTime;
            break;
          }
        }
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
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(initialPosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Stores & Vehicle Path')),
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 2,
              ),
              markers: _markers.values.toSet(),
              polylines: _polylines,
            ),

            // Floating Information Card
            Positioned(
              top: 30,
              left: 20,
              width: 300,
              height: 120,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "🚗 Closest Store: $closestStoreName",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "⚡ Highest Speed: ${maxSpeed.toStringAsFixed(2)} km/h",
                      ),
                      Text(
                        "📏 Distance Traveled: ${totalDistance.toStringAsFixed(2)} meters",
                      ),
                      Text("⏳ First Close Timestamp: $firstCloseTimestamp"),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
