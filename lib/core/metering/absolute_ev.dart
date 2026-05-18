import '../exposure/exposure_math.dart';

/// One native auto-exposure metadata sample for the metered region.
class ExposureSample {
  const ExposureSample({
    required this.exposureSeconds,
    required this.iso,
    required this.apertureF,
    required this.midLuma,
  });

  /// Sensor exposure (integration) time, seconds.
  final double exposureSeconds;

  /// Sensor sensitivity (ISO) the camera chose.
  final double iso;

  /// Lens f-number (phone lenses are fixed; falls back to a sane default
  /// when the platform does not report it).
  final double apertureF;

  /// Linear luminance of the metered region, 0..1 (0.18 == middle grey).
  final double midLuma;
}

/// Converts a camera's own auto-exposure metadata into an absolute scene
/// EV at ISO 100 — no manual calibration required. Derives from the camera
/// exposure equation N^2/t = L·S/K:
///
///   EV100 = log2(N^2/t) − log2(S/100) + log2(Y/0.18) + c
///
/// where Y is the metered region's linear luminance and `c` is an optional
/// per-device residual (default 0; exposed for fine-tuning only).
class AbsoluteEvCalculator {
  const AbsoluteEvCalculator({this.deviceConstant = 0});

  final double deviceConstant;

  static const double _midGrey = 0.18;
  static const double _eps = 1e-6;

  double ev100(ExposureSample s) {
    final t = s.exposureSeconds <= 0 ? _eps : s.exposureSeconds;
    final iso = s.iso <= 0 ? 100.0 : s.iso;
    final n = s.apertureF <= 0 ? 1.8 : s.apertureF;
    final y = s.midLuma.clamp(_eps, 1.0);

    final base = ExposureMath.log2((n * n) / t);
    final isoTerm = ExposureMath.log2(iso / 100.0);
    final lumaTerm = ExposureMath.log2(y / _midGrey);
    return base - isoTerm + lumaTerm + deviceConstant;
  }

  /// Solve the residual so [sample] reads exactly [knownEv100] (optional
  /// one-tap fine calibration against a trusted meter).
  AbsoluteEvCalculator anchorTo(ExposureSample sample, double knownEv100) {
    final raw = AbsoluteEvCalculator().ev100(sample);
    return AbsoluteEvCalculator(deviceConstant: knownEv100 - raw);
  }
}
