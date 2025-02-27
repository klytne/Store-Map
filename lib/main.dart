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
import 'dart:math';

void main() {
  runApp(const MyApp());
}

// Function to format a DateTime object into a readable string format
String formatDateTime(DateTime dt) {
  return DateFormat('yyyy-MM-dd – kk:mm').format(dt);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  //Declare variables
  final Map<String, Marker> _markers = {}; // Map to store markers
  final Set<Polyline> _polylines = {}; // Set to hold polylines
  List<PathPoint> _pathPoints = []; // List of path points for the vehicle's movement
  List<Store> stores = []; // List to hold stores
  late GoogleMapController controller;  // Google Maps controller to manage the map
  BitmapDescriptor? pinLocationIcon; // Store pin icon
  late BitmapDescriptor initialPointIcon; // Icon for the initial point
  late BitmapDescriptor vehicleIcon; // Vehicle icon

  // Variables for displaying info card data
  String closestStoreName = "Loading...";
  double maxSpeed = 0.0;
  double totalDistance = 0.0;
  String firstCloseTimestamp = "N/A";

  @override
  void initState() {
    super.initState();

    // Load custom icons first then load path and stores
    _setCustomStorePin().then((_) => _loadPathAndStores()); // store pin icon
    _setCustomInitialPin().then((_) => _loadPathAndStores()); // initial point icon
    _vehiclePin().then((_) => _loadPathAndStores()); // vehicle icon
  }

  // Load custom store icon
  Future<void> _setCustomStorePin() async {
    pinLocationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 1.0),
      'assets/store.png',
    );
  }

  // Load custom initial icon
  Future<void> _setCustomInitialPin() async {
    initialPointIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 1.0),
      'assets/initial_point.png',
    );
  }

  // Load vehicle icon
  Future<void> _vehiclePin() async {
    vehicleIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 1.0),
      'assets/car.png',
    );
  }

  // Load store locations
  Future<List<Store>> loadStores() async {
    final rawCsv = await rootBundle.loadString('assets/storesCopy.csv'); // Load the CSV file as a raw string
    
    // Convert the CSV data into a table format
    List<List<dynamic>> csvTable = const CsvToListConverter(
      fieldDelimiter: ';', // Semicolon as delimiter
    ).convert(rawCsv);

    // Skip first row
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

  // Load path data and display store locations
  Future<void> _loadPathAndStores() async {

     // Load store locations and path points from CSV
    final stores = await loadStores();
    final pathPoints = await loadPathPoints();

    // Variables to track the closest store to the vehicle path
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

      // Clear previous markers
      _markers.clear();

      // Add markers at stores
      for (final store in stores) {
        _markers[store.name] = Marker(
          markerId: MarkerId(store.name),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(title: store.name), // Store name in marker info
          icon: pinLocationIcon ?? BitmapDescriptor.defaultMarker,  // Use custom store icon
        );
      }

      // Find closest store to the path
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
            closestStore = store; // Update closest store
          }
        }
      }

      // Find highest speed recorded
      maxSpeed = pathPoints.map((p) => p.speed).reduce((a, b) => a > b ? a : b);

      // Find timestamp when vehicle is close to a store
      if (closestStore != null) {
        double minDistance = double.infinity;
        firstCloseTime = null;

        for (final point in pathPoints) {
          double distance = Geolocator.distanceBetween(
            closestStore!.latitude,
            closestStore!.longitude,
            point.latitude,
            point.longitude,
          );

          // If this is the smallest distance so far, update firstCloseTime
          if (distance < minDistance) {
            minDistance = distance;
            firstCloseTime = point.dateTime;
          }
        }
      }

      // Add markers along the vehicle path
      for (final point in pathPoints.whereIndexed(
        (index, p) => index % 10 == 0, // one every 10 points
      )) {
        _markers['${point.latitude}-${point.longitude}'] = Marker(
          markerId: MarkerId('${point.latitude}-${point.longitude}'),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(
            title: "🚗 ${formatDateTime(point.dateTime)}",
            snippet:
                '⚡ Speed: ${point.speed} km/h, 🧭 Heading: ${point.heading}°',
          ),
        );
      }
    });

    // Loop through each point in the path and calculate the total distance traveled
    // by summing the distance between consecutive GPS coordinates.
    for (int i = 1; i < pathPoints.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        pathPoints[i - 1].latitude,
        pathPoints[i - 1].longitude,
        pathPoints[i].latitude,
        pathPoints[i].longitude,
      );
    }

    // Initial point marker (where the vehicle starts)
    final firstPoint = pathPoints.first;
    _markers['initial_point'] = Marker(
      markerId: const MarkerId('initial_point'),
      position: LatLng(firstPoint.latitude, firstPoint.longitude),
      icon: initialPointIcon, // Custom image marker
      infoWindow: InfoWindow(
        title:
            "🚗 Start Point: ${DateFormat('yyyy-MM-dd HH:mm').format(firstPoint.dateTime)}",
        snippet:
            "⚡ Speed: ${firstPoint.speed} km/h / 🧭 Heading: ${firstPoint.heading}°",
      ),
    );

    // Vehicle marker
    // Calculating positon on a path
    double offsetMeters = 72.8;
    double latOffset = offsetMeters / 111320;
    double lngOffset = offsetMeters / (111320 * cos(firstPoint.latitude * pi / 180));

    // Place the vehicle marker at the new offset position
    _markers['vehicle'] = Marker(
      markerId: const MarkerId('vehicle'),
      position: LatLng(
        firstPoint.latitude + latOffset, // move north
        firstPoint.longitude + lngOffset,
      ),
      icon: vehicleIcon,
    );

    // Update state for the info card
    closestStoreName = closestStore?.name ?? "Unknown"; // closet store
    // first close timestamp
    firstCloseTimestamp =
        firstCloseTime != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(firstCloseTime!)
            : "N/A";
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
              width: 320,
              height: 130,
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
                      Text("🚗 Closest Store: $closestStoreName"),
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
