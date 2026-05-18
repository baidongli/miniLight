import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/exposure/exposure_scales.dart';

void main() {
  group('ExposureScales.snap', () {
    test('snaps aperture to nearest full stop in stop space', () {
      expect(
        ExposureScales.snap(5.0, ExposureScales.fullApertures),
        anyOf(4.0, 5.6),
      );
      expect(ExposureScales.snap(7.9, ExposureScales.fullApertures), 8.0);
      expect(ExposureScales.snap(1.0, ExposureScales.fullApertures), 1.0);
    });

    test('snaps shutter to nearest standard speed', () {
      expect(
        ExposureScales.snap(1 / 130, ExposureScales.fullShutters),
        closeTo(1 / 125, 1e-9),
      );
      expect(
        ExposureScales.snap(0.9, ExposureScales.fullShutters),
        closeTo(1, 1e-9),
      );
    });

    test('handles NaN / infinity by returning first scale entry', () {
      expect(ExposureScales.snap(double.nan, ExposureScales.fullApertures),
          ExposureScales.fullApertures.first);
      expect(
          ExposureScales.snap(double.infinity, ExposureScales.fullShutters),
          ExposureScales.fullShutters.first);
    });
  });

  group('formatting', () {
    test('formatShutter fast speeds', () {
      expect(ExposureScales.formatShutter(1 / 125), '1/125');
      expect(ExposureScales.formatShutter(1 / 8000), '1/8000');
    });

    test('formatShutter slow speeds', () {
      expect(ExposureScales.formatShutter(2), '2"');
      expect(ExposureScales.formatShutter(30), '30"');
    });

    test('formatAperture', () {
      expect(ExposureScales.formatAperture(1.4), 'f/1.4');
      expect(ExposureScales.formatAperture(8), 'f/8');
      expect(ExposureScales.formatAperture(16), 'f/16');
    });
  });
}
