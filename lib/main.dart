import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_strings.dart';
import 'services/camera_meter_service.dart';
import 'services/exposure_metadata_channel.dart';
import 'services/light_sensor_service.dart';
import 'services/real_meter_service.dart';
import 'services/roll_store.dart';
import 'state/meter_controller.dart';
import 'ui/screens/meter_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MeterController();
  final rolls = RollStore();
  await controller.load();
  await rolls.load();
  runApp(MiniLightApp(controller: controller, rolls: rolls));
}

class MiniLightApp extends StatelessWidget {
  const MiniLightApp({
    super.key,
    required this.controller,
    required this.rolls,
  });

  final MeterController controller;
  final RollStore rolls;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: rolls),
        ChangeNotifierProvider(create: (_) => CameraMeterService()),
        ChangeNotifierProvider(create: (_) => LightSensorService()),
        ChangeNotifierProvider(
          create: (_) => RealMeterService(ExposureMetadataChannel()),
        ),
      ],
      child: Consumer<MeterController>(
        builder: (context, meter, _) => MaterialApp(
          title: 'miniLight',
          debugShowCheckedModeBanner: false,
          locale: meter.locale,
          localizationsDelegates: const [
            AppStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppStrings.supported,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE0A82E),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
          ),
          home: const MeterScreen(),
        ),
      ),
    );
  }
}
