import 'package:flutter/material.dart';
import 'package:obssource/l10n/app_localizations.dart';

extension ContextExt on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this)!;
}