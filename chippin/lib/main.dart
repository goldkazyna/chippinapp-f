import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // Show errors on screen instead of grey screen in release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bug_report, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('FLUTTER ERROR',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red)),
              const SizedBox(height: 12),
              SelectableText('${details.exceptionAsString()}\n\n${details.stack}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
