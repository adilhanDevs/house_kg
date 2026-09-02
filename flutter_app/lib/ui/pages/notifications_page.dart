import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/chat_controller.dart' show describeApiError;
import '../../data/chat_models.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import 'chat_page.dart';

const Key kNotificationsListKey = Key('notifications_list');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<AppNotification> _items = [];
  String? _nextCursor;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await AppScope.read(context).apiClient.getNotifications();
      if (!mounted) return;
      final results = page['results'];
      setState(() {
        _items
          ..clear()
          ..addAll([
            for (final item in results is List ? results : const [])
              if (item is Map<String, dynamic>) AppNotification.fromJson(item),
          ]);
        _nextCursor = page['next'] as String?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    try {
      final page =
          await AppScope.read(context).apiClient.getNotifications(cursor: cursor);
      if (!mounted) return;
      final results = page['results'];
      setState(() {
        final known = _items.map((n) => n.id).toSet();
        _items.addAll([
          for (final item in results is List ? results : const [])
            if (item is Map<String, dynamic>)
              if (!known.contains((item['id'] as num?)?.toInt() ?? 0))
                AppNotification.fromJson(item),
        ]);
        _nextCursor = page['next'] as String?;
      });
    } catch (e) {
      debugPrint('Не удалось догрузить уведомления: ${describeApiError(e)}');
    }
  }

  Future<void> _open(AppNotification notification) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!state.isAuthenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы открыть переписку')),
      );
      navigator.pushNamed(Routes.welcome);
      return;
    }

    unawaited(_markRead(notification));

    if (notification.isNewMessage) {
      final conversationId = notification.conversationId;
      if (conversationId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Диалог недоступен')),
        );
        return;
      }
      await navigator.pushNamed(
        Routes.conversation,
        arguments: ChatArgs(conversationId, peerName: notification.title),
      );
      if (mounted) await _load();
      return;
    }

    final slug = notification.listingSlug;
    if (slug != null && slug.isNotEmpty) {
      await navigator.pushNamed(Routes.listing, arguments: ListingArgs(slug));
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await AppScope.read(context)
          .apiClient
          .markNotificationsRead(ids: [notification.id]);
      if (!mounted) return;
      final index = _items.indexWhere((n) => n.id == notification.id);
      if (index >= 0) {
        setState(() {
          _items[index] = AppNotification(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            body: notification.body,
            isRead: true,
            payload: notification.payload,
            listingSlug: notification.listingSlug,
            createdAt: notification.createdAt,
          );
        });
      }
    } catch (e) {
      debugPrint('Не удалось отметить уведомление: ${describeApiError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      appBar: AppBar(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: const Color(0xffffffff),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff1c1939)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.notificationsTitle,
          style: figStyle(
            fontSize: 17.0,
            family: FigFont.display,
            weight: 600,
            height: 1.2,
            color: const Color(0xff000000),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.chatTitle,
            icon: const Icon(Icons.forum_outlined, color: _accent),
            onPressed: () => Navigator.of(context).pushNamed(Routes.conversations),
          ),
        ],
      ),
      bottomNavigationBar: const AppTabBar(active: null),
      body: SafeArea(child: _body(l10n)),
    );
  }

  Widget _body(dynamic l10n) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null && _items.isEmpty) {
      return _Placeholder(text: _error!, actionLabel: l10n.retry, onAction: _load);
    }
    if (_items.isEmpty) {
      return _Placeholder(text: l10n.notificationsEmpty);
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) _loadMore();
          return false;
        },
        child: ListView.separated(
          key: kNotificationsListKey,
          itemCount: _items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1.0, color: Color(0xffeeeeee)),
          itemBuilder: (context, index) => _NotificationTile(
            notification: _items[index],
            onTap: () => _open(_items[index]),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

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

  IconData get _icon =>
      notification.isNewMessage ? Icons.forum_outlined : Icons.notifications_none;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead ? null : const Color(0x0fea812e),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.0,
              height: 40.0,
              decoration: const BoxDecoration(
                color: Color(0xfff1f1f4),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20.0, color: _accent),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: notification.isRead ? 500 : 600,
                            height: 1.2,
                            color: const Color(0xff000000),
                          ),
                        ),
                      ),
                      Text(
                        _time,
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
                  const SizedBox(height: 4.0),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: figStyle(
                      fontSize: 13.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.3,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: figStyle(
                fontSize: 15.0,
                family: FigFont.display,
                weight: 500,
                height: 1.3,
                color: _muted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12.0),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: figStyle(
                    fontSize: 15.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.3,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
