import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/settings/neon_settings_controls.dart';

void main() {
  late TextEditingController controller;
  var clipboardText = '';

  setUp(() {
    controller = TextEditingController(text: 'Hello music settings');
    clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboardText = (call.arguments as Map)['text'] as String;
              return null;
            case 'Clipboard.getData':
              return {'text': clipboardText};
            case 'Clipboard.hasStrings':
              return {'value': clipboardText.isNotEmpty};
          }
          return null;
        });
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> showInput(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: NeonSettingsInput(
                controller: controller,
                label: 'Test input',
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset character(WidgetTester tester, int offset) {
    final render =
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
    return render.localToGlobal(
      render.getLocalRectForCaret(TextPosition(offset: offset)).center,
    );
  }

  testWidgets('mouse drag selects a range in settings input', (tester) async {
    await showInput(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: character(tester, 6));
    await mouse.down(character(tester, 6));
    await mouse.moveTo(character(tester, 9));
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.moveTo(character(tester, 11));
    await mouse.up();
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );
    await mouse.removePointer();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('double click selects a word in settings input', (tester) async {
    await showInput(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: character(tester, 8));
    await mouse.down(character(tester, 8));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.down(character(tester, 8));
    await mouse.up();
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );
    await mouse.removePointer();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('click positions the caret and shift click extends selection', (
    tester,
  ) async {
    await showInput(tester);
    await tester.tapAt(character(tester, 6), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.selection, const TextSelection.collapsed(offset: 6));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(character(tester, 11), kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('keyboard selection can be copied and replaced by pasting', (
    tester,
  ) async {
    await showInput(tester);
    await tester.tapAt(character(tester, 6), kind: PointerDeviceKind.mouse);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboardText, 'music');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 20),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.text, 'music');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('right click offers copy for the selected word', (tester) async {
    await showInput(tester);
    await tester.tapAt(character(tester, 8), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(character(tester, 8), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tapAt(
      character(tester, 8),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboardText, 'music');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('clicking input padding focuses the field', (tester) async {
    await showInput(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(NeonSettingsInput)) + const Offset(5, 5),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('disabled field cannot receive focus or mouse selection', (
    tester,
  ) async {
    await showInput(tester, enabled: false);
    await tester.tapAt(character(tester, 8), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(controller.selection, const TextSelection.collapsed(offset: -1));

    await showInput(tester);
    await tester.tapAt(character(tester, 8), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await showInput(tester, enabled: false);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
