import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';

class ProPhotoConfirmPage extends StatefulWidget {
  const ProPhotoConfirmPage({super.key});

  @override
  State<ProPhotoConfirmPage> createState() => _ProPhotoConfirmPageState();
}

class _ProPhotoConfirmPageState extends State<ProPhotoConfirmPage> {
  bool _faceUploaded = false;
  bool _passportUploaded = true;

  void _onNext() {
    final state = AppScope.read(context);
    state.pro = true;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.pro, (route) => false);
  }

  void _checkAutoAdvance() {
    if (_faceUploaded && _passportUploaded) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _faceUploaded && _passportUploaded) {
          _onNext();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    return FigStage(
      frame: frame('24'),
      background: const Color(0xffffffff),
      overlays: [
        // Кнопка «Загрузить / Загружено» для фото с лицом
        Positioned(
          left: 255.0,
          top: 200.0,
          width: 95.0,
          height: 36.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _faceUploaded = !_faceUploaded);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(_faceUploaded ? 'Фото с лицом загружено!' : 'Фото с лицом удалено'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: orangeColor,
                ),
              );
              _checkAutoAdvance();
            },
            child: Container(
              decoration: BoxDecoration(
                color: _faceUploaded ? orangeColor : const Color(0xffffffff),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _faceUploaded ? orangeColor : const Color(0xff7d7d7d).withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _faceUploaded ? 'Загружено' : 'Загрузить',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: _faceUploaded ? Colors.white : const Color(0xff7d7d7d),
                ),
              ),
            ),
          ),
        ),

        // Кнопка «Загрузить / Загружено» для фото с паспортом
        Positioned(
          left: 255.0,
          top: 248.0,
          width: 95.0,
          height: 36.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _passportUploaded = !_passportUploaded);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(_passportUploaded ? 'Фото с паспортом загружено!' : 'Фото с паспортом удалено'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: orangeColor,
                ),
              );
              _checkAutoAdvance();
            },
            child: Container(
              decoration: BoxDecoration(
                color: _passportUploaded ? orangeColor : const Color(0xffffffff),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _passportUploaded ? orangeColor : const Color(0xff7d7d7d).withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _passportUploaded ? 'Загружено' : 'Загрузить',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: _passportUploaded ? Colors.white : const Color(0xff7d7d7d),
                ),
              ),
            ),
          ),
        ),

        // Кнопка [ Далее ] (размер из макета 324 × 36)
        Positioned(
          left: 25.0,
          top: 310.0,
          width: 324.0,
          height: 36.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onNext,
            child: Container(
              decoration: BoxDecoration(
                color: orangeColor,
                borderRadius: BorderRadius.circular(18.0),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Далее',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
