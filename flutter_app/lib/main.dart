// Точка входа приложения.
//   flutter run                           — запуск приложения
//   flutter run -t lib/prototype_shell.dart — режим 57 кадров макета
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';

export 'prototype_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Кадры нарисованы во весь экран и держат свои поля под системные полосы:
  // пустая полоса 0..48 сверху и полоса внутри таб-бара снизу. Приложение
  // должно занимать весь экран, иначе система добавит эти поля ещё раз.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HouseKgzAppScope());
}
