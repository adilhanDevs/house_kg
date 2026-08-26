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
  (PropertyKind.room, 'Комната', 143, 188, 82),
  (PropertyKind.commercial, 'Коммерция', 233, 188, 101),
];

/// Второй ряд «Типа недвижимости» — признаки самого дома, а не его вида.
const Rect _secondaryChip = Rect.fromLTWH(25, 226, 87, 30);
const Rect _seriesChip = Rect.fromLTWH(120, 226, 91, 30);


/// Ряд «Квадратуры»: четыре диапазона и поле для своего. В макете он шире
/// экрана и уезжает за правый край, поэтому здесь он прокручивается вбок.
const double _areaTop = 390;
const List<double> _areaWidths = [68, 68, 67, 67];
const double _customAreaWidth = 186;
const double _areaLeft = 25;
const double _areaGap = 8;


class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  TextEditingController? _from;
  TextEditingController? _to;
  TextEditingController? _area;
  TextEditingController? _customRoomsCtrl;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _from = TextEditingController(text: state.priceFrom?.toString() ?? '');
    _to = TextEditingController(text: state.priceTo?.toString() ?? '');
    _area = TextEditingController(text: state.customArea?.label ?? '');
    _customRoomsCtrl = TextEditingController(text: state.customRooms?.toString() ?? '');
  }

  @override
  void dispose() {
    _from?.dispose();
    _to?.dispose();
    _area?.dispose();
    _customRoomsCtrl?.dispose();
    super.dispose();
  }

  TextEditingController _getFrom(AppState state) =>
      _from ??= TextEditingController(text: state.priceFrom?.toString() ?? '');
  TextEditingController _getTo(AppState state) =>
      _to ??= TextEditingController(text: state.priceTo?.toString() ?? '');
  TextEditingController _getArea(AppState state) =>
      _area ??= TextEditingController(text: state.customArea?.label ?? '');
  TextEditingController _getRoomsCtrl(AppState state) =>
      _customRoomsCtrl ??= TextEditingController(text: state.customRooms?.toString() ?? '');

  void _applyPrice(AppState state) {
    state.setPrice(
      from: int.tryParse(_getFrom(state).text.replaceAll(' ', '')),
      to: int.tryParse(_getTo(state).text.replaceAll(' ', '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fromCtrl = _getFrom(state);
    final toCtrl = _getTo(state);
    final areaCtrl = _getArea(state);
    final roomsCtrl = _getRoomsCtrl(state);

    return FigStage(
      frame: frame('12'),
      background: const Color(0xfffefefe),
      bottomBar: const AppTabBar(active: 1),
      overlays: [
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
        Positioned(
          left: 0,
          top: 308,
          right: 0,
          height: FigChip.height,
          child: ColoredBox(
            color: const Color(0xfffefefe),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              children: [
                for (final (rooms, label, w) in const [
                  (1, '1 ком.', 65.0),
                  (2, '2 ком.', 67.0),
                  (3, '3 ком.', 67.0),
                  (4, '4 ком.', 67.0),
                ]) ...[
                  FigChip(
                    label: label,
                    width: w,
                    selected: state.rooms.contains(rooms),
                    onTap: () => state.toggleRooms(rooms),
                  ),
                  const SizedBox(width: 8),
                ],
                FigChipInput(
                  width: 130,
                  controller: roomsCtrl,
                  hint: 'Своё кол-во',
                  keyboardType: TextInputType.number,
                  onChanged: (text) => state.setCustomRooms(int.tryParse(text.replaceAll(' ', ''))),
                ),
              ],
            ),
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
                  controller: areaCtrl,
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
            controller: fromCtrl,
            hint: 'Цена от',
            keyboardType: TextInputType.number,
            searchIcon: false,
            onChanged: (_) => _applyPrice(state),
          ),
        ),
        Positioned(
          left: 191,
          top: 475,
          child: FigInputBox(
            width: 158,
            controller: toCtrl,
            hint: 'Цена до',
            keyboardType: TextInputType.number,
            searchIcon: false,
            onChanged: (_) => _applyPrice(state),
          ),
        ),
        Positioned(
          left: 25,
          top: 560,
          right: 25,
          height: 86,
          child: ColoredBox(
            color: const Color(0xfffefefe),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (seller, label) in const [
                  (SellerKind.owner, 'Только собственник'),
                  (SellerKind.realtor, 'Риелторы'),
                  (SellerKind.agency, 'Агенство недвижимости'),
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                          letterSpacing: -0.15,
                          color: Color(0xff85858a),
                        ),
                      ),
                      FigToggle(
                        value: state.sellers.contains(seller),
                        label: label,
                        onChanged: (_) => state.toggleSeller(seller),
                      ),
                    ],
                  ),
              ],
            ),
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
                    text: state.results.isEmpty
                        ? 'Ничего не найдено'
                        : 'Показать варианты (${state.results.length})',
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
