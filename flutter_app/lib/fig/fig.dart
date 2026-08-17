// Runtime for the screens generated out of the Figma HTML prototype.
//
// The prototype ships every screen as absolutely-positioned CSS boxes on a
// 375pt-wide canvas. These widgets reproduce the handful of CSS features the
// markup actually uses — box + border-radius + shadows (incl. inset rings),
// background images, backdrop-filter, flexbox rows/columns and inline SVG —
// so the generated screens can stay a literal transcription of the design.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Font families used by the design.
///
/// The prototype's CSS stack is `"SF Pro Text", -apple-system,
/// BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial,
/// sans-serif` — in practice it resolves to the platform UI font. Leaving
/// these `null` makes Flutter do exactly the same thing (San Francisco on
/// iOS/macOS, Roboto on Android). Point them at a bundled font family here if
/// you ever need byte-identical text on every platform.
abstract final class FigFont {
  static const String? text = null;
  static const String? display = null;
  static const String? pro = null;
}

const FontWeight _w400 = FontWeight.w400;

FontWeight _weight(int w) => switch (w) {
      100 => FontWeight.w100,
      200 => FontWeight.w200,
      300 => FontWeight.w300,
      400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      800 => FontWeight.w800,
      900 => FontWeight.w900,
      _ => _w400,
    };

/// A CSS text run. [height] is `line-height / font-size`; the even leading
/// distribution is what makes Flutter's line boxes match the browser's.
TextStyle figStyle({
  required double fontSize,
  String? family,
  int weight = 400,
  double? height,
  double? letterSpacing,
  Color? color,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: _weight(weight),
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// `vertical-align: super` on a smaller run (the "м²" superscripts).
InlineSpan figSuper(String text, TextStyle style, double parentFontSize) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Transform.translate(
      offset: Offset(0, -parentFontSize * 0.34),
      child: Text(text, style: style),
    ),
  );
}

/// Recolours everything below it.
///
/// The prototype restyles the tab bar after mounting it — the active tab turns
/// accent and its label goes semibold — by walking the mounted `<svg>`s and
/// `<span>`s and overwriting their colour. This is the same override, applied
/// through the widget tree instead.
class FigTint extends InheritedWidget {
  const FigTint({super.key, required this.color, this.weight, required super.child});

  final Color color;
  final int? weight;

  static FigTint? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FigTint>();

  @override
  bool updateShouldNotify(FigTint old) => old.color != color || old.weight != weight;
}

/// A `<span>` from the design: an inline span tree in a fixed-size box.
class FigText extends StatelessWidget {
  const FigText({
    super.key,
    required this.span,
    this.width,
    this.height,
    this.align = TextAlign.start,
    this.noWrap = false,
    this.ellipsis = false,
    this.opacity,
  });

  final InlineSpan span;
  final double? width;
  final double? height;
  final TextAlign align;

  /// `white-space: nowrap`
  final bool noWrap;

  /// `text-overflow: ellipsis`
  final bool ellipsis;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final tint = FigTint.of(context);
    Widget child = Text.rich(
      tint == null ? span : _tinted(span, tint),
      textAlign: align,
      softWrap: !noWrap,
      maxLines: ellipsis ? 1 : null,
      overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.visible,
      textHeightBehavior: const TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    if (opacity != null) child = Opacity(opacity: opacity!, child: child);
    return child;
  }

  InlineSpan _tinted(InlineSpan span, FigTint tint) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: (span.style ?? const TextStyle()).copyWith(
        color: tint.color,
        fontWeight: tint.weight == null ? null : _weight(tint.weight!),
      ),
      children: span.children?.map((s) => _tinted(s, tint)).toList(),
    );
  }
}

/// `box-shadow: inset 0 0 0 <width> <color>` — a ring drawn inside the box
/// that, unlike a real border, takes up no layout space.
class FigInset {
  const FigInset(this.color, this.width);

  final Color color;
  final double width;
}

/// A CSS `background-image`.
///
/// With no factors it is `center / cover`. With them it is the percentage
/// form — `background-position: x% y%` / `background-size: w% h%` — where the
/// image is scaled to a fraction of the box and the same relative point of
/// image and box are lined up.
class FigBgImage {
  const FigBgImage(
    this.asset, {
    this.x = 0.5,
    this.y = 0.5,
    this.wFactor,
    this.hFactor,
  });

  final String asset;
  final double x;
  final double y;
  final double? wFactor;
  final double? hFactor;
}

/// A `<div>` from the design.
class FigBox extends StatelessWidget {
  const FigBox({
    super.key,
    this.width,
    this.height,
    this.color,
    this.radius,
    this.corners,
    this.clip = false,
    this.opacity,
    this.blur,
    this.padding,
    this.shadows = const [],
    this.insets = const [],
    this.border,
    this.bgImage,
    this.overlays = const [],
    this.child,
  });

  final double? width;
  final double? height;
  final Color? color;

  /// `border-radius` with one value for all four corners.
  final double? radius;

  /// `border-radius` written per corner, clockwise from the top left, as CSS
  /// does it: the bottom sheets round only their top.
  final List<double>? corners;

  /// `overflow: hidden`
  final bool clip;
  final double? opacity;

  /// `backdrop-filter: blur()`, already converted to a sigma.
  final double? blur;
  final EdgeInsets? padding;
  final List<BoxShadow> shadows;
  final List<FigInset> insets;

  /// A CSS `border`. The generator has already folded its width into [width],
  /// [height] and [padding], so this only paints.
  final Border? border;
  final FigBgImage? bgImage;

  /// Gradients painted over the background image, in CSS source order.
  final List<Gradient> overlays;
  final Widget? child;

  BorderRadius get _radius {
    if (corners != null) {
      final [tl, tr, br, bl] = corners!;
      return BorderRadius.only(
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomRight: Radius.circular(br),
        bottomLeft: Radius.circular(bl),
      );
    }
    return radius == null ? BorderRadius.zero : BorderRadius.circular(radius!);
  }

  Widget _background(FigBgImage b) {
    final image = AssetImage(b.asset);
    if (b.wFactor == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          image: DecorationImage(image: image, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: _radius,
      child: FractionallySizedBox(
        alignment: Alignment(b.x * 2 - 1, b.y * 2 - 1),
        widthFactor: b.wFactor,
        heightFactor: b.hFactor,
        child: Image(image: image, fit: BoxFit.fill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? content = child;
    if (content != null && padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    final layers = <Widget>[];
    if (bgImage != null) {
      layers.add(Positioned.fill(child: _background(bgImage!)));
    }
    for (final gradient in overlays) {
      layers.add(Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient, borderRadius: _radius),
        ),
      ));
    }
    if (border != null) {
      layers.add(Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: _radius, border: border),
          ),
        ),
      ));
    }
    for (final inset in insets) {
      layers.add(Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _radius,
              border: Border.all(
                color: inset.color,
                width: inset.width,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
          ),
        ),
      ));
    }
    if (content != null) layers.add(content);

    // The unpositioned child (the content) is what sizes the stack, so boxes
    // without an explicit size still grow to fit — as they do in CSS.
    Widget core = layers.isEmpty
        ? const SizedBox.shrink()
        : layers.length == 1 && content != null
            ? content
            : Stack(clipBehavior: Clip.none, children: layers);

    if (color != null) {
      core = DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: _radius),
        child: core,
      );
    }
    if (blur != null) {
      core = ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
          child: core,
        ),
      );
    } else if (clip) {
      core = ClipRRect(borderRadius: _radius, child: core);
    }
    if (width != null || height != null) {
      core = SizedBox(width: width, height: height, child: core);
    }
    if (shadows.isNotEmpty) {
      core = DecoratedBox(
        decoration: BoxDecoration(borderRadius: _radius, boxShadow: shadows),
        child: core,
      );
    }
    if (opacity != null) core = Opacity(opacity: opacity!, child: core);
    return core;
  }
}

/// Lays its child out with one axis unconstrained, then takes the parent's
/// size and aligns the child inside it.
///
/// This is `overflow: visible`. A CSS flex box hands its items the space they
/// ask for and simply lets them spill past a fixed width or height; Flutter's
/// [Flex] instead clamps them to the box. Wrapping the flex in this widget
/// restores the CSS behaviour, and is a no-op whenever the content does fit.
class FigOverflow extends SingleChildRenderObjectWidget {
  const FigOverflow({
    super.key,
    this.freeWidth = false,
    this.freeHeight = true,
    this.alignment = Alignment.center,
    required Widget super.child,
  });

  /// Axes left unconstrained for the child.
  final bool freeWidth;
  final bool freeHeight;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFigOverflow(freeWidth, freeHeight, alignment);

  @override
  void updateRenderObject(BuildContext context, _RenderFigOverflow renderObject) {
    renderObject
      ..freeWidth = freeWidth
      ..freeHeight = freeHeight
      ..alignment = alignment;
  }
}

class _RenderFigOverflow extends RenderShiftedBox {
  _RenderFigOverflow(this._freeWidth, this._freeHeight, this._alignment)
      : super(null);

  bool _freeWidth;
  bool get freeWidth => _freeWidth;
  set freeWidth(bool value) {
    if (_freeWidth == value) return;
    _freeWidth = value;
    markNeedsLayout();
  }

  bool _freeHeight;
  bool get freeHeight => _freeHeight;
  set freeHeight(bool value) {
    if (_freeHeight == value) return;
    _freeHeight = value;
    markNeedsLayout();
  }

  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(
        minWidth: freeWidth ? 0 : constraints.minWidth,
        maxWidth: freeWidth ? double.infinity : constraints.maxWidth,
        minHeight: freeHeight ? 0 : constraints.minHeight,
        maxHeight: freeHeight ? double.infinity : constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset =
        alignment.alongOffset((size - child.size) as Offset);
  }
}

/// One `<path>` or `<circle>` inside a [FigSvg], in viewBox units.
class FigShape {
  const FigShape({
    this.d,
    this.fill,
    this.evenOdd = false,
    this.stroke,
    this.strokeWidth = 1,
    this.roundCap = false,
    this.roundJoin = false,
    this.cx,
    this.cy,
    this.r,
  });

  final String? d;
  final Color? fill;
  final bool evenOdd;
  final Color? stroke;
  final double strokeWidth;
  final bool roundCap;
  final bool roundJoin;
  final double? cx;
  final double? cy;
  final double? r;

  FigShape tinted(Color color) => FigShape(
        d: d,
        fill: fill == null ? null : color,
        evenOdd: evenOdd,
        stroke: stroke == null ? null : color,
        strokeWidth: strokeWidth,
        roundCap: roundCap,
        roundJoin: roundJoin,
        cx: cx,
        cy: cy,
        r: r,
      );
}

/// An inline `<svg>`: shapes in viewBox units scaled into a `width × height`
/// box. `currentColor` is already resolved when the screen is generated.
class FigSvg extends StatelessWidget {
  const FigSvg({
    super.key,
    required this.width,
    required this.height,
    required this.vbWidth,
    required this.vbHeight,
    this.vbLeft = 0,
    this.vbTop = 0,
    required this.shapes,
    this.dropShadows = const [],
  });

  final double width;
  final double height;
  final double vbLeft;
  final double vbTop;
  final double vbWidth;
  final double vbHeight;
  final List<FigShape> shapes;

  /// `filter: drop-shadow(…)`, in CSS pixels, outermost first.
  final List<BoxShadow> dropShadows;

  @override
  Widget build(BuildContext context) {
    final tint = FigTint.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FigSvgPainter(
          vbLeft,
          vbTop,
          vbWidth,
          vbHeight,
          tint == null ? shapes : shapes.map((s) => s.tinted(tint.color)).toList(),
          dropShadows,
        ),
        size: Size(width, height),
      ),
    );
  }
}

class _FigSvgPainter extends CustomPainter {
  const _FigSvgPainter(
    this.vbLeft,
    this.vbTop,
    this.vbWidth,
    this.vbHeight,
    this.shapes,
    this.dropShadows,
  );

  final double vbLeft;
  final double vbTop;
  final double vbWidth;
  final double vbHeight;
  final List<FigShape> shapes;
  final List<BoxShadow> dropShadows;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / vbWidth, size.height / vbHeight);
    canvas.translate(-vbLeft, -vbTop);
    for (final shadow in dropShadows.reversed) {
      final paint = Paint()
        ..color = shadow.color
        ..maskFilter = shadow.blurRadius > 0
            ? MaskFilter.blur(BlurStyle.normal, shadow.blurRadius / 2)
            : null;
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      for (final shape in shapes) {
        if (shape.d != null) {
          canvas.drawPath(figPath(shape.d!, shape.evenOdd), paint);
        } else if (shape.r != null) {
          canvas.drawCircle(Offset(shape.cx!, shape.cy!), shape.r!, paint);
        }
      }
      canvas.restore();
    }
    for (final shape in shapes) {
      if (shape.fill != null) {
        final paint = Paint()
          ..color = shape.fill!
          ..style = PaintingStyle.fill;
        if (shape.d != null) {
          canvas.drawPath(figPath(shape.d!, shape.evenOdd), paint);
        } else if (shape.r != null) {
          canvas.drawCircle(Offset(shape.cx!, shape.cy!), shape.r!, paint);
        }
      }
      if (shape.stroke != null) {
        final paint = Paint()
          ..color = shape.stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = shape.strokeWidth
          ..strokeCap = shape.roundCap ? StrokeCap.round : StrokeCap.butt
          ..strokeJoin = shape.roundJoin ? StrokeJoin.round : StrokeJoin.miter;
        if (shape.d != null) {
          canvas.drawPath(figPath(shape.d!, shape.evenOdd), paint);
        } else if (shape.r != null) {
          canvas.drawCircle(Offset(shape.cx!, shape.cy!), shape.r!, paint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigSvgPainter old) =>
      old.shapes != shapes ||
      old.dropShadows != dropShadows ||
      old.vbLeft != vbLeft ||
      old.vbTop != vbTop ||
      old.vbWidth != vbWidth ||
      old.vbHeight != vbHeight;
}

final Map<String, Path> _pathCache = {};

final RegExp _pathToken = RegExp(r'([MmLlHhVvCcSsZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)');

/// Parses SVG path data. The exported screens only ever use absolute `M`, `L`,
/// `C` and `Z`, but the tab bar's heart icon comes from the prototype's own
/// markup and is written with relative commands, so this handles both.
/// Results are cached — the same icon path repeats across screens.
Path figPath(String d, [bool evenOdd = false]) {
  final key = evenOdd ? 'e:$d' : d;
  return _pathCache.putIfAbsent(key, () {
    final path = Path();
    if (evenOdd) path.fillType = PathFillType.evenOdd;

    final tokens = _pathToken.allMatches(d).toList();
    var i = 0;
    var command = '';
    double x = 0, y = 0, startX = 0, startY = 0;

    bool atCommand() => i < tokens.length && tokens[i].group(1) != null;
    double number() {
      final value = tokens[i].group(2);
      if (value == null) {
        throw FormatException('expected a number in path command "$command": $d');
      }
      i++;
      return double.parse(value);
    }

    while (i < tokens.length) {
      if (atCommand()) command = tokens[i++].group(1)!;
      final relative = command == command.toLowerCase();
      final dx = relative ? x : 0.0;
      final dy = relative ? y : 0.0;
      switch (command.toUpperCase()) {
        case 'M':
          x = dx + number();
          y = dy + number();
          path.moveTo(x, y);
          startX = x;
          startY = y;
          // extra coordinate pairs after a moveto are implicit linetos
          command = relative ? 'l' : 'L';
        case 'L':
          x = dx + number();
          y = dy + number();
          path.lineTo(x, y);
        case 'H':
          x = dx + number();
          path.lineTo(x, y);
        case 'V':
          y = dy + number();
          path.lineTo(x, y);
        case 'C':
          final x1 = dx + number();
          final y1 = dy + number();
          final x2 = dx + number();
          final y2 = dy + number();
          x = dx + number();
          y = dy + number();
          path.cubicTo(x1, y1, x2, y2, x, y);
        case 'Z':
          path.close();
          x = startX;
          y = startY;
          if (!atCommand() && i < tokens.length) {
            throw FormatException('numbers after a close-path command in: $d');
          }
        default:
          throw FormatException('unsupported path command "$command" in: $d');
      }
    }
    return path;
  });
}
