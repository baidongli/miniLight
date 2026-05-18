import 'dart:math' as math;

/// A film stock preset. [reciprocityPower] models reciprocity failure for
/// long exposures using the common power law
///
///   t_corrected = t_metered ^ p   (applied only when t_metered > [threshold])
///
/// p = 1.0 means no correction. Values here are practical approximations
/// distilled from manufacturer datasheets; treat them as a starting point.
class FilmStock {
  const FilmStock({
    required this.name,
    required this.iso,
    this.reciprocityPower = 1.0,
    this.reciprocityThreshold = 1.0,
  });

  final String name;
  final double iso;
  final double reciprocityPower;
  final double reciprocityThreshold;

  /// Metered shutter time corrected for this film's reciprocity behaviour.
  double correctReciprocity(double meteredSeconds) {
    if (reciprocityPower == 1.0 || meteredSeconds <= reciprocityThreshold) {
      return meteredSeconds;
    }
    return math.pow(meteredSeconds, reciprocityPower).toDouble();
  }

  static const List<FilmStock> presets = [
    FilmStock(name: 'Generic (no reciprocity)', iso: 100),
    FilmStock(name: 'Kodak Portra 160', iso: 160, reciprocityPower: 1.0),
    FilmStock(name: 'Kodak Portra 400', iso: 400, reciprocityPower: 1.0),
    FilmStock(name: 'Kodak Gold 200', iso: 200, reciprocityPower: 1.1),
    FilmStock(name: 'Kodak Tri-X 400', iso: 400, reciprocityPower: 1.33),
    FilmStock(name: 'Kodak T-Max 100', iso: 100, reciprocityPower: 1.16),
    FilmStock(name: 'Ilford HP5 Plus 400', iso: 400, reciprocityPower: 1.31),
    FilmStock(name: 'Ilford FP4 Plus 125', iso: 125, reciprocityPower: 1.26),
    FilmStock(name: 'Fujifilm Velvia 50', iso: 50, reciprocityPower: 1.2),
    FilmStock(name: 'CineStill 800T', iso: 800, reciprocityPower: 1.0),
  ];
}
