import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_player_visuals.dart';

void main() {
  test('particles respawn after drifting fully outside the surface', () {
    final motion = CosmicMusicMotion(seed: 950);
    addTearDown(motion.dispose);

    for (var tick = 0; tick < 5000; tick++) {
      motion.advance(const Duration(milliseconds: 100));
    }

    expect(motion.elapsedSeconds, closeTo(500, 0.001));
    expect(motion.respawnCount, greaterThan(0));
  });

  testWidgets('only the expanded player keeps its cosmic background moving', (
    tester,
  ) async {
    const backgroundKey = ValueKey('animated_cosmic_background');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CosmicMusicSurface(
            backgroundKey: backgroundKey,
            width: 380,
            height: 140,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final expandedPainter =
        tester
                .widget<CustomPaint>(find.byKey(backgroundKey))
                .painter!
            as CosmicMusicBackgroundPainter;
    expect(expandedPainter.elapsedSeconds, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(expandedPainter.elapsedSeconds, greaterThan(0));

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CosmicMusicSurface(
            backgroundKey: backgroundKey,
            width: 82,
            height: 82,
            compact: true,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final compactPainter =
        tester
                .widget<CustomPaint>(find.byKey(backgroundKey))
                .painter!
            as CosmicMusicBackgroundPainter;
    final compactElapsed = compactPainter.elapsedSeconds;
    await tester.pump(const Duration(seconds: 1));

    expect(compactPainter.elapsedSeconds, compactElapsed);
  });
}
