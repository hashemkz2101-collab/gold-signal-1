import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GoldSignalApp()));
}

class GoldSignalApp extends StatelessWidget {
  const GoldSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gold Signal Assistant',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFC9A227),
        brightness: Brightness.dark,
      ),
      home: const HomeShell(),
    );
  }
}
