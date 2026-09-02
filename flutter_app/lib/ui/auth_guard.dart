// Проверка входа перед действием, которое сервер выполнит только для своих.
//
// После закрытия анонимного доступа к объявлениям такие действия отвечают 401,
// и раньше пользователь видел голую ошибку вместо предложения войти.
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/routes.dart';

/// Пускает дальше, если пользователь вошёл. Иначе уводит на экран входа.
///
/// Возвращает `true`, когда действие можно выполнять.
bool requireAuth(BuildContext context, {String? reason}) {
  final state = AppScope.read(context);
  if (state.isAuthenticated) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(reason ?? 'Войдите, чтобы продолжить'),
      duration: const Duration(seconds: 3),
    ),
  );
  Navigator.of(context).pushNamed(Routes.welcome);
  return false;
}
