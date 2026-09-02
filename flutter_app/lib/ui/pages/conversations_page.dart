// Список диалогов.
//
// Данные и порядок отдаёт сервер (курсорная пагинация по last_message_at),
// клиент только показывает и подгружает следующую страницу.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/chat_controller.dart' show describeApiError;
import '../../data/chat_models.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import 'chat_page.dart';

const Key kConversationsListKey = Key('conversations_list');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final List<Conversation> _items = [];
  final ScrollController _scroll = ScrollController();

  String? _nextCursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_nextCursor == null || _isLoadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await AppScope.read(context).apiClient.getConversations();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_parse(page));
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
    setState(() => _isLoadingMore = true);
    try {
      final page =
          await AppScope.read(context).apiClient.getConversations(cursor: cursor);
      if (!mounted) return;
      setState(() {
        final known = _items.map((c) => c.id).toSet();
        _items.addAll(_parse(page).where((c) => !known.contains(c.id)));
        _nextCursor = page['next'] as String?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<Conversation> _parse(Map<String, dynamic> page) {
    final results = page['results'];
    if (results is! List) return const [];
    return [
      for (final item in results)
        if (item is Map<String, dynamic>) Conversation.fromJson(item),
    ];
  }

  Future<void> _open(Conversation conversation) async {
    await Navigator.of(context).pushNamed(
      Routes.conversation,
      arguments: ChatArgs(
        conversation.id,
        peerName: conversation.peer.name,
        listingTitle: conversation.listingTitle,
      ),
    );
    // Вернулись из диалога — счётчики непрочитанного могли измениться.
    if (mounted) await _load();
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
          l10n.chatTitle,
          style: figStyle(
            fontSize: 17.0,
            family: FigFont.display,
            weight: 600,
            height: 1.2,
            color: const Color(0xff000000),
          ),
        ),
      ),
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
      return _Placeholder(text: l10n.chatEmpty);
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: ListView.separated(
        key: kConversationsListKey,
        controller: _scroll,
        itemCount: _items.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1.0, color: Color(0xffeeeeee)),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20.0,
                  height: 20.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: _accent),
                ),
              ),
            );
          }
          return _ConversationTile(
            conversation: _items[index],
            onTap: () => _open(_items[index]),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  String get _time {
    final at = conversation.latestMessage?.createdAt ?? conversation.lastMessageAt;
    if (at == null) return '';
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
    }
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = conversation.latestMessage?.text ?? 'Диалог начат';
    final avatar = conversation.peer.avatarUrl;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24.0,
              backgroundColor: const Color(0xfff1f1f4),
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage(avatar)
                  : null,
              child: avatar == null || avatar.isEmpty
                  ? const Icon(Icons.person_outline, color: _muted)
                  : null,
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
                          conversation.peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: 600,
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
                  if (conversation.listingTitle.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      conversation.listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figStyle(
                        fontSize: 12.0,
                        family: FigFont.display,
                        weight: 500,
                        height: 1.2,
                        color: _accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figStyle(
                            fontSize: 13.0,
                            family: FigFont.display,
                            weight: 500,
                            height: 1.3,
                            color: _muted,
                          ),
                        ),
                      ),
                      // Счётчик непрочитанного считает сервер — своего не заводим.
                      if (conversation.hasUnread) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: figStyle(
                              fontSize: 11.0,
                              family: FigFont.display,
                              weight: 700,
                              height: 1.2,
                              color: const Color(0xffffffff),
                            ),
                          ),
                        ),
                      ],
                    ],
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
