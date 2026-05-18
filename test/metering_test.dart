import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/metering/metering.dart';

void main() {
  group('LuminanceSampler.meanLuma', () {
    test('uniform plane returns its value for all modes', () {
      final plane = Uint8List(64 * 64)..fillRange(0, 64 * 64, 120);
      for (final mode in MeteringMode.values) {
        expect(
          LuminanceSampler.meanLuma(
            yPlane: plane,
            width: 64,
            height: 64,
            rowStride: 64,
            mode: mode,
          ),
          closeTo(120, 1e-6),
        );
      }
    });

    test('spot reads center, ignoring a bright border', () {
      const w = 100, h = 100;
      final plane = Uint8List(w * h)..fillRange(0, w * h, 255);
      for (var y = 40; y < 60; y++) {
        for (var x = 40; x < 60; x++) {
          plane[y * w + x] = 10;
        }
      }
      final spot = LuminanceSampler.meanLuma(
        yPlane: plane,
        width: w,
        height: h,
        rowStride: w,
        mode: MeteringMode.spot,
      );
      expect(spot, closeTo(10, 1));
    });

    test('respects row stride padding', () {
      const w = 10, h = 4, stride = 16;
      final plane = Uint8List(stride * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          plane[y * stride + x] = 80;
        }
      }
      expect(
        LuminanceSampler.meanLuma(
          yPlane: plane,
          width: w,
          height: h,
          rowStride: stride,
          mode: MeteringMode.average,
        ),
        closeTo(80, 1e-6),
      );
    });

    test('meanLumaAtPoint reads around the given normalised point', () {
      const w = 100, h = 100;
      final plane = Uint8List(w * h)..fillRange(0, w * h, 200);
      // Dark patch around the upper-left quarter (25%, 25%).
      for (var y = 15; y < 35; y++) {
        for (var x = 15; x < 35; x++) {
          plane[y * w + x] = 5;
        }
      }
      final dark = LuminanceSampler.meanLumaAtPoint(
        yPlane: plane,
        width: w,
        height: h,
        rowStride: w,
        nx: 0.25,
        ny: 0.25,
      );
      final bright = LuminanceSampler.meanLumaAtPoint(
        yPlane: plane,
        width: w,
        height: h,
        rowStride: w,
        nx: 0.75,
        ny: 0.75,
      );
      expect(dark, closeTo(5, 1));
      expect(bright, closeTo(200, 1));
    });

    test('meanLumaAtPoint clamps points outside 0..1', () {
      final plane = Uint8List(50 * 50)..fillRange(0, 50 * 50, 90);
      expect(
        LuminanceSampler.meanLumaAtPoint(
          yPlane: plane,
          width: 50,
          height: 50,
          rowStride: 50,
          nx: 5,
          ny: -3,
        ),
        closeTo(90, 1e-6),
      );
    });

    test('bgraToY uses Rec.601 weights', () {
      final bgra = Uint8List.fromList([0, 0, 255, 255]); // pure red
      final y = LuminanceSampler.bgraToY(bgra, 1, 1);
      expect(y[0], (0.299 * 255).round());
    });
  });
}
