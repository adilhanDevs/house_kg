// Интерактивный флоу онбординга (Кадры 2, 3, 4) с переходом по кнопке «Далее».
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../l10n/l10n.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0; // 0: Screen02Onboarding1, 1: Screen03Onboarding2, 2: Screen04Onboarding3

  void _onNext() {
    if (_step < 2) {
      setState(() {
        _step++;
      });
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() {
        _step--;
      });
    } else {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.welcome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final frameNumber = switch (_step) {
      0 => '02',
      1 => '03',
      _ => '04',
    };

    return FigStage(
      frame: frame(frameNumber),
      background: const Color(0xffffffff),
      overlays: [
        Positioned(
          left: 31.0,
          top: 670.0,
          width: 314.0,
          height: 52.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onNext,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffea812e),
                borderRadius: BorderRadius.circular(10.0),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.next,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
