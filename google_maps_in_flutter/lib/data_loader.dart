import 'dart:convert';
import 'package:flutter/services.dart';

Future<List<Map<String, dynamic>>> loadPathData() async {
  final String response = await rootBundle.loadString('assets/PathTravelled.json');
  return List<Map<String, dynamic>>.from(json.decode(response));
}

Future<List<Map<String, dynamic>>> loadStoreData() async {
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
