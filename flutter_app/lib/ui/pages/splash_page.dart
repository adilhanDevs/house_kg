// «Сплэш» — кадр 1 макета с оранжевым логотипом-коробкой. Через две секунды
// уходит дальше; клик в любой точке не ждёт таймер.
//
// Куда именно — зависит от того, вошёл ли пользователь. Раньше сплэш всегда
// вёл на онбординг, и человек с сохранёнными токенами каждый запуск заново
// пролистывал карусель и упирался в экран входа.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.delay = const Duration(seconds: 2)});

  /// Сколько сплэш висит сам по себе.
  final Duration delay;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  /// Уходим ровно один раз: клик за мгновение до таймера не должен открыть
  /// онбординг дважды.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _next() async {
    if (_leaving || !mounted) return;
    // Сплэш может остаться под открытым сверху экраном — так бывает, когда
    // приложение открыли сразу на внутреннем маршруте. Тогда таймеру срабатывать
    // нельзя: pushReplacement снял бы не сплэш, а то, что смотрит пользователь.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _leaving = true;
    _timer?.cancel();

    final state = AppScope.read(context);
    final navigator = Navigator.of(context);

    // Токены читаются из хранилища асинхронно: не дождавшись, мы отправили бы
    // вошедшего пользователя на онбординг просто потому, что не успели узнать
    // о его входе.
    await state.authInitialized;
    if (!mounted) return;

    navigator.pushReplacementNamed(
      state.isAuthenticated ? Routes.home : Routes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: FigStage(
        frame: frame('01'),
        background: const Color(0xffffffff),
        onTapAnywhere: () => _next(),
      ),
    );
  }
}
