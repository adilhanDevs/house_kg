// Состояние одного диалога: история, отправка, докачка старых сообщений.
//
// Порядок сообщений задаёт сервер. Курсор у него составной — по паре
// (created_at, id), — поэтому у сообщений с одинаковым временем порядок всё
// равно однозначный. Локально пересортировывать по времени нельзя: это как раз
// и сломает разрешение ничьей по id.
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'chat_models.dart';

const Uuid _uuid = Uuid();

/// Диалог, загруженный на экран.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.api,
    required this.conversationId,
    required this.myUserId,
  });

  final ListingApiClient api;
  final String conversationId;

  /// Чьи сообщения считать своими. 0 — пользователь неизвестен.
  final int myUserId;

  final List<ChatMessage> _messages = <ChatMessage>[];

  /// Сообщения в хронологическом порядке — как их отдал сервер.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool _isLoadingOlder = false;
  bool _isSending = false;
  String? _error;
  String? _olderCursor;

  bool get isLoading => _isLoading;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get isSending => _isSending;
  bool get hasOlder => _olderCursor != null;
  String? get error => _error;
  bool get isEmpty => _messages.isEmpty;

  /// Последнее подтверждённое сервером сообщение — от него идёт докачка новых
  /// и им же отмечается прочтение.
  ChatMessage? get lastConfirmed {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isPending) return _messages[i];
    }
    return null;
  }

  /// Первая загрузка: сервер отдаёт самые свежие сообщения хронологически.
  Future<void> loadInitial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await api.getMessages(conversationId);
      _messages
        ..clear()
        ..addAll(_parse(page));
      _olderCursor = page['next'] as String?;
    } catch (e) {
      _error = describeApiError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Докачка вверх. `next` в режиме истории ведёт к более старым сообщениям.
  Future<void> loadOlder() async {
    final cursor = _olderCursor;
    if (cursor == null || _isLoadingOlder) return;

    _isLoadingOlder = true;
    notifyListeners();
    try {
      final page = await api.getMessages(conversationId, cursor: cursor);
      _mergeOlder(_parse(page));
      _olderCursor = page['next'] as String?;
    } catch (e) {
      _error = describeApiError(e);
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  /// Догружает только новое — при возврате на экран или по таймеру.
  ///
  /// Полную историю ради этого не перечитываем: сервер умеет отдавать хвост
  /// после известного сообщения.
  Future<void> fetchNew() async {
    final anchor = lastConfirmed;
    if (anchor == null) {
      await loadInitial();
      return;
    }
    try {
      final page = await api.getMessagesAfter(conversationId, anchor.id);
      _mergeNewer(_parse(page));
    } catch (e) {
      // Молча: догрузка новых — фоновая операция, ронять экран из-за неё
      // нельзя, история на экране остаётся валидной.
      debugPrint('Не удалось догрузить новые сообщения: ${describeApiError(e)}');
    }
  }

  /// Отправляет сообщение. Пузырь появляется сразу, до ответа сервера.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    // Идентификатор придумывается ОДИН раз на логическое сообщение и живёт
    // до успеха: повтор с тем же значением сервер считает тем же сообщением.
    final pending = ChatMessage(
      id: _uuid.v4(),
      senderId: myUserId,
      text: trimmed,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    final withId = ChatMessage(
      id: pending.id,
      senderId: pending.senderId,
      text: pending.text,
      createdAt: pending.createdAt,
      clientMessageId: pending.id,
      status: MessageStatus.sending,
    );
    _messages.add(withId);
    notifyListeners();

    await _deliver(withId);
  }

  /// Повторная отправка того же сообщения — тем же client_message_id.
  Future<void> retry(ChatMessage failed) async {
    final clientId = failed.clientMessageId;
    if (clientId == null || _isSending) return;

    final index = _indexOfClientId(clientId);
    if (index < 0) return;

    _messages[index] = _messages[index].copyWith(status: MessageStatus.sending);
    notifyListeners();

    await _deliver(_messages[index]);
  }

  Future<void> _deliver(ChatMessage pending) async {
    final clientId = pending.clientMessageId!;
    _isSending = true;
    notifyListeners();
    try {
      final response = await api.sendMessage(conversationId, pending.text, clientId);
      final confirmed = ChatMessage.fromJson(response);
      final index = _indexOfClientId(clientId);
      if (index >= 0) {
        // Заменяем пузырь, а не добавляем второй: сервер мог вернуть уже
        // существующее сообщение, если этот же id доходил раньше.
        _messages[index] = confirmed;
      } else if (_indexOfId(confirmed.id) < 0) {
        _messages.add(confirmed);
      }
      _error = null;
    } catch (e) {
      final index = _indexOfClientId(clientId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
      }
      _error = describeApiError(e);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Отмечает диалог прочитанным до последнего подтверждённого сообщения.
  Future<int> markRead() async {
    final anchor = lastConfirmed;
    if (anchor == null) return 0;
    try {
      final response = await api.markConversationRead(conversationId, anchor.id);
      return (response['unread_count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Не удалось отметить диалог прочитанным: ${describeApiError(e)}');
      return 0;
    }
  }

  List<ChatMessage> _parse(Map<String, dynamic> page) {
    final results = page['results'];
    if (results is! List) return const <ChatMessage>[];
    return [
      for (final item in results)
        if (item is Map<String, dynamic>) ChatMessage.fromJson(item),
    ];
  }

  /// Старая страница встаёт перед текущей, порядок внутри страницы не трогаем.
  void _mergeOlder(List<ChatMessage> older) {
    final fresh = [for (final m in older) if (!_contains(m)) m];
    if (fresh.isEmpty) return;
    _messages.insertAll(0, fresh);
  }

  /// Новые сообщения дописываются в конец.
  void _mergeNewer(List<ChatMessage> newer) {
    for (final message in newer) {
      final byClient = message.clientMessageId != null
          ? _indexOfClientId(message.clientMessageId!)
          : -1;
      if (byClient >= 0) {
        _messages[byClient] = message;
        continue;
      }
      if (_indexOfId(message.id) >= 0) continue;
      _messages.add(message);
    }
    notifyListeners();
  }

  /// Одно и то же сообщение может прийти в соседних страницах — по id и по
  /// client_message_id отсекаем повтор.
  bool _contains(ChatMessage message) {
    if (_indexOfId(message.id) >= 0) return true;
    final clientId = message.clientMessageId;
    return clientId != null && _indexOfClientId(clientId) >= 0;
  }

  int _indexOfId(String id) => _messages.indexWhere((m) => m.id == id);

  int _indexOfClientId(String clientId) =>
      _messages.indexWhere((m) => m.clientMessageId == clientId);
}

/// Человеческий текст ошибки вместо «Instance of ApiException».
String describeApiError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Войдите, чтобы продолжить переписку';
    if (error.statusCode == 403) return 'Нет доступа к этому диалогу';
    if (error.statusCode == 404) return 'Диалог не найден';
    return error.message;
  }
  if (error is NetworkException) return error.message;
  return 'Что-то пошло не так. Попробуйте ещё раз';
}
