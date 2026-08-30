import 'package:flutter/widgets.dart';

Widget safeNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? fallback,
}) {
  Widget img = Image.network(
    url,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => fallback ?? const SizedBox(),
  );
  if (borderRadius != null) {
    img = ClipRRect(borderRadius: borderRadius, child: img);
  }
  return img;
}
