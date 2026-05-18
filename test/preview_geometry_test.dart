import 'package:flutter_test/flutter_test.dart';
import 'package:minilight/core/metering/preview_geometry.dart';

void main() {
  group('PreviewGeometry.toImageNormalized', () {
    test('orientation 0, no cover crop: identity-ish mapping', () {
      const g = PreviewGeometry(
        viewWidth: 100,
        viewHeight: 100,
        childWidth: 100,
        childHeight: 100,
        sensorOrientation: 0,
      );
      final c = g.toImageNormalized(50, 50);
      expect(c.nx, closeTo(0.5, 1e-9));
      expect(c.ny, closeTo(0.5, 1e-9));
      final tl = g.toImageNormalized(0, 0);
      expect(tl.nx, closeTo(0, 1e-9));
      expect(tl.ny, closeTo(0, 1e-9));
    });

    test('orientation 90 rotates portrait tap into landscape image', () {
      const g = PreviewGeometry(
        viewWidth: 50,
        viewHeight: 100,
        childWidth: 50,
        childHeight: 100,
        sensorOrientation: 90,
      );
      // Center stays center under any rotation.
      final c = g.toImageNormalized(25, 50);
      expect(c.nx, closeTo(0.5, 1e-9));
      expect(c.ny, closeTo(0.5, 1e-9));
      // Top-left of portrait display -> (cnx=0,cny=0) -> (0, 1).
      final tl = g.toImageNormalized(0, 0);
      expect(tl.nx, closeTo(0, 1e-9));
      expect(tl.ny, closeTo(1, 1e-9));
    });

    test('cover crop maps the visible centre correctly', () {
      // view 100x200, child 100x100 -> scale 2. The child is cropped
      // horizontally (only the middle 50% of its width is visible) and
      // shown in full vertically.
      const g = PreviewGeometry(
        viewWidth: 100,
        viewHeight: 200,
        childWidth: 100,
        childHeight: 100,
        sensorOrientation: 0,
      );
      final mid = g.toImageNormalized(50, 100);
      expect(mid.nx, closeTo(0.5, 1e-9));
      expect(mid.ny, closeTo(0.5, 1e-9));
      // Left edge of the view sees the cropped child, not x=0.
      final left = g.toImageNormalized(0, 100);
      expect(left.nx, greaterThan(0.0));
      expect(left.nx, lessThan(0.5));
      expect(left.nx, closeTo(0.25, 1e-9));
      // Vertically uncropped: top of the view is image y=0.
      final top = g.toImageNormalized(50, 0);
      expect(top.ny, closeTo(0.0, 1e-9));
    });

    test('degenerate sizes fall back to clamped passthrough', () {
      const g = PreviewGeometry(
        viewWidth: 0,
        viewHeight: 0,
        childWidth: 0,
        childHeight: 0,
        sensorOrientation: 90,
      );
      final c = g.toImageNormalized(2, -1);
      expect(c.nx, 1.0);
      expect(c.ny, 0.0);
    });
  });
}
