import 'dart:math' as math;

/// Maps a measured mean luma (0..255, camera exposure locked) to a scene
/// EV referenced to ISO 100 using a linear model in stop space:
///
///   ev100 = slope * log2(lumaNorm) + intercept
///
/// The camera plugin does not expose per-frame exposure metadata (shutter /
/// ISO / aperture) on either platform, so absolute EV cannot be derived from
/// a single auto-exposed frame. Instead the camera is exposure-locked and a
/// one- or two-point calibration anchors the model to a trusted reference
/// (a known meter, or the Sunny-16 rule). This is the same pragmatic
/// approach free light-meter apps use.
class CalibrationModel {
  const CalibrationModel({this.slope = 1.0, this.intercept = 14.0});

  final double slope;
  final double intercept;

  static const double _eps = 1.0 / 255.0;

  double _lumaNorm(double meanLuma) =>
      (meanLuma / 255.0).clamp(_eps, 1.0).toDouble();

  double ev100(double meanLuma) =>
      slope * (math.log(_lumaNorm(meanLuma)) / math.ln2) + intercept;

  /// Single-point calibration: keep [slope], shift [intercept] so that
  /// [meanLuma] reads exactly [knownEv100].
  CalibrationModel anchorTo(double meanLuma, double knownEv100) {
    final logL = math.log(_lumaNorm(meanLuma)) / math.ln2;
    return CalibrationModel(slope: slope, intercept: knownEv100 - slope * logL);
  }

  /// Two-point calibration: fit both [slope] and [intercept] from two
  /// reference samples. Falls back to single-point if the samples are too
  /// close to separate the slope reliably.
  static CalibrationModel fromTwoPoints({
    required double lumaA,
    required double ev100A,
    required double lumaB,
    required double ev100B,
  }) {
    final la = math.log((lumaA / 255.0).clamp(_eps, 1.0)) / math.ln2;
    final lb = math.log((lumaB / 255.0).clamp(_eps, 1.0)) / math.ln2;
    if ((la - lb).abs() < 0.5) {
      return const CalibrationModel().anchorTo(lumaA, ev100A);
    }
    final slope = (ev100A - ev100B) / (la - lb);
    final intercept = ev100A - slope * la;
    return CalibrationModel(slope: slope, intercept: intercept);
  }

  Map<String, double> toJson() => {'slope': slope, 'intercept': intercept};

  factory CalibrationModel.fromJson(Map<String, dynamic> j) => CalibrationModel(
        slope: (j['slope'] as num?)?.toDouble() ?? 1.0,
        intercept: (j['intercept'] as num?)?.toDouble() ?? 14.0,
      );
}
