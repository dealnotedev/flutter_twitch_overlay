import 'package:flutter/material.dart';
import 'package:obssource/l10n/app_localizations.dart';

extension ContextExt on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this)!;
}

extension HexColor on Color {
  static Color? fromHex(String? hexString) {
    if (hexString == null) {
      return null;
    }

    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {}

    return null;
  }
}

extension TextStyleExt on TextStyle {
  Size calculateMaxSingleLineTextSize(
    Iterable<String> texts, {
    required TextScaler scaler,
    TextDirection? direction,
  }) {
    double width = 0;
    double height = 0;

    for (String text in texts) {
      final textPainter = TextPainter(
        text: TextSpan(style: this, text: text),
        textScaler: scaler,
        maxLines: 1,
        textDirection: direction ?? TextDirection.ltr,
      );

      textPainter.layout();

      if (width < textPainter.width) {
        width = textPainter.width;
      }
      if (height < textPainter.height) {
        height = textPainter.height;
      }
    }

    return Size(width, height);
  }
}
