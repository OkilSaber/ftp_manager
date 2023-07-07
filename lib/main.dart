import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'home_page.dart';
import 'types/config.dart';

void main() async {
  Hive.registerAdapter(ConfigAdapter());
  await Hive.initFlutter();
  await Hive.openBox<Config>('FTPConfigs');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FTP Client',
      theme: ThemeData(brightness: MediaQuery.of(context).platformBrightness),
      home: const HomePage(),
    );
  }
}
