import 'package:flutter/material.dart';

import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';

class CategoryPageArgs {
  const CategoryPageArgs(this.kind);
  final PropertyKind kind;
}

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.kind});

  final PropertyKind kind;

  @override
  Widget build(BuildContext context) {
    final title = kind.localized(context.l10n);

    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      appBar: AppBar(
        backgroundColor: const Color(0xffffffff),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xff000000),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: figStyle(
            fontSize: 20.0,
            family: FigFont.display,
            weight: 600,
            color: const Color(0xff000000),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80.0,
                  height: 80.0,
                  decoration: BoxDecoration(
                    color: const Color(0xfffdf1e8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 40.0,
                    color: Color(0xffea812e),
                  ),
                ),
                const SizedBox(height: 24.0),
                const Text(
                  'Экран в разработке',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff000000),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12.0),
                const Text(
                  'Данный раздел находится в процессе разработки и скоро станет доступен.',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                    color: Color(0xff7d7d7d),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32.0),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffea812e),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Text(
                      'Вернуться назад',
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffffffff),
                      ),
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
