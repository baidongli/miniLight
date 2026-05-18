import 'dart:math' as math;

enum StopIncrement { full, half, third }

/// Standard photographic value scales and helpers for snapping a continuous
/// computed value to the nearest real-world setting.
class ExposureScales {
  const ExposureScales._();

  static const List<double> fullApertures = [
    1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11, 16, 22, 32, 45, 64,
  ];

  static const List<double> halfApertures = [
    1.0, 1.2, 1.4, 1.7, 2.0, 2.4, 2.8, 3.3, 4.0, 4.8, 5.6, 6.7,
    8.0, 9.5, 11, 13, 16, 19, 22, 27, 32, 38, 45, 54, 64,
  ];

  static const List<double> thirdApertures = [
    1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5,
    4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10, 11, 13, 14,
    16, 18, 20, 22, 25, 29, 32, 36, 40, 45, 51, 57, 64,
  ];

  /// Shutter times in seconds, slowest -> fastest, full-stop scale.
  static const List<double> fullShutters = [
    60, 30, 15, 8, 4, 2, 1,
    1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60, 1 / 125,
    1 / 250, 1 / 500, 1 / 1000, 1 / 2000, 1 / 4000, 1 / 8000,
  ];

  static const List<double> isoScale = [
    25, 32, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400,
    500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 6400,
  ];

  static List<double> apertures(StopIncrement inc) => switch (inc) {
        StopIncrement.full => fullApertures,
        StopIncrement.half => halfApertures,
        StopIncrement.third => thirdApertures,
      };

  /// Nearest value in [scale] to [value], compared in log2 (stop) space so
  /// that "closeness" matches how exposure is actually perceived.
  static double snap(double value, List<double> scale) {
    if (value.isNaN || value.isInfinite) return scale.first;
    final target = math.log(value) / math.ln2;
    var best = scale.first;
    var bestDelta = double.infinity;
    for (final s in scale) {
      final d = (math.log(s) / math.ln2 - target).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = s;
      }
    }
    return best;
  }

  /// Human label for a shutter time, e.g. `1/125`, `2"`, `30"`.
  static String formatShutter(double seconds) {
    if (seconds >= 1) {
      final r = seconds.roundToDouble();
      final s = (seconds - r).abs() < 0.01
          ? r.toInt().toString()
          : seconds.toStringAsFixed(1);
      return '$s"';
    }
    final denom = (1 / seconds).round();
    return '1/$denom';
  }

  static String formatAperture(double f) {
    if (f >= 10 || f == f.roundToDouble()) return 'f/${f.round()}';
    return 'f/${f.toStringAsFixed(1)}';
  }
}
