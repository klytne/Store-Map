import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
// import 'dart:convert';
import 'package:csv/csv.dart';
import 'src/store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Map<String, Marker> _markers = {};

  Future<List<Store>> loadStores() async {
    final rawCsv = await rootBundle.loadString('assets/storesCopy.csv');
    List<List<dynamic>> csvTable = const CsvToListConverter(
      fieldDelimiter: ';', // Use semicolon as delimiter
    ).convert(rawCsv);

    // If there's whitespace around your data, you might want to trim it.
  List<Store> stores = csvTable.skip(1).map((row) {
    return Store(
      name: row[0].toString().trim(),
      latitude: double.parse(row[1].toString().trim()),
      longitude: double.parse(row[2].toString().trim()),
    );
  }).toList();

    return stores;
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    final stores = await loadStores();

    setState(() {
      _markers.clear();
      for (final store in stores) {
        final marker = Marker(
          markerId: MarkerId(store.name),
          position: LatLng(store.latitude, store.longitude),
          infoWindow: InfoWindow(
            title: store.name,
          ),
        );
        _markers[store.name] = marker;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Store Locations'),
        ),
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
