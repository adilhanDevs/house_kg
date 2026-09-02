// Отправка, идемпотентность и пагинация диалога.
//
// Здесь проверяется то, что легко сломать незаметно: повтор не должен
// создавать второй пузырь, соседние страницы истории не должны дублировать
// сообщения, а порядок при одинаковом created_at задаёт сервер, а не клиент.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/chat_controller.dart';
import 'package:house_kgz/data/chat_models.dart';

const String kConversation = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _message(
  String id, {
  int senderId = 2,
  String text = 'привет',
  String createdAt = '2026-09-01T10:00:00Z',
  String? clientMessageId,
}) =>
    {
      'id': id,
      'sender_id': senderId,
      'text': text,
      'created_at': createdAt,
      'client_message_id': clientMessageId,
    };

/// «Сервер», который отвечает заранее заданными страницами.
class _ChatServer extends http.BaseClient {
  _ChatServer({
    this.pages = const [],
    this.afterPage,
    this.sendFailsTimes = 0,
    this.existingForClientId,
  });

  /// Страницы истории по порядку обращения: первая — самая свежая.
  final List<Map<String, dynamic>> pages;

  /// Ответ на запрос с after=.
  final Map<String, dynamic>? afterPage;

  /// Сколько первых попыток отправки провалить.
  final int sendFailsTimes;

  /// Если задано — POST с этим client_message_id вернёт уже существующее
  /// сообщение со статусом 200, как это делает настоящий сервер.
  final Map<String, dynamic>? existingForClientId;

  int historyCalls = 0;
  int sendCalls = 0;
  final List<Map<String, dynamic>> sentBodies = [];

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'POST' && path.endsWith('/messages/')) {
      sendCalls += 1;
      final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      sentBodies.add(body);
      if (sendCalls <= sendFailsTimes) {
        return _json({
          'error': {'code': 'server_error', 'message': 'Сервер недоступен', 'details': {}}
        }, 500);
      }
      if (existingForClientId != null) {
        // Сервер узнал client_message_id и вернул уже созданное сообщение.
        return _json(existingForClientId!, 200);
      }
      return _json(
        _message(
          'srv-${body['client_message_id']}',
          senderId: 1,
          text: body['text'] as String,
          clientMessageId: body['client_message_id'] as String,
        ),
        201,
      );
    }

    if (request.method == 'GET' && path.endsWith('/messages/')) {
      if (request.url.queryParameters.containsKey('after')) {
        return _json(afterPage ?? {'results': [], 'next': null, 'previous': null, 'count': 0});
      }
      final page = historyCalls < pages.length ? pages[historyCalls] : pages.last;
      historyCalls += 1;
      return _json(page);
    }

    if (request.method == 'POST' && path.endsWith('/read/')) {
      return _json({'updated': 1, 'unread_count': 0});
    }

    return _json(<String, dynamic>{});
  }
}

ChatController _controller(_ChatServer server) => ChatController(
      api: ListingApiClient(baseUrl: 'http://test.com', client: server),
      conversationId: kConversation,
      myUserId: 1,
    );

void main() {
  group('отправка сообщения', () {
    test('одно нажатие — один запрос и один пузырь', () async {
      final server = _ChatServer(
        pages: [
          {'results': [], 'next': null, 'previous': null, 'count': 0}
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.send('Привет');

      expect(server.sendCalls, 1);
      expect(chat.messages.length, 1);
      expect(chat.messages.single.text, 'Привет');
      expect(chat.messages.single.status, MessageStatus.sent);
    });

    test('повтор после ошибки идёт с тем же client_message_id', () async {
      final server = _ChatServer(
        pages: [
          {'results': [], 'next': null, 'previous': null, 'count': 0}
        ],
        sendFailsTimes: 1,
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.send('Привет');
      expect(chat.messages.single.status, MessageStatus.failed);
      final firstId = server.sentBodies.first['client_message_id'];

      await chat.retry(chat.messages.single);

      expect(server.sendCalls, 2);
      expect(
        server.sentBodies[1]['client_message_id'],
        firstId,
        reason: 'повтор с новым id лишил бы сервер защиты от дубля',
      );
      expect(chat.messages.length, 1, reason: 'второй пузырь появиться не должен');
      expect(chat.messages.single.status, MessageStatus.sent);
    });

    test('сервер вернул уже существующее сообщение — дубля нет', () async {
      final existing = _message(
        'srv-existing',
        senderId: 1,
        text: 'Привет',
        clientMessageId: 'cli-1',
      );
      final server = _ChatServer(
        pages: [
          {'results': [], 'next': null, 'previous': null, 'count': 0}
        ],
        existingForClientId: existing,
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.send('Привет');

      expect(chat.messages.length, 1);
      expect(chat.messages.single.id, 'srv-existing');
    });

    test('пока запрос в пути, второе нажатие игнорируется', () async {
      final server = _ChatServer(
        pages: [
          {'results': [], 'next': null, 'previous': null, 'count': 0}
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();

      // Два вызова подряд без ожидания первого.
      final first = chat.send('Привет');
      final second = chat.send('Привет');
      await Future.wait([first, second]);

      expect(server.sendCalls, 1);
      expect(chat.messages.length, 1);
    });

    test('текст пользователя не теряется при ошибке', () async {
      final server = _ChatServer(
        pages: [
          {'results': [], 'next': null, 'previous': null, 'count': 0}
        ],
        sendFailsTimes: 5,
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.send('Важное сообщение');

      expect(chat.messages.single.text, 'Важное сообщение');
      expect(chat.messages.single.status, MessageStatus.failed);
      expect(chat.error, isNotNull);
      expect(chat.error, isNot(contains('Instance of')));
    });
  });

  group('пагинация истории', () {
    test('первая страница показывается в порядке сервера', () async {
      final server = _ChatServer(
        pages: [
          {
            'results': [
              _message('m3', createdAt: '2026-09-01T10:00:02Z'),
              _message('m4', createdAt: '2026-09-01T10:00:03Z'),
            ],
            'next': 'http://test.com/api/v1/conversations/$kConversation/messages/?cursor=older',
            'previous': null,
            'count': 4,
          }
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();

      expect(chat.messages.map((m) => m.id).toList(), ['m3', 'm4']);
      expect(chat.hasOlder, isTrue);
    });

    test('старые сообщения встают перед текущими', () async {
      final server = _ChatServer(
        pages: [
          {
            'results': [_message('m3'), _message('m4')],
            'next': 'http://test.com/api/v1/conversations/$kConversation/messages/?cursor=older',
            'previous': null,
            'count': 4,
          },
          {
            'results': [_message('m1'), _message('m2')],
            'next': null,
            'previous': null,
            'count': 4,
          },
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();
      await chat.loadOlder();

      expect(chat.messages.map((m) => m.id).toList(), ['m1', 'm2', 'm3', 'm4']);
      expect(chat.hasOlder, isFalse);
    });

    test('пересечение соседних страниц не даёт дублей', () async {
      final server = _ChatServer(
        pages: [
          {
            'results': [_message('m2'), _message('m3')],
            'next': 'http://test.com/api/v1/conversations/$kConversation/messages/?cursor=older',
            'previous': null,
            'count': 3,
          },
          {
            // m2 повторяется — так бывает на границе страниц.
            'results': [_message('m1'), _message('m2')],
            'next': null,
            'previous': null,
            'count': 3,
          },
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();
      await chat.loadOlder();

      expect(chat.messages.map((m) => m.id).toList(), ['m1', 'm2', 'm3']);
    });

    test('одинаковое время — порядок сервера сохраняется', () async {
      const sameTime = '2026-09-01T10:00:00Z';
      final server = _ChatServer(
        pages: [
          {
            'results': [
              _message('bbb', createdAt: sameTime),
              _message('aaa', createdAt: sameTime),
              _message('ccc', createdAt: sameTime),
            ],
            'next': null,
            'previous': null,
            'count': 3,
          }
        ],
      );
      final chat = _controller(server);
      await chat.loadInitial();

      // Никакой локальной пересортировки: как отдал сервер, так и лежит.
      expect(chat.messages.map((m) => m.id).toList(), ['bbb', 'aaa', 'ccc']);
    });
  });

  group('докачка новых', () {
    test('запрашивается хвост после последнего сообщения', () async {
      final server = _ChatServer(
        pages: [
          {
            'results': [_message('m1')],
            'next': null,
            'previous': null,
            'count': 1,
          }
        ],
        afterPage: {
          'results': [_message('m2', text: 'новое')],
          'next': null,
          'previous': null,
          'count': 1,
        },
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.fetchNew();

      expect(chat.messages.map((m) => m.id).toList(), ['m1', 'm2']);
      expect(server.historyCalls, 1, reason: 'всю историю перечитывать не нужно');
    });

    test('уже известное сообщение из хвоста не дублируется', () async {
      final server = _ChatServer(
        pages: [
          {
            'results': [_message('m1')],
            'next': null,
            'previous': null,
            'count': 1,
          }
        ],
        afterPage: {
          'results': [_message('m1')],
          'next': null,
          'previous': null,
          'count': 1,
        },
      );
      final chat = _controller(server);
      await chat.loadInitial();

      await chat.fetchNew();

      expect(chat.messages.length, 1);
    });
  });
}
