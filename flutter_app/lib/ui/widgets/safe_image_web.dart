// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

final Set<String> _registeredViews = {};

Widget safeNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? fallback,
}) {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty ||
      (!cleanUrl.startsWith('http://') &&
          !cleanUrl.startsWith('https://') &&
          !cleanUrl.startsWith('blob:'))) {
    return fallback ?? const SizedBox();
  }

  final viewType = 'img-${cleanUrl.hashCode.abs()}-${fit.name}';
  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = cleanUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover'
        ..style.border = 'none'
        ..style.pointerEvents = 'none'
        ..style.userSelect = 'none';
      return img;
    });
  }

  Widget child = IgnorePointer(child: HtmlElementView(viewType: viewType));
  if (borderRadius != null) {
    child = ClipRRect(borderRadius: borderRadius, child: child);
  }
  return IgnorePointer(child: child);
}
