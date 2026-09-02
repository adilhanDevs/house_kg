// Настоящие данные пользователя поверх статичных кадров профиля.
//
// В макете имя, аватар и плашка роли нарисованы картинкой («Садыр Жапаров»),
// поэтому страницы закрывают этот участок белой маской и кладут сверху эти
// виджеты с данными из `GET /users/me/`.
import 'package:flutter/material.dart';

import 'safe_image.dart';

/// Аватар из профиля; если фото нет — инициалы на фирменном фоне.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.url,
    this.initials = '',
    this.size = 64.0,
    this.radius = 12.0,
  });

  final String? url;
  final String initials;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xfffdf1e8),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '—' : initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.bold,
          color: const Color(0xffea812e),
        ),
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return SizedBox(
      width: size,
      height: size,
      child: buildSafeNetworkImage(
        url: url!,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
        fallback: placeholder,
      ),
    );
  }
}

/// Синяя плашка роли: «Клиент», «Собственник», «Риелтор», «Агентство».
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25.0,
      padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 3.0),
      decoration: BoxDecoration(
        color: const Color(0x33006cfb),
        borderRadius: BorderRadius.circular(4.0),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          height: 1.0,
          letterSpacing: -0.13,
          color: Color(0xff006cfb),
        ),
      ),
    );
  }
}

/// Обложка профиля; если фото нет — градиент-заглушка или переданный fallback.
class ProfileCover extends StatelessWidget {
  const ProfileCover({
    super.key,
    this.url,
    this.width = double.infinity,
    this.height = 140.0,
    this.radius = 16.0,
    this.borderRadius,
    this.fallback,
    this.darken = false,
  });

  final String? url;
  final double width;
  final double height;
  final double radius;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final bool darken;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(radius);
    final placeholder = fallback ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: effectiveRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfff7931e), Color(0xffea812e), Color(0xffcb6015)],
            ),
          ),
          child: const Center(
            child: Icon(Icons.photo_outlined, color: Colors.white70, size: 36),
          ),
        );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildSafeNetworkImage(
              url: url!,
              fit: BoxFit.cover,
              fallback: placeholder,
            ),
            if (darken)
              Container(
                color: const Color(0x5e000000),
              ),
          ],
        ),
      ),
    );
  }
}

