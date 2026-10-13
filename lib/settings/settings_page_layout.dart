import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/music/music_player_visuals.dart';

/// Settings form with its preview beside it, or above it when narrow.
class SettingsPageLayout extends StatelessWidget {
  static const _wideWidth = 960.0;
  static const _padding = EdgeInsets.fromLTRB(28, 22, 28, 26);

  final Key? scrollKey;
  final Widget form;
  final Widget preview;

  const SettingsPageLayout({
    super.key,
    this.scrollKey,
    required this.form,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideWidth) {
          return SingleChildScrollView(
            key: scrollKey,
            padding: _padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, const Gap(24), form],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: scrollKey,
                padding: _padding,
                child: form,
              ),
            ),
            Container(
              width: 1,
              color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.13),
            ),
            SizedBox(
              width: (constraints.maxWidth * 0.5).clamp(420.0, 860.0),
              child: SingleChildScrollView(padding: _padding, child: preview),
            ),
          ],
        );
      },
    );
  }
}
