/// A single recorded exposure within a roll.
class ShotEntry {
  ShotEntry({
    required this.frame,
    required this.timestamp,
    required this.ev100,
    required this.aperture,
    required this.shutterSeconds,
    required this.iso,
    this.note = '',
    this.latitude,
    this.longitude,
  });

  final int frame;
  final DateTime timestamp;
  final double ev100;
  final double aperture;
  final double shutterSeconds;
  final double iso;
  final String note;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
        'frame': frame,
        'timestamp': timestamp.toIso8601String(),
        'ev100': ev100,
        'aperture': aperture,
        'shutterSeconds': shutterSeconds,
        'iso': iso,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory ShotEntry.fromJson(Map<String, dynamic> j) => ShotEntry(
        frame: j['frame'] as int,
        timestamp: DateTime.parse(j['timestamp'] as String),
        ev100: (j['ev100'] as num).toDouble(),
        aperture: (j['aperture'] as num).toDouble(),
        shutterSeconds: (j['shutterSeconds'] as num).toDouble(),
        iso: (j['iso'] as num).toDouble(),
        note: j['note'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );
}

/// A roll of film: a named, ISO-rated sequence of [ShotEntry]s.
class FilmRoll {
  FilmRoll({
    required this.id,
    required this.name,
    required this.filmName,
    required this.iso,
    required this.createdAt,
    List<ShotEntry>? shots,
  }) : shots = shots ?? [];

  final String id;
  String name;
  final String filmName;
  final double iso;
  final DateTime createdAt;
  final List<ShotEntry> shots;

  int get nextFrame => shots.isEmpty
      ? 1
      : shots.map((s) => s.frame).reduce((a, b) => a > b ? a : b) + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filmName': filmName,
        'iso': iso,
        'createdAt': createdAt.toIso8601String(),
        'shots': shots.map((s) => s.toJson()).toList(),
      };

  factory FilmRoll.fromJson(Map<String, dynamic> j) => FilmRoll(
        id: j['id'] as String,
        name: j['name'] as String,
        filmName: j['filmName'] as String? ?? '',
        iso: (j['iso'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        shots: ((j['shots'] as List?) ?? const [])
            .map((e) => ShotEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Export this roll as CSV (one header row + one row per frame).
  String toCsv() {
    String esc(String s) =>
        s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    final b = StringBuffer()
      ..writeln('frame,timestamp,ev100,aperture,shutter_seconds,iso,'
          'latitude,longitude,note');
    for (final s in shots) {
      b.writeln([
        s.frame,
        s.timestamp.toIso8601String(),
        s.ev100.toStringAsFixed(2),
        s.aperture.toStringAsFixed(2),
        s.shutterSeconds.toStringAsExponential(4),
        s.iso.toStringAsFixed(0),
        s.latitude?.toStringAsFixed(6) ?? '',
        s.longitude?.toStringAsFixed(6) ?? '',
        esc(s.note),
      ].join(','));
    }
    return b.toString();
  }
}
