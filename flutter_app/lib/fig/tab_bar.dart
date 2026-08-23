// GENERATED from screens/Components.bundle.js — the mockup's tab bar,
// restyled the way the prototype does at runtime.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import 'fig.dart';

/// The bottom tab bar: Главное · Поиск · История · Избранное · Профиль.
class FigTabBar extends StatelessWidget {
  const FigTabBar({super.key, this.active, this.mockupTab, this.onTap});

  /// Which tab the prototype highlights (`SCREEN_TAB`), or null where it
  /// leaves the mockup's own colours alone.
  final int? active;

  /// Which tab the mockup draws highlighted on the screen the bar is on.
  /// The bar is drawn once, from the catalog screen, so screens whose
  /// mockup marks another tab pass it here — colour only, no bolder label,
  /// exactly as the mockup has it. Ignored once [active] is set.
  final int? mockupTab;

  final void Function(int index)? onTap;

  /// The box the mockup clips the bar to where it draws it itself.
  static const double clipWidth = 375.0;
  static const double clipHeight = 84.0;

  static const Color _accent = Color(0xffea812e);
  static const Color _idle = Color(0xffacacb0);

  // the two colours the mockup uses to mark a tab as selected
  static bool _isSelected(Color base) {
    final rgb = base.toARGB32() & 0xFFFFFF;
    return rgb == 0xEA812E || rgb == 0xFF2727;
  }

  Color _color(int cell, Color base) {
    if (active == null) {
      if (mockupTab == null) return base;
      if (mockupTab == cell) return _accent;
      return _isSelected(base) ? _idle : base;
    }
    if (active == cell) return _accent;
    return _isSelected(base) ? _idle : base;
  }

  int? _weight(int cell) => active == cell ? 600 : null;

  Widget _tab(int index, Widget child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(index),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 377.0,
      height: 85.5,
      color: const Color(0xffffffff),
      radius: 8.0,
      blur: 32.0,
      padding: const EdgeInsets.fromLTRB(1.0, 0.5, 1.0, 1.0),
      border: const Border(top: BorderSide(color: Color(0xffececec), width: 0.5), right: BorderSide(color: Color(0xffffffff), width: 1.0), bottom: BorderSide(color: Color(0xffffffff), width: 1.0), left: BorderSide(color: Color(0xffffffff), width: 1.0)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 28.0, top: 11.0,
            child: FigBox(
              width: 320.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _tab(0,
                      FigBox(
                        width: 37.0,
                        child: FigOverflow(
                          alignment: const Alignment(0.0, -1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 3.0,
                            children: [
                              FigTint(
                                color: _color(0, const Color(0xffacacb0)),
                                child: FigBox(
                                  width: 24.0,
                                  height: 24.0,
                                  clip: true,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 1.0, top: 2.0,
                                        child: FigSvg(
                                          width: 22.731, height: 20.0,
                                          vbLeft: 0.0, vbTop: 0.0, vbWidth: 22.731, vbHeight: 20.0,
                                          shapes: const [FigShape(d: _p0, fill: Color(0xffacacb0))],
                                        )
                                      ),
                                    ],
                                  )
                                  ,
                                )
                                ,
                              ),
                              FigTint(
                                color: _color(0, const Color(0xffacacb0)),
                                weight: _weight(0),
                                child: FigText(
                                  width: 37.0,
                                  span: 
                                    TextSpan(text: 'Главное', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xffacacb0)))
                                  ,
                                )
                                ,
                              ),
                            ],
                          )
                          ,
                        )
                        ,
                      )
                    ),
                    _tab(1,
                      FigBox(
                        width: 39.0,
                        child: FigOverflow(
                          alignment: const Alignment(0.0, -1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 3.0,
                            children: [
                              FigTint(
                                color: _color(1, const Color(0xffea812e)),
                                child: FigBox(
                                  width: 24.0,
                                  height: 24.0,
                                  clip: true,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 1.0, top: 2.0,
                                        child: Opacity(
                                          opacity: 0.0,
                                          child: FigSvg(
                                            width: 21.548, height: 20.0,
                                            vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.548, vbHeight: 20.0,
                                            shapes: const [FigShape(d: _p1, fill: Color(0xffea812e))],
                                          ),
                                        )
                                      ),
                                      Positioned(
                                        left: 2.5, top: 2.0,
                                        child: FigBox(
                                          width: 19.443,
                                          height: 19.268,
                                          clip: true,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                left: 0.0, top: 0.0,
                                                child: Opacity(
                                                  opacity: 0.0,
                                                  child: FigSvg(
                                                    width: 19.443, height: 19.268,
                                                    vbLeft: 0.0, vbTop: 0.0, vbWidth: 19.443, vbHeight: 19.268,
                                                    shapes: const [FigShape(d: _p2, fill: Color(0xffea812e))],
                                                  ),
                                                )
                                              ),
                                              Positioned(
                                                left: 0.0, top: 0.0,
                                                child: FigSvg(
                                                  width: 19.082, height: 19.268,
                                                  vbLeft: 0.0, vbTop: 0.0, vbWidth: 19.082, vbHeight: 19.268,
                                                  shapes: const [FigShape(d: _p3, fill: Color(0xffea812e))],
                                                )
                                              ),
                                            ],
                                          )
                                          ,
                                        )
                                      ),
                                    ],
                                  )
                                  ,
                                )
                                ,
                              ),
                              FigTint(
                                color: _color(1, const Color(0xffea812e)),
                                weight: _weight(1),
                                child: FigText(
                                  noWrap: true,
                                  span: 
                                    TextSpan(text: 'Поиск', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xffea812e)))
                                  ,
                                )
                                ,
                              ),
                            ],
                          )
                          ,
                        )
                        ,
                      )
                    ),
                    _tab(2,
                      FigBox(
                        width: 39.0,
                        child: FigOverflow(
                          alignment: const Alignment(0.0, -1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 3.0,
                            children: [
                              FigTint(
                                color: _color(2, const Color(0xffb1b1b5)),
                                child: FigBox(
                                  width: 24.0,
                                  height: 24.0,
                                  clip: true,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 1.0, top: 2.0,
                                        child: Opacity(
                                          opacity: 0.0,
                                          child: FigSvg(
                                            width: 21.548, height: 20.0,
                                            vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.548, vbHeight: 20.0,
                                            shapes: const [FigShape(d: _p1, fill: Color(0xf2aeaeb2))],
                                          ),
                                        )
                                      ),
                                      Positioned(
                                        left: 2.5, top: 1.0,
                                        child: FigBox(
                                          width: 20.0,
                                          height: 21.28,
                                          clip: true,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                left: 0.0, top: 0.0,
                                                child: Opacity(
                                                  opacity: 0.0,
                                                  child: FigSvg(
                                                    width: 20.0, height: 21.28,
                                                    vbLeft: 0.0, vbTop: 0.0, vbWidth: 20.0, vbHeight: 21.28,
                                                    shapes: const [FigShape(d: _p4, fill: Color(0xffb1b1b5))],
                                                  ),
                                                )
                                              ),
                                              Positioned(
                                                left: 5.465, top: 1.312,
                                                child: FigSvg(
                                                  width: 8.72, height: 1.03,
                                                  vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.72, vbHeight: 1.03,
                                                  shapes: const [FigShape(d: _p5, fill: Color(0xffb1b1b5))],
                                                )
                                              ),
                                              Positioned(
                                                left: 3.53, top: 3.436,
                                                child: FigSvg(
                                                  width: 12.591, height: 1.204,
                                                  vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.591, vbHeight: 1.204,
                                                  shapes: const [FigShape(d: _p6, fill: Color(0xffb1b1b5))],
                                                )
                                              ),
                                              Positioned(
                                                left: 1.524, top: 5.874,
                                                child: FigSvg(
                                                  width: 16.602, height: 14.112,
                                                  vbLeft: 0.0, vbTop: 0.0, vbWidth: 16.602, vbHeight: 14.112,
                                                  shapes: const [FigShape(d: _p7, fill: Color(0xffb1b1b5))],
                                                )
                                              ),
                                              Positioned(
                                                left: 7.118, top: 9.743,
                                                child: FigSvg(
                                                  width: 6.634, height: 6.47,
                                                  vbLeft: 0.0, vbTop: 0.0, vbWidth: 6.634, vbHeight: 6.47,
                                                  shapes: const [FigShape(d: _p8, fill: Color(0xffb1b1b5))],
                                                )
                                              ),
                                            ],
                                          )
                                          ,
                                        )
                                      ),
                                    ],
                                  )
                                  ,
                                )
                                ,
                              ),
                              FigTint(
                                color: _color(2, const Color(0xf2aeaeb2)),
                                weight: _weight(2),
                                child: FigText(
                                  noWrap: true,
                                  width: 39.0,
                                  span: 
                                    TextSpan(text: 'История', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
                                  ,
                                )
                                ,
                              ),
                            ],
                          )
                          ,
                        )
                        ,
                      )
                    ),
                    _tab(3,
                      FigBox(
                        width: 39.0,
                        child: FigOverflow(
                          alignment: const Alignment(0.0, -1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 3.0,
                            children: [
                              FigTint(
                                color: _color(3, const Color(0xffacacb0)),
                                child: FigBox(
                                  width: 24.0,
                                  height: 24.0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 0.0, top: 0.0,
                                        child: FigSvg(
                                          width: 24.0, height: 24.0,
                                          vbLeft: 0.0, vbTop: 0.0, vbWidth: 24.0, vbHeight: 24.0,
                                          shapes: const [FigShape(d: _p9, stroke: Color(0xff000000), strokeWidth: 1.7, roundJoin: true)],
                                        )
                                      ),
                                    ],
                                  )
                                  ,
                                )
                                ,
                              ),
                              FigTint(
                                color: _color(3, const Color(0xf2aeaeb2)),
                                weight: _weight(3),
                                child: FigText(
                                  noWrap: true,
                                  width: 39.0,
                                  span: 
                                    TextSpan(text: 'Избранное', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
                                  ,
                                )
                                ,
                              ),
                            ],
                          )
                          ,
                        )
                        ,
                      )
                    ),
                    _tab(4,
                      FigBox(
                        width: 42.0,
                        child: FigOverflow(
                          alignment: const Alignment(0.0, -1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 3.0,
                            children: [
                              FigTint(
                                color: _color(4, const Color(0xf2aeaeb2)),
                                child: FigBox(
                                  width: 24.0,
                                  height: 24.0,
                                  clip: true,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 2.0, top: 2.0,
                                        child: FigSvg(
                                          width: 20.0, height: 20.0,
                                          vbLeft: 0.0, vbTop: 0.0, vbWidth: 20.0, vbHeight: 20.0,
                                          shapes: const [FigShape(d: _p10, fill: Color(0xf2aeaeb2))],
                                        )
                                      ),
                                    ],
                                  )
                                  ,
                                )
                                ,
                              ),
                              FigTint(
                                color: _color(4, const Color(0xf2aeaeb2)),
                                weight: _weight(4),
                                child: FigText(
                                  width: 42.0,
                                  span: 
                                    TextSpan(text: 'Профиль', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
                                  ,
                                )
                                ,
                              ),
                            ],
                          )
                          ,
                        )
                        ,
                      )
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
        ],
      )
      ,
    );
  }
}

const String _p0 =
    'M 8.618 19.019 L 14.113 19.019 L 14.113 12.087 C 14.113 11.649 13.827 11.363 13.389 11.363 L 9.351 11.363 C 8.904 11.363 8.618 11.649 8.618 12.087 L 8.618 19.019 Z M 4.895 20 L 17.779 20 C 19.131 20 19.921 19.229 19.921 17.895 L 19.921 7.373 L 18.388 6.325 L 18.388 17.505 C 18.388 18.124 18.055 18.467 17.455 18.467 L 5.218 18.467 C 4.609 18.467 4.276 18.124 4.276 17.505 L 4.276 6.335 L 2.743 7.373 L 2.743 17.895 C 2.743 19.229 3.533 20 4.895 20 Z M 0 9.401 C 0 9.792 0.305 10.163 0.819 10.163 C 1.086 10.163 1.305 10.02 1.505 9.858 L 11.037 1.859 C 11.246 1.669 11.503 1.669 11.713 1.859 L 21.245 9.858 C 21.435 10.02 21.654 10.163 21.921 10.163 C 22.369 10.163 22.731 9.887 22.731 9.43 C 22.731 9.144 22.635 8.954 22.435 8.782 L 12.522 0.45 C 11.818 -0.15 10.942 -0.15 10.227 0.45 L 0.305 8.782 C 0.095 8.954 0 9.182 0 9.401 Z M 17.531 5.107 L 19.921 7.125 L 19.921 2.726 C 19.921 2.307 19.655 2.04 19.236 2.04 L 18.217 2.04 C 17.807 2.04 17.531 2.307 17.531 2.726 L 17.531 5.107 Z';
const String _p1 =
    'M 21.548 0 L 0 0 L 0 20 L 21.548 20 L 21.548 0 Z';
const String _p2 =
    'M 19.443 0 L 0 0 L 0 19.268 L 19.443 19.268 L 19.443 0 Z';
const String _p3 =
    'M 0 7.793 C 0 12.09 3.496 15.586 7.793 15.586 C 9.492 15.586 11.045 15.039 12.324 14.121 L 17.129 18.935 C 17.354 19.16 17.646 19.268 17.959 19.268 C 18.623 19.268 19.082 18.77 19.082 18.115 C 19.082 17.803 18.965 17.52 18.76 17.315 L 13.984 12.51 C 14.99 11.201 15.586 9.57 15.586 7.793 C 15.586 3.496 12.09 0 7.793 0 C 3.496 0 0 3.496 0 7.793 Z M 1.67 7.793 C 1.67 4.414 4.414 1.67 7.793 1.67 C 11.172 1.67 13.916 4.414 13.916 7.793 C 13.916 11.172 11.172 13.916 7.793 13.916 C 4.414 13.916 1.67 11.172 1.67 7.793 Z';
const String _p4 =
    'M 20 0 L 0 0 L 0 21.28 L 20 21.28 L 20 0 Z';
const String _p5 =
    'M 8.72 1.03 L 0 1.03 C 0.035 0.372 0.521 0 1.331 0 L 7.389 0 C 8.198 0 8.685 0.372 8.72 1.03 Z';
const String _p6 =
    'M 12.591 1.204 C 12.287 1.163 11.964 1.142 11.624 1.142 L 0.966 1.142 C 0.627 1.142 0.304 1.163 0 1.204 C 0.103 0.431 0.718 0 1.724 0 L 10.877 0 C 11.882 0 12.489 0.431 12.591 1.204 Z';
const String _p7 =
    'M 2.972 14.112 L 13.63 14.112 C 15.608 14.112 16.602 13.275 16.602 11.618 L 16.602 2.494 C 16.602 0.837 15.608 0 13.63 0 L 2.972 0 C 0.994 0 0 0.829 0 2.494 L 0 11.618 C 0 13.275 0.994 14.112 2.972 14.112 Z M 3 12.816 C 2.054 12.816 1.524 12.382 1.524 11.545 L 1.524 2.558 C 1.524 1.73 2.054 1.295 3 1.295 L 13.611 1.295 C 14.539 1.295 15.078 1.73 15.078 2.558 L 15.078 11.545 C 15.078 12.382 14.539 12.816 13.611 12.816 L 3 12.816 Z';
const String _p8 =
    'M 0.947 6.372 L 6.332 3.661 C 6.739 3.468 6.73 3.001 6.332 2.8 L 0.947 0.088 C 0.54 -0.113 0 0.04 0 0.434 L 0 6.026 C 0 6.412 0.502 6.597 0.947 6.372 Z';
const String _p9 =
    'M12 20.25c-.28 0-.55-.1-.76-.28C6.79 16.2 3.75 13.53 3.75 10.1c0-2.6 2-4.6 4.53-4.6 1.44 0 2.77.67 3.72 1.79.95-1.12 2.28-1.79 3.72-1.79 2.53 0 4.53 2 4.53 4.6 0 3.43-3.04 6.1-7.49 9.87-.21.18-.48.28-.76.28Z';
const String _p10 =
    'M 2.805 20 L 17.195 20 C 19.096 20 20 19.46 20 18.272 C 20 15.443 16.211 11.35 10.006 11.35 C 3.789 11.35 0 15.443 0 18.272 C 0 19.46 0.904 20 2.805 20 Z M 2.267 18.369 C 1.969 18.369 1.843 18.294 1.843 18.067 C 1.843 16.296 4.751 12.981 10.006 12.981 C 15.249 12.981 18.157 16.296 18.157 18.067 C 18.157 18.294 18.042 18.369 17.745 18.369 L 2.267 18.369 Z M 10.006 10.011 C 12.73 10.011 14.951 7.721 14.951 4.935 C 14.951 2.171 12.742 0 10.006 0 C 7.292 0 5.06 2.214 5.06 4.957 C 5.072 7.732 7.281 10.011 10.006 10.011 Z M 10.006 8.38 C 8.334 8.38 6.903 6.868 6.903 4.957 C 6.903 3.078 8.311 1.631 10.006 1.631 C 11.711 1.631 13.108 3.056 13.108 4.935 C 13.108 6.847 11.689 8.38 10.006 8.38 Z';
