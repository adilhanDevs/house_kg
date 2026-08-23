import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../ui/app_tab_bar.dart';

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
                    // Back button
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushNamed(context, Routes.home);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Icon(Icons.arrow_back_ios_new, size: 20.0, color: Color(0xff000000)),
                      ),
                    ),

                    // Header Title
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

                    // Filter chips
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

                    // 21 августа section
                    if (_selectedFilter == 0 || _selectedFilter == 1 || _selectedFilter == 2 || _selectedFilter == 3) ...[
                      const Text(
                        '21 августа',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff000000),
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      if (_selectedFilter == 0 || _selectedFilter == 1)
                        _buildTransactionRow('+12 000 сом (12 000 кирпичей)', Colors.green, isBonus: false),
                      if (_selectedFilter == 0 || _selectedFilter == 1 || _selectedFilter == 3)
                        _buildTransactionRow('+1 200 кирпичей (бонус за пополнение)', Colors.green, isBonus: true),
                      if (_selectedFilter == 0 || _selectedFilter == 2)
                        _buildTransactionRow('-500 кирпичей', Colors.red, isBonus: true),
                      const SizedBox(height: 12.0),
                      const Divider(color: Color(0xffe5e5ea), height: 1),
                      const SizedBox(height: 16.0),
                    ],

                    // 20 августа section
                    if (_selectedFilter == 0 || _selectedFilter == 1 || _selectedFilter == 2) ...[
                      const Text(
                        '20 августа',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff000000),
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      if (_selectedFilter == 0 || _selectedFilter == 1)
                        _buildTransactionRow('+12 000 сом (12 000 кирпичей)', Colors.green, isBonus: false),
                      if (_selectedFilter == 0 || _selectedFilter == 2)
                        _buildTransactionRow('-500 кирпичей', Colors.red, isBonus: true),
                      const SizedBox(height: 12.0),
                      const Divider(color: Color(0xffe5e5ea), height: 1),
                    ],
                  ],
                ),
              ),
            ),

            // Fixed Bottom Button "Далее"
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
      // Без SafeArea: полоса под жест уже заложена в самом таб-баре макета.
      bottomNavigationBar: const AppTabBar(active: 4),
    );
  }

  Widget _buildTransactionRow(String text, Color color, {required bool isBonus}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (isBonus) ...[
            Container(
              width: 20.0,
              height: 14.0,
              decoration: BoxDecoration(
                color: const Color(0xffb83227),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
