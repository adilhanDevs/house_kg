// Поле поиска — та же плашка, что рисует макет, но в неё можно печатать.
//
// Размеры и стили сняты с «Каталога»: белая плашка радиусом 10 с обводкой
// #EEEEEE в полпикселя и двумя мягкими тенями, внутри отступ 15, иконка 14×14
// и текст 13/500 цвета #555555 через 8 pt.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Лупа из макета.
const String _glassRing =
    'M 6.222 0 C 2.786 0 0 2.786 0 6.222 C 0 9.658 2.786 12.444 6.222 12.444 C 9.658 12.444 12.444 9.658 12.444 6.222 C 12.444 2.786 9.658 0 6.222 0 Z M 1.244 6.222 C 1.244 3.473 3.473 1.244 6.222 1.244 C 8.971 1.244 11.2 3.473 11.2 6.222 C 11.2 8.971 8.971 11.2 6.222 11.2 C 3.473 11.2 1.244 8.971 1.244 6.222 Z';
const String _glassTail =
    'M 0.182 0.182 C 0.425 -0.061 0.819 -0.061 1.062 0.182 L 3.201 2.321 C 3.444 2.564 3.444 2.958 3.201 3.201 C 2.958 3.444 2.564 3.444 2.321 3.201 L 0.182 1.062 C -0.061 0.819 -0.061 0.425 0.182 0.182 Z';

const Color _accent = Color(0xffea812e);
const Color _text = Color(0xff555555);

class FigSearchField extends StatelessWidget {
  const FigSearchField({
    super.key,
    required this.width,
    this.fieldHeight = 40.0,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  final double width;
  final double fieldHeight;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const double height = 40.0;

  @override
  Widget build(BuildContext context) {
    final style = figStyle(
      fontSize: 13.0,
      family: FigFont.display,
      weight: 500,
      height: 1.538,
      letterSpacing: -0.13,
      color: _text,
    );
    return FigBox(
      width: width,
      height: fieldHeight,
      color: const Color(0xffffffff),
      radius: 10.0,
      padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 15.0),
      shadows: const [
        BoxShadow(color: Color(0xffeeeeee), blurRadius: 0.0, spreadRadius: 0.5),
        BoxShadow(color: Color(0x0a000000), blurRadius: 4.0),
        BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0),
      ],
      child: FigOverflow(
        alignment: const Alignment(-1.0, 0.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8.0,
          children: [
            const _Glass(),
            Expanded(
              child: TextField(
                controller: controller,
                style: style,
                cursorColor: _accent,
                cursorWidth: 1.5,
                cursorHeight: 15,
                maxLines: 1,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: style,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 14,
        height: 14,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: FigSvg(
                width: 12.444,
                height: 12.444,
                vbWidth: 12.444,
                vbHeight: 12.444,
                shapes: [FigShape(d: _glassRing, fill: _accent)],
              ),
            ),
            Positioned(
              left: 10.617,
              top: 10.617,
              child: FigSvg(
                width: 3.383,
                height: 3.383,
                vbWidth: 3.383,
                vbHeight: 3.383,
                shapes: [FigShape(d: _glassTail, fill: _accent)],
              ),
            ),
          ],
        ),
      );
}
