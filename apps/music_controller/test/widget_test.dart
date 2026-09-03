import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/control/remote_music_requests.dart';
import 'package:obssource_music_controller/main.dart';

void main() {
  testWidgets('shows an expanded player and connection state', (tester) async {
    tester.view.physicalSize = const Size(440, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = RemoteMusicRequests(
      endpoint: Uri.parse('http://127.0.0.1:47821'),
    );
    addTearDown(requests.close);

    await tester.pumpWidget(MusicControllerApp(requests: requests));

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('music_player_compact')), findsNothing);
    expect(
      find.byKey(const ValueKey('connection_status_label')),
      findsOneWidget,
    );
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final player = find.byKey(const ValueKey('music_player_expanded'));
    final status = find.byKey(const ValueKey('connection_status'));
    final divider = find.byKey(const ValueKey('connection_status_divider'));
    expect(tester.getSize(player).width, 440);
    expect(tester.getBottomRight(player).dy, tester.getTopLeft(divider).dy);
    expect(tester.getBottomRight(divider).dy, tester.getTopLeft(status).dy);
    expect(tester.getBottomRight(status).dy, 390);

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('music_controller_player_surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.zero);
    expect(decoration.boxShadow, isNull);
  });
}
