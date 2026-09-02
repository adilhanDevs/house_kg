import 'package:flutter/material.dart';

/// Нижняя архитектурная иллюстрация для экранов авторизации и регистрации (Reference: Start screen).
///
/// Фасад здания строго привязан к нижнему краю (фундамент/тротуар на y = 0.000 у самого низа),
/// а верхняя часть плавно масштабируется и заполняет отведённую область без наложений на форму.
class AuthBottomIllustration extends StatelessWidget {
  const AuthBottomIllustration({
    super.key,
    this.height,
    this.assetPath = 'assets/figma/aab1efb98f0c6da0.png',
  });

  final double? height;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Координаты фасада в исходном ассете 3840 x 2743:
        // X: 200..2320 (ширина 2120)
        // Y: 80..2060 (высота 1980) — Y=2060 это линия фундамента
        const assetOriginalWidth = 3840.0;
        const assetOriginalHeight = 2743.0;
        const cropX1 = 200.0;
        const cropWidth = 2120.0;
        const cropBottomMargin = 2743.0 - 2060.0; // 683.0 px от фундамента до низа файла

        final imgWidth = screenWidth * (assetOriginalWidth / cropWidth);
        final imgHeight = imgWidth * (assetOriginalHeight / assetOriginalWidth);
        final leftOffset = -imgWidth * (cropX1 / assetOriginalWidth);
        final bottomOffset = -imgHeight * (cropBottomMargin / assetOriginalHeight);

        // По умолчанию высота иллюстрации на мобильных экранах 250..300 px
        final naturalHeight = (screenWidth * 0.72).clamp(200.0, 320.0);
        final containerHeight = height ?? naturalHeight;

        return ClipRect(
          child: SizedBox(
            width: double.infinity,
            height: containerHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: leftOffset,
                  bottom: bottomOffset,
                  width: imgWidth,
                  height: imgHeight,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      if (assetPath != 'assets/login/Register-screen-photo.png') {
                        return Image.asset(
                          'assets/login/Register-screen-photo.png',
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
