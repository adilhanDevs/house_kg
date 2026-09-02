import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n.dart';

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

  final ScrollController _scrollController = ScrollController();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadTransactions();
    }
  }

  String? _getKind() {
    switch (_selectedFilter) {
      case 1:
        return 'topup';
      case 2:
        return 'spend';
      case 3:
        return 'bonus';
      default:
        return null;
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _hasMore = true;
      _nextCursor = null;
    }
    
    if (!_hasMore || (_isLoadingMore && !refresh)) return;

    if (refresh) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final state = AppScope.read(context);
      final response = await state.apiClient.getWalletTransactions(
        kind: _getKind(),
        cursor: _nextCursor,
      );
      
      if (mounted) {
        setState(() {
          final results = response['results'] as List<dynamic>? ?? [];
          if (refresh) {
            _transactions = results;
          } else {
            _transactions.addAll(results);
          }
          _nextCursor = response['next'] as String?;
          _hasMore = _nextCursor != null;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _onFilterChanged(int index) {
    if (_selectedFilter == index) return;
    setState(() {
      _selectedFilter = index;
    });
    _loadTransactions(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);
    final l10n = context.l10n;

    final filters = [
      l10n.walletFilterAll,
      l10n.walletFilterTopup,
      l10n.walletFilterSpend,
      l10n.walletFilterBonus,
    ];

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
                    Text(
                      l10n.profileHistoryRow,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      l10n.walletHistorySubtitle,
                      style: const TextStyle(
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
                        children: List.generate(filters.length, (index) {
                          final isSelected = _selectedFilter == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => _onFilterChanged(index),
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
                                  filters[index],
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

                    // Список транзакций
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.only(top: 40.0),
                            child: Center(child: CircularProgressIndicator(color: orangeColor)),
                          )
                        : _transactions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 40.0),
                                child: Center(child: Text(l10n.walletEmpty)),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ..._buildTransactionList(),
                                  if (_isLoadingMore)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20.0),
                                      child: Center(child: CircularProgressIndicator(color: orangeColor)),
                                    ),
                                ],
                              ),
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
                  child: Text(
                    l10n.next,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffffffff),
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

  List<Widget> _buildTransactionList() {
    final widgets = <Widget>[];
    String? currentDate;

    for (final tx in _transactions) {
      // Пытаемся извлечь дату или используем заглушку
      final rawDate = tx['created_at'] as String?;
      final displayDate = rawDate != null ? _formatDate(rawDate) : 'Неизвестно';

      if (currentDate != displayDate) {
        if (currentDate != null) {
          widgets.add(const SizedBox(height: 16.0));
          widgets.add(const Divider(color: Color(0xffe5e5ea), height: 1));
          widgets.add(const SizedBox(height: 20.0));
        }
        widgets.add(_buildDateHeader(displayDate));
        currentDate = displayDate;
      }

      final amount = tx['amount'] as int? ?? 0;
      final kind = tx['kind'] as String? ?? '';
      final desc = tx['description'] as String? ?? '';
      
      final isPositive = amount > 0;
      final amountStr = isPositive ? '+$amount' : '$amount';
      final text = '$amountStr кирпичей ($desc)';

      if (kind == 'topup') {
        widgets.add(_buildCoinRow(text));
      } else {
        widgets.add(_buildBrickRow(text, isPositive: isPositive));
      }
    }
    
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 16.0));
      widgets.add(const Divider(color: Color(0xffe5e5ea), height: 1));
    }

    return widgets;
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (e) {
      return isoString;
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
