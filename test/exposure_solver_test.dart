import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/exposure/exposure_scales.dart';
import 'package:minilight/core/exposure/exposure_solver.dart';
import 'package:minilight/core/exposure/film_stock.dart';

void main() {
  group('ExposureSolver', () {
    test('aperture priority solves a sane shutter for Sunny-16', () {
      const solver = ExposureSolver(
        film: FilmStock(name: 'ISO100', iso: 100),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 16,
        fixedShutterSeconds: 1 / 125,
      );
      final s = solver.solve(15);
      expect(s.aperture, 16);
      expect(1 / s.shutterSeconds, closeTo(125, 1)); // ~1/125
      expect(s.iso, 100);
    });

    test('shutter priority solves a sane aperture', () {
      const solver = ExposureSolver(
        film: FilmStock(name: 'ISO100', iso: 100),
        priority: PriorityMode.shutter,
        increment: StopIncrement.full,
        fixedAperture: 8,
        fixedShutterSeconds: 1 / 125,
      );
      final s = solver.solve(15);
      expect(1 / s.shutterSeconds, closeTo(125, 1));
      expect(s.aperture, closeTo(16, 0.001));
    });

    test('faster film needs less light: smaller aperture or faster shutter',
        () {
      const slow = ExposureSolver(
        film: FilmStock(name: 'ISO100', iso: 100),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 8,
        fixedShutterSeconds: 1 / 125,
      );
      const fast = ExposureSolver(
        film: FilmStock(name: 'ISO400', iso: 400),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 8,
        fixedShutterSeconds: 1 / 125,
      );
      expect(fast.solve(12).shutterSeconds,
          lessThan(slow.solve(12).shutterSeconds));
    });

    test('reciprocity correction lengthens long exposures', () {
      const solver = ExposureSolver(
        film: FilmStock(
            name: 'TriX', iso: 400, reciprocityPower: 1.33),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 22,
        fixedShutterSeconds: 1,
      );
      final s = solver.solve(3); // dim scene -> long shutter
      expect(s.shutterSeconds, greaterThan(1));
      expect(s.reciprocityApplied, isTrue);
      expect(s.shutterAfterReciprocity, greaterThan(s.shutterSeconds));
    });
  });
}
