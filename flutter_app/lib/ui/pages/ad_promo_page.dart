import 'package:house_kgz/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _useTarget = true;
  bool _useClientBase = false;
  bool _useWhatsappBase = false;
  bool _useBricks = false;

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
      final pricing = await state.apiClient.getPromotionPricing(days: days > 0 ? days : 1);
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
      await state.apiClient.promoteListing(slug, days, _idempotencyKey);
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
        await state.apiClient.promoteListing(slug, days, _idempotencyKey);
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
            SnackBar(content: Text(context.l10n.addListingPublishedNoPromo), backgroundColor: Color(0xffd93025)),
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

  Widget _buildBrickIcon({double width = 24.0, double height = 16.0}) {
    return Image.asset(
      'assets/figma/7d929ed14946ddce.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.black),
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
      appBar: AppBar(
        title: Text(l10n.addListingPromoTitle, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18.0)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.addListingPromoIntro,
                      style: const TextStyle(fontSize: 14.0, color: Color(0xff7d7d7d)),
                    ),
                    const SizedBox(height: 16.0),
                    const Divider(color: Color(0xffe5e5ea), thickness: 1, height: 1),
                    const SizedBox(height: 16.0),
                    _buildSectionTitle(l10n.addListingPromoBudget),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _useBricks = true),
                            child: Container(
                              height: 38.0,
                              decoration: BoxDecoration(
                                color: _useBricks ? orange : Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: _useBricks ? null : Border.all(color: const Color(0xffe5e5ea)),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBrickIcon(),
                                  const SizedBox(width: 4.0),
                                  Flexible(
                                    child: Text(
                                      l10n.addListingSpendBricks,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: _useBricks ? Colors.white : const Color(0xff7d7d7d),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _useBricks = false),
                            child: Container(
                              height: 38.0,
                              decoration: BoxDecoration(
                                color: !_useBricks ? orange : Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: !_useBricks ? null : Border.all(color: const Color(0xffe5e5ea)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.addListingPromoTopupWallet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: !_useBricks ? Colors.white : const Color(0xff7d7d7d),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    if (!_useBricks)
                      Row(
                        children: [
                          Container(
                            width: 125.0,
                            height: 36.0,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: const Color(0xffe5e5ea)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _sumController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.black),
                              decoration: InputDecoration(
                                hintText: l10n.addListingEnterAmount,
                                hintStyle: const TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Container(
                              height: 36.0,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xffe8f6e4),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xffc5e8bc)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildBrickIcon(width: 22, height: 15),
                                  const SizedBox(width: 4.0),
                                  Flexible(
                                    child: Text(
                                      l10n.addListingPromoBricksResult(sumValue.toString()),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xff4dba17)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        height: 36.0,
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f6e4),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xffc5e8bc)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildBrickIcon(),
                            const SizedBox(width: 6.0),
                            Flexible(
                              child: Text(
                                _pricing == null
                                    ? l10n.addListingPromoBalance(_walletBalance.toString())
                                    : l10n.addListingPromoBalanceAndCost(_walletBalance.toString(), _promotionCost.toString()),
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: _pricing != null && _walletBalance < _promotionCost ? const Color(0xffd93025) : const Color(0xff4dba17),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    const Divider(color: Color(0xffe5e5ea), thickness: 1, height: 1),
                    const SizedBox(height: 16.0),
                    _buildSectionTitle(l10n.addListingPromoDays),
                    const SizedBox(height: 12.0),
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
                              width: 30.0,
                              height: 30.0,
                              margin: const EdgeInsets.only(right: 4.0),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xfffdf1e8) : Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: isSel ? orange : const Color(0xffe5e5ea)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? orange : const Color(0xff7d7d7d),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Container(
                            height: 30.0,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: const Color(0xffe5e5ea)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _daysController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                if (val.isNotEmpty) setState(() => _selectedDay = 0);
                              },
                              style: const TextStyle(fontSize: 12.0, color: Colors.black),
                              decoration: InputDecoration(
                                hintText: l10n.addListingPromoDaysHint,
                                hintStyle: const TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    _buildToggleRow(l10n.addListingPromoExact, _useTarget, (v) => setState(() => _useTarget = v)),
                    const SizedBox(height: 16.0),
                    _buildToggleRow(l10n.addListingPromoClientBase, _useClientBase, (v) => setState(() => _useClientBase = v)),
                    const SizedBox(height: 16.0),
                    _buildToggleRow(l10n.addListingPromoWhatsapp, _useWhatsappBase, (v) => setState(() => _useWhatsappBase = v)),
                    const SizedBox(height: 24.0),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xfff7f7f7),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.addListingPromoEstimatedViews,
                            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            l10n.addListingPromoEstimateDesc,
                            style: const TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x1a000000), offset: Offset(0, -1), blurRadius: 4)],
              ),
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
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: _submitting == _PromoAction.next
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(l10n.addListingNext, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8.0),
                  OutlinedButton(
                    onPressed: _isPublishing ? null : () => _publishListing(withPromo: false, action: _PromoAction.skip),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: orange,
                      side: BorderSide(color: orange),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: _submitting == _PromoAction.skip
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: orange, strokeWidth: 2))
                        : Text(l10n.addListingContinueNoPromo, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                  ),
                ],
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
          child: Text(title, style: const TextStyle(fontSize: 15.0, color: Colors.black)),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xffea812e),
        ),
      ],
    );
  }
}
