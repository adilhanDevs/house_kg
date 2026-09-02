// Диалог по объявлению.
//
// Порядок и пагинацию держит ChatController: экран только рисует. Список
// перевёрнут (reverse: true), поэтому «низ» — это начало списка, и подгрузка
// старых сообщений вверх не сдвигает то, что человек читает.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/chat_controller.dart';
import '../../data/chat_models.dart';
import '../../fig/fig.dart';

const Key kChatInputKey = Key('chat_input');
const Key kChatSendKey = Key('chat_send');
const Key kChatListKey = Key('chat_list');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);
const Color _danger = Color(0xffd93025);
const Color _peerBubble = Color(0xfff1f1f4);

/// Аргументы экрана: диалог известен по id, остальное подгружается.
@immutable
class ChatArgs {
  const ChatArgs(this.conversationId, {this.peerName, this.listingTitle});

  final String conversationId;
  final String? peerName;
  final String? listingTitle;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.args});

  final ChatArgs args;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  ChatController? _chat;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Conversation? _conversation;
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    _chat?.removeListener(_onChatChanged);
    _chat?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final state = AppScope.read(context);
    final chat = ChatController(
      api: state.apiClient,
      conversationId: widget.args.conversationId,
      // Свой id из AppState не берём: там сейчас идут чужие правки. «Своё»
      // сообщение определяется от обратного — по id собеседника из диалога.
      myUserId: 0,
    )..addListener(_onChatChanged);
    setState(() => _chat = chat);

    // Шапку тянем отдельно: из уведомления известен только id диалога.
    try {
      final data = await state.apiClient.getConversation(widget.args.conversationId);
      if (mounted) setState(() => _conversation = Conversation.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => _fatalError = describeApiError(e));
    }

    await chat.loadInitial();
    if (!mounted) return;
    await chat.markRead();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  /// Список перевёрнут: край прокрутки — это самые старые сообщения.
  void _onScroll() {
    final chat = _chat;
    if (chat == null || !chat.hasOlder || chat.isLoadingOlder) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      chat.loadOlder();
    }
  }

  Future<void> _send() async {
    final chat = _chat;
    final text = _input.text.trim();
    if (chat == null || text.isEmpty || chat.isSending) return;

    _input.clear();
    await chat.send(text);
    if (!mounted) return;
    // К своему сообщению прокручиваем: оно в перевёрнутом списке в самом низу.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Своё сообщение — то, которое отправил не собеседник.
  ///
  /// Пока диалог не загружен, своими считаются только неподтверждённые
  /// пузыри: их отправляли прямо сейчас с этого экрана.
  bool _isMine(ChatMessage message, ChatController chat) {
    final peerId = _conversation?.peer.id;
    if (peerId == null || peerId == 0) return message.isPending;
    return message.senderId != peerId;
  }

  String get _title =>
      _conversation?.peer.name ?? widget.args.peerName ?? 'Диалог';

  String? get _subtitle =>
      _conversation?.listingTitle.isNotEmpty == true
          ? _conversation!.listingTitle
          : widget.args.listingTitle;

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final subtitle = _subtitle;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              style: figStyle(
                fontSize: 16.0,
                family: FigFont.display,
                weight: 600,
                height: 1.2,
                color: const Color(0xff000000),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
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
        actions: [
          if (_conversation?.listingSlug.isNotEmpty == true)
            IconButton(
              tooltip: 'Открыть объявление',
              icon: const Icon(Icons.home_work_outlined, color: _accent),
              onPressed: () => Navigator.of(context).pushNamed(
                Routes.listing,
                arguments: ListingArgs(_conversation!.listingSlug),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body(chat)),
            _Composer(
              controller: _input,
              sending: chat?.isSending ?? false,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ChatController? chat) {
    if (_fatalError != null && (chat == null || chat.isEmpty)) {
      return _Centered(
        text: _fatalError!,
        actionLabel: 'Повторить',
        onAction: _bootstrap,
      );
    }
    if (chat == null || (chat.isLoading && chat.isEmpty)) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (chat.error != null && chat.isEmpty) {
      return _Centered(
        text: chat.error!,
        actionLabel: 'Повторить',
        onAction: chat.loadInitial,
      );
    }
    if (chat.isEmpty) {
      return const _Centered(text: 'Начните диалог');
    }

    // reverse: true — первый элемент внизу экрана.
    final items = chat.messages.reversed.toList();
    return ListView.builder(
      key: kChatListKey,
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: items.length + (chat.hasOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(strokeWidth: 2.0, color: _accent),
              ),
            ),
          );
        }
        final message = items[index];
        return _Bubble(
          message: message,
          mine: _isMine(message, chat),
          onRetry: () => chat.retry(message),
        );
      },
    );
  }
}

/// Пузырь сообщения. Свои — справа оранжевым, чужие — слева серым.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.onRetry});

  final ChatMessage message;
  final bool mine;
  final VoidCallback onRetry;

  String get _time {
    final at = message.createdAt;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final failed = message.status == MessageStatus.failed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
              decoration: BoxDecoration(
                color: mine ? _accent : _peerBubble,
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Text(
                message.text,
                style: figStyle(
                  fontSize: 15.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.3,
                  color: mine ? const Color(0xffffffff) : const Color(0xff1c1939),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                failed ? 'Не отправлено' : _time,
                style: figStyle(
                  fontSize: 11.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.2,
                  color: failed ? _danger : _muted,
                ),
              ),
              if (message.status == MessageStatus.sending) ...[
                const SizedBox(width: 6.0),
                const SizedBox(
                  width: 10.0,
                  height: 10.0,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: _muted),
                ),
              ],
              if (failed) ...[
                const SizedBox(width: 8.0),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRetry,
                  child: Text(
                    'Повторить',
                    style: figStyle(
                      fontSize: 11.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.2,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Поле ввода и кнопка отправки.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffe5e5ea))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: kChatInputKey,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Сообщение',
                hintStyle: figStyle(fontSize: 15.0, family: FigFont.display, color: _muted),
                filled: true,
                fillColor: _peerBubble,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          GestureDetector(
            key: kChatSendKey,
            behavior: HitTestBehavior.opaque,
            // Пока запрос в пути, повторное нажатие не проходит: логическое
            // сообщение должно остаться одним.
            onTap: sending ? null : onSend,
            child: Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                color: sending ? _accent.withValues(alpha: 0.6) : _accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward, color: Color(0xffffffff), size: 20.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.actionLabel, this.onAction});

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
