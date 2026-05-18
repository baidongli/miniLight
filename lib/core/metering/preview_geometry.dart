/// Maps a tap on the displayed camera preview back to a normalised point on
/// the raw camera image, accounting for the `BoxFit.cover` crop and the
/// sensor rotation.
///
/// Pure math (no Flutter types beyond plain doubles) so it can be unit
/// tested. The preview is rendered as a child sized
/// `previewWidth x previewHeight` *in display orientation* (the meter
/// screen swaps the sensor's landscape dimensions to portrait), scaled with
/// cover to fill a `viewWidth x viewHeight` box.
class PreviewGeometry {
  const PreviewGeometry({
    required this.viewWidth,
    required this.viewHeight,
    required this.childWidth,
    required this.childHeight,
    required this.sensorOrientation,
  });

  /// Size of the on-screen preview area (the gesture surface).
  final double viewWidth;
  final double viewHeight;

  /// Size of the preview child in display orientation (portrait): for a
  /// back camera this is `previewSize.height x previewSize.width`.
  final double childWidth;
  final double childHeight;

  /// Camera sensor orientation in degrees (0/90/180/270).
  final int sensorOrientation;

  /// Convert a tap at display pixels ([dx],[dy]) within the view into a
  /// normalised point on the raw image plane (x along image width, y along
  /// image height), clamped to 0..1.
  ({double nx, double ny}) toImageNormalized(double dx, double dy) {
    if (childWidth <= 0 || childHeight <= 0 || viewWidth <= 0 ||
        viewHeight <= 0) {
      return (nx: dx.clamp(0.0, 1.0), ny: dy.clamp(0.0, 1.0));
    }

    // Undo BoxFit.cover: only the centre crop of the child is visible.
    final scale = (viewWidth / childWidth) > (viewHeight / childHeight)
        ? viewWidth / childWidth
        : viewHeight / childHeight;
    final visibleW = viewWidth / scale;
    final visibleH = viewHeight / scale;
    final offsetX = (childWidth - visibleW) / 2.0;
    final offsetY = (childHeight - visibleH) / 2.0;

    final childX = offsetX + (dx.clamp(0.0, viewWidth)) / viewWidth * visibleW;
    final childY = offsetY + (dy.clamp(0.0, viewHeight)) / viewHeight * visibleH;

    final cnx = (childX / childWidth).clamp(0.0, 1.0);
    final cny = (childY / childHeight).clamp(0.0, 1.0);

    // Undo the sensor rotation that turns the landscape frame into the
    // portrait display child.
    return switch (sensorOrientation % 360) {
      90 => (nx: cny, ny: 1.0 - cnx),
      270 => (nx: 1.0 - cny, ny: cnx),
      180 => (nx: 1.0 - cnx, ny: 1.0 - cny),
      _ => (nx: cnx, ny: cny),
    };
  }
}
