import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';

class WalletHistoryPage extends StatefulWidget {
  const WalletHistoryPage({super.key});

  @override
  State<WalletHistoryPage> createState() => _WalletHistoryPageState();
}

class _WalletHistoryPageState extends State<WalletHistoryPage> {
  int _selectedFilter = 0; // 0: Все операции, 1: Пополнение, 2: Списание, 3: Бонусы

  final List<String> _filters = [
    'Все операции',
    'Пополнение',
    'Списание',
    'Бонусы',
  ];

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Кнопка назад
                    GestureDetector(
                      onTap: () {
                        final state = AppScope.read(context);
                        final profileRoute = state.pro ? Routes.pro : Routes.profile;
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushNamedAndRemoveUntil(context, profileRoute, (r) => false);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Icon(Icons.arrow_back_ios_new, size: 20.0, color: Color(0xff000000)),
                      ),
                    ),

                    // Заголовок
                    const Text(
                      'История пополнения',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      'Сатүрн — шестая планета по удалённости от Солнца и вторая по размерам планета',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Color(0x993c3c43),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Фильтры-чипы
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_filters.length, (index) {
                          final isSelected = _selectedFilter == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: isSelected ? orangeColor : const Color(0xffe5e5ea),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  _filters[index],
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? orangeColor : const Color(0x993c3c43),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Контент в зависимости от фильтра
                    ..._buildFilterContent(),
                  ],
                ),
              ),
            ),

            // Фирменная оранжевая кнопка «Далее»
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: () {
                    final state = AppScope.read(context);
                    final nextRoute = state.pro ? Routes.pro : Routes.profile;
                    Navigator.pushNamedAndRemoveUntil(context, nextRoute, (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orangeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Далее',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilterContent() {
    switch (_selectedFilter) {
      case 1: // Пополнение
        return [
          _buildDateHeader('21 августа'),
          _buildCoinRow('+12 000 сом (12 000 кирпичей)'),
          _buildBrickRow('+1 200 кирпичей (бонус за пополнение)', isPositive: true),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
          const SizedBox(height: 20.0),
          _buildDateHeader('20 августа'),
          _buildCoinRow('+12 000 сом (12 000 кирпичей)'),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
        ];

      case 2: // Списание
        return [
          _buildDateHeader('21 августа'),
          _buildBrickRow('-500 кирпичей', isPositive: false),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
        ];

      case 3: // Бонусы
        return [
          _buildDateHeader('21 августа'),
          _buildBrickRow('+1 200 кирпичей (бонус за пополнение)', isPositive: true),
          _buildBrickRow('+300 кирпичей (бонус за квест)', isPositive: true),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
        ];

      case 0: // Все операции
      default:
        return [
          _buildDateHeader('21 августа'),
          _buildCoinRow('+12 000 сом (12 000 кирпичей)'),
          _buildBrickRow('+1 200 кирпичей (бонус за пополнение)', isPositive: true),
          _buildBrickRow('-500 кирпичей', isPositive: false),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
          const SizedBox(height: 20.0),
          _buildDateHeader('20 августа'),
          _buildCoinRow('+12 000 сом (12 000 кирпичей)'),
          _buildBrickRow('-500 кирпичей', isPositive: false),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xffe5e5ea), height: 1),
        ];
    }
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17.0,
          fontWeight: FontWeight.bold,
          color: Color(0xff000000),
        ),
      ),
    );
  }

  Widget _buildCoinRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.0,
            height: 34.0,
            child: Center(
              child: Image.asset(
                'assets/figma/c9723efccfaf2ac1.png',
                width: 24.0,
                height: 24.0,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on,
                  size: 20.0,
                  color: Color(0xff8e8e93),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: Color(0xff34c759),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrickRow(String text, {required bool isPositive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.0,
            height: 34.0,
            child: Image.asset(
              'assets/figma/7d929ed14946ddce.png',
              width: 50.0,
              height: 34.0,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xff34c759) : const Color(0xffff3b30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
