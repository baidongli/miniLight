import 'exposure_math.dart';

/// All exposure compensations applied on top of the metered scene EV,
/// expressed in stops. Positive [netStops] means the scene needs MORE light
/// (open up / slow down), i.e. the working EV is reduced by that many stops.
class ExposureAdjustments {
  const ExposureAdjustments({
    this.pushPullStops = 0,
    this.filterStops = 0,
    this.bellowsStops = 0,
    this.exposureCompensation = 0,
  });

  /// Push (+) / pull (-) processing. Changes the film's effective speed:
  /// rating ISO 400 film at EI 800 is +1 push.
  final double pushPullStops;

  /// Light lost to filters (ND, polarizer, contrast filters). Always >= 0.
  final double filterStops;

  /// Bellows / close-up extension light loss. Always >= 0.
  final double bellowsStops;

  /// Free exposure compensation dial (EV). Positive = more exposure.
  final double exposureCompensation;

  /// Net extra light needed beyond the meter reading, in stops. Push/pull
  /// is NOT included here: it is applied as an effective-ISO change via
  /// [effectiveIso] so it is not double-counted.
  double get netStops =>
      filterStops + bellowsStops + exposureCompensation;

  /// Effective ISO after push/pull (the exposure index actually used).
  double effectiveIso(double filmIso) =>
      filmIso * ExposureMath.evToLinear(pushPullStops);

  ExposureAdjustments copyWith({
    double? pushPullStops,
    double? filterStops,
    double? bellowsStops,
    double? exposureCompensation,
  }) =>
      ExposureAdjustments(
        pushPullStops: pushPullStops ?? this.pushPullStops,
        filterStops: filterStops ?? this.filterStops,
        bellowsStops: bellowsStops ?? this.bellowsStops,
        exposureCompensation:
            exposureCompensation ?? this.exposureCompensation,
      );

  Map<String, dynamic> toJson() => {
        'pushPullStops': pushPullStops,
        'filterStops': filterStops,
        'bellowsStops': bellowsStops,
        'exposureCompensation': exposureCompensation,
      };

  factory ExposureAdjustments.fromJson(Map<String, dynamic> j) =>
      ExposureAdjustments(
        pushPullStops: (j['pushPullStops'] as num?)?.toDouble() ?? 0,
        filterStops: (j['filterStops'] as num?)?.toDouble() ?? 0,
        bellowsStops: (j['bellowsStops'] as num?)?.toDouble() ?? 0,
        exposureCompensation:
            (j['exposureCompensation'] as num?)?.toDouble() ?? 0,
      );

  /// Bellows extension light loss in stops from focal length and the
  /// actual lens-to-film distance (same units). Macro work needs this.
  static double bellowsStopsFor({
    required double focalLength,
    required double extension,
  }) {
    if (focalLength <= 0 || extension <= 0) return 0;
    final factor = (extension * extension) / (focalLength * focalLength);
    return ExposureMath.log2(factor);
  }
}

/// Ansel Adams Zone System. A spot reading is rendered as middle grey
/// (Zone V) by the meter; placing it on another zone shifts the exposure
/// so that tone falls where the photographer wants it.
class ZonePlacement {
  const ZonePlacement(this.zone);

  /// 0..10. Zone V is the meter's neutral reference.
  final int zone;

  static const ZonePlacement zoneV = ZonePlacement(5);

  /// Stops to add to the metered EV. Placing a reading on a darker zone
  /// (e.g. III) means less exposure than metering it as grey.
  double get evShift => (zone - 5).toDouble();

  ZonePlacement clamp() => ZonePlacement(zone.clamp(0, 10));
}
