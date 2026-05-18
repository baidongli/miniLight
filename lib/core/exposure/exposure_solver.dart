import 'camera_body.dart';
import 'exposure_adjustments.dart';
import 'exposure_math.dart';
import 'exposure_scales.dart';
import 'film_stock.dart';

enum PriorityMode { aperture, shutter }

class ExposureSolution {
  const ExposureSolution({
    required this.ev100,
    required this.workingEv,
    required this.effectiveIso,
    required this.aperture,
    required this.shutterSeconds,
    required this.shutterAfterReciprocity,
    required this.iso,
  });

  /// Metered scene EV at ISO 100 (before any adjustments).
  final double ev100;

  /// EV actually solved against, after zone + compensations + push/pull.
  final double workingEv;

  /// Exposure index after push/pull.
  final double effectiveIso;

  final double aperture;
  final double shutterSeconds;
  final double shutterAfterReciprocity;

  /// The film's box speed.
  final double iso;

  bool get reciprocityApplied =>
      (shutterAfterReciprocity - shutterSeconds).abs() > 1e-6;
}

/// Combines the metered scene EV with the film, camera body, Zone System
/// placement and all exposure compensations into a snapped, real-world
/// recommendation.
class ExposureSolver {
  const ExposureSolver({
    required this.film,
    required this.priority,
    required this.increment,
    required this.fixedAperture,
    required this.fixedShutterSeconds,
    this.body = CameraBody.generic,
    this.adjustments = const ExposureAdjustments(),
    this.zone = ZonePlacement.zoneV,
  });

  final FilmStock film;
  final PriorityMode priority;
  final StopIncrement increment;
  final double fixedAperture;
  final double fixedShutterSeconds;
  final CameraBody body;
  final ExposureAdjustments adjustments;
  final ZonePlacement zone;

  ExposureSolution solve(double ev100) {
    final ei = adjustments.effectiveIso(film.iso);
    final evAtEi = ExposureMath.evAtIso(ev100, ei);
    // More light needed (filters/bellows/+comp) lowers the working EV;
    // placing the reading on a brighter zone also opens up.
    final workingEv = evAtEi - adjustments.netStops - zone.evShift;

    double aperture;
    double shutter;
    if (priority == PriorityMode.aperture) {
      aperture = body.clampAperture(
        ExposureScales.snap(
          fixedAperture,
          ExposureScales.apertures(increment),
        ),
      );
      shutter = body.snapShutter(
        ExposureMath.shutterForAperture(workingEv, aperture),
      );
    } else {
      shutter = body.snapShutter(fixedShutterSeconds);
      final rawAperture =
          ExposureMath.apertureForShutter(workingEv, shutter);
      aperture = body.clampAperture(
        ExposureScales.snap(rawAperture, ExposureScales.apertures(increment)),
      );
    }

    return ExposureSolution(
      ev100: ev100,
      workingEv: workingEv,
      effectiveIso: ei,
      aperture: aperture,
      shutterSeconds: shutter,
      shutterAfterReciprocity: film.correctReciprocity(shutter),
      iso: film.iso,
    );
  }

  /// Average several spot EV readings (multi-spot metering / placing the
  /// average on Zone V).
  static double averageEv(Iterable<double> readings) {
    final list = readings.toList();
    if (list.isEmpty) return double.nan;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
