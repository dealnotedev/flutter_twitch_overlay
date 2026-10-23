import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/vinyl_record.dart';

void main() {
  test('the edition of a request is independent of selection order', () {
    final ids = List.generate(100, (index) => 'request-$index');
    final first = {for (final id in ids) id: VinylEdition.forItem(id)};
    for (final id in ids.reversed) {
      expect(VinylEdition.forItem(id), first[id]);
    }
  });

  test('ordinary vinyl dominates and gold remains the rarest edition', () {
    final counts = {for (final edition in VinylEdition.values) edition: 0};
    for (var i = 0; i < 10000; i++) {
      final edition = VinylEdition.forItem('request-$i');
      counts[edition] = counts[edition]! + 1;
    }
    expect(counts[VinylEdition.classic], inInclusiveRange(8300, 8700));
    expect(counts[VinylEdition.clear], inInclusiveRange(650, 950));
    expect(counts[VinylEdition.marble], inInclusiveRange(380, 620));
    expect(counts[VinylEdition.gold], inInclusiveRange(120, 280));
  });

  testWidgets('only clear vinyl lets the platter show through its grooves', (
    tester,
  ) async {
    for (final edition in VinylEdition.values) {
      final capture = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: capture,
              child: VinylRecord(edition: edition),
            ),
          ),
        ),
      );
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels =
          (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData();
            image.dispose();
            return bytes!;
          }))!;
      int alphaAt(int x, int y) => pixels.getUint8((y * 220 + x) * 4 + 3);
      expect(alphaAt(110, 80), 255, reason: 'The cover label stays opaque.');
      expect(
        alphaAt(20, 110),
        edition == VinylEdition.clear ? inExclusiveRange(0, 200) : 255,
        reason: '${edition.name} vinyl opacity at an outer groove',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
