// «Фильтр» — кадр 12 макета с живыми чипами, ценой и тумблерами.
//
// Координаты чипов, полей и тумблеров сняты с кадра, поэтому живые элементы
// встают ровно на нарисованные и закрывают их.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../fig_controls.dart';

/// Чипы «Тип недвижимости», первый ряд.
const List<(PropertyKind, String, double, double, double)> _kindChips = [
  (PropertyKind.newBuilding, 'Новостройки', 25, 188, 110),
  (PropertyKind.room, 'Квартиры', 143, 188, 82),
  (PropertyKind.commercial, 'Коммерция', 233, 188, 101),
];

/// Второй ряд «Типа недвижимости» — признаки самого дома, а не его вида.
const Rect _secondaryChip = Rect.fromLTWH(25, 226, 87, 30);
const Rect _seriesChip = Rect.fromLTWH(120, 226, 91, 30);

/// Чипы «Количество комнат».
const List<(int, String, double, double, double)> _roomChips = [
  (1, '1 ком.', 25, 308, 65),
  (2, '2 ком.', 98, 308, 67),
  (3, '3 ком.', 173, 308, 67),
  (4, '4 ком.', 248, 308, 67),
];

/// Ряд «Квадратуры»: четыре диапазона и поле для своего. В макете он шире
/// экрана и уезжает за правый край, поэтому здесь он прокручивается вбок.
const double _areaTop = 390;
const List<double> _areaWidths = [68, 68, 67, 67];
const double _customAreaWidth = 186;
const double _areaLeft = 25;
const double _areaGap = 8;

/// Тумблеры «Продавца».
const double _toggleLeft = 319;
const List<(SellerKind, double)> _sellerToggles = [
  (SellerKind.owner, 563),
  (SellerKind.realtor, 591),
  (SellerKind.agency, 619),
];

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

    return FigStage(
      frame: frame('12'),
      background: const Color(0xfffefefe),
      bottomBar: const AppTabBar(active: 1),
      overlays: [
        // в макете у «Фильтра» кнопки «назад» нет; справа от заголовка пусто —
        // ставим её туда, чтобы не налезала на «Фильтр»
        const FigBackButton(left: 330, top: 62),
        for (final (kind, label, x, y, w) in _kindChips)
          Positioned(
            left: x,
            top: y,
            child: FigChip(
              label: label,
              width: w,
              selected: state.kinds.contains(kind),
              onTap: () => state.toggleKind(kind),
            ),
          ),
        Positioned(
          left: _secondaryChip.left,
          top: _secondaryChip.top,
          child: FigChip(
            label: 'Вторичка',
            width: _secondaryChip.width,
            selected: state.secondaryOnly,
            onTap: () => state.setSecondaryOnly(!state.secondaryOnly),
          ),
        ),
        Positioned(
          left: _seriesChip.left,
          top: _seriesChip.top,
          child: FigChip(
            label: '103 серия',
            width: _seriesChip.width,
            selected: state.series103,
            onTap: () => state.setSeries103(!state.series103),
          ),
        ),
        for (final (rooms, label, x, y, w) in _roomChips)
          Positioned(
            left: x,
            top: y,
            child: FigChip(
              label: label,
              width: w,
              selected: state.rooms.contains(rooms),
              onTap: () => state.toggleRooms(rooms),
            ),
          ),
        Positioned(
          left: 0,
          top: _areaTop,
          right: 0,
          height: FigChip.height,
          child: ColoredBox(
            color: const Color(0xfffefefe),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _areaLeft),
              children: [
                for (var i = 0; i < kAreaRanges.length; i++) ...[
                  FigChip(
                    label: kAreaRanges[i].label,
                    width: _areaWidths[i],
                    selected: state.areas.contains(kAreaRanges[i]),
                    onTap: () => state.toggleArea(kAreaRanges[i]),
                  ),
                  const SizedBox(width: _areaGap),
                ],
                FigChipInput(
                  width: _customAreaWidth,
                  controller: _area,
                  hint: 'Введите свою квадратуру',
                  onChanged: (text) => state.setCustomArea(AreaRange.parse(text)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 25,
          top: 475,
          child: FigInputBox(
            width: 158,
            controller: _from,
            hint: 'Цена от',
            keyboardType: TextInputType.number,
            searchIcon: false,
            onChanged: (_) => _applyPrice(),
          ),
        ),
        Positioned(
          left: 191,
          top: 475,
          child: FigInputBox(
            width: 158,
            controller: _to,
            hint: 'Цена до',
            keyboardType: TextInputType.number,
            searchIcon: false,
            onChanged: (_) => _applyPrice(),
          ),
        ),
        for (final (seller, y) in _sellerToggles)
          Positioned(
            left: _toggleLeft,
            top: y,
            child: FigToggle(
              value: state.sellers.contains(seller),
              label: seller.label,
              onChanged: (_) => state.toggleSeller(seller),
            ),
          ),
        // Кнопка завершения фильтрации («Поиск» / «Показать результаты»)
        Positioned(
          left: 25,
          top: 650,
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
              width: 325,
              height: 48,
              radius: 12,
              color: const Color(0xffea812e),
              child: Center(
                child: FigText(
                  noWrap: true,
                  span: TextSpan(
                    text: 'Показать варианты (${state.results.length})',
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
        ),
        // Заглушка, чтобы снизу под кнопкой не проглядывали серые верха карточек
        const Positioned(
          left: 0,
          top: 700,
          width: 375,
          height: 400,
          child: ColoredBox(color: Color(0xffffffff)),
        ),
      ],
    );
  }
}
