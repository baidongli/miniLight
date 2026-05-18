import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/metering/metering.dart';
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
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        SpotOverlay(mode: cam.meteringMode),
      ],
    );
  }

  Widget _modeSelector(BuildContext context, CameraMeterService cam) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<MeteringMode>(
        segments: MeteringMode.values
            .map((m) => ButtonSegment(value: m, label: Text(m.label)))
            .toList(),
        selected: {cam.meteringMode},
        showSelectedIcon: false,
        onSelectionChanged: (s) => cam.setMeteringMode(s.first),
      ),
    );
  }
}
