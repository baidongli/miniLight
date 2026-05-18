import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/log/shot_log.dart';
import '../../core/metering/metering.dart';
import '../../core/metering/preview_geometry.dart';
import '../../l10n/app_strings.dart';
import '../../services/camera_meter_service.dart';
import '../../services/light_sensor_service.dart';
import '../../services/location_service.dart';
import '../../services/real_meter_service.dart';
import '../../services/roll_store.dart';
import '../../state/meter_controller.dart';
import '../widgets/reading_panel.dart';
import '../widgets/spot_overlay.dart';
import 'compensations_screen.dart';
import 'rolls_screen.dart';
import 'settings_screen.dart';

class MeterScreen extends StatefulWidget {
  const MeterScreen({super.key});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> {
  bool _started = false;
  Offset? _tapLocal;
  double? _heldEv;
  final _location = LocationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final cam = context.read<CameraMeterService>();
    final meter = context.read<MeterController>();
    final light = context.read<LightSensorService>();
    final real = context.read<RealMeterService>();
    cam.calibration = meter.calibration;
    real.calc = meter.absoluteCalc;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cam.start();
      light.start();
      real.start(regionMode: cam.meteringMode.index);
    });
  }

  double? _sourceEv(
    MeterController meter,
    CameraMeterService cam,
    LightSensorService light,
    RealMeterService real,
  ) {
    switch (meter.source) {
      case MeterSource.incident:
        if (light.available && light.lux > 0) {
          return meter.incidentCalc.ev100(light.lux);
        }
        return cam.ev100;
      case MeterSource.real:
        return (real.available ? real.ev100 : null) ?? cam.ev100;
      case MeterSource.camera:
        return cam.ev100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cam = context.watch<CameraMeterService>();
    final meter = context.watch<MeterController>();
    final light = context.watch<LightSensorService>();
    final real = context.watch<RealMeterService>();

    final liveEv = _sourceEv(meter, cam, light, real);
    final ev = meter.held ? _heldEv : liveEv;
    final solution = meter.solve(ev);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('app')),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.exposure),
            tooltip: s.t('compensations'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CompensationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark),
            tooltip: s.t('shot_log'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RollsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: s.t('settings'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: solution == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _saveShot(context, meter, solution),
              icon: const Icon(Icons.add_a_photo),
              label: Text(s.t('save_shot')),
            ),
      body: Column(
        children: [
          Expanded(child: _preview(context, cam, meter, real)),
          _clipping(s, cam),
          _sourceBar(s, meter),
          _modeSelector(context, cam, real, s),
          ReadingPanel(
            solution: solution,
            film: meter.film,
            meanLuma: cam.meanLuma,
          ),
        ],
      ),
    );
  }

  Widget _clipping(AppStrings s, CameraMeterService cam) {
    String? msg;
    if (cam.meanLuma >= 250) {
      msg = s.t('overexposed');
    } else if (cam.meanLuma > 0 && cam.meanLuma <= 8) {
      msg = s.t('underexposed');
    }
    if (msg == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.red.shade900,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _sourceBar(AppStrings s, MeterController meter) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<MeterSource>(
              segments: [
                ButtonSegment(
                    value: MeterSource.camera,
                    label: Text(s.t('metering_camera'))),
                ButtonSegment(
                    value: MeterSource.incident,
                    label: Text(s.t('metering_incident'))),
                ButtonSegment(
                    value: MeterSource.real,
                    label: Text(s.t('metering_real'))),
              ],
              selected: {meter.source},
              showSelectedIcon: false,
              onSelectionChanged: (v) => meter.setSource(v.first),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              if (!meter.held) _heldEv = _lastLiveEv;
              meter.toggleHold();
            },
            icon: Icon(meter.held ? Icons.lock : Icons.lock_open),
            label: Text(meter.held ? s.t('hold') : s.t('live')),
          ),
        ],
      ),
    );
  }

  double? _lastLiveEv;

  Widget _preview(
    BuildContext context,
    CameraMeterService cam,
    MeterController meter,
    RealMeterService real,
  ) {
    if (cam.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(cam.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    final controller = cam.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = controller.value.previewSize;
    if (!cam.isFocusActive && _tapLocal != null) _tapLocal = null;
    _lastLiveEv =
        _sourceEv(meter, cam, context.read<LightSensorService>(), real);

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
              sensorOrientation: controller.description.sensorOrientation,
            );
            final p = geom.toImageNormalized(
                d.localPosition.dx, d.localPosition.dy);
            cam.setFocusPoint(p.nx, p.ny);
            real.setPoint(p.nx, p.ny);
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

  Widget _modeSelector(
    BuildContext context,
    CameraMeterService cam,
    RealMeterService real,
    AppStrings s,
  ) {
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
            onSelectionChanged: (sel) {
              cam.setMeteringMode(sel.first);
              real.setRegion(sel.first.index);
            },
          ),
          const SizedBox(height: 4),
          Text(
            cam.isFocusActive ? s.t('focus_active') : s.t('tap_hint'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShot(
    BuildContext context,
    MeterController meter,
    solution,
  ) async {
    final store = context.read<RollStore>();
    final s = AppStrings.of(context);
    var roll = store.activeRoll;
    roll ??= store.createRoll(
      name: 'Roll ${DateTime.now().toIso8601String().substring(0, 10)}',
      filmName: meter.film.name,
      iso: meter.film.iso,
    );
    final gps = await _location.current();
    store.addShot(ShotEntry(
      frame: roll.nextFrame,
      timestamp: DateTime.now(),
      ev100: solution.ev100,
      aperture: solution.aperture,
      shutterSeconds: solution.shutterAfterReciprocity,
      iso: solution.iso,
      latitude: gps?.lat,
      longitude: gps?.lng,
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.t('save_shot')} · ${roll.name}')),
      );
    }
  }
}
