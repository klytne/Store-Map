class PathPoint {
  final DateTime dateTime;
  final double latitude;
  final double longitude;
  final int heading;
  final double speed;

  PathPoint({
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
  });

  factory PathPoint.fromJson(Map<String, dynamic> json) {
    final timeStamp = json['timeStamp'] as int;
    return PathPoint(
      dateTime: DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: json['heading'] as int,
      speed: (json['speed'] as num).toDouble(),
    );
  }
}
