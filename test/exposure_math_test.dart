import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/exposure/exposure_math.dart';

void main() {
  group('ExposureMath', () {
    test('evAtIso shifts one stop per ISO doubling', () {
      expect(ExposureMath.evAtIso(10, 100), closeTo(10, 1e-9));
      expect(ExposureMath.evAtIso(10, 200), closeTo(11, 1e-9));
      expect(ExposureMath.evAtIso(10, 400), closeTo(12, 1e-9));
      expect(ExposureMath.evAtIso(10, 50), closeTo(9, 1e-9));
    });

    test('evToIso100 inverts evAtIso', () {
      const ev = 12.3;
      for (final iso in [25.0, 100.0, 400.0, 3200.0]) {
        final at = ExposureMath.evAtIso(ev, iso);
        expect(ExposureMath.evToIso100(at, iso), closeTo(ev, 1e-9));
      }
    });

    test('Sunny-16: EV15, f/16 -> ~1/125 at ISO 100', () {
      final t = ExposureMath.shutterForAperture(15, 16);
      expect(1 / t, closeTo(128, 1)); // 16^2 / 2^15 = 1/128
    });

    test('apertureForShutter is inverse of shutterForAperture', () {
      const ev = 13.0;
      final t = ExposureMath.shutterForAperture(ev, 5.6);
      expect(ExposureMath.apertureForShutter(ev, t), closeTo(5.6, 1e-9));
    });

    test('evFromTriangle round-trips Sunny-16', () {
      final ev = ExposureMath.evFromTriangle(
        aperture: 16,
        shutterSeconds: 1 / 128,
        iso: 100,
      );
      expect(ev, closeTo(15, 1e-9));
    });

    test('evFromTriangle accounts for ISO', () {
      final ev = ExposureMath.evFromTriangle(
        aperture: 16,
        shutterSeconds: 1 / 256,
        iso: 200,
      );
      expect(ev, closeTo(15, 1e-9));
    });
  });
}
