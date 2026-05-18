import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/metering/calibration.dart';

void main() {
  group('CalibrationModel', () {
    test('brighter scene yields higher EV', () {
      const m = CalibrationModel();
      expect(m.ev100(200), greaterThan(m.ev100(50)));
    });

    test('anchorTo makes the anchored luma read the known EV', () {
      const m = CalibrationModel();
      final c = m.anchorTo(120, 15);
      expect(c.ev100(120), closeTo(15, 1e-6));
      expect(c.slope, m.slope);
    });

    test('one stop of luma is one EV with default slope', () {
      const m = CalibrationModel();
      expect(m.ev100(200) - m.ev100(100), closeTo(1, 1e-9));
    });

    test('fromTwoPoints fits slope and intercept', () {
      final c = CalibrationModel.fromTwoPoints(
        lumaA: 200,
        ev100A: 15,
        lumaB: 50,
        ev100B: 13,
      );
      expect(c.ev100(200), closeTo(15, 1e-6));
      expect(c.ev100(50), closeTo(13, 1e-6));
    });

    test('fromTwoPoints falls back to single point when too close', () {
      final c = CalibrationModel.fromTwoPoints(
        lumaA: 120,
        ev100A: 14,
        lumaB: 121,
        ev100B: 9,
      );
      expect(c.ev100(120), closeTo(14, 1e-6));
    });

    test('json round-trips', () {
      const c = CalibrationModel(slope: 1.3, intercept: 12.5);
      final back = CalibrationModel.fromJson(c.toJson());
      expect(back.slope, 1.3);
      expect(back.intercept, 12.5);
    });
  });
}
