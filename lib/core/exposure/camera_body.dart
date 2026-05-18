import 'exposure_scales.dart';

/// A film camera body with the exact shutter speeds and apertures it can
/// actually set, so recommendations snap to dials that exist on the camera
/// (e.g. a Leica M has no 1/3-stop speeds; a Hasselblad tops out at 1/500).
class CameraBody {
  const CameraBody({
    required this.name,
    required this.shutterSeconds,
    this.minAperture,
    this.maxAperture,
  });

  final String name;

  /// Available shutter times in seconds. Empty = use the generic scale.
  final List<double> shutterSeconds;

  /// Optional aperture clamp (the mounted lens range).
  final double? minAperture;
  final double? maxAperture;

  bool get isGeneric => shutterSeconds.isEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'shutterSeconds': shutterSeconds,
        'minAperture': minAperture,
        'maxAperture': maxAperture,
      };

  factory CameraBody.fromJson(Map<String, dynamic> j) => CameraBody(
        name: j['name'] as String,
        shutterSeconds: ((j['shutterSeconds'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        minAperture: (j['minAperture'] as num?)?.toDouble(),
        maxAperture: (j['maxAperture'] as num?)?.toDouble(),
      );

  static const generic = CameraBody(name: 'Generic', shutterSeconds: []);

  static const List<CameraBody> presets = [
    generic,
    CameraBody(
      name: 'Leica M (mechanical)',
      shutterSeconds: [1, 1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60,
        1 / 125, 1 / 250, 1 / 500, 1 / 1000],
    ),
    CameraBody(
      name: 'Hasselblad 500 C/M',
      shutterSeconds: [1, 1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60,
        1 / 125, 1 / 250, 1 / 500],
    ),
    CameraBody(
      name: 'Nikon FM2',
      shutterSeconds: [1, 1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60,
        1 / 125, 1 / 250, 1 / 500, 1 / 1000, 1 / 2000, 1 / 4000],
    ),
    CameraBody(
      name: 'Pentax K1000',
      shutterSeconds: [1, 1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60,
        1 / 125, 1 / 250, 1 / 500, 1 / 1000],
    ),
  ];

  double snapShutter(double seconds) => isGeneric
      ? ExposureScales.snap(seconds, ExposureScales.fullShutters)
      : ExposureScales.snap(seconds, shutterSeconds);

  double clampAperture(double f) {
    var v = f;
    if (minAperture != null && v < minAperture!) v = minAperture!;
    if (maxAperture != null && v > maxAperture!) v = maxAperture!;
    return v;
  }
}
