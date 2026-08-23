import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../app_tab_bar.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const listingId = 'technopark'; // "Технопарк" listing ID

    return FigStage(
      frame: frame('17'),
      // «Уведомления» больше не вкладка — их открывают с «Главной» и из
      // профиля, поэтому в меню ничего не подсвечено.
      bottomBar: const AppTabBar(active: null),
      overlays: [
        // Слева от заголовка места нет — стрелка встаёт справа от него, как на
        // «Фильтре».
        const FigBackButton(left: 330, top: 62),
        // Card 1 (Технопарк)
        Positioned(
          left: 25.0,
          top: 93.0,
          width: 326.0,
          height: 56.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.listing,
              arguments: ListingArgs(listingId),
            ),
          ),
        ),

        // Card 2 (Технопарк)
        Positioned(
          left: 25.0,
          top: 154.0,
          width: 326.0,
          height: 56.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.listing,
              arguments: ListingArgs(listingId),
            ),
          ),
        ),

        // Card 3 (Технопарк)
        Positioned(
          left: 25.0,
          top: 215.0,
          width: 326.0,
          height: 56.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.listing,
              arguments: ListingArgs(listingId),
            ),
          ),
        ),

        // Card 4 (Технопарк)
        Positioned(
          left: 25.0,
          top: 276.0,
          width: 326.0,
          height: 56.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.listing,
              arguments: ListingArgs(listingId),
            ),
          ),
        ),
      ],
    );
  }
}
