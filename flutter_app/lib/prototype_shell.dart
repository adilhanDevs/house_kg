import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fig/tab_bar.dart';
import 'prototype.dart';

void mainPrototype() => runApp(const HouseKgzApp());

class HouseKgzApp extends StatelessWidget {
  const HouseKgzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'House KGZ (Prototype)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFF1C1B19)),
      home: const PrototypeShell(),
    );
  }
}

/// Shows one screen at a time on the design's 375×812 canvas, exactly like the
/// HTML prototype's stage. Tapping a hotspot moves on; a long press anywhere
/// opens the screen list.
class PrototypeShell extends StatefulWidget {
  const PrototypeShell({super.key, this.initialIndex = 0});

  /// Which screen to open on. The prototype starts at the splash.
  final int initialIndex;

  @override
  State<PrototypeShell> createState() => _PrototypeShellState();
}

class _PrototypeShellState extends State<PrototypeShell> {
  /// The prototype's stage is white behind the screen, which shows on the
  /// screens the mockup draws shorter than the viewport.
  static const Color stageColor = Color(0xFFFFFFFF);

  late int _index = widget.initialIndex;
  final List<int> _history = [];
  Timer? _timer;

  /// Режим исполнителя (`state.pro` в прототипе): его включает «Режим
  /// исполнителя» на экране 05, и пока он включён пятая вкладка меню ведёт в
  /// профиль исполнителя, а не клиента.
  bool _pro = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleAutoAdvance() {
    _timer?.cancel();
    final screen = figScreens[_index];
    final delay = screen.autoAdvanceAfter;
    final target = screen.autoAdvanceTo;
    if (delay == null || target == null) return;
    _timer = Timer(delay, () => _go(target));
  }

  void _go(int target, {bool push = true, bool? pro}) {
    if (!mounted || target < 0 || target >= figScreens.length) return;
    setState(() {
      if (push) {
        _history.add(_index);
        if (_history.length > 30) _history.removeAt(0);
      }
      if (pro != null) _pro = pro;
      // возврат ко входу — новый вход, режим снова клиентский
      if (figResetsPro(target)) _pro = false;
      _index = target;
    });
    _scheduleAutoAdvance();
  }

  void _back() {
    if (_history.isEmpty) return;
    _go(_history.removeLast(), push: false);
  }

  void _tap(int tab) =>
      _go(tab == 4 && _pro ? figProProfile : figTabTargets[tab]);

  Future<void> _pickScreen() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF141312),
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: figScreens.length,
          itemBuilder: (context, i) {
            final screen = figScreens[i];
            final selected = i == _index;
            return ListTile(
              dense: true,
              leading: Text(
                screen.number,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: selected ? 0.9 : 0.4),
                ),
              ),
              title: Text(
                screen.title,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? const Color(0xFFF0A05F) : Colors.white70,
                ),
              ),
              trailing: Text(
                screen.node,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
              selected: selected,
              selectedTileColor: const Color(0x2EEA812E),
              onTap: () => Navigator.of(context).pop(i),
            );
          },
        ),
      ),
    );
    if (picked != null) _go(picked);
  }

  @override
  Widget build(BuildContext context) {
    final screen = figScreens[_index];

    Widget canvas = SizedBox(
      width: screen.width,
      height: screen.height,
      child: Stack(
        children: [
          screen.builder(context),
          for (final hotspot in screen.hotspots)
            Positioned(
              left: hotspot.left,
              top: hotspot.top,
              width: hotspot.width,
              height: hotspot.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hotspot.back
                    ? _back
                    : () => _go(hotspot.target, pro: hotspot.pro),
                child: const SizedBox.expand(),
              ),
            ),
          // where the mockup itself draws the bar, it sits clipped in place and
          // scrolls with the content. It goes on top of the zones: the
          // prototype stops at a tab cell before it looks at anything else,
          // and screen 40 puts a canvas-sized zone under the bar.
          if (screen.tabBarAt != null)
            Positioned(
              left: screen.tabBarAt!.dx,
              top: screen.tabBarAt!.dy,
              width: FigTabBar.clipWidth,
              height: FigTabBar.clipHeight,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: FigTabBar(
                        active: screen.activeTab,
                        mockupTab: screen.mockupTab,
                        onTap: _tap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (screen.tapAnywhereTo != null) {
      // the prototype's fallback: whatever the tap did not land on — a zone or
      // a tab cell — walks the flow on. Wrapping the canvas puts it last in the
      // gesture arena, so the zones and the bar still win where they are.
      canvas = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _go(screen.tapAnywhereTo!),
        child: canvas,
      );
    }
    if (screen.height > screen.viewportHeight) {
      canvas = SingleChildScrollView(child: canvas);
    }
    if (screen.tabBarPinned) {
      // these two screens have no bar in the mockup, so the prototype pins one
      // to the bottom of the viewport and the content scrolls underneath it
      canvas = Stack(
        children: [
          Positioned.fill(child: canvas),
          Positioned(
            left: 0,
            bottom: 0,
            child: FigTabBar(
              active: screen.activeTab,
              mockupTab: screen.mockupTab,
              onTap: _tap,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: GestureDetector(
        onLongPress: _pickScreen,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(
              constraints.maxWidth / screen.viewportWidth,
              constraints.maxHeight / screen.viewportHeight,
            );
            return Center(
              child: SizedBox(
                width: screen.viewportWidth * scale,
                height: screen.viewportHeight * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: screen.viewportWidth,
                    height: screen.viewportHeight,
                    child: ColoredBox(color: stageColor, child: canvas),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
