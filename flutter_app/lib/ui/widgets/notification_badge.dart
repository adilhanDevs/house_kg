// Красный счётчик непрочитанных уведомлений на колокольчике.
//
// Число считает сервер (GET /notifications/unread-count/), своего счётчика
// клиент не ведёт. Значок сам перечитывает количество, когда экран под ним
// снова становится верхним, — то есть после возврата из ленты уведомлений
// цифра сразу верная.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/route_observer.dart';

const Key kNotificationBadgeKey = Key('notification_badge');

/// Значок с количеством непрочитанных. Пока их нет — не занимает места.
class NotificationBadge extends StatefulWidget {
  const NotificationBadge({super.key});

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> with RouteAware {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Вернулись с экрана, открытого поверх этого, — уведомления могли
  /// прочитаться, число надо обновить.
  @override
  void didPopNext() => _refresh();

  Future<void> _refresh() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    if (!state.isAuthenticated) {
      if (_count != 0) setState(() => _count = 0);
      return;
    }
    try {
      final data = await state.apiClient.getUnreadNotificationCount();
      if (!mounted) return;
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (count != _count) setState(() => _count = count);
    } catch (e) {
      // Счётчик — украшение: из-за него экран падать не должен.
      debugPrint('Счётчик уведомлений не обновился: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();

    // Больше сотни в кружок не влезает и смысла не несёт.
    final label = _count > 99 ? '99+' : '$_count';
    return IgnorePointer(
      child: Container(
        key: kNotificationBadgeKey,
        constraints: const BoxConstraints(minWidth: 16.0),
        height: 16.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xffd93025),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: const Color(0xffffffff), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.0,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: Color(0xffffffff),
          ),
        ),
      ),
    );
  }
}
