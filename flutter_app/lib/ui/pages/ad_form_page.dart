import 'package:flutter/material.dart';

import '../../data/listings.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../fig_controls.dart';

const List<String> kBishkekDistricts = [
  'Район Бишкека',
  'Асанбай',
  'Центр',
  'Октябрьский',
  'Первомайский',
  'Свердловский',
  'Ленинский',
  'Джал',
  '7-й микрорайон',
  '10-й микрорайон',
  'Кок-Жар',
];

/// Страница «Добавить недвижимость» (Чистый Flutter layout без наложения дублирующихся графических кадеров).
class AdFormPage extends StatefulWidget {
  const AdFormPage({super.key});

  @override
  State<AdFormPage> createState() => _AdFormPageState();
}

class _AdFormPageState extends State<AdFormPage> {
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _builderController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  void _showDistrictPicker(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Выберите район Бишкека',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: kBishkekDistricts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final district = kBishkekDistricts[index];
                    return ListTile(
                      title: Text(district),
                      trailing: state.draftDistrict == district
                          ? const Icon(Icons.check, color: Color(0xffea812e))
                          : null,
                      onTap: () {
                        state.setDraft(() {
                          state.draftDistrict = district;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const orangeColor = Color(0xffea812e);

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Прогресс-бар сверху
              Container(
                height: 4.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffe8e9f1),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.25,
                  child: Container(
                    decoration: BoxDecoration(
                      color: orangeColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Заголовок и подзаголовок
              const Text(
                'Добавить недвижимость',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.',
                style: TextStyle(
                  fontSize: 14.0,
                  height: 1.35,
                  color: Color(0xff7d7d7d),
                ),
              ),
              const SizedBox(height: 24.0),

              // 1. Тип недвижимости
              _buildSectionTitle('Тип недвижимости'),
              const SizedBox(height: 10.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildChip(
                    label: 'Новостройки',
                    selected: state.draftKinds.contains(PropertyKind.newBuilding),
                    onTap: () => state.setDraft(() {
                      state.draftKinds.clear();
                      state.draftKinds.add(PropertyKind.newBuilding);
                    }),
                  ),
                  _buildChip(
                    label: 'Комната',
                    selected: state.draftKinds.contains(PropertyKind.room),
                    onTap: () => state.setDraft(() {
                      state.draftKinds.clear();
                      state.draftKinds.add(PropertyKind.room);
                    }),
                  ),
                  _buildChip(
                    label: 'Коммерция',
                    selected: state.draftKinds.contains(PropertyKind.commercial),
                    onTap: () => state.setDraft(() {
                      state.draftKinds.clear();
                      state.draftKinds.add(PropertyKind.commercial);
                    }),
                  ),
                  _buildChip(
                    label: 'Частный дом',
                    selected: state.draftKinds.contains(PropertyKind.house),
                    onTap: () => state.setDraft(() {
                      state.draftKinds.clear();
                      state.draftKinds.add(PropertyKind.house);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 2. Местоположение
              _buildSectionTitle('Местоположение'),
              const SizedBox(height: 10.0),
              GestureDetector(
                onTap: () => _showDistrictPicker(context, state),
                child: Container(
                  height: 44.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f5f7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.draftDistrict.isEmpty ? 'Район Бишкека' : state.draftDistrict,
                        style: TextStyle(
                          fontSize: 15.0,
                          color: state.draftDistrict.isEmpty
                              ? const Color(0x993c3c43)
                              : const Color(0xff000000),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: orangeColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 3. Количество комнат
              _buildSectionTitle('Количество комнат'),
              const SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final roomNum = index + 1;
                  return _buildChip(
                    label: '$roomNum ком.',
                    selected: state.draftRooms == roomNum,
                    onTap: () => state.setDraft(() => state.draftRooms = roomNum),
                  );
                }),
              ),
              const SizedBox(height: 24.0),

              // 4. Квадратура
              _buildSectionTitle('Квадратура'),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _areaController,
                      hintText: 'Введите свою квадратуру...',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => state.setDraft(() => state.draftArea = val),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  _buildChip(label: '45-55', selected: false, onTap: () {}),
                  const SizedBox(width: 8.0),
                  _buildChip(label: '65-75', selected: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: 24.0),

              // 5. Этаж
              _buildSectionTitle('Этаж'),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  for (int index = 0; index < 5; index++) ...[
                    if (index > 0) const SizedBox(width: 8.0),
                    SizedBox(
                      width: 44.0,
                      child: _buildChip(
                        label: '${index + 1}',
                        selected: state.draftFloor == index + 1,
                        onTap: () => state.setDraft(() => state.draftFloor = index + 1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24.0),

              // 6. Кол-во этажей в здании
              _buildSectionTitle('Кол-во этажей в здании'),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  for (int index = 0; index < 5; index++) ...[
                    if (index > 0) const SizedBox(width: 8.0),
                    SizedBox(
                      width: 44.0,
                      child: _buildChip(
                        label: '${index + 1}',
                        selected: state.draftFloors == index + 1,
                        onTap: () => state.setDraft(() => state.draftFloors = index + 1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24.0),

              // 7. Строительная компания
              _buildSectionTitle('Строительная компания'),
              const SizedBox(height: 10.0),
              _buildInputField(
                controller: _builderController,
                hintText: 'Введите строительную компанию',
                onChanged: (val) => state.setDraft(() => state.draftBuilder = val),
              ),
              const SizedBox(height: 24.0),

              // 8. Цена
              _buildSectionTitle('Цена'),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _priceController,
                      hintText: 'Цена',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => state.setDraft(() => state.draftPrice = val),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  _buildChip(
                    label: 'USD',
                    selected: state.draftUsd,
                    onTap: () => state.setDraft(() => state.draftUsd = true),
                  ),
                  const SizedBox(width: 8.0),
                  _buildChip(
                    label: 'KGS',
                    selected: !state.draftUsd,
                    onTap: () => state.setDraft(() => state.draftUsd = false),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 9. Вы являетесь?
              _buildSectionTitle('Вы являетесь?'),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: 'Собственником',
                value: state.draftOwner,
                onChanged: (val) => state.setDraft(() => state.draftOwner = val),
              ),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: 'Риелтором',
                value: !state.draftOwner,
                onChanged: (val) => state.setDraft(() => state.draftOwner = !val),
              ),
              const SizedBox(height: 12.0),
              _buildToggleRow(
                label: 'Агентством недвижимости',
                value: false,
                onChanged: (_) {},
              ),
              const SizedBox(height: 32.0),

              // 10. Кнопка Далее
              SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.adPhotos),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    'Далее',
                    style: TextStyle(
                      fontSize: 17.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: Color(0xff000000),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const orangeColor = Color(0xffea812e);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xfffdf1e8) : const Color(0xffffffff),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: selected ? const Color(0xfffdf1e8) : const Color(0xffe5e5ea),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? orangeColor : const Color(0xff7d7d7d),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 44.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f7),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15.0, color: Color(0xff000000)),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 15.0, color: Color(0x993c3c43)),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15.0,
            color: Color(0xff3c3c43),
          ),
        ),
        FigToggle(
          value: value,
          label: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
