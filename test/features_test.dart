import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/exposure/camera_body.dart';
import 'package:minilight/core/exposure/exposure_adjustments.dart';
import 'package:minilight/core/exposure/exposure_solver.dart';
import 'package:minilight/core/exposure/film_stock.dart';
import 'package:minilight/core/log/shot_log.dart';
import 'package:minilight/core/metering/absolute_ev.dart';
import 'package:minilight/core/metering/incident_ev.dart';

void main() {
  group('ExposureAdjustments', () {
    test('push/pull changes effective ISO', () {
      const a = ExposureAdjustments(pushPullStops: 1);
      expect(a.effectiveIso(400), closeTo(800, 1e-6));
      const b = ExposureAdjustments(pushPullStops: -1);
      expect(b.effectiveIso(400), closeTo(200, 1e-6));
    });

    test('net stops sums filter/bellows/comp, excludes push', () {
      const a = ExposureAdjustments(
        filterStops: 2,
        bellowsStops: 1,
        exposureCompensation: 0.5,
        pushPullStops: 3,
      );
      expect(a.netStops, closeTo(3.5, 1e-9));
    });

    test('bellows stops from focal/extension', () {
      // extension 2x focal -> 4x light -> 2 stops.
      expect(
        ExposureAdjustments.bellowsStopsFor(focalLength: 50, extension: 100),
        closeTo(2, 1e-9),
      );
    });

    test('json round-trips', () {
      const a = ExposureAdjustments(
          filterStops: 1.5, bellowsStops: 0.5, exposureCompensation: -1);
      final b = ExposureAdjustments.fromJson(a.toJson());
      expect(b.netStops, closeTo(a.netStops, 1e-9));
    });
  });

  group('ZonePlacement', () {
    test('Zone V is neutral, III is -2, VII is +2', () {
      expect(const ZonePlacement(5).evShift, 0);
      expect(const ZonePlacement(3).evShift, -2);
      expect(const ZonePlacement(7).evShift, 2);
    });
  });

  group('ExposureSolver with adjustments', () {
    test('+1 exposure compensation gives one stop more exposure', () {
      const base = ExposureSolver(
        film: FilmStock(name: 'x', iso: 100),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 8,
        fixedShutterSeconds: 1 / 125,
      );
      const comp = ExposureSolver(
        film: FilmStock(name: 'x', iso: 100),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 8,
        fixedShutterSeconds: 1 / 125,
        adjustments: ExposureAdjustments(exposureCompensation: 1),
      );
      expect(comp.solve(12).shutterSeconds,
          greaterThan(base.solve(12).shutterSeconds));
    });

    test('camera body snaps shutter to its available speeds', () {
      const leica = CameraBody(
        name: 'L',
        shutterSeconds: [1, 1 / 2, 1 / 4, 1 / 8, 1 / 15, 1 / 30, 1 / 60,
          1 / 125, 1 / 250, 1 / 500, 1 / 1000],
      );
      const solver = ExposureSolver(
        film: FilmStock(name: 'x', iso: 100),
        priority: PriorityMode.aperture,
        increment: StopIncrement.full,
        fixedAperture: 16,
        fixedShutterSeconds: 1 / 125,
        body: leica,
      );
      final s = solver.solve(15);
      expect(leica.shutterSeconds.contains(s.shutterSeconds), isTrue);
    });
  });

  group('AbsoluteEvCalculator', () {
    test('Sunny-16 metadata yields ~EV15', () {
      // f/1.8, 1/4000s, ISO 100, mid-grey region.
      const calc = AbsoluteEvCalculator();
      final ev = calc.ev100(const ExposureSample(
        exposureSeconds: 1 / 4000,
        iso: 100,
        apertureF: 1.8,
        midLuma: 0.18,
      ));
      // log2(1.8^2 * 4000) ≈ 13.6 ; brightness in this range.
      expect(ev, closeTo(13.6, 0.3));
    });

    test('one stop brighter region adds ~1 EV', () {
      const calc = AbsoluteEvCalculator();
      final a = calc.ev100(const ExposureSample(
          exposureSeconds: 0.01, iso: 100, apertureF: 2, midLuma: 0.18));
      final b = calc.ev100(const ExposureSample(
          exposureSeconds: 0.01, iso: 100, apertureF: 2, midLuma: 0.36));
      expect(b - a, closeTo(1, 1e-6));
    });

    test('anchorTo makes the sample read the known EV', () {
      const sample = ExposureSample(
          exposureSeconds: 0.02, iso: 200, apertureF: 2.8, midLuma: 0.2);
      final c = const AbsoluteEvCalculator().anchorTo(sample, 12);
      expect(c.ev100(sample), closeTo(12, 1e-6));
    });
  });

  group('IncidentEv', () {
    test('EV rises one stop per doubling of lux', () {
      const i = IncidentEv();
      expect(i.ev100(2000) - i.ev100(1000), closeTo(1, 1e-9));
    });

    test('anchorTo calibrates the constant', () {
      final i = const IncidentEv().anchorTo(8000, 13);
      expect(i.ev100(8000), closeTo(13, 1e-6));
    });
  });

  group('FilmRoll CSV', () {
    test('exports header and rows with escaped notes', () {
      final roll = FilmRoll(
        id: '1',
        name: 'Test',
        filmName: 'HP5',
        iso: 400,
        createdAt: DateTime(2024, 1, 1),
      )..shots.add(ShotEntry(
          frame: 1,
          timestamp: DateTime(2024, 1, 1, 12),
          ev100: 12.3,
          aperture: 8,
          shutterSeconds: 1 / 125,
          iso: 400,
          note: 'a, "b"',
        ));
      final csv = roll.toCsv();
      expect(csv, contains('frame,timestamp,ev100'));
      expect(csv, contains('"a, ""b"""'));
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
    });

    test('nextFrame increments past the max frame', () {
      final roll = FilmRoll(
        id: '1',
        name: 'r',
        filmName: 'f',
        iso: 100,
        createdAt: DateTime(2024),
      );
      expect(roll.nextFrame, 1);
      roll.shots.add(ShotEntry(
          frame: 5,
          timestamp: DateTime(2024),
          ev100: 1,
          aperture: 1,
          shutterSeconds: 1,
          iso: 1));
      expect(roll.nextFrame, 6);
    });
  });

  group('FilmStock json', () {
    test('custom film round-trips', () {
      const f = FilmStock(
          name: 'My', iso: 250, reciprocityPower: 1.4, custom: true);
      final b = FilmStock.fromJson(f.toJson());
      expect(b.name, 'My');
      expect(b.iso, 250);
      expect(b.reciprocityPower, 1.4);
      expect(b.custom, isTrue);
    });
  });
}
