// Блок «Последние уведомления» в профиле.
//
// В кадре эти карточки нарисованы: два одинаковых «Технопарка» со снижением
// цены, одни и те же у всех пользователей. Панель перекрывает нарисованное
// непрозрачным фоном и показывает то, что реально пришло с сервера.
//
// Размер задаётся снаружи: полоса, которую надо закрыть, у каждого кадра своя
// и снята измерением, а не подобрана на глаз.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/route_observer.dart';
import '../../app/routes.dart';
import '../../data/chat_controller.dart' show describeApiError;
import '../../data/chat_models.dart';
import '../../fig/fig.dart';
import '../pages/chat_page.dart';

const Key kLatestNotificationsKey = Key('latest_notifications');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);

/// Последние уведомления пользователя поверх нарисованных карточек кадра.
class LatestNotifications extends StatefulWidget {
  const LatestNotifications({
    super.key,
    required this.width,
    required this.height,
    this.maxItems = 2,
  });

  final double width;
  final double height;

  /// Сколько карточек помещается в полосу кадра.
  final int maxItems;

  @override
  State<LatestNotifications> createState() => _LatestNotificationsState();
}

class _LatestNotificationsState extends State<LatestNotifications> with RouteAware {
  List<AppNotification> _items = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Вернулись из ленты — что-то могли прочитать, список надо обновить.
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    if (!state.isAuthenticated) {
      setState(() {
        _items = const [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final page = await state.apiClient.getNotifications();
      if (!mounted) return;
      final results = page['results'];
      final parsed = <AppNotification>[
        for (final item in results is List ? results : const [])
          if (item is Map<String, dynamic>) AppNotification.fromJson(item),
      ];
      setState(() {
        _items = parsed.take(widget.maxItems).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    final navigator = Navigator.of(context);

    if (notification.isNewMessage) {
      final conversationId = notification.conversationId;
      if (conversationId == null) {
        await navigator.pushNamed(Routes.notifications);
        return;
      }
      await navigator.pushNamed(
        Routes.conversation,
        arguments: ChatArgs(conversationId, peerName: notification.title),
      );
      return;
    }

    final slug = notification.listingSlug;
    if (slug != null && slug.isNotEmpty) {
      await navigator.pushNamed(Routes.listing, arguments: ListingArgs(slug));
      return;
    }
    await navigator.pushNamed(Routes.notifications);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: kLatestNotificationsKey,
      width: widget.width,
      height: widget.height,
      // Непрозрачный фон обязателен: под панелью нарисованные карточки кадра.
      color: const Color(0xffffffff),
      child: _body(),
    );
  }

  Widget _body() {
    if (_isLoading && _items.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18.0,
          height: 18.0,
          child: CircularProgressIndicator(strokeWidth: 2.0, color: _accent),
        ),
      );
    }
    if (_items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _error ?? 'Уведомлений пока нет',
          style: figStyle(
            fontSize: 13.0,
            family: FigFont.display,
            weight: 500,
            height: 1.3,
            color: _muted,
          ),
        ),
      );
    }

    final rowHeight = widget.height / _items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final notification in _items)
          SizedBox(
            height: rowHeight,
            child: _NotificationRow(
              notification: notification,
              onTap: () => _open(notification),
            ),
          ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  String get _time {
    final at = notification.createdAt;
    if (at == null) return '';
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
    }
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}';
  }

  IconData get _icon => switch (notification.type) {
        'new_message' => Icons.forum_outlined,
        'price_drop' => Icons.trending_down,
        'listing_moderated' => Icons.verified_outlined,
        'wallet_topup' => Icons.account_balance_wallet_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                color: const Color(0xfff1f1f4),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(_icon, size: 20.0, color: _accent),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figStyle(
                      fontSize: 14.0,
                      family: FigFont.display,
                      weight: notification.isRead ? 500 : 600,
                      height: 1.2,
                      color: const Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    notification.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figStyle(
                      fontSize: 12.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.2,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _time,
                  style: figStyle(
                    fontSize: 11.0,
                    family: FigFont.display,
                    weight: 500,
                    height: 1.2,
                    color: _muted,
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: 4.0),
                  Container(
                    width: 8.0,
                    height: 8.0,
                    decoration: const BoxDecoration(
                      color: Color(0xffd93025),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
