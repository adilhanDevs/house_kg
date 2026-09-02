import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n.dart';

const Key kProfileBalanceSectionKey = Key('profile_balance_section');
const Key kProfileBalanceValueKey = Key('profile_balance_value');
const Key kProfileBalanceTitleKey = Key('profile_balance_title');
const Key kProfileBalanceTopupButtonKey = Key('profile_balance_topup_button');

const Color _accent = Color(0xffea812e);
const Color _dividerColor = Color(0xfff2f2f7);

/// Форматирует число с разделением тысяч пробелом (например, 16 700).
String formatBricks(int amount) {
  final str = amount.abs().toString();
  final buffer = StringBuffer();
  final length = str.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(str[i]);
  }
  final formatted = buffer.toString();
  return amount < 0 ? '-$formatted' : formatted;
}

/// Возвращает локализованную строку баланса с суффиксом валюты.
String localizedBricksLabel(BuildContext context, int count) {
  final formatted = formatBricks(count);
  final isKy = Localizations.localeOf(context).languageCode == 'ky';
  return isKy ? '$formatted кирпич' : '$formatted кирпичей';
}

/// Компактная секция баланса и кнопки пополнения для Profile и ProProfile.
class ProfileBalanceSection extends StatelessWidget {
  const ProfileBalanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;

    // Баланс показываем авторизованным пользователям
    if (!state.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final balance = state.walletBalance > 0 ? state.walletBalance : state.bricks;

    return Container(
      key: kProfileBalanceSectionKey,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _dividerColor, width: 1.0),
          bottom: BorderSide(color: _dividerColor, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizedBricksLabel(context, balance),
                  key: kProfileBalanceValueKey,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: Color(0xff000000),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3.0),
                Text(
                  l10n.proWalletTitle,
                  key: kProfileBalanceTitleKey,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w400,
                    color: Color(0xff7d7d7d),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          ElevatedButton(
            key: kProfileBalanceTopupButtonKey,
            onPressed: () async {
              await Navigator.of(context).pushNamed(Routes.topup);
              if (context.mounted) {
                AppScope.read(context).fetchProfile();
                AppScope.read(context).fetchWalletBalance();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: Text(
              l10n.proTopUp,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
