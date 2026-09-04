// Модели диалогов, сообщений и уведомлений.
//
// Поля повторяют ответы бэкенда один в один (apps/messaging/serializers.py,
// apps/notifications/serializers.py). Ничего не достраиваем и не переименовываем:
// контракт уже задеплоен.
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

/// Собеседник в диалоге.
@immutable
class ChatPeer {
  const ChatPeer({required this.id, required this.name, this.avatarUrl});

  final int id;
  final String name;
  final String? avatarUrl;

  factory ChatPeer.fromJson(Map<String, dynamic> json) => ChatPeer(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] as String?)?.trim().isNotEmpty == true
        ? (json['name'] as String).trim()
        : 'Собеседник',
    avatarUrl: json['avatar_url'] as String?,
  );
}

/// Последнее сообщение диалога — то, что видно в списке.
@immutable
class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final int senderId;
  final String text;
  final DateTime? createdAt;

  factory ChatPreview.fromJson(Map<String, dynamic> json) => ChatPreview(
    id: json['id']?.toString() ?? '',
    senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(
      json['created_at']?.toString() ?? '',
    )?.toLocal(),
  );
}

/// Диалог по конкретному объявлению.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.peer,
    this.listingSlug = '',
    this.listingTitle = '',
    this.listingPrice,
    this.listingCurrency = '',
    this.listingCoverUrl,
    this.latestMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  final String id;
  final ChatPeer peer;
  final String listingSlug;
  final String listingTitle;
  final String? listingPrice;
  final String listingCurrency;
  final String? listingCoverUrl;
  final ChatPreview? latestMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;

  bool get hasUnread => unreadCount > 0;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'];
    final latest = json['latest_message'];
    return Conversation(
      id: json['id']?.toString() ?? '',
      peer: peer is Map<String, dynamic>
          ? ChatPeer.fromJson(peer)
          : const ChatPeer(id: 0, name: 'Собеседник'),
      listingSlug: json['listing_slug'] as String? ?? '',
      listingTitle: json['listing_title'] as String? ?? '',
      listingPrice: json['listing_price']?.toString(),
      listingCurrency: json['listing_currency'] as String? ?? '',
      listingCoverUrl: json['listing_cover_url'] as String?,
      latestMessage: latest is Map<String, dynamic>
          ? ChatPreview.fromJson(latest)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// Что происходит с сообщением, пока сервер не подтвердил его.
enum MessageStatus {
  /// Подтверждено сервером.
  sent,

  /// Отправляется: показываем, но помечаем.
  sending,

  /// Отправка не удалась — можно повторить тем же client_message_id.
  failed,
}

/// Сообщение диалога.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.clientMessageId,
    this.status = MessageStatus.sent,
  });

  /// UUID сообщения на сервере. У неподтверждённого совпадает с
  /// `clientMessageId` — чтобы у пузыря был стабильный ключ.
  final String id;
  final int senderId;
  final String text;
  final DateTime createdAt;

  /// UUID, придуманный клиентом. По нему сервер защищается от дублей, а мы —
  /// узнаём своё же сообщение, вернувшееся из ответа.
  final String? clientMessageId;

  final MessageStatus status;

  bool get isPending => status != MessageStatus.sent;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    clientMessageId: json['client_message_id']?.toString(),
  );

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
    id: id,
    senderId: senderId,
    text: text,
    createdAt: createdAt,
    clientMessageId: clientMessageId,
    status: status ?? this.status,
  );
}

/// Уведомление из ленты.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.payload = const {},
    this.listingSlug,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> payload;
  final String? listingSlug;
  final DateTime? createdAt;

  /// Уведомление о новом сообщении — по нему открывается диалог.
  bool get isNewMessage => type == 'new_message';

  /// Уведомление о снижении цены.
  bool get isPriceDrop => type == 'price_drop';

  /// Диалог из payload. Пусто, если сервер его не прислал.
  String? get conversationId {
    final value = payload['conversation_id'];
    final id = value?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  int? get senderId {
    final value = payload['sender_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? get oldPrice =>
      payload['old_price']?.toString() ?? payload['old_price_usd']?.toString();

  String? get newPrice =>
      payload['new_price']?.toString() ?? payload['new_price_usd']?.toString();

  String? get currency => payload['currency']?.toString();

  String? get districtName =>
      payload['district']?.toString() ?? payload['district_name']?.toString();

  int? get rooms => (payload['rooms'] as num?)?.toInt();

  String? get area => payload['area']?.toString();

  int? get floor => (payload['floor'] as num?)?.toInt();

  int? get floors => (payload['floors'] as num?)?.toInt();

  String? get coverUrl => payload['cover_url']?.toString();

  /// Проверяет, является ли уведомление проверочным (test push).
  ///
  /// Учитывает не только `payload['kind'] == 'test_push'`, но и типичные
  /// заголовки/тексты проверочных уведомлений (на русском и кыргызском, с дефисом
  /// или тире), чтобы даже старые записи из базы без payload или с частичным
  /// payload корректно локализовались при переключении языка в приложении.
  bool get isTestPush {
    if (payload['kind'] == 'test_push') return true;
    final cleanTitle = title
        .toLowerCase()
        .replaceAll('—', '-')
        .replaceAll('–', '-');
    if (cleanTitle.contains('проверка прочтения') ||
        cleanTitle.contains('окулганын текшерүү') ||
        cleanTitle.contains('проверка уведомлений') ||
        cleanTitle.contains('билдирмелерди текшерүү')) {
      return true;
    }
    final cleanBody = body.toLowerCase();
    if (cleanBody.contains('контрольное уведомление') ||
        cleanBody.contains('көзөмөл билдирмеси') ||
        cleanBody.contains('push-уведомления работают') ||
        cleanBody.contains('push-билдирмелер иштеп')) {
      return true;
    }
    return false;
  }

  String displayTitle(AppLocalizations l10n) {
    final localized = _localizedPayloadText('title', l10n.localeName);
    if (localized != null) return localized;
    if (isTestPush) return l10n.notificationTestPushTitle;
    final fallback = _localizedPayloadText('title', 'ru');
    if (fallback != null) return fallback;
    return title;
  }

  String displayBody(AppLocalizations l10n) {
    final localized = _localizedPayloadText('body', l10n.localeName);
    if (localized != null) return localized;
    if (isTestPush) return l10n.notificationTestPushBody;
    final fallback = _localizedPayloadText('body', 'ru');
    if (fallback != null) return fallback;
    return body;
  }

  String? _localizedPayloadText(String field, String localeName) {
    final i18n = payload['${field}_i18n'];
    if (i18n is! Map) return null;
    final languageCode = localeName.split('_').first.toLowerCase();
    final value = i18n[languageCode] ??
        i18n[localeName] ??
        i18n[localeName.toLowerCase()];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] == true,
      payload: payload is Map<String, dynamic> ? payload : const {},
      listingSlug: json['listing_slug'] as String?,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// Настройки уведомлений. Поля — ровно те, что отдаёт сервер.
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.pushEnabled = true,
    this.newMessageEnabled = true,
    this.priceDropEnabled = true,
    this.savedFilterEnabled = true,
    this.listingModeratedEnabled = true,
    this.promotionExpiringEnabled = true,
    this.walletTopupEnabled = true,
    this.systemEnabled = true,
  });

  final bool pushEnabled;
  final bool newMessageEnabled;
  final bool priceDropEnabled;
  final bool savedFilterEnabled;
  final bool listingModeratedEnabled;
  final bool promotionExpiringEnabled;
  final bool walletTopupEnabled;
  final bool systemEnabled;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] != false;
    return NotificationSettings(
      pushEnabled: flag('push_enabled'),
      newMessageEnabled: flag('new_message_enabled'),
      priceDropEnabled: flag('price_drop_enabled'),
      savedFilterEnabled: flag('saved_filter_enabled'),
      listingModeratedEnabled: flag('listing_moderated_enabled'),
      promotionExpiringEnabled: flag('promotion_expiring_enabled'),
      walletTopupEnabled: flag('wallet_topup_enabled'),
      systemEnabled: flag('system_enabled'),
    );
  }

  NotificationSettings copyWith({bool? newMessageEnabled, bool? pushEnabled}) =>
      NotificationSettings(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        newMessageEnabled: newMessageEnabled ?? this.newMessageEnabled,
        priceDropEnabled: priceDropEnabled,
        savedFilterEnabled: savedFilterEnabled,
        listingModeratedEnabled: listingModeratedEnabled,
        promotionExpiringEnabled: promotionExpiringEnabled,
        walletTopupEnabled: walletTopupEnabled,
        systemEnabled: systemEnabled,
      );
}
