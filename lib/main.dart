import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/camera_meter_service.dart';
import 'state/meter_controller.dart';
import 'ui/screens/meter_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MeterController();
  await controller.load();
  runApp(MiniLightApp(controller: controller));
}

class MiniLightApp extends StatelessWidget {
  const MiniLightApp({super.key, required this.controller});

  final MeterController controller;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider(create: (_) => CameraMeterService()),
      ],
      child: MaterialApp(
        title: 'miniLight',
        debugShowCheckedModeBanner: false,
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
    );
  }
}
