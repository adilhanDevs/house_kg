import 'package:house_kgz/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../widgets/finik_payment_flow.dart';

enum _PromoAction { next, skip }

class AdPromoPage extends StatefulWidget {
  const AdPromoPage({super.key});

  @override
  State<AdPromoPage> createState() => _AdPromoPageState();
}

class _AdPromoPageState extends State<AdPromoPage> {
  // START WITH REFERENCE STATE (use bricks = true)
  bool _useTarget = true;
  bool _useClientBase = false;
  bool _useWhatsappBase = false;
  bool _useBricks = true;

  int _selectedDay = 1;
  final TextEditingController _sumController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  
  late final String _idempotencyKey;
  Map<String, dynamic>? _pricing;

  _PromoAction? _submitting;
  bool get _isPublishing => _submitting != null;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPricing());
  }

  Future<void> _loadPricing() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    final days = int.tryParse(_daysController.text.trim()) ?? _selectedDay;
    try {
      final options = <String>[];
      if (_useTarget) options.add('use_exact_promotion');
      if (_useClientBase) options.add('use_client_database');
      if (_useWhatsappBase) options.add('use_whatsapp_database');
      final pricing = await state.apiClient.getPromotionPricing(days: days > 0 ? days : 1, options: options);
      if (mounted) setState(() => _pricing = pricing);
    } catch (e) {
      debugPrint('Pricing err: $e');
    }
  }

  int get _promotionCost => (_pricing?['total_cost'] as num?)?.toInt() ?? 0;
  int get _walletBalance => (_pricing?['balance'] as num?)?.toInt() ?? AppScope.read(context).walletBalance;

  @override
  void dispose() {
    _sumController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<bool> _promote(AppState state, String slug, int days) async {
    try {
      final options = <String>[];
      if (_useTarget) options.add('use_exact_promotion');
      if (_useClientBase) options.add('use_client_database');
      if (_useWhatsappBase) options.add('use_whatsapp_database');
      await state.apiClient.promoteListing(slug, days, options, _idempotencyKey);
      return true;
    } on ApiException catch (e) {
      if (!e.isInsufficientFunds || !mounted) {
        if (mounted) _showPromotionError(e.message);
        return false;
      }
      final missing = e.missingBricks ?? (_promotionCost - _walletBalance);
      if (missing <= 0) {
        _showPromotionError(e.message);
        return false;
      }
      final paid = await startFinikPayment(
        context: context,
        amountSom: missing,
        purposeTitle: context.l10n.addListingPromoTopup,
        state: state,
      );
      if (paid != true || !mounted) return false;
      await state.fetchWalletBalance();
      try {
        final options = <String>[];
      if (_useTarget) options.add('use_exact_promotion');
      if (_useClientBase) options.add('use_client_database');
      if (_useWhatsappBase) options.add('use_whatsapp_database');
      await state.apiClient.promoteListing(slug, days, options, _idempotencyKey);
        return true;
      } catch (re) {
        if (mounted) _showPromotionError(re is ApiException ? re.message : re.toString());
        return false;
      }
    } catch (e) {
      if (mounted) _showPromotionError(e.toString());
      return false;
    }
  }

  void _showPromotionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.addListingPromoNotPaid(message)), backgroundColor: const Color(0xffd93025)),
    );
  }

  Future<void> _publishListing({required bool withPromo, _PromoAction action = _PromoAction.next}) async {
    if (_isPublishing) return;
    setState(() => _submitting = action);
    final state = AppScope.read(context);
    final slug = state.draftSlug ?? 'draft-slug';
    try {
      await state.apiClient.publishListing(slug);
      state.resetDraft();
      var promoted = false;
      if (withPromo) {
        final days = int.tryParse(_daysController.text.trim()) ?? _selectedDay;
        promoted = await _promote(state, slug, days);
        if (!promoted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.addListingPublishedNoPromo), backgroundColor: const Color(0xffd93025)),
          );
          Navigator.of(context).pushReplacementNamed(Routes.adPreview, arguments: slug);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(promoted ? context.l10n.addListingPublishedPromoSuccess : context.l10n.addListingPublishedSuccess2),
            backgroundColor: const Color(0xffea812e),
          ),
        );
        Navigator.of(context).pushReplacementNamed(Routes.adPreview, arguments: slug);
      }
    } catch (e) {
      if (mounted) {
        final err = e is ApiException ? e.message : e.toString();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.addListingPublishingTitle),
            content: Text(err),
            actions: [
              TextButton(
                onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pushNamed(Routes.tariffs); },
                child: const Text('Сменить тариф', style: TextStyle(color: Color(0xfff5222d), fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pushReplacementNamed(Routes.adPreview, arguments: slug); },
                child: Text(context.l10n.addListingToPreview, style: TextStyle(color: Color(0xffea812e))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffea812e)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.l10n.addListingGotIt, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  void _onNext() => _publishListing(withPromo: true, action: _PromoAction.next);

  Widget _buildBrickIcon({double size = 24.0, double scale = 1.0}) {
    Widget image = Image.asset(
      'assets/figma/7d929ed14946ddce.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    if (scale != 1.0) {
      image = Transform.scale(scale: scale, child: image);
    }
    return SizedBox(width: size, height: size, child: image);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xffea812e);
    final sumText = _sumController.text.trim().replaceAll(' ', '');
    final int sumValue = int.tryParse(sumText) ?? 0;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top area: Back button + Progress bar
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 24.0, left: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: const LinearProgressIndicator(
                              value: 0.85,
                              backgroundColor: Color(0xfff0f0f0),
                              color: Color(0xffea812e),
                              minHeight: 6.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24.0),
                        Text(
                          l10n.addListingPromoTitle,
                          style: const TextStyle(fontSize: 32.0, fontWeight: FontWeight.w800, color: Colors.black, height: 1.1, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          l10n.addListingPromoIntro,
                          style: const TextStyle(fontSize: 17.0, color: Color(0xff6e6e73), height: 1.4),
                        ),
                        
                        const SizedBox(height: 48.0),
                        
                        _buildSectionTitle(l10n.addListingPromoBudget),
                        const SizedBox(height: 20.0),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _useBricks = false),
                                child: Container(
                                  height: 60.0,
                                  decoration: BoxDecoration(
                                    color: !_useBricks ? orange : Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: !_useBricks ? null : Border.all(color: const Color(0xffe5e5ea), width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!_useBricks)
                                         Padding(padding: const EdgeInsets.only(right: 8.0), child: _buildBrickIcon(size: 24.0, scale: 1.8)),
                                      Flexible(
                                        child: Text(
                                          l10n.addListingPromoTopupWallet,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w700,
                                            color: !_useBricks ? Colors.white : const Color(0xff7d7d7d),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _useBricks = true),
                                child: Container(
                                  height: 60.0,
                                  decoration: BoxDecoration(
                                    color: _useBricks ? orange : Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: _useBricks ? null : Border.all(color: const Color(0xffe5e5ea), width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(padding: const EdgeInsets.only(right: 8.0), child: _buildBrickIcon(size: 24.0, scale: 1.8)),
                                      Flexible(
                                        child: Text(
                                          l10n.addListingSpendBricks,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w700,
                                            color: _useBricks ? Colors.white : const Color(0xff7d7d7d),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        if (_useBricks) ...[
                          const SizedBox(height: 24.0),
                          const Divider(color: Color(0xffe5e5ea), thickness: 1, height: 1),
                          const SizedBox(height: 24.0),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.85,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8f6e4),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Row(
                                  children: [
                                    _buildBrickIcon(size: 24.0, scale: 2.0),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Text(
                                        _pricing == null
                                            ? l10n.addListingPromoBalance(_walletBalance.toString())
                                            : l10n.addListingPromoBalanceAndCost(_walletBalance.toString(), _promotionCost.toString()),
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                          color: _pricing != null && _walletBalance < _promotionCost ? const Color(0xffd93025) : const Color(0xff188038),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 24.0),
                          const Divider(color: Color(0xffe5e5ea), thickness: 1, height: 1),
                          const SizedBox(height: 24.0),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 56.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: const Color(0xffe5e5ea), width: 1.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _sumController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Colors.black),
                                    decoration: InputDecoration(
                                      hintText: l10n.addListingEnterAmount,
                                      hintStyle: const TextStyle(fontSize: 15.0, color: Color(0xff7d7d7d)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                flex: 5,
                                child: Container(
                                  height: 56.0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffe8f6e4),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBrickIcon(size: 24.0, scale: 2.0),
                                      const SizedBox(width: 8.0),
                                      Flexible(
                                        child: Text(
                                          l10n.addListingPromoBricksResult(sumValue.toString()),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Color(0xff188038)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                          
                        const SizedBox(height: 48.0),
                        
                        _buildSectionTitle(l10n.addListingPromoDays),
                        const SizedBox(height: 20.0),
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              final day = i + 1;
                              final isSel = _selectedDay == day;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                    _loadPricing();
                                    _daysController.clear();
                                  });
                                },
                                child: Container(
                                  width: 48.0,
                                  height: 48.0,
                                  margin: const EdgeInsets.only(right: 10.0),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xfffdf1e8) : Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: isSel ? orange : const Color(0xffe5e5ea), width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 17.0,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                      color: isSel ? orange : const Color(0xff7d7d7d),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            Expanded(
                              child: Container(
                                height: 48.0,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: const Color(0xffe5e5ea), width: 1.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _daysController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    if (val.isNotEmpty) setState(() => _selectedDay = 0);
                                  },
                                  style: const TextStyle(fontSize: 16.0, color: Colors.black, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    hintText: l10n.addListingPromoDaysHint,
                                    hintStyle: const TextStyle(fontSize: 15.0, color: Color(0xff7d7d7d), fontWeight: FontWeight.normal),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 48.0),
                        
                        _buildToggleRow(l10n.addListingPromoExact, _useTarget, (v) { setState(() => _useTarget = v); _loadPricing(); }),
                        const SizedBox(height: 16.0),
                        _buildToggleRow(l10n.addListingPromoClientBase, _useClientBase, (v) { setState(() => _useClientBase = v); _loadPricing(); }),
                        const SizedBox(height: 16.0),
                        _buildToggleRow(l10n.addListingPromoWhatsapp, _useWhatsappBase, (v) { setState(() => _useWhatsappBase = v); _loadPricing(); }),
                        
                        const SizedBox(height: 56.0),
                        
                        Text(
                          l10n.addListingPromoEstimatedViews,
                          style: const TextStyle(fontSize: 26.0, fontWeight: FontWeight.w800, color: Color(0xffea812e), letterSpacing: -0.5, height: 1.2),
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          l10n.addListingPromoEstimateDesc,
                          style: const TextStyle(fontSize: 16.0, color: Color(0xff6e6e73), height: 1.5),
                        ),
                        
                        const SizedBox(height: 48.0),
                        
                        Text(
                          l10n.addListingPromoCostSummary(_promotionCost.toString()),
                          style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w800, color: Color(0xffea812e), letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // BOTTOM CTA AREA (Fills remaining space, anchors to bottom)
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 48.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _isPublishing ? null : _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                          ),
                          child: _submitting == _PromoAction.next
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(l10n.addListingNext, style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16.0),
                        TextButton(
                          onPressed: _isPublishing ? null : () => _publishListing(withPromo: false, action: _PromoAction.skip),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xffea812e),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                          child: _submitting == _PromoAction.skip
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xffea812e), strokeWidth: 2))
                              : Text(l10n.addListingContinueNoPromo, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                        ),
                      ],
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

  Widget _buildToggleRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17.0, color: Color(0xff555555), fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 16),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xffea812e),
          activeTrackColor: const Color(0xffea812e),
        ),
      ],
    );
  }
}
