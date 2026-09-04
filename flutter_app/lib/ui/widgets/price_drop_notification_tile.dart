import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/chat_models.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import 'safe_image.dart';

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);
const Color _greenAccent = Color(0xff188038);

String formatNotificationPrice(String? rawPrice, String? rawCurrency) {
  if (rawPrice == null || rawPrice.trim().isEmpty) return '';
  final cleaned = rawPrice.replaceAll(' ', '').trim();
  final numVal = double.tryParse(cleaned);
  final isUsd =
      (rawCurrency ?? '').toUpperCase() == 'USD' || rawCurrency == r'$';

  String formatted;
  if (numVal != null) {
    if (numVal == numVal.roundToDouble()) {
      final intVal = numVal.toInt();
      final str = intVal.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write(' ');
        }
        buffer.write(str[i]);
      }
      formatted = buffer.toString();
    } else {
      formatted = numVal.toStringAsFixed(2);
    }
  } else {
    formatted = cleaned;
  }

  if (isUsd) {
    return '$formatted \$';
  } else {
    return '$formatted сом';
  }
}

class PriceDropNotificationTile extends StatelessWidget {
  const PriceDropNotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.backgroundColor,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final Color? backgroundColor;

  String _formatSpecs(AppLocalizations l10n) {
    final parts = <String>[];
    final rooms = notification.rooms;
    if (rooms != null && rooms > 0) {
      parts.add(l10n.cardRoomsShort(rooms));
    }
    final rawArea = notification.area;
    if (rawArea != null && rawArea.isNotEmpty) {
      final numArea = double.tryParse(rawArea);
      if (numArea != null) {
        final areaStr = numArea == numArea.roundToDouble()
            ? numArea.toInt().toString()
            : numArea.toString();
        parts.add('${l10n.cardAreaMeters(areaStr)}²');
      } else {
        parts.add('${l10n.cardAreaMeters(rawArea)}²');
      }
    }
    final floor = notification.floor;
    if (floor != null && floor > 0) {
      parts.add(l10n.cardFloor(floor));
    }
    return parts.join(' • ');
  }

  String _resolveCoverUrl(BuildContext context, String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    if (rawUrl.startsWith('/')) {
      try {
        final baseUrl = AppScope.read(context).apiClient.baseUrl;
        final uri = Uri.tryParse(baseUrl);
        if (uri != null) {
          final origin =
              '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
          return '$origin$rawUrl';
        }
      } catch (_) {}
    }
    return rawUrl;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coverUrl = _resolveCoverUrl(context, notification.coverUrl);
    final titleText = notification.districtName?.isNotEmpty == true
        ? notification.districtName!
        : (notification.displayTitle(l10n).isNotEmpty
              ? notification.displayTitle(l10n)
              : l10n.notificationFallbackTitle);
    final specsText = _formatSpecs(l10n);

    final oldPriceFormatted = formatNotificationPrice(
      notification.oldPrice,
      notification.currency,
    );
    final newPriceFormatted = formatNotificationPrice(
      notification.newPrice,
      notification.currency,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            backgroundColor ??
            (notification.isRead
                ? Colors.transparent
                : const Color(0x0fea812e)),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка объекта слева
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Container(
                width: 56.0,
                height: 56.0,
                color: const Color(0xfff5f5f7),
                child: coverUrl.isNotEmpty
                    ? buildSafeNetworkImage(
                        url: coverUrl,
                        fit: BoxFit.cover,
                        fallback: const Center(
                          child: Icon(
                            Icons.home_outlined,
                            size: 26.0,
                            color: _muted,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.home_outlined,
                          size: 26.0,
                          color: _muted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12.0),

            // Информация по центру
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.2,
                            color: const Color(0xff000000),
                          ),
                        ),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 6.0),
                        Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (specsText.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      specsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figStyle(
                        fontSize: 13.0,
                        family: FigFont.display,
                        weight: 500,
                        height: 1.25,
                        color: _muted,
                      ),
                    ),
                  ] else if (notification.displayBody(l10n).isNotEmpty &&
                      oldPriceFormatted.isEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      notification.displayBody(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: figStyle(
                        fontSize: 13.0,
                        family: FigFont.display,
                        weight: 500,
                        height: 1.25,
                        color: _muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),

            // Цены и статус снижения справа
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (oldPriceFormatted.isNotEmpty)
                  Text(
                    oldPriceFormatted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        figStyle(
                          fontSize: 13.0,
                          family: FigFont.display,
                          weight: 500,
                          height: 1.2,
                          color: _muted,
                        ).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: _muted,
                        ),
                  ),
                if (newPriceFormatted.isNotEmpty) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    newPriceFormatted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figStyle(
                      fontSize: 15.0,
                      family: FigFont.display,
                      weight: 700,
                      height: 1.2,
                      color: const Color(0xff000000),
                    ),
                  ),
                ],
                const SizedBox(height: 3.0),
                Text(
                  l10n.priceDecreased,
                  style: figStyle(
                    fontSize: 11.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.2,
                    color: _greenAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
