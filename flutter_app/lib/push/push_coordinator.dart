import 'dart:async';

abstract interface class PushMessaging {
  Stream<String> get tokenRefresh;
  Stream<Map<String, dynamic>> get taps;
  Stream<Map<String, dynamic>> get foreground;
  Future<Map<String, dynamic>?> initialMessage();
  Future<bool> permission();
  Future<String?> token();
  Future<void> deleteToken();
}

class PushIntent {
  const PushIntent(
    this.notificationId,
    this.recipientId,
    this.type, {
    this.conversationId,
    this.listingSlug,
  });
  final String notificationId;
  final int recipientId;
  final String type;
  final String? conversationId;
  final String? listingSlug;

  static PushIntent? parse(Map<String, dynamic> data) {
    final id = data['notification_id'];
    final recipient = data['recipient_id'];
    if (id is! String ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(id) ||
        recipient is! String)
      return null;
    final user = int.tryParse(recipient);
    if (user == null || user <= 0) return null;
    final type = data['type'];
    if (type == 'new_message') {
      final conversation = data['conversation_id'];
      if (conversation is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(conversation))
        return null;
      return PushIntent(id, user, type, conversationId: conversation);
    }
    if (type == 'price_drop') {
      final slug = data['listing_slug'];
      if (slug is! String ||
          slug.length > 255 ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(slug))
        return null;
      return PushIntent(id, user, type, listingSlug: slug);
    }
    return null;
  }
}

/// One coordinator per application, independent of Firebase and widget rebuilds.
class PushCoordinator {
  PushCoordinator({
    required this.messaging,
    required this.register,
    required this.deactivate,
    required this.onForeground,
    required this.onPending,
  });
  final PushMessaging messaging;
  final Future<void> Function(String) register;
  final Future<void> Function() deactivate;
  final void Function() onForeground;
  final void Function() onPending;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  Future<void> _queue = Future.value();
  Future<void> get idle => _queue;
  int? _user;
  int _generation = 0;
  bool _disposed = false;
  bool _started = false;
  bool _initialCancelled = false;
  String? _registered;
  PushIntent? _pending;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscriptions.add(
      messaging.tokenRefresh.listen((token) {
        final generation = _generation;
        _enqueue(() => _sync(generation, token: token));
      }, onError: (Object _) {}),
    );
    _subscriptions.add(messaging.taps.listen(_capture, onError: (Object _) {}));
    _subscriptions.add(
      messaging.foreground.listen((data) {
        if (!_disposed && _user != null && data['recipient_id'] == '$_user') {
          onForeground();
        }
      }, onError: (Object _) {}),
    );
    try {
      final initial = await messaging.initialMessage();
      if (initial != null && !_initialCancelled) _capture(initial);
    } catch (_) {
      /* Push must never prevent startup. */
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        /* Retry on resume; never log tokens. */
      }
    });
    return _queue;
  }

  Future<void> setUser(int? user) {
    if (_user == user) return idle;
    if (_user != null) {
      _pending = null;
      _initialCancelled = true;
    }
    _user = user;
    _generation++;
    _registered = null;
    final generation = _generation;
    onPending();
    return _enqueue(() => _sync(generation));
  }

  Future<void> resume() {
    final generation = _generation;
    return _enqueue(() => _sync(generation));
  }

  Future<void> _sync(int generation, {String? token}) async {
    bool current() => !_disposed && _user != null && generation == _generation;
    if (!current()) return;
    final permitted = await messaging.permission();
    if (!current()) return;
    if (!permitted) {
      if (_registered != null) {
        await deactivate();
        _registered = null;
      }
      return;
    }
    final value = token ?? await messaging.token();
    if (!current() || value == null || value.isEmpty || value == _registered)
      return;
    await register(value);
    if (current()) _registered = value;
  }

  /// Called before backend auth is cleared. In-flight registration finishes first.
  Future<void> logout() {
    _initialCancelled = true;
    _generation++;
    _user = null;
    _pending = null;
    _registered = null;
    return _enqueue(() async {
      try {
        await deactivate();
      } finally {
        // Invalidates delivery even if the deactivation request was offline.
        await messaging.deleteToken();
      }
    });
  }

  void _capture(Map<String, dynamic> data) {
    if (_disposed) return;
    final intent = PushIntent.parse(data);
    if (intent == null || _seen.contains(intent.notificationId)) return;
    if (_user != null && intent.recipientId != _user) return;
    _pending = intent;
    onPending();
  }

  PushIntent? takePending({required bool navigationReady}) {
    if (!navigationReady || _user == null || _disposed) return null;
    final intent = _pending;
    _pending = null;
    if (intent == null || intent.recipientId != _user) return null;
    _seen.add(intent.notificationId);
    if (_seen.length > 100) _seen.remove(_seen.first);
    return intent;
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _pending = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
