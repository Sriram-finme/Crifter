import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';

void main() {
  runApp(
    const ProviderScope(
      child: StausoApp(),
    ),
  );
}

class StausoApp extends StatelessWidget {
  const StausoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Text('Stauso'),
        ),
      ),
    );
  }
}
