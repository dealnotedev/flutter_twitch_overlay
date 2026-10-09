import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/settings/neon_settings_controls.dart';

class AvatarSettingsControls extends StatefulWidget {
  final Settings settings;

  const AvatarSettingsControls({super.key, required this.settings});

  @override
  State<AvatarSettingsControls> createState() => _AvatarSettingsControlsState();
}

class _AvatarSettingsControlsState extends State<AvatarSettingsControls> {
  late final StreamSubscription<AvatarSettings> _subscription;
  int? _resolutionDraft;
  bool _saving = false;
  bool _saveError = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.settings.avatarChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Future<void> _save(AvatarSettings value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      await widget.settings.saveAvatar(value);
    } catch (_) {
      if (mounted) _saveError = true;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _resolutionDraft = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final value = widget.settings.avatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.overlay_settings_avatar,
          style: const TextStyle(
            color: MusicPlayerPalette.neonPinkBright,
            fontFamily: 'Segoe Script',
            fontSize: 22,
            fontStyle: FontStyle.italic,
            shadows: MusicPlayerPalette.pinkTextGlow,
          ),
        ),
        const Gap(6),
        Text(l.avatar_settings_description, style: _secondary),
        const Gap(18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MusicPlayerPalette.midnight.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MusicPlayerPalette.neonPink.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeonSettingsSlider(
                sliderKey: const ValueKey('avatar_resolution'),
                label: l.avatar_settings_resolution,
                value: _resolutionDraft ?? value.resolution,
                min: AvatarSettings.minResolution,
                max: AvatarSettings.maxResolution,
                formatValue: (resolution) => '$resolution × $resolution',
                onChanged:
                    _saving
                        ? null
                        : (resolution) =>
                            setState(() => _resolutionDraft = resolution),
                onChangeEnd:
                    _saving
                        ? null
                        : (resolution) => unawaited(
                          _save(
                            widget.settings.avatar.copyWith(
                              resolution: resolution,
                            ),
                          ),
                        ),
              ),
              Text(l.avatar_settings_resolution_hint, style: _secondary),
              const Gap(24),
              Text(
                l.avatar_settings_renderer,
                style: const TextStyle(
                  color: MusicPlayerPalette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(10),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _rendererButton(
                    'avatar_renderer_optimized',
                    l.avatar_settings_renderer_optimized,
                    AvatarPixelRenderer.rawAtlas,
                  ),
                  _rendererButton(
                    'avatar_renderer_legacy',
                    l.avatar_settings_renderer_legacy,
                    AvatarPixelRenderer.legacyCanvas,
                  ),
                ],
              ),
              const Gap(8),
              Text(l.avatar_settings_renderer_hint, style: _secondary),
            ],
          ),
        ),
        if (_saveError) ...[
          const Gap(10),
          Text(
            l.overlay_settings_save_error,
            style: const TextStyle(
              color: MusicPlayerPalette.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _rendererButton(
    String key,
    String label,
    AvatarPixelRenderer renderer,
  ) => NeonSettingsButton(
    key: ValueKey(key),
    label: label,
    selected: widget.settings.avatar.renderer == renderer,
    onPressed:
        _saving
            ? null
            : () => unawaited(
              _save(widget.settings.avatar.copyWith(renderer: renderer)),
            ),
  );

  static const _secondary = TextStyle(
    color: MusicPlayerPalette.textSecondary,
    fontSize: 12,
  );
}
