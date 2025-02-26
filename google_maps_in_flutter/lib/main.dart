import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'data_loader.dart'; // Ensure your JSON data loader is correct

void main() => runApp(MaterialApp(home: VehicleMap()));

class VehicleMap extends StatefulWidget {
  const VehicleMap({super.key});

  @override
  // ignore: library_private_types_in_public_api
  // ignore: library_private_types_in_public_api
  _VehicleMapState createState() => _VehicleMapState();
}

class _VehicleMapState extends State<VehicleMap> {
  GoogleMapController? mapController;
  // ignore: prefer_final_fields
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> routeCoordinates = [];
  List<LatLng> pathPoints = [];
  List<Marker> storeMarkers = [];
  int _currentPositionIndex = 0;
  LatLng _initialPosition = LatLng(-30.5595, 22.9375); // Default: South Africa

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  // Load path and store data
  void _loadMapData() async {
    try {
      final pathData = await loadPathData(); // Ensure JSON is formatted correctly
      final storeData = await loadStoreData();

      print("Path Data Loaded: ${pathData.length} points");
      print("Store Data Loaded: ${storeData.length} stores");

      setState(() {
        pathPoints = pathData.map((p) => LatLng(p['latitude'], p['longitude'])).toList();
        storeMarkers = storeData.map((store) => Marker(
          markerId: MarkerId(store['name']),
          position: LatLng(store['lat'], store['lng']),
          infoWindow: InfoWindow(title: store['name']),
        )).toList();
        routeCoordinates = pathPoints;

        // Update initial position to first path point if available
        if (pathPoints.isNotEmpty) {
          _initialPosition = pathPoints.first;
        }
      });

      _addPolyline();
      _initializeVehicle();
    } catch (e) {
      print("Error loading map data: $e");
    }
  }

  // Add polyline to map
  void _addPolyline() {
    if (routeCoordinates.isEmpty) {
      print("No route coordinates available to add polyline.");
      return;
    }

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

  // Initialize vehicle movement
  void _initializeVehicle() {
    if (routeCoordinates.isNotEmpty) {
      setState(() {
        _markers.add(Marker(
          markerId: MarkerId('vehicle'),
          position: routeCoordinates.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      });

      Timer.periodic(Duration(seconds: 2), (timer) {
        _moveVehicle();
      });
    }
  }

  // Move vehicle along the route
  void _moveVehicle() {
    if (_currentPositionIndex < routeCoordinates.length - 1) {
      setState(() {
        _currentPositionIndex++;
        LatLng newPosition = routeCoordinates[_currentPositionIndex];

        // Update vehicle marker position
        _markers.removeWhere((m) => m.markerId.value == 'vehicle');
        _markers.add(Marker(
          markerId: MarkerId('vehicle'),
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));

        // Move camera to new vehicle position
        mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vehicle Path Visualizer')),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
          if (routeCoordinates.isNotEmpty) {
            mapController.animateCamera(
              CameraUpdate.newLatLngZoom(_initialPosition, 12),
            );
          }
        },
        initialCameraPosition: CameraPosition(
          target: _initialPosition, // South Africa or first path point
          zoom: 12,
        ),
        markers: {...storeMarkers, ..._markers},
        polylines: _polylines,
      ),
    );
  }
}
