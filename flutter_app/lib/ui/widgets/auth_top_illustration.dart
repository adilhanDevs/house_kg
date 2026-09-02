import 'package:flutter/material.dart';

/// Верхняя архитектурная иллюстрация для экрана входа (Reference: Frame 05).
class AuthTopIllustration extends StatelessWidget {
  const AuthTopIllustration({
    super.key,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.bottomCenter,
    this.assetPath = 'assets/login/welcome_top_illustration.png',
  });

  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: double.infinity,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        // Fallback на общий ассет чертежа с кадрированием
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;

            const assetOriginalWidth = 3840.0;
            const assetOriginalHeight = 2743.0;
            const cropX1 = 1380.0;
            const cropY1 = 70.0;
            const cropWidth = 1940.0;
            const cropHeight = 1990.0;

            final imgWidth = screenWidth * (assetOriginalWidth / cropWidth);
            final imgHeight = imgWidth * (assetOriginalHeight / assetOriginalWidth);
            final leftOffset = -imgWidth * (cropX1 / assetOriginalWidth);
            final topOffset = -imgHeight * (cropY1 / assetOriginalHeight);
            final naturalHeight = screenWidth * (cropHeight / cropWidth);

            return ClipRect(
              child: SizedBox(
                width: double.infinity,
                height: height ?? naturalHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: leftOffset,
                      top: topOffset,
                      width: imgWidth,
                      height: imgHeight,
                      child: Image.asset(
                        'assets/figma/aab1efb98f0c6da0.png',
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
