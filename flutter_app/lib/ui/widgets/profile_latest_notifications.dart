// Блок «Последние уведомления» для обычного и Pro-профилей.
//
// Получает настоящие уведомления с сервера (GET /api/v1/notifications/),
// поддерживает типы new_message, price_drop, модерацию и другие,
// открывает соответствующий экран (чат / объявление) и отмечает прочтение.
// Если уведомлений нет — показывает «У вас пока нет уведомлений», никаких
// моковых карточек из макета Figma.
import "dart:async";

import "package:flutter/material.dart";

import "../../app/app_state.dart";
import "../../app/route_observer.dart";
import "../../app/routes.dart";
import "../../data/chat_controller.dart" show describeApiError;
import "../../data/chat_models.dart";
import "../../fig/fig.dart";
import "../../l10n/l10n.dart";
import "../pages/chat_page.dart";
import "price_drop_notification_tile.dart";

const Key kProfileNotificationsSectionKey = Key(
  "profile_notifications_section",
);
const Key kProfileNotificationsSeeAllKey = Key("profile_notifications_see_all");
const Key kProfileNotificationsEmptyKey = Key("profile_notifications_empty");
const Key kProfileNotificationsLoadingKey = Key(
  "profile_notifications_loading",
);
const Key kProfileNotificationsErrorKey = Key("profile_notifications_error");

Key kProfileNotificationTileKey(int id) => Key("profile_notification_tile_$id");

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);

class ProfileLatestNotifications extends StatefulWidget {
  const ProfileLatestNotifications({
    super.key,
    this.maxItems = 2,
    this.width,
    this.showTitle = true,
  });

  /// Сколько последних уведомлений показывать в превью профиля.
  final int maxItems;

  final double? width;
  final bool showTitle;

  @override
  State<ProfileLatestNotifications> createState() =>
      _ProfileLatestNotificationsState();
}

class _ProfileLatestNotificationsState extends State<ProfileLatestNotifications>
    with RouteAware {
  final List<AppNotification> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _lastUserPhone;

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
    final state = AppScope.of(context);
    final currentPhone = state.isAuthenticated
        ? (state.userPhone ?? "authenticated")
        : null;
    if (_lastUserPhone != currentPhone) {
      _lastUserPhone = currentPhone;
      _items.clear();
      _refresh();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// При возврате с открытого экрана (например, с ленты уведомлений или чата)
  /// обновляем превью — статус прочтения мог измениться.
  @override
  void didPopNext() => _refresh();

  Future<void> _refresh() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    if (!state.isAuthenticated) {
      if (mounted) {
        setState(() {
          _items.clear();
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = _items.isEmpty;
      _error = null;
    });

    try {
      final page = await state.apiClient.getNotifications();
      if (!mounted) return;
      final results = page["results"];
      final list = [
        for (final item in results is List ? results : const [])
          if (item is Map<String, dynamic>) AppNotification.fromJson(item),
      ];

      setState(() {
        _items
          ..clear()
          ..addAll(list.take(widget.maxItems));
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = describeApiError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);

    if (!state.isAuthenticated) {
      navigator.pushNamed(Routes.welcome);
      return;
    }

    unawaited(_markRead(notification));

    if (notification.isNewMessage) {
      final conversationId = notification.conversationId;
      if (conversationId != null && conversationId.isNotEmpty) {
        await navigator.pushNamed(
          Routes.conversation,
          arguments: ChatArgs(
            conversationId,
            peerName: _localizedTitle(notification, context.l10n),
          ),
        );
        if (mounted) await _refresh();
        return;
      }
    }

    final slug = notification.listingSlug;
    if (slug != null && slug.isNotEmpty) {
      await navigator.pushNamed(Routes.listing, arguments: ListingArgs(slug));
      if (mounted) await _refresh();
      return;
    }

    // Если нет специального роута — открываем полный список уведомлений
    await navigator.pushNamed(Routes.notifications);
    if (mounted) await _refresh();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await AppScope.read(
        context,
      ).apiClient.markNotificationsRead(ids: [notification.id]);
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
      debugPrint("Не удалось отметить уведомление: $e");
    }
  }

  void _onSeeAll() async {
    await Navigator.of(context).pushNamed(Routes.notifications);
    if (mounted) await _refresh();
  }

  IconData _iconForType(String type) {
    return switch (type) {
      "new_message" => Icons.forum_outlined,
      "price_drop" => Icons.trending_down,
      "listing_moderated" => Icons.verified_outlined,
      "promotion_expiring" => Icons.campaign_outlined,
      "wallet_topup" => Icons.account_balance_wallet_outlined,
      "saved_filter_match" => Icons.search,
      _ => Icons.notifications_none,
    };
  }

  String _formatTime(DateTime? at) {
    if (at == null) return "";
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return "${at.hour.toString().padLeft(2, "0")}:${at.minute.toString().padLeft(2, "0")}";
    }
    return "${at.day.toString().padLeft(2, "0")}.${at.month.toString().padLeft(2, "0")}";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: kProfileNotificationsSectionKey,
      width: widget.width,
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showTitle) ...[
            Text(
              l10n.notificationsLatest,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
                color: Color(0xff000000),
              ),
            ),
            const SizedBox(height: 12.0),
          ],
          _buildBody(l10n),
          const SizedBox(height: 12.0),
          GestureDetector(
            key: kProfileNotificationsSeeAllKey,
            behavior: HitTestBehavior.opaque,
            onTap: _onSeeAll,
            child: SizedBox(
              width: double.infinity,
              height: 28.0,
              child: Center(
                child: Text(
                  l10n.homeSeeAll,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff7d7d7d),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading && _items.isEmpty) {
      return SizedBox(
        key: kProfileNotificationsLoadingKey,
        height: 54.0,
        child: const Center(
          child: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(strokeWidth: 2.0, color: _accent),
          ),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Container(
        key: kProfileNotificationsErrorKey,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 16.0, color: _muted),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                l10n.notificationsLoadError,
                style: figStyle(
                  fontSize: 12.0,
                  family: FigFont.display,
                  weight: 500,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            GestureDetector(
              onTap: _refresh,
              child: Text(
                l10n.retry,
                style: figStyle(
                  fontSize: 12.0,
                  family: FigFont.display,
                  weight: 600,
                  color: _accent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Container(
        key: kProfileNotificationsEmptyKey,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        alignment: Alignment.center,
        child: Text(
          l10n.notificationsProfileEmpty,
          style: figStyle(
            fontSize: 13.0,
            family: FigFont.display,
            weight: 500,
            color: _muted,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const Divider(height: 1.0, color: Color(0xfff0f0f0)),
          _buildItemTile(_items[i], l10n),
        ],
      ],
    );
  }

  Widget _buildItemTile(AppNotification item, AppLocalizations l10n) {
    if (item.isPriceDrop) {
      return PriceDropNotificationTile(
        key: kProfileNotificationTileKey(item.id),
        notification: item,
        onTap: () => _open(item),
        backgroundColor: Colors.transparent,
      );
    }
    return GestureDetector(
      key: kProfileNotificationTileKey(item.id),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                color: const Color(0xfff5f5f7),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(_iconForType(item.type), size: 22.0, color: _accent),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _localizedTitle(item, l10n),
                          style: const TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 6.0),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Container(
                            width: 6.0,
                            height: 6.0,
                            decoration: const BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6.0),
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_localizedBody(item, l10n).isNotEmpty) ...[
                    const SizedBox(height: 3.0),
                    Text(
                      _localizedBody(item, l10n),
                      style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: _muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedTitle(AppNotification item, AppLocalizations l10n) {
    final title = item.displayTitle(l10n);
    if (l10n.localeName.startsWith('ky')) {
      final normalized = title
          .toLowerCase()
          .replaceAll('—', '-')
          .replaceAll('–', '-');
      if (normalized.contains('проверка прочтения')) {
        return l10n.notificationTestPushTitle;
      }
    }
    return title.isNotEmpty ? title : l10n.notificationFallbackTitle;
  }

  String _localizedBody(AppNotification item, AppLocalizations l10n) {
    final body = item.displayBody(l10n);
    if (l10n.localeName.startsWith('ky')) {
      final normalized = body.toLowerCase();
      if (normalized.contains('контрольное уведомление')) {
        return l10n.notificationTestPushBody;
      }
    }
    return body;
  }
}
