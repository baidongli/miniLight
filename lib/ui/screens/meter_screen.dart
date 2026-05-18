import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/metering/metering.dart';
import '../../core/metering/preview_geometry.dart';
import '../../services/camera_meter_service.dart';
import '../../state/meter_controller.dart';
import '../widgets/reading_panel.dart';
import '../widgets/spot_overlay.dart';
import 'settings_screen.dart';

class MeterScreen extends StatefulWidget {
  const MeterScreen({super.key});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> {
  bool _started = false;
  Offset? _tapLocal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final cam = context.read<CameraMeterService>();
    final meter = context.read<MeterController>();
    cam.calibration = meter.calibration;
    WidgetsBinding.instance.addPostFrameCallback((_) => cam.start());
  }

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraMeterService>();
    final meter = context.watch<MeterController>();
    final solution = meter.solve(cam.ev100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('miniLight'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _preview(context, cam)),
          _modeSelector(context, cam),
          ReadingPanel(
            solution: solution,
            film: meter.film,
            meanLuma: cam.meanLuma,
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, CameraMeterService cam) {
    if (cam.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            cam.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
    final controller = cam.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = controller.value.previewSize;
    if (!cam.isFocusActive && _tapLocal != null) _tapLocal = null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final geom = PreviewGeometry(
              viewWidth: constraints.maxWidth,
              viewHeight: constraints.maxHeight,
              childWidth: preview?.height ?? 1,
              childHeight: preview?.width ?? 1,
              sensorOrientation:
                  controller.description.sensorOrientation,
            );
            final p = geom.toImageNormalized(
              d.localPosition.dx,
              d.localPosition.dy,
            );
            cam.setFocusPoint(p.nx, p.ny);
            setState(() => _tapLocal = d.localPosition);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: preview?.height ?? 1,
                  height: preview?.width ?? 1,
                  child: CameraPreview(controller),
                ),
              ),
              SpotOverlay(
                mode: cam.meteringMode,
                focusMarker: cam.isFocusActive ? _tapLocal : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeSelector(BuildContext context, CameraMeterService cam) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<MeteringMode>(
            segments: MeteringMode.values
                .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                .toList(),
            selected: {cam.meteringMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => cam.setMeteringMode(s.first),
          ),
          const SizedBox(height: 4),
          Text(
            cam.isFocusActive
                ? 'Tap-to-meter active · pick a mode to reset'
                : 'Tap the preview to meter that spot',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
