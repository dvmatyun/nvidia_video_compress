import 'package:flutter/material.dart';
import 'controllers/compression_controller.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = CompressionController();
  await controller.initialize();
  runApp(MainApp(controller: controller));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.controller});
  final CompressionController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Compressor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0078D4),
          surface: Color(0xFF2A2A2A),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF0078D4);
            return Colors.transparent;
          }),
        ),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
