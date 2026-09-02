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

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _area;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _from = TextEditingController(text: state.priceFrom?.toString() ?? '');
    _to = TextEditingController(text: state.priceTo?.toString() ?? '');
    _area = TextEditingController(text: state.customArea?.label ?? '');
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _area.dispose();
    super.dispose();
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
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in PropertyKind.values)
                        FigChip(
                          label: kind.localized(l10n),
                          selected: state.kinds.contains(kind),
                          onTap: () => state.toggleKind(kind),
                        ),
                    ],
                  ),

                  if (visible.contains(ListingField.isSecondary) ||
                      visible.contains(ListingField.series)) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                  ],

                  if (visible.contains(ListingField.rooms)) ...[
                    const SizedBox(height: 20),
                    _title(l10n.filterRoomsCount),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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

                  const SizedBox(height: 20),
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

                  const SizedBox(height: 20),
                  _title(l10n.filterPrice),
                  Row(
                    children: [
                      Expanded(
                        child: FigInputBox(
                          width: double.infinity,
                          controller: _from,
                          hint: l10n.filterPriceFrom,
                          keyboardType: TextInputType.number,
                          searchIcon: false,
                          onChanged: (_) => _applyPrice(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FigInputBox(
                          width: double.infinity,
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
                    const SizedBox(height: 20),
                    _title(l10n.filterPlotPurpose),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                    const SizedBox(height: 20),
                    _title(l10n.filterCommercialPurpose),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                    const SizedBox(height: 20),
                    _title(l10n.filterBuildingLine),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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

                  const SizedBox(height: 20),
                  _title(l10n.filterSeller),
                  for (final seller in SellerKind.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: FigText(
        span: TextSpan(
          text: text,
          style: figStyle(
            fontSize: 17.0,
            family: FigFont.display,
            weight: 600,
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
                text: l10n.filterShowVariants(state.results.length),
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
