// Управляющие элементы макета, которым нужно состояние: чип, переключатель и
// поле ввода. Стили сняты с кадра «Фильтр».
//
// Каждый из них встаёт поверх такого же нарисованного, поэтому сначала
// закрывает его цветом страницы: в макете и невыбранный чип, и выключенный
// тумблер полупрозрачны, и без подложки нижний слой просвечивал бы.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

const Color _accentText = Color(0xe0ea812e);
const Color _mutedText = Color(0xe07d7d7d);
const Color _mutedBorder = Color(0x807d7d7d);

/// Заливка и обводка поля ввода — как на кадрах «Вход» и «Регистрация».
const Color _fieldFill = Color(0x1f787880);
const Color _fieldInk = Color(0x993c3c43);

/// Лупа слева в поле ввода: кружок и ручка, 16×16 в коробке 25×22.
class _SearchIcon extends StatelessWidget {
  const _SearchIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 25.0,
        height: 22.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0.0,
              top: 3.0,
              child: FigSvg(
                width: 16.0,
                height: 16.0,
                vbLeft: 0.0,
                vbTop: 0.0,
                vbWidth: 16.0,
                vbHeight: 16.0,
                shapes: [
                  FigShape(cx: 6.6, cy: 6.6, r: 5.1, stroke: _fieldInk, strokeWidth: 1.7),
                  FigShape(d: 'M 10.4 10.4 L 14.4 14.4', stroke: _fieldInk, strokeWidth: 1.7, roundCap: true),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Подложка под элемент, который встаёт на нарисованный.
class _Cover extends StatelessWidget {
  const _Cover({required this.width, required this.height, required this.child});

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              left: -4.0,
              top: -4.0,
              right: -4.0,
              bottom: -4.0,
              child: ColoredBox(color: Color(0xffffffff)),
            ),
            child,
          ],
        ),
      );
}

/// Чип-фильтр: 30 pt в высоту, радиус 8, подпись 13/500 по центру.
class FigChip extends StatelessWidget {
  const FigChip({
    super.key,
    required this.label,
    required this.width,
    required this.selected,
    this.onTap,
  });

  final String label;

  /// Ширина из макета — чтобы чип встал ровно на нарисованный.
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  static const double height = 30.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: selected ? const Color(0xfffdf1e8) : const Color(0xffffffff),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: selected ? const Color(0xfffdf1e8) : const Color(0xffe5e5ea),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? const Color(0xffea812e) : const Color(0x993c3c43),
            ),
          ),
        ),
      ),
    );
  }
}

/// Чип, в который вводят текст, — «Введите свою квадратуру» из «Фильтра».
class FigChipInput extends StatefulWidget {
  const FigChipInput({
    super.key,
    required this.width,
    this.controller,
    this.value,
    required this.hint,
    this.keyboardType,
    this.onChanged,
    this.onTap,
  });

  final double width;
  final TextEditingController? controller;
  final String? value;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  State<FigChipInput> createState() => _FigChipInputState();
}

class _FigChipInputState extends State<FigChipInput> {
  late final TextEditingController _ctrl;
  FocusNode? _focusNode;

  FocusNode get _effectiveFocusNode => _focusNode ??= FocusNode()..addListener(_handleFocusChange);

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus) {
      _scrollToSelf();
    }
  }

  void _scrollToSelf() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 1.0,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant FigChipInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && widget.value != null && widget.value != _ctrl.text) {
      _ctrl.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _focusNode?.removeListener(_handleFocusChange);
    _focusNode?.dispose();
    if (widget.controller == null) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = figStyle(
      fontSize: 13.0,
      family: FigFont.display,
      weight: 500,
      height: 1.077,
      letterSpacing: 0.065,
      color: _mutedText,
    );
    return _Cover(
      width: widget.width,
      height: FigChip.height,
      child: FigBox(
        width: widget.width,
        height: FigChip.height,
        radius: 8.0,
        blur: 2.0,
        opacity: 0.6,
        insets: const [FigInset(_mutedBorder, 1.0)],
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Center(
          child: TextField(
            controller: _ctrl,
            focusNode: _effectiveFocusNode,
            style: style,
            keyboardType: widget.keyboardType,
            cursorColor: _accentText,
            cursorWidth: 1.5,
            maxLines: 1,
            decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: style),
            onChanged: widget.onChanged,
            onTap: () {
              _scrollToSelf();
              widget.onTap?.call();
            },
          ),
        ),
      ),
    );
  }
}

/// Тумблер: в макете 30×16, радиус 8 (по высоте текста).
class FigToggle extends StatelessWidget {
  const FigToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  static const double width = 30.0;
  static const double height = 16.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: _Cover(
          width: width,
          height: height,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: value ? const Color(0xffea812e) : const Color(0xffe5e5ea),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  left: value ? 16.0 : 2.0,
                  top: 2.0,
                  child: Container(
                    width: 12.0,
                    height: 12.0,
                    decoration: const BoxDecoration(
                      color: Color(0xffffffff),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 2.0,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Поле ввода макета: серая плашка 36 pt с текстом 15/400.
class FigInputBox extends StatefulWidget {
  const FigInputBox({
    super.key,
    required this.width,
    this.controller,
    required this.hint,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
    this.searchIcon = true,
  });

  final double width;
  final TextEditingController? controller;
  final String hint;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// Лупа слева — она есть в макете у полей входа и регистрации, но не у
  /// «Цена от/до» в фильтре.
  final bool searchIcon;

  /// Размеры поля из макета: 324×36 на кадре шириной 375.
  static const double height = 36.0;

  @override
  State<FigInputBox> createState() => _FigInputBoxState();
}

class _FigInputBoxState extends State<FigInputBox> {
  TextEditingController? _internalCtrl;
  FocusNode? _internalNode;

  TextEditingController get _effectiveCtrl => widget.controller ?? (_internalCtrl ??= TextEditingController());
  FocusNode get _effectiveNode => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void dispose() {
    _internalCtrl?.dispose();
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = figStyle(
      fontSize: 15.0,
      family: FigFont.display,
      weight: 400,
      height: 1.467,
      letterSpacing: -0.43,
      color: const Color(0x993c3c43),
    );
    final textStyle = figStyle(
      fontSize: 15.0,
      family: FigFont.display,
      weight: 500,
      height: 1.467,
      letterSpacing: -0.43,
      color: const Color(0xff000000),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _effectiveNode.requestFocus(),
      child: _Cover(
        width: widget.width,
        height: FigInputBox.height,
        child: FigBox(
          width: widget.width,
          height: FigInputBox.height,
          color: _fieldFill,
          radius: 10.0,
          padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 7.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.searchIcon) const _SearchIcon(),
              Expanded(
                child: TextField(
                  controller: _effectiveCtrl,
                  focusNode: _effectiveNode,
                  style: textStyle,
                  keyboardType: widget.keyboardType,
                  cursorColor: const Color(0xffea812e),
                  cursorWidth: 1.5,
                  maxLines: 1,
                  decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: hintStyle),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
