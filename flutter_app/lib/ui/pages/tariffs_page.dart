import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/tariff.dart';
import '../../data/api_client.dart';
import '../../l10n/l10n.dart';
import '../widgets/finik_payment_sheet.dart';

class TariffsPage extends StatefulWidget {
  const TariffsPage({super.key});

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      state.fetchTariffs();
    });
  }

  Future<void> _handleBuy(BuildContext context, AppState state, TariffPlan plan, {required bool withBricks}) async {
    if (plan.code == state.currentTariffCode) return;

    final costText = withBricks
        ? '${plan.priceBricks ?? plan.priceSom} кирпичей'
        : '${plan.priceSom} сом';

    final message = plan.isFree
        ? 'Перейти на базовый тариф «${plan.name}»?\nЛимит составит до ${plan.maxPosts} активных постов.'
        : withBricks
            ? 'С вашего баланса кошелька будет списано $costText.\nВаш текущий баланс: ${state.walletBalance} кирпичей.\nЛимит активных постов: до ${plan.maxPosts}.\n\nАктивировать тариф «${plan.name}»?'
            : 'Стоимость тарифа: $costText на 1 месяц.\nЛимит активных постов: до ${plan.maxPosts}.\n\nПодтвердить оформление тарифа «${plan.name}»?';

    if (!withBricks && !plan.isFree) {
      // Открываем интерфейс оплаты Finik Pay
      final paid = await showFinikPaymentSheet(
        context: context,
        amountSom: plan.priceSom,
        purposeTitle: 'Подписка на тариф «${plan.name}» (1 месяц)',
        tariff: plan,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Тариф «${plan.name}» успешно оплачен и активирован!'),
              backgroundColor: const Color(0xff2e7d32),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
      if (paid == true) return;
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(plan.isFree ? 'Смена тарифа' : 'Подписка «${plan.name}»'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xff8e8e93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffea812e),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(plan.isFree ? 'Перейти' : 'Подтвердить', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await state.buySubscription(plan, withBricks: withBricks);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Тариф «${plan.name}» успешно активирован!'),
            backgroundColor: const Color(0xff2e7d32),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      // Не хватило кирпичей — предлагаем оплатить недостачу через Finik и
      // повторить. Остальные ошибки показываем как есть, а не под заголовком
      // «Недостаточно средств», которым раньше накрывало вообще всё.
      if (e.isInsufficientFunds) {
        final missing = e.missingBricks;
        final topUp = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Недостаточно кирпичей'),
            content: Text(
              missing != null
                  ? 'Не хватает $missing кирпичей. Пополнить кошелёк и подключить тариф?'
                  : e.message,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffea812e)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Пополнить', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (topUp == true && mounted && missing != null) {
          final paid = await showFinikPaymentSheet(
            context: context,
            amountSom: missing,
            purposeTitle: 'Пополнение на тариф «${plan.name}»',
            state: state,
            tariff: plan,
          );
          if (paid == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Тариф «${plan.name}» успешно активирован!'),
                backgroundColor: const Color(0xff2e7d32),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (topUp == true && mounted) {
          Navigator.pushNamed(context, Routes.topup);
        }
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не удалось подключить тариф'),
            content: Text(e.message),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffea812e)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Понятно', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось подключить тариф: $e'),
            backgroundColor: const Color(0xffd93025),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFeatureIcon(TariffFeatureIcon iconType) {
    const brandColor = Color(0xffea812e);
    switch (iconType) {
      case TariffFeatureIcon.promotion:
        return const Icon(Icons.bar_chart_rounded, color: brandColor, size: 28);
      case TariffFeatureIcon.posts:
        return const Icon(Icons.article_outlined, color: brandColor, size: 28);
      case TariffFeatureIcon.reels:
        return const Icon(Icons.videocam_outlined, color: brandColor, size: 28);
      case TariffFeatureIcon.bricks:
        return const Icon(Icons.account_balance_wallet_outlined, color: brandColor, size: 28);
      case TariffFeatureIcon.catalog:
        return const Icon(Icons.menu_book_outlined, color: brandColor, size: 28);
      case TariffFeatureIcon.whatsapp:
        return const Icon(Icons.chat_bubble_outline_rounded, color: brandColor, size: 28);
    }
  }

  Widget _buildCard(BuildContext context, AppState state, TariffPlan plan) {
    final isCurrent = plan.code == state.currentTariffCode;

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main card container
          Container(
            height: 520,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent ? const Color(0xffea812e) : const Color(0xffe8e8ed),
                width: isCurrent ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrent ? const Color(0x1aea812e) : const Color(0x0a000000),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background decorative sketches
                Positioned(
                  right: 0,
                  bottom: 60,
                  child: Opacity(
                    opacity: 0.15,
                    child: plan.code == 'owner'
                        ? const Icon(Icons.apartment_outlined, size: 170, color: Colors.black87)
                        : plan.code == 'top'
                            ? const Icon(Icons.map_outlined, size: 170, color: Colors.black87)
                            : plan.code == 'vip'
                                ? const Icon(Icons.holiday_village_outlined, size: 170, color: Colors.black87)
                                : const Icon(Icons.domain_add_outlined, size: 170, color: Colors.black87),
                  ),
                ),

                // Card content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1c1c1e),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xfffee2e2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Активен',
                                style: TextStyle(color: Color(0xffea812e), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Features grid / column
                      Expanded(
                        child: ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: plan.features.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, i) {
                            final feature = plan.features[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildFeatureIcon(feature.icon),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    feature.title,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xff48484a),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Bottom Primary Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent
                                ? const Color(0xffea812e)
                                : (plan.isFree ? const Color(0xff48484a) : const Color(0xffea812e)),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isCurrent
                              ? null
                              : () => _handleBuy(context, state, plan, withBricks: false),
                          child: Text(
                            isCurrent
                                ? 'Ваш тариф'
                                : (plan.isFree ? 'Выбрать тариф' : 'Купить за ${plan.priceSom} сом'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Secondary option: "или 🧱 X Кирпичей"
          if (plan.canPayWithBricks && !isCurrent) ...[
            const SizedBox(height: 8),
            const Text(
              'или',
              style: TextStyle(fontSize: 12, color: Color(0xff8e8e93)),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleBuy(context, state, plan, withBricks: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xffdcf5e3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffc2ebd0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🧱', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '${plan.priceBricks} Кирпичей',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff2e7d32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 52), // Space placeholder to maintain vertical alignment
          ],
        ],
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    final state = AppScope.read(context);
    final targetRoute = state.draftSlug != null ? Routes.adPromo : Routes.profile;
    try {
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } catch (_) {
      try {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;
    final plans = kDefaultTariffPlans;

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          l10n.tariffsTitle,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xffea812e)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      l10n.tariffsSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xff666668),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Horizontal list of 4 tariff cards
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: plans.map((p) => _buildCard(context, state, p)).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
