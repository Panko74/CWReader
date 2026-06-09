import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class Ebook2CWApp extends StatelessWidget {
  const Ebook2CWApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CWReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A5276),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
