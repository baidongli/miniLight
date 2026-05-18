import 'dart:math' as math;

/// Pure exposure math. No Flutter / platform dependencies so it is unit
/// testable and reusable across iOS and Android.
///
/// Convention: an `ev100` value is the Exposure Value of a scene referenced
/// to ISO 100. The camera exposure equation used throughout is
///
///   N^2 / t = 2^EV
///
/// where `N` is the aperture f-number, `t` the shutter time in seconds, and
/// `EV` is the exposure value already adjusted for the working ISO.
class ExposureMath {
  const ExposureMath._();

  static double log2(double x) => math.log(x) / math.ln2;

  /// 2^[stops]; converts a stop offset to a linear light ratio.
  static double evToLinear(double stops) => math.pow(2, stops).toDouble();

  /// Scene EV referenced to ISO 100, expressed at an arbitrary working [iso].
  static double evAtIso(double ev100, double iso) =>
      ev100 + log2(iso / 100.0);

  /// Inverse of [evAtIso]: bring an EV measured at [iso] back to ISO 100.
  static double evToIso100(double evAtIso, double iso) =>
      evAtIso - log2(iso / 100.0);

  /// Shutter time (seconds) required for a given [aperture] at [evAtIso].
  static double shutterForAperture(double evAtIso, double aperture) =>
      (aperture * aperture) / math.pow(2, evAtIso);

  /// Aperture f-number required for a given [shutterSeconds] at [evAtIso].
  static double apertureForShutter(double evAtIso, double shutterSeconds) =>
      math.sqrt(shutterSeconds * math.pow(2, evAtIso));

  /// EV implied by a full aperture + shutter + iso combination.
  static double evFromTriangle({
    required double aperture,
    required double shutterSeconds,
    required double iso,
  }) {
    final evWorking = log2((aperture * aperture) / shutterSeconds);
    return evToIso100(evWorking, iso);
  }
}
