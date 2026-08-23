// Интерактивный флоу онбординга (Кадры 2, 3, 4) с переходом по кнопке «Далее».
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../screens/screen_02_onboarding_1.dart';
import '../../screens/screen_03_onboarding_2.dart';
import '../../screens/screen_04_onboarding_3.dart';

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
    final frameNumber = switch (_step) {
      0 => '02',
      1 => '03',
      _ => '04',
    };

    return FigStage(
      frame: frame(frameNumber),
      background: const Color(0xffffffff),
      overlays: [
        // Интерактивная зона для кнопки «Далее» (31, 670, 314, 52)
        FigZone(
          31.0,
          670.0,
          314.0,
          52.0,
          label: 'Далее',
          onTap: _onNext,
        ),
      ],
    );
  }
}
