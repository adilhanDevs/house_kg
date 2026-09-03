import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/kind_fields.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import '../fig_controls.dart';

const Color _accent = Color(0xffea812e);
const Color _page = Color(0xfffefefe);

/// Отступ от края экрана — тот же, что был у кадра.
const double _gutter = 25;

/// Отступ между секциями фильтра — воздуха в макете больше, чем было.
const double _sectionGap = 28;

/// Промежуток между чипами в одном ряду.
const double _chipSpacing = 10;

/// Высота ряда «Продавец» — просторнее прежнего, чтобы тумблер не жался к
/// соседней строке.
const double _sellerRowGap = 16;

/// «Цена от/до» — заметно выше обычного поля входа, как в макете.
const double _priceFieldHeight = 48;
const double _priceFieldRadius = 14;

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

/// Пауза перед запросом количества: пока пользователь щёлкает чипами,
/// на сервер уходит один запрос, а не по одному на каждое нажатие.
const Duration _countDebounce = Duration(milliseconds: 350);

class _FilterPageState extends State<FilterPage> {
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _area;
  late final AppState _appState;

  /// Сколько объявлений подходит под текущий фильтр. Считает сервер: у
  /// клиента нет каталога, по которому можно было бы это узнать.
  int? _count;
  String _signature = '';
  Timer? _debounce;

  /// Номер последнего запроса — ответ на устаревший игнорируется.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _appState = AppScope.read(context);
    _from = TextEditingController(text: _appState.priceFrom?.toString() ?? '');
    _to = TextEditingController(text: _appState.priceTo?.toString() ?? '');
    _area = TextEditingController(text: _appState.customArea?.label ?? '');
    _signature = _appState.filterSignature;
    _appState.addListener(_onFilterChanged);
    _fetchCount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _appState.removeListener(_onFilterChanged);
    _from.dispose();
    _to.dispose();
    _area.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    final signature = _appState.filterSignature;
    if (signature == _signature) return;
    _signature = signature;

    _debounce?.cancel();
    _debounce = Timer(_countDebounce, () {
      if (mounted) _fetchCount();
    });
  }

  Future<void> _fetchCount() async {
    final requestId = ++_requestId;
    try {
      final count = await _appState.apiClient.getListingsCount(
        filters: _appState.filterParams,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _count = count);
    } catch (e) {
      // Счётчик — подсказка на кнопке: из-за него экран фильтра падать или
      // блокироваться не должен. Кнопка просто остаётся без числа.
      if (!mounted || requestId != _requestId) return;
      setState(() => _count = null);
      debugPrint('Не удалось получить количество: $e');
    }
  }

  void _applyPrice() {
    AppScope.read(context).setPrice(
      from: int.tryParse(_from.text.replaceAll(' ', '')),
      to: int.tryParse(_to.text.replaceAll(' ', '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;

    final visible = fieldsForKinds(state.kinds);

    return Scaffold(
      backgroundColor: _page,
      bottomNavigationBar: const AppTabBar(active: 1),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, l10n),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 16),
                children: [
                  _title(l10n.filterPropertyType),
                  Wrap(
                    spacing: _chipSpacing,
                    runSpacing: _chipSpacing,
                    children: [
                      for (final kind in PropertyKind.values)
                        FigChip(
                          label: kind.localized(l10n),
                          selected: state.kinds.contains(kind),
                          onTap: () => state.toggleKind(kind),
                        ),
                      if (visible.contains(ListingField.isSecondary))
                        FigChip(
                          label: l10n.filterSecondary,
                          selected: state.secondaryOnly,
                          onTap: () => state.setSecondaryOnly(!state.secondaryOnly),
                        ),
                      if (visible.contains(ListingField.series))
                        FigChip(
                          label: l10n.filterSeries103,
                          selected: state.series103,
                          onTap: () => state.setSeries103(!state.series103),
                        ),
                    ],
                  ),

                  if (visible.contains(ListingField.rooms)) ...[
                    const SizedBox(height: _sectionGap),
                    _title(l10n.filterRoomsCount),
                    Wrap(
                      spacing: _chipSpacing,
                      runSpacing: _chipSpacing,
                      children: [
                        for (var count = 1; count <= 4; count++)
                          FigChip(
                            label: '$count ${l10n.filterRoomsUnit}',
                            selected: state.rooms.contains(count),
                            onTap: () => state.toggleRooms(count),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: _sectionGap),
                  _title(l10n.filterArea),
                  SizedBox(
                    height: FigChip.height,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final range in kAreaRanges) ...[
                          FigChip(
                            label: range.label,
                            selected: state.areas.contains(range),
                            onTap: () => state.toggleArea(range),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FigChipInput(
                          width: 186,
                          controller: _area,
                          hint: l10n.filterCustomArea,
                          onChanged: (text) => state.setCustomArea(AreaRange.parse(text)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: _sectionGap),
                  _title(l10n.filterPrice),
                  Row(
                    children: [
                      Expanded(
                        child: FigInputBox(
                          width: double.infinity,
                          height: _priceFieldHeight,
                          radius: _priceFieldRadius,
                          controller: _from,
                          hint: l10n.filterPriceFrom,
                          keyboardType: TextInputType.number,
                          searchIcon: false,
                          onChanged: (_) => _applyPrice(),
                        ),
                      ),
                      const SizedBox(width: _chipSpacing),
                      Expanded(
                        child: FigInputBox(
                          width: double.infinity,
                          height: _priceFieldHeight,
                          radius: _priceFieldRadius,
                          controller: _to,
                          hint: l10n.filterPriceTo,
                          keyboardType: TextInputType.number,
                          searchIcon: false,
                          onChanged: (_) => _applyPrice(),
                        ),
                      ),
                    ],
                  ),

                  if (visible.contains(ListingField.plotPurpose)) ...[
                    const SizedBox(height: _sectionGap),
                    _title(l10n.filterPlotPurpose),
                    Wrap(
                      spacing: _chipSpacing,
                      runSpacing: _chipSpacing,
                      children: [
                        for (final entry in plotPurposeLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.plotPurposes.contains(entry.key),
                            onTap: () => state.togglePlotPurpose(entry.key),
                          ),
                      ],
                    ),
                  ],

                  if (visible.contains(ListingField.commercialPurpose)) ...[
                    const SizedBox(height: _sectionGap),
                    _title(l10n.filterCommercialPurpose),
                    Wrap(
                      spacing: _chipSpacing,
                      runSpacing: _chipSpacing,
                      children: [
                        for (final entry in commercialPurposeLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.commercialPurposes.contains(entry.key),
                            onTap: () => state.toggleCommercialPurpose(entry.key),
                          ),
                      ],
                    ),
                  ],

                  if (visible.contains(ListingField.buildingLine)) ...[
                    const SizedBox(height: _sectionGap),
                    _title(l10n.filterBuildingLine),
                    Wrap(
                      spacing: _chipSpacing,
                      runSpacing: _chipSpacing,
                      children: [
                        for (final entry in buildingLineLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.buildingLines.contains(entry.key),
                            onTap: () => state.toggleBuildingLine(entry.key),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: _sectionGap),
                  _title(l10n.filterSeller),
                  for (final seller in SellerKind.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _sellerRowGap),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FigText(
                              span: TextSpan(
                                text: seller.localized(l10n),
                                style: figStyle(
                                  fontSize: 15.0,
                                  family: FigFont.display,
                                  weight: 500,
                                  color: const Color(0xff000000),
                                ),
                              ),
                            ),
                          ),
                          FigToggle(
                            value: state.sellers.contains(seller),
                            onChanged: (_) => state.toggleSeller(seller),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _showResults(context, state, l10n),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 8),
      child: Row(
        children: [
          FigText(
            span: TextSpan(
              text: l10n.filterTitle,
              style: figStyle(
                fontSize: 24.0,
                family: FigFont.display,
                weight: 600,
                color: const Color(0xff000000),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xff7d7d7d)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FigText(
        span: TextSpan(
          text: text,
          style: figStyle(
            fontSize: 18.0,
            family: FigFont.display,
            weight: 700,
            color: const Color(0xff000000),
          ),
        ),
      ),
    );
  }

  Widget _showResults(BuildContext context, AppState state, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, Routes.catalog);
          }
        },
        child: FigBox(
          width: double.infinity,
          height: 48,
          radius: 12,
          color: _accent,
          child: Center(
            child: FigText(
              noWrap: true,
              span: TextSpan(
                text: _count == null
                    ? l10n.catalogShowListings
                    : l10n.filterShowVariants(_count!),
                style: figStyle(
                  fontSize: 16.0,
                  family: FigFont.display,
                  weight: 600,
                  height: 1.0,
                  color: const Color(0xffffffff),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
