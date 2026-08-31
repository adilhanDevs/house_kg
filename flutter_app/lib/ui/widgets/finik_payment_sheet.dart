import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_state.dart';
import '../../data/api_client.dart';
import '../../data/topup.dart';
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
  bool _isDisposed = false;

  /// Счёт, выставленный бэкендом. Пока его нет — платить нечем.
  TopupIntent? _intent;
  String? _error;
  String? _statusText;
  int _creditedBricks = 0;

  int _secondsLeft = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPayment());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    super.dispose();
  }

  String get _formattedTimer {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Выставляет счёт на бэкенде и запускает отсчёт до его истечения.
  Future<void> _initPayment() async {
    setState(() {
      _error = null;
      _statusText = null;
    });

    try {
      final intent = await widget.state.createTopup(widget.amountSom);
      if (!mounted) return;

      setState(() {
        _intent = intent;
        _secondsLeft = intent.secondsLeft;
        // Первым предлагаем банк, который бэкенд отдал первым.
        if (intent.providers.isNotEmpty) {
          _selectedBankId = intent.providers.first.code;
        }
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.state.topupError ?? 'Не удалось выставить счёт');
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_secondsLeft <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft = _intent?.secondsLeft ?? (_secondsLeft > 0 ? _secondsLeft - 1 : 0);
      });
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  /// Ссылка, по которой уходим платить: диплинк выбранного банка, если бэкенд
  /// его дал, иначе страница оплаты провайдера.
  String _payTarget() {
    final intent = _intent;
    if (intent == null) return '';

    for (final provider in intent.providers) {
      if (provider.code == _selectedBankId && provider.deeplink.isNotEmpty) {
        return provider.deeplink;
      }
    }
    return intent.paymentUrl;
  }

  Future<void> _handlePay() async {
    if (_isProcessing) return;

    final intent = _intent;
    if (intent == null) {
      await _initPayment();
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // На вкладке «Банки» уводим пользователя в приложение банка. На вкладке QR
    // он уже оплатил сканированием — там только ждём подтверждения.
    if (_tabIndex == 0) {
      // Диплинк банка настраивается в админке и может не открыться (нет
      // приложения, устаревшая схема). Тогда уходим на страницу оплаты
      // провайдера — она работает в любом браузере.
      var opened = await _openPayTarget(_payTarget());
      if (!opened && intent.paymentUrl.isNotEmpty) {
        opened = await _openPayTarget(intent.paymentUrl);
      }

      if (!opened) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _error = 'Не удалось открыть страницу оплаты. '
              'Воспользуйтесь QR-кодом.';
        });
        return;
      }
    }

    await _waitForConfirmation(intent);
  }

  Future<bool> _openPayTarget(String target) async {
    if (target.isEmpty) return false;
    final uri = Uri.tryParse(target);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Не удалось открыть $target: $e');
      return false;
    }
  }

  /// Ждёт, пока бэкенд не подтвердит оплату вебхуком провайдера.
  ///
  /// Успех показывается только по статусу `succeeded` — приложение не решает
  /// само, что деньги пришли.
  Future<void> _waitForConfirmation(TopupIntent intent) async {
    if (!mounted) return;
    setState(() => _statusText = 'Ждём подтверждения оплаты…');

    final result = await widget.state.waitForTopup(
      intent.paymentId,
      isCancelled: () => _isDisposed,
    );

    if (!mounted) return;

    if (!result.status.isSuccess) {
      setState(() {
        _isProcessing = false;
        _statusText = null;
        _error = switch (result.status) {
          TopupStatus.failed => 'Оплата не прошла. Попробуйте ещё раз.',
          TopupStatus.expired => 'Счёт истёк. Выставьте новый.',
          _ => 'Подтверждение пока не пришло. Если деньги списаны, '
              'баланс обновится автоматически.',
        };
      });
      return;
    }

    // Тариф подключаем только после подтверждённой оплаты. Если подключить
    // не удалось — деньги уже зачислены кирпичами, и об этом надо сказать
    // прямо, а не показывать успех: иначе пользователь уйдёт с экрана
    // уверенным, что тариф работает.
    if (widget.tariff != null) {
      try {
        await widget.state.buySubscription(widget.tariff!, withBricks: true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusText = null;
          _error = 'Оплата прошла и кирпичи зачислены, но тариф подключить не '
              'удалось: ${e is ApiException ? e.message : e}. Попробуйте '
              'подключить его на экране тарифов.';
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _statusText = null;
      _creditedBricks = result.creditedBricks;
      _isSuccess = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    widget.onSuccess?.call();
    Navigator.of(context).pop(true);
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
                : _creditedBricks > 0
                    ? 'Начислено $_creditedBricks кирпичей'
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

        // Ошибка или ход подтверждения
        if (_error != null || _statusText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _error != null ? const Color(0xfffef2f2) : const Color(0xfff3f4f6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _error != null ? const Color(0xfffecaca) : const Color(0xffe5e7eb),
                ),
              ),
              child: Text(
                _error ?? _statusText!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: _error != null ? const Color(0xffb91c1c) : const Color(0xff4b5563),
                ),
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
                disabledBackgroundColor: const Color(0xffe5c9ab),
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
                      _intent == null
                          ? 'Выставить счёт'
                          : _tabIndex == 0
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

  /// Способы оплаты приходят с бэкенда (`providers` в ответе на счёт).
  /// Локальный список нужен только ради иконки и цвета; если бэкенд банк не
  /// прислал — платить по нему нельзя, поэтому и показывать его незачем.
  List<FinikBankOption> get _bankOptions {
    final providers = _intent?.providers ?? const <TopupProvider>[];
    if (providers.isEmpty) return kFinikBanks;

    return providers.map((provider) {
      final matches = kFinikBanks.where((b) => b.id == provider.code);
      final design = matches.isEmpty ? null : matches.first;
      return FinikBankOption(
        id: provider.code,
        name: provider.name.isNotEmpty ? provider.name : (design?.name ?? provider.code),
        subtitle: design?.subtitle ?? 'Оплата через ${provider.name}',
        primaryColor: design?.primaryColor ?? const Color(0xff2d3142),
        icon: design?.icon ?? Icons.account_balance,
      );
    }).toList();
  }

  Widget _buildBanksList() {
    final banks = _bankOptions;
    if (banks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Способы оплаты не настроены. Воспользуйтесь QR-кодом.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xff6b7280)),
        ),
      );
    }

    return Column(
      children: banks.map((bank) {
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
    final payload = _intent?.qrPayload ?? '';

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
            // Код кодирует ссылку на оплату, выданную платёжным шлюзом.
            // Пока счёт не выставлен, показывать нечего.
            child: payload.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xffea812e)),
                      ),
                    ),
                  )
                : QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 146,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xff1f2024),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xff1f2024),
                    ),
                    errorStateBuilder: (context, error) => const Center(
                      child: Text(
                        'Не удалось построить QR',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xffb91c1c)),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          const Text(
            'QR для оплаты через банковское приложение',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff18181b)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Откройте MBank, Optima24, Bakai или О!Деньги\n'
            'и наведите камеру на QR-код',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xff6b7280), height: 1.3),
          ),
        ],
      ),
    );
  }
}
