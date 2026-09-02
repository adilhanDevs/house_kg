// «Добро пожаловать!» — экран входа по номеру и паролю (Frame 05).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../widgets/auth_top_illustration.dart';

const Color _muted = Color(0x993c3c43);
const Color _accent = Color(0xffea812e);
const Color _fieldFill = Color(0x1f787880);
const Color _fieldInk = Color(0x993c3c43);

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  void _onLogin() async {
    if (_isLoading) return;
    final l10n = context.l10n;
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _complain(l10n.fillAllFields);
      return;
    }

    setState(() => _isLoading = true);
    final state = AppScope.read(context);
    try {
      await state.loginWithPassword(phone, password);
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.home, (route) => false);
      }
    } catch (e) {
      if (mounted) _complain(_errorText(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _errorText(Object error) {
    if (error is ApiException) return error.message;
    if (error is NetworkException) return error.message;
    return error.toString();
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xffd93025),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onRegister() {
    Navigator.of(context).pushNamed(Routes.register);
  }

  void _onForgotPassword() {
    Navigator.of(context).pushNamed(Routes.passwordReset);
  }

  void _onProMode() {
    final state = AppScope.read(context);
    state.pro = true;
    Navigator.of(context).pushNamed(Routes.proSignup);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final availableWidth = constraints.maxWidth;

            // На reference-height основную добавочную высоту получает иллюстрация.
            // Ограничение по ширине не даёт ей чрезмерно кадрироваться на узких экранах.
            final heightDrivenImage = availableHeight * 0.9 - 365.0;
            final widthDrivenImage = availableWidth * 1.24;
            final illustrationHeight = math
                .min(heightDrivenImage, widthDrivenImage)
                .clamp(170.0, 500.0)
                .toDouble();

            // Все интервалы меняются непрерывно; ни один из них не поглощает
            // свободную высоту отдельно от остальной композиции.
            final heightFactor = ((availableHeight - 500.0) / 344.0).clamp(
              0.0,
              1.0,
            );
            double responsiveGap(double compact, double reference) {
              return compact + (reference - compact) * heightFactor;
            }

            final topBarPadding = responsiveGap(8.0, 22.0);
            final stepBarToImage = responsiveGap(6.0, 13.0);
            final imageToTitle = responsiveGap(8.0, 12.0);
            final titleToSubtitle = responsiveGap(4.0, 6.0);
            final subtitleToFields = responsiveGap(10.0, 16.0);
            final fieldsGap = responsiveGap(8.0, 10.0);
            final fieldsToButton = responsiveGap(10.0, 14.0);
            final buttonToRegister = responsiveGap(12.0, 20.0);
            final registerToForgot = responsiveGap(4.0, 8.0);
            final forgotToExecutor = responsiveGap(16.0, 24.0);
            final bottomPadding = responsiveGap(10.0, 16.0);

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight,
                  maxWidth: availableWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Верхний прогресс-бар
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        25.0,
                        topBarPadding,
                        25.0,
                        0.0,
                      ),
                      child: const _StepBar(progress: 0.16),
                    ),
                    SizedBox(height: stepBarToImage),

                    // 2. Единая normal-flow композиция от иллюстрации до нижнего действия.
                    AuthTopIllustration(height: illustrationHeight),
                    SizedBox(height: imageToTitle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать!',
                            style: figStyle(
                              fontSize: 22.0,
                              family: FigFont.display,
                              weight: 700,
                              height: 1.1,
                              color: const Color(0xff000000),
                            ),
                          ),
                          SizedBox(height: titleToSubtitle),
                          Text(
                            'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.',
                            style: figStyle(
                              fontSize: 15.0,
                              family: FigFont.display,
                              weight: 400,
                              height: 1.35,
                              color: _muted,
                            ),
                          ),
                          SizedBox(height: subtitleToFields),
                          _Field(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            hint: l10n.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          SizedBox(height: fieldsGap),
                          _Field(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            hint: l10n.password,
                            keyboardType: TextInputType.visiblePassword,
                          ),
                          SizedBox(height: fieldsToButton),
                          _PrimaryButton(
                            label: l10n.login,
                            busy: _isLoading,
                            onTap: _onLogin,
                          ),
                          SizedBox(height: buttonToRegister),
                          Center(
                            child: _Link(
                              label: l10n.register,
                              color: _accent,
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                              onTap: _onRegister,
                            ),
                          ),
                          SizedBox(height: registerToForgot),
                          Center(
                            child: _Link(
                              label: l10n.forgotPassword,
                              color: const Color(0xff8e8e93),
                              fontSize: 13.0,
                              fontWeight: FontWeight.w400,
                              onTap: _onForgotPassword,
                            ),
                          ),
                          SizedBox(height: forgotToExecutor),
                          Center(
                            child: _Link(
                              label: 'Режим исполнителя',
                              color: const Color(0xff7d7d7d),
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              onTap: _onProMode,
                            ),
                          ),
                          SizedBox(height: bottomPadding),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Полоска прогресса вверху (оранжевый отрезок на серой подложке).
class _StepBar extends StatelessWidget {
  const _StepBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 4.0,
      decoration: BoxDecoration(
        color: const Color(0xffe5e5ea),
        borderRadius: BorderRadius.circular(2.0),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
      ),
    );
  }
}

/// Поле ввода: серая плашка 44 pt, лупа слева, радиус 10 pt.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final hintStyle = figStyle(
      fontSize: 15.0,
      family: FigFont.display,
      weight: 400,
      height: 1.467,
      letterSpacing: -0.43,
      color: _fieldInk,
    );
    final textStyle = figStyle(
      fontSize: 15.0,
      family: FigFont.display,
      weight: 500,
      height: 1.467,
      letterSpacing: -0.43,
      color: const Color(0xff000000),
    );

    return Container(
      width: double.infinity,
      height: 44.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        children: [
          const _SearchIcon(),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
              keyboardType: keyboardType,
              cursorColor: _accent,
              cursorWidth: 1.5,
              maxLines: 1,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: hintStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Иконка поиска слева в поле ввода.
class _SearchIcon extends StatelessWidget {
  const _SearchIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16.0,
      height: 16.0,
      child: FigSvg(
        width: 16.0,
        height: 16.0,
        vbLeft: 0.0,
        vbTop: 0.0,
        vbWidth: 16.0,
        vbHeight: 16.0,
        shapes: [
          FigShape(
            cx: 6.6,
            cy: 6.6,
            r: 5.1,
            stroke: _fieldInk,
            strokeWidth: 1.7,
          ),
          FigShape(
            d: 'M 10.4 10.4 L 14.4 14.4',
            stroke: _fieldInk,
            strokeWidth: 1.7,
            roundCap: true,
          ),
        ],
      ),
    );
  }
}

/// Основная оранжевая кнопка формы: 44 pt в высоту, радиус 10 pt (точно по размеру полей ввода).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 44.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? _accent.withValues(alpha: 0.6) : _accent,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: busy
            ? const SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xffffffff),
                ),
              )
            : Text(
                label,
                style: figStyle(
                  fontSize: 16.0,
                  family: FigFont.display,
                  weight: 600,
                  height: 1.25,
                  color: const Color(0xffffffff),
                ),
              ),
      ),
    );
  }
}

/// Текстовая ссылка.
class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.onTap,
    required this.color,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: figStyle(
          fontSize: fontSize,
          family: FigFont.display,
          weight: fontWeight == FontWeight.w600 ? 600 : 500,
          height: 1.333,
          color: color,
        ),
      ),
    );
  }
}
