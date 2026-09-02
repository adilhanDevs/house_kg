import 'package:flutter/material.dart';

/// Верхняя архитектурная иллюстрация для экрана входа (Reference: Welcome screen / Frame 05).
///
/// Чертёж `aab1efb98f0c6da0.png` (3840x2743) кадрируется по осям F–B (X: 1450..3580)
/// и вертикали от отметок крыши до фундамента (Y: 80..2060).
class AuthTopIllustration extends StatelessWidget {
  const AuthTopIllustration({
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

        const assetOriginalWidth = 3840.0;
        const assetOriginalHeight = 2743.0;
        const cropX1 = 1450.0;
        const cropY1 = 80.0;
        const cropWidth = 2130.0;
        const cropHeight = 1980.0;

        final imgWidth = screenWidth * (assetOriginalWidth / cropWidth);
        final imgHeight = imgWidth * (assetOriginalHeight / assetOriginalWidth);
        final leftOffset = -imgWidth * (cropX1 / assetOriginalWidth);
        final topOffset = -imgHeight * (cropY1 / assetOriginalHeight);
        final naturalHeight = screenWidth * (cropHeight / cropWidth);

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
                  top: topOffset,
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
