import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/listings.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import '../widgets/safe_image.dart';

const Color _accent = Color(0xffea812e);
const Color _ink = Color(0xff000000);
const Color _muted = Color(0x993c3c43);
const Color _line = Color(0xffe5e5ea);
const Color _accentSoft = Color(0xfffdf1e8);

/// Поля страницы и шаг сетки.
const double _side = 20.0;
const double _gap = 6.0;

/// Сколько объектов в ряду.
const int _columns = 3;

/// Порядок в истории.
enum _Order {
  newest,
  oldest;

  String localized(dynamic l10n) => switch (this) {
        _Order.newest => l10n.historyOrderNewest,
        _Order.oldest => l10n.historyOrderOldest,
      };
}

/// Срок по умолчанию — тот, о котором говорит подпись под чипами.
const _Period _kPeriod = _Period.month;

/// За какой срок показывать.
enum _Period {
  all(null),
  today(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30));

  const _Period(this.span);
  final Duration? span;

  String localized(dynamic l10n) => switch (this) {
        _Period.all => l10n.historyPeriodAll,
        _Period.today => l10n.historyPeriodToday,
        _Period.week => l10n.historyPeriodWeek,
        _Period.month => l10n.historyPeriodMonth,
      };
}

class ViewHistoryPage extends StatefulWidget {
  const ViewHistoryPage({super.key});

  @override
  State<ViewHistoryPage> createState() => _ViewHistoryPageState();
}

class _ViewHistoryPageState extends State<ViewHistoryPage> {
  _Order _order = _Order.newest;
  _Period _period = _kPeriod;
  PropertyKind? _kind;

  /// Режим выбора и что в нём отмечено.
  bool _selecting = false;
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).loadViewHistory();
    });
  }

  List<ViewEntry> _entries(AppState state) {
    final now = DateTime.now();
    final list = state.viewed.where((e) {
      final span = _period.span;
      if (span != null && now.difference(e.at) > span) return false;
      if (_kind != null && e.listing.kind != _kind) return false;
      return true;
    }).toList();
    list.sort((a, b) => _order == _Order.newest
        ? b.at.compareTo(a.at)
        : a.at.compareTo(b.at));
    return list;
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _picked.clear();
    });
  }

  void _open(ViewEntry entry) {
    if (_selecting) {
      setState(() {
        _picked.contains(entry.id)
            ? _picked.remove(entry.id)
            : _picked.add(entry.id);
      });
      return;
    }
    Navigator.of(context)
        .pushNamed(Routes.listingVideo, arguments: ListingArgs(entry.id));
  }

  void _remove(AppState state) {
    state.forgetViewed(_picked);
    setState(() {
      _picked.clear();
      _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;
    final entries = _entries(state);

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(l10n),
            Padding(
              padding: const EdgeInsets.fromLTRB(_side, 14, _side, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Dropdown(
                      label: _order.localized(l10n),
                      selected: _order != _Order.newest,
                      onTap: () => _pickOrder(l10n),
                    ),
                    const SizedBox(width: 8),
                    _Dropdown(
                      label: _period.localized(l10n),
                      selected: _period != _kPeriod,
                      onTap: () => _pickPeriod(l10n),
                    ),
                    const SizedBox(width: 8),
                    _Dropdown(
                      label: _kind?.localized(l10n) ?? l10n.historyAllTypes,
                      selected: _kind != null,
                      onTap: () => _pickKind(l10n),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_side, 14, _side, 14),
              child: Text(
                l10n.historySubtitle,
                style: const TextStyle(fontSize: 13.0, color: _muted, height: 1.35),
              ),
            ),
            Expanded(
              child: state.isHistoryLoading && entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.loading,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : entries.isEmpty
                      ? _Empty(message: l10n.historyEmpty)
                      : _Grid(
                          entries: entries,
                          selecting: _selecting,
                          picked: _picked,
                          onTap: _open,
                        ),
            ),
            if (_selecting)
              Padding(
                padding: const EdgeInsets.fromLTRB(_side, 12, _side, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: _picked.isEmpty ? null : () => _remove(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _line,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _picked.isEmpty
                          ? l10n.historyClearSelection
                          : l10n.historyRemovePicked(_picked.length),
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: _picked.isEmpty ? _muted : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppTabBar(active: 2),
    );
  }

  Widget _header(dynamic l10n) => Padding(
        padding: const EdgeInsets.fromLTRB(_side, 12, _side, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                l10n.tabHistory,
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleSelecting,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  _selecting ? l10n.historyDone : l10n.historySelect,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _pickOrder(dynamic l10n) async {
    final picked = await _choose<_Order>(
      title: l10n.historyOrderTitle,
      options: _Order.values,
      label: (o) => o.localized(l10n),
      current: _order,
    );
    if (picked != null) setState(() => _order = picked);
  }

  Future<void> _pickPeriod(dynamic l10n) async {
    final picked = await _choose<_Period>(
      title: l10n.historyPeriodTitle,
      options: _Period.values,
      label: (p) => p.localized(l10n),
      current: _period,
    );
    if (picked != null) setState(() => _period = picked);
  }

  Future<void> _pickKind(dynamic l10n) async {
    final picked = await _choose<int>(
      title: l10n.filterPropertyType,
      options: [for (var i = 0; i <= PropertyKind.values.length; i++) i],
      label: (i) => i == 0 ? l10n.historyAllTypes : PropertyKind.values[i - 1].localized(l10n),
      current: _kind == null ? 0 : PropertyKind.values.indexOf(_kind!) + 1,
    );
    if (picked == null) return;
    setState(() => _kind = picked == 0 ? null : PropertyKind.values[picked - 1]);
  }

  Future<T?> _choose<T>({
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(_side, 16, _side, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            for (final option in options)
              InkWell(
                onTap: () => Navigator.of(context).pop(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _side,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(option),
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: option == current
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: option == current ? _accent : _ink,
                          ),
                        ),
                      ),
                      if (option == current)
                        const Icon(Icons.check, size: 18, color: _accent),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Чип-выпадашка: подпись и галочка вниз.
class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: selected ? _accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: selected ? _accent : _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _accent : _muted,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                size: 15,
                color: selected ? _accent : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сетка просмотренного: три плитки в ряд.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.entries,
    required this.selecting,
    required this.picked,
    required this.onTap,
  });

  final List<ViewEntry> entries;
  final bool selecting;
  final Set<String> picked;
  final void Function(ViewEntry) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(_side, 0, _side, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        crossAxisSpacing: _gap,
        mainAxisSpacing: _gap,
        childAspectRatio: 3 / 4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) => HistoryTile(
        entry: entries[i],
        selecting: selecting,
        picked: picked.contains(entries[i].id),
        onTap: () => onTap(entries[i]),
      ),
    );
  }
}

/// Плитка объекта: фотография, цена и район поверх затемнения.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.entry,
    required this.selecting,
    required this.picked,
    required this.onTap,
  });

  final ViewEntry entry;
  final bool selecting;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listing = entry.listing;
    return Semantics(
      button: true,
      selected: selecting ? picked : null,
      label: listing.district,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              (listing.photo.startsWith('http://') || listing.photo.startsWith('https://'))
                  ? buildSafeNetworkImage(
                      url: listing.photo,
                      fit: BoxFit.cover,
                      fallback: const ColoredBox(color: Color(0xffd9d9d9)),
                    )
                  : Image.asset(
                      listing.photo,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) =>
                          const ColoredBox(color: Color(0xffd9d9d9)),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing.district,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xccffffff),
                      ),
                    ),
                    Text(
                      listing.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x59000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      _ago(entry.at),
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xf2ffffff),
                      ),
                    ),
                  ),
                ),
              ),
              if (selecting)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: picked ? _accent : const Color(0x66000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: picked
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «2 ч назад» — когда объект открывали.
String _ago(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
  if (diff.inHours < 24) return '${diff.inHours} ч';
  return '${diff.inDays} дн';
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.0, color: _muted, height: 1.4),
          ),
        ),
      );
}
