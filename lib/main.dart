import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // Added this for asset loading

void main() => runApp(MaterialApp(home: VehicleMap()));

class VehicleMap extends StatefulWidget {
  const VehicleMap({super.key});

  @override
  VehicleMapState createState() => VehicleMapState();
}

class VehicleMapState extends State<VehicleMap> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<LatLng> routeCoordinates = [];
  List<LatLng> pathPoints = [];
  List<Marker> storeMarkers = [];

  LatLng vehiclePosition = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _loadMapData();
    Timer.periodic(Duration(seconds: 1), (timer) {
      _moveVehicle();
    });
  }

  // Load path and store data
  Future<void> _loadMapData() async {
    try {
      final pathData = await _loadPathData();
      final storeData = await _loadStoreData();

      if (pathData.isNotEmpty) {
        setState(() {
          pathPoints = pathData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();
          storeMarkers = storeData.map((store) => Marker(
            markerId: MarkerId(store['name']),
            position: LatLng(store['lat'], store['lng']),
            infoWindow: InfoWindow(title: store['name']),
          )).toList();
          routeCoordinates = pathPoints; // Update route with the new path data
        });

        _addPolyline();  // Call this after loading data
      }
    // ignore: empty_catches
    } catch (e) {
    }
  }

  // Load the PathTravelled.json file from assets
  Future<List<Map<String, dynamic>>> _loadPathData() async {
    final String response = await rootBundle.loadString('assets/PathTravelled.json');
    return List<Map<String, dynamic>>.from(json.decode(response));
  }

  // Load the storesCopy.csv file from assets
  Future<List<Map<String, dynamic>>> _loadStoreData() async {
    final String response = await rootBundle.loadString('assets/storesCopy.csv');
    return response
        .split('\n')
        .skip(1)
        .map((line) {
          final parts = line.split(',');
          return {'name': parts[0], 'lat': double.parse(parts[1]), 'lng': double.parse(parts[2])};
        })
        .toList();
  }

  // Add a polyline to the map
  void _addPolyline() {
    final Polyline polyline = Polyline(
      polylineId: PolylineId('vehicle_route'),
      points: routeCoordinates,
      color: Colors.blue,
      width: 5,
    );

    setState(() {
      _polylines.add(polyline);
    });
  }

  // Move vehicle along the route
  void _moveVehicle() {
    setState(() {
      if (routeCoordinates.isNotEmpty) {
        vehiclePosition = routeCoordinates.removeAt(0);
        _markers.add(
          Marker(
            markerId: MarkerId('vehicle'),
            position: vehiclePosition,
            icon: BitmapDescriptor.defaultMarker,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle Path Visualizer'),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: routeCoordinates.isNotEmpty ? routeCoordinates[0] : LatLng(37.7749, -122.4194),
          zoom: 13,
        ),
        markers: Set<Marker>.of(storeMarkers),
        polylines: _polylines,
      ),
    );
  }
}
