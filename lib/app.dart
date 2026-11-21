import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

class CWReaderApp extends StatelessWidget {
  const CWReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1A5276);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'CWReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
