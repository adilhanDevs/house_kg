// «Код подтверждения» — кадр 08/57 макета с 4-значным вводом СМС-кода.
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/stage.dart';

class CodePage extends StatefulWidget {
  const CodePage({super.key, this.nextRoute = Routes.home});

  final String nextRoute;

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _code = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    if (value.length > 4) {
      value = value.substring(0, 4);
      _codeController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {
      _code = value;
    });

    if (value.length == 4) {
      // Автоматическое перенаправление при вводе 4 цифр
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          if (widget.nextRoute == Routes.home) {
            Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
          } else {
            Navigator.of(context).pushNamed(widget.nextRoute);
          }
        }
      });
    }
  }

  void _onGoBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProFlow = widget.nextRoute == Routes.proPhoto1;
    final frameId = isProFlow ? '57' : '08';

    return FigStage(
      frame: frame(frameId),
      background: const Color(0xffffffff),
      overlays: [
        // Дисплей 4 цифр кода (ручной ввод с клавиатуры)
        Positioned(
          left: 26.0,
          top: isProFlow ? 200.0 : 610.0,
          child: SizedBox(
            width: 272.0,
            height: 60.0,
            child: Stack(
              children: [
                // Скрытый фокусный TextField для получения ввода клавиатуры
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: _onCodeChanged,
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
                // Интерактивное наложение ручного ввода
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(4, (index) {
                        final hasInput = index < _code.length;
                        final digit = hasInput ? _code[index] : 'X';
                        final isFocused = _code.length == index || (_code.length == 4 && index == 3);

                        return Container(
                          width: 56.0,
                          height: 60.0,
                          margin: EdgeInsets.only(right: index < 3 ? 16.0 : 0.0),
                          color: const Color(0xffffffff),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  digit,
                                  style: TextStyle(
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                    color: hasInput
                                        ? const Color(0xff071e68)
                                        : const Color(0xff1c1939),
                                  ),
                                ),
                              ),
                              Container(
                                height: 2.0,
                                color: isFocused ? const Color(0xffea812e) : const Color(0xff071e68),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Кликбельная кнопка «Вернуться назад»
        Positioned(
          left: 0.0,
          top: isProFlow ? 280.0 : 726.0,
          width: 375.0,
          height: 44.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onGoBack,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: const Text(
                'Вернуться назад',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xffea812e),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
