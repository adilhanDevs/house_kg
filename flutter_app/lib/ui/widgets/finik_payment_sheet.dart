import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_state.dart';
import '../../data/finik_payment_service.dart';
import '../../data/tariff.dart';

class FinikBankOption {
  final String id;
  final String name;
  final String subtitle;
  final Color primaryColor;
  final IconData icon;
  final String? deepLinkScheme;

  const FinikBankOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primaryColor,
    required this.icon,
    this.deepLinkScheme,
  });
}

const List<FinikBankOption> kFinikBanks = [
  FinikBankOption(
    id: 'mbank',
    name: 'MBank',
    subtitle: 'Коммерческий банк КЫРГЫЗСТАН',
    primaryColor: Color(0xff12b76a),
    icon: Icons.account_balance,
    deepLinkScheme: 'mbank://pay',
  ),
  FinikBankOption(
    id: 'optima',
    name: 'Optima24',
    subtitle: 'Оптима Банк',
    primaryColor: Color(0xffea812e),
    icon: Icons.credit_card,
    deepLinkScheme: 'optima24://pay',
  ),
  FinikBankOption(
    id: 'bakai',
    name: 'Bakai Bank',
    subtitle: 'Бакай Банк',
    primaryColor: Color(0xff104b9c),
    icon: Icons.account_balance_wallet,
    deepLinkScheme: 'bakai://pay',
  ),
  FinikBankOption(
    id: 'odengi',
    name: 'О!Деньги',
    subtitle: 'Кошелёк О!Деньги',
    primaryColor: Color(0xffe6007e),
    icon: Icons.phone_android,
    deepLinkScheme: 'omoney://pay',
  ),
  FinikBankOption(
    id: 'megapay',
    name: 'MegaPay',
    subtitle: 'MegaCom кошелёк',
    primaryColor: Color(0xff00b050),
    icon: Icons.payment,
    deepLinkScheme: 'megapay://pay',
  ),
  FinikBankOption(
    id: 'card',
    name: 'Банковская карта',
    subtitle: 'Visa, MasterCard, Элкарт',
    primaryColor: Color(0xff2d3142),
    icon: Icons.credit_card_rounded,
  ),
];

/// Открывает интерактивный интерфейс оплаты Finik Pay
Future<bool?> showFinikPaymentSheet({
  required BuildContext context,
  required int amountSom,
  required String purposeTitle,
  TariffPlan? tariff,
  AppState? state,
  VoidCallback? onSuccess,
}) {
  final appState = state ?? AppScope.read(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FinikPaymentSheetContent(
      state: appState,
      amountSom: amountSom,
      purposeTitle: purposeTitle,
      tariff: tariff,
      onSuccess: onSuccess,
    ),
  );
}

class _FinikPaymentSheetContent extends StatefulWidget {
  final AppState state;
  final int amountSom;
  final String purposeTitle;
  final TariffPlan? tariff;
  final VoidCallback? onSuccess;

  const _FinikPaymentSheetContent({
    required this.state,
    required this.amountSom,
    required this.purposeTitle,
    this.tariff,
    this.onSuccess,
  });

  @override
  State<_FinikPaymentSheetContent> createState() => _FinikPaymentSheetContentState();
}

class _FinikPaymentSheetContentState extends State<_FinikPaymentSheetContent> {
  int _tabIndex = 0; // 0 = Банковские приложения, 1 = QR-код
  String _selectedBankId = 'mbank';
  bool _isProcessing = false;
  bool _isSuccess = false;
  FinikPaymentResponse? _invoice;
  int _secondsLeft = 899; // 14:59

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPayment();
    });
  }

  String get _formattedTimer {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initPayment() async {
    final state = widget.state;
    try {
      final invoice = await state.createFinikTopup(widget.amountSom);
      if (mounted) {
        setState(() => _invoice = invoice);
      }
    } catch (e) {
      debugPrint('Error init Finik invoice: $e');
    }
  }

  Future<void> _handlePay() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final state = widget.state;

    try {
      // 1. Попытка открыть приложение выбранного банка через диплинк (на реальном устройстве)
      final selectedBank = kFinikBanks.firstWhere(
        (b) => b.id == _selectedBankId,
        orElse: () => kFinikBanks.first,
      );

      if (selectedBank.deepLinkScheme != null && _invoice != null) {
        try {
          final uri = Uri.parse('${selectedBank.deepLinkScheme}?orderId=${_invoice!.orderId}&amount=${widget.amountSom}');
          launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
        } catch (_) {}
      }

      // 2. Подтверждаем и сверяем платёж через Finik Pay
      final invoice = _invoice ?? await state.createFinikTopup(widget.amountSom);
      await state.confirmFinikTopup(invoice);

      // Если это покупка тарифа, активируем тариф
      if (widget.tariff != null) {
        try {
          await state.buySubscription(widget.tariff!, withBricks: false);
        } catch (e) {
          debugPrint('Error buying subscription in sheet: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      debugPrint('Payment sheet error: $e\n$st');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка оплаты: ${e.toString()}'),
            backgroundColor: const Color(0xffd32f2f),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      child: SafeArea(
        top: false,
        child: _isSuccess ? _buildSuccessView() : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xffe8f5e9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xff2e7d32), size: 54),
          ),
          const SizedBox(height: 20),
          const Text(
            'Оплата прошла успешно!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff1f2024)),
          ),
          const SizedBox(height: 8),
          Text(
            widget.tariff != null
                ? 'Тариф «${widget.tariff!.name}» успешно подключён'
                : 'Кошелёк пополнен на ${widget.amountSom} сом',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xff666668)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9fa),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe5e7eb)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Сумма оплаты:', style: TextStyle(color: Color(0xff71717a), fontSize: 14)),
                Text('${widget.amountSom} сом', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff18181b))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xffe0e0e0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffea812e).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('⚡ ', style: TextStyle(fontSize: 13)),
                    Text(
                      'Finik Pay',
                      style: TextStyle(
                        color: Color(0xffea812e),
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xfff3f4f6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Защищённый платёж 🇰🇬',
                  style: TextStyle(fontSize: 11.5, color: Color(0xff4b5563), fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xff8e8e93)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xfff0f0f0)),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff2d3142), Color(0xff1e212d)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff2d3142).withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'К оплате',
                            style: TextStyle(color: Color(0xff9e9ea7), fontSize: 13),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xffea812e), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _formattedTimer,
                                style: const TextStyle(color: Color(0xffea812e), fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.amountSom} сом',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.purposeTitle,
                        style: const TextStyle(color: Color(0xffd1d5db), fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Tabs: Банки / QR-код
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff3f4f6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabIndex == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _tabIndex == 0
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Банки Кыргызстана',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _tabIndex == 0 ? const Color(0xff1f2024) : const Color(0xff6b7280),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabIndex == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _tabIndex == 1
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'QR-код для оплаты',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _tabIndex == 1 ? const Color(0xff1f2024) : const Color(0xff6b7280),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Content
                if (_tabIndex == 0) _buildBanksList() else _buildQrCodeView(),
              ],
            ),
          ),
        ),

        // Bottom CTA Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffea812e),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessing ? null : _handlePay,
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(
                      _tabIndex == 0
                          ? 'Оплатить ${widget.amountSom} сом'
                          : 'Я отсканировал и оплатил',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanksList() {
    return Column(
      children: kFinikBanks.map((bank) {
        final isSelected = _selectedBankId == bank.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedBankId = bank.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xfffff7ed) : const Color(0xfffafafa),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xffea812e) : const Color(0xffe5e7eb),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bank.primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(bank.icon, color: bank.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff18181b)),
                        ),
                        Text(
                          bank.subtitle,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xff71717a)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xffea812e) : const Color(0xffd1d5db),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQrCodeView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xfff9fafb),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe5e7eb)),
      ),
      child: Column(
        children: [
          Container(
            width: 170,
            height: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // QR representation pattern
                CustomPaint(
                  size: const Size(146, 146),
                  painter: _QrPatternPainter(),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Национальный стандарт QR (ELQR / Finik)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff18181b)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Откройте MBank, Optima24, Bakai или О!Деньги\nи наведите камеру на QR-код',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xff6b7280), height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff1f2024)
      ..style = PaintingStyle.fill;

    // Corner finder patterns
    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, 36, 36), paint);
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(x + 6, y + 6, 24, 24), whitePaint);
      canvas.drawRect(Rect.fromLTWH(x + 11, y + 11, 14, 14), paint);
    }

    drawFinder(0, 0);
    drawFinder(size.width - 36, 0);
    drawFinder(0, size.height - 36);

    // Grid dots
    final step = 8.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if ((x < 42 && y < 42) || (x > size.width - 42 && y < 42) || (x < 42 && y > size.height - 42)) {
          continue;
        }
        if ((x.toInt() * 7 + y.toInt() * 13) % 19 < 9) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, y + 1, step - 2, step - 2), const Radius.circular(1.5)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
