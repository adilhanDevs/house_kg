import 'package:flutter/widgets.dart';

import 'safe_image_stub.dart'
    if (dart.library.html) 'safe_image_web.dart';

Widget buildSafeNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? fallback,
}) {
  return safeNetworkImage(
    url: url,
    fit: fit,
    borderRadius: borderRadius,
    fallback: fallback,
  );
}
