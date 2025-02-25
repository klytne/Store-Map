import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'path_point.dart';

Future<List<PathPoint>> loadPathPoints() async {
  final jsonString = await rootBundle.loadString('assets/PathTravelled.json');
  final List<dynamic> data = json.decode(jsonString);
  return data.map((json) => PathPoint.fromJson(json)).toList();
}