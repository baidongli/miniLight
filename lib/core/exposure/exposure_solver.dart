import 'exposure_math.dart';
import 'exposure_scales.dart';
import 'film_stock.dart';

enum PriorityMode { aperture, shutter }

class ExposureSolution {
  const ExposureSolution({
    required this.ev100,
    required this.evAtIso,
    required this.aperture,
    required this.shutterSeconds,
    required this.shutterAfterReciprocity,
    required this.iso,
  });

  final double ev100;
  final double evAtIso;
  final double aperture;
  final double shutterSeconds;

  /// Shutter time after applying the film's reciprocity correction. Equal to
  /// [shutterSeconds] when no correction applies.
  final double shutterAfterReciprocity;
  final double iso;

  bool get reciprocityApplied =>
      (shutterAfterReciprocity - shutterSeconds).abs() > 1e-6;
}

/// Combines the metered scene EV with a film stock and a user-selected
/// priority to produce a snapped, real-world exposure recommendation.
class ExposureSolver {
  const ExposureSolver({
    required this.film,
    required this.priority,
    required this.increment,
    required this.fixedAperture,
    required this.fixedShutterSeconds,
  });

  final FilmStock film;
  final PriorityMode priority;
  final StopIncrement increment;
  final double fixedAperture;
  final double fixedShutterSeconds;

  ExposureSolution solve(double ev100) {
    final evIso = ExposureMath.evAtIso(ev100, film.iso);

    double aperture;
    double shutter;
    if (priority == PriorityMode.aperture) {
      aperture = ExposureScales.snap(
        fixedAperture,
        ExposureScales.apertures(increment),
      );
      final raw = ExposureMath.shutterForAperture(evIso, aperture);
      shutter = ExposureScales.snap(raw, ExposureScales.fullShutters);
    } else {
      shutter = ExposureScales.snap(
        fixedShutterSeconds,
        ExposureScales.fullShutters,
      );
      final raw = ExposureMath.apertureForShutter(evIso, shutter);
      aperture = ExposureScales.snap(
        raw,
        ExposureScales.apertures(increment),
      );
    }

    return ExposureSolution(
      ev100: ev100,
      evAtIso: evIso,
      aperture: aperture,
      shutterSeconds: shutter,
      shutterAfterReciprocity: film.correctReciprocity(shutter),
      iso: film.iso,
    );
  }
}
