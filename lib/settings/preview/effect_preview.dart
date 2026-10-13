import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/effect_stage.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';

/// Effect sample the preview can play.
class PreviewSample {
  final String id;
  final String label;
  final void Function(PreviewTarget target) play;

  const PreviewSample({
    required this.id,
    required this.label,
    required this.play,
  });
}

/// What a [PreviewSample] plays into.
class PreviewTarget {
  final EffectRuntime runtime;

  /// Forces the golden or the normal flashbang instead of the random one.
  bool? flashbangPro;

  PreviewTarget(this.runtime);
}

/// Local sample data: no Twitch API or channel points involved. Only emote
/// pictures come from the Twitch CDN, as they do on stream.
abstract final class PreviewData {
  static const avatarUrl =
      '${Avatar.assetScheme}${Assets.assetsIcDefaultAvatar96dp}';

  static var _ids = 0;

  static String nextId() => 'preview-${_ids++}';

  static UserInfo user(String name) =>
      UserInfo(id: 'preview-$name', login: name.toLowerCase(), name: name);

  static String rewardId(RewardAction action) => 'preview-${action.name}';

  static Future<UserDto?> loadUser(String id) async => UserDto(
    id: id,
    login: id,
    // Sample users are `preview-<name>`; show just the name.
    displayName: id.replaceFirst('preview-', ''),
    profileImageUrl: avatarUrl,
  );

  static Future<img.Image?> loadAvatar(String url) =>
      url.startsWith(Avatar.assetScheme)
          ? RainyAvatar.loadImageFromAssets(
            url.substring(Avatar.assetScheme.length),
          )
          : RainyAvatar.loadImageFromUrl(url);
}

/// Plays effects with the current settings on a virtual stream canvas.
///
/// The preview has its own [EffectRuntime]; it never touches Twitch, the kill
/// server or the music queue. Its picture is part of the overlay, so it is
/// visible on stream, and its sound only plays when explicitly enabled.
class EffectPreview extends StatefulWidget {
  static const canvas = Size(1920, 1080);

  final Settings settings;
  final List<PreviewSample> samples;

  /// Caption in front of the samples, e.g. "Viewers:".
  final String? samplesLabel;

  /// Keeps the sticker layer ready for sticker samples.
  final bool screenAttack;

  /// Shows the card of every redemption, even when cards are turned off.
  /// Other previews hide cards to show only their effect.
  final bool rewardCards;

  const EffectPreview({
    super.key,
    required this.settings,
    required this.samples,
    this.samplesLabel,
    this.screenAttack = false,
    this.rewardCards = false,
  });

  @override
  State<EffectPreview> createState() => _EffectPreviewState();
}

class _EffectPreviewState extends State<EffectPreview> {
  late EffectRuntime _runtime;
  late PreviewTarget _target;
  late String _sampleId;
  StreamSubscription<AvatarSettings>? _avatarSubscription;
  Timer? _repeatTimer;
  DateTime? _lastPlay;
  bool _repeat = false;
  bool _sound = false;

  PreviewSample get _sample => widget.samples.firstWhere(
    (sample) => sample.id == _sampleId,
    orElse: () => widget.samples.first,
  );

  @override
  void initState() {
    super.initState();
    _sampleId = widget.samples.first.id;
    _createRuntime();
    _avatarSubscription = widget.settings.avatarChanges.listen((_) {
      if (mounted) setState(() {});
    });
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _repeatIfIdle(),
    );
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _avatarSubscription?.cancel();
    _runtime.dispose();
    super.dispose();
  }

  void _createRuntime() {
    _runtime = EffectRuntime(
      alerts: _alerts,
      rewardEffects: _rewardEffects,
      kills: () => widget.settings.kills,
      loadUser: PreviewData.loadUser,
      loadAvatar: PreviewData.loadAvatar,
      audio: _sound ? const ObsAlertAudio() : const SilentAlertAudio(),
      keepScreenAttackMounted: widget.screenAttack,
    );
    _target = PreviewTarget(_runtime);
  }

  /// Current look of every alert, shown even while the alert is turned off so
  /// it can be tuned before enabling it.
  AlertsSettings _alerts() {
    final alerts = widget.settings.alerts;
    return alerts.copyWith(
      follow: alerts.follow.copyWith(enabled: true),
      raid: alerts.raid.copyWith(enabled: true, minViewers: 1),
      subscriptions: alerts.subscriptions.copyWith(
        subscribe: true,
        resubscribe: true,
        gift: true,
      ),
      // Only the reward card page shows cards; elsewhere they hide the effect.
      rewardCard: alerts.rewardCard.copyWith(enabled: widget.rewardCards),
      chat: alerts.chat.copyWith(highlighted: true, firstMessage: true),
    );
  }

  /// Current effect parameters with every action bound to a sample reward.
  RewardEffectsSettings _rewardEffects() {
    var effects = widget.settings.rewardEffects;
    for (final action in RewardAction.values) {
      effects = effects.withBinding(
        action,
        effects
            .binding(action)
            .withReward(id: PreviewData.rewardId(action), title: action.name)
            .copyWith(enabled: true),
      );
    }
    return switch (_target.flashbangPro) {
      true => effects.copyWith(flashbangProChancePercent: 100),
      false => effects.copyWith(flashbangProChancePercent: 0),
      null => effects,
    };
  }

  void _play([PreviewSample? sample]) {
    final selected = sample ?? _sample;
    setState(() => _sampleId = selected.id);
    _lastPlay = DateTime.now();
    selected.play(_target);
  }

  /// Drops everything shown, including pauses and stickers.
  void _stop() {
    final previous = _runtime;
    setState(_createRuntime);
    // The stage switches to the new runtime first.
    SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  void _repeatIfIdle() {
    final last = _lastPlay;
    // A pause stays until removed; repeating would restart its picture.
    if (!_repeat || last == null || !_runtime.idle || _runtime.pause != null) {
      return;
    }
    if (DateTime.now().difference(last) < const Duration(seconds: 2)) return;
    _play();
  }

  void _toggleSound() {
    _sound = !_sound;
    _stop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.live_tv_rounded,
              color: MusicPlayerPalette.neonPinkBright,
              size: 20,
            ),
            const Gap(8),
            Expanded(
              child: Text(
                l.preview_title,
                style: const TextStyle(
                  color: MusicPlayerPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          l.preview_on_air,
          style: const TextStyle(
            color: MusicPlayerPalette.textSecondary,
            fontSize: 12,
          ),
        ),
        const Gap(12),
        _buildCanvas(),
        const Gap(14),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.samplesLabel case final label?)
              Text(
                label,
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
            for (final sample in widget.samples)
              NeonSettingsButton(
                key: ValueKey('preview_sample_${sample.id}'),
                label: sample.label,
                selected: sample.id == _sampleId,
                onPressed: () => _play(sample),
              ),
          ],
        ),
        const Gap(10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            NeonSettingsButton(
              key: const ValueKey('preview_play'),
              label: l.preview_play,
              icon: Icons.play_arrow_rounded,
              onPressed: _play,
            ),
            NeonSettingsButton(
              key: const ValueKey('preview_stop'),
              label: l.preview_stop,
              icon: Icons.stop_rounded,
              onPressed: _stop,
            ),
            NeonSettingsButton(
              key: const ValueKey('preview_repeat'),
              label: l.preview_repeat,
              icon: _repeat ? Icons.repeat_on_rounded : Icons.repeat_rounded,
              selected: _repeat,
              onPressed: () => setState(() => _repeat = !_repeat),
            ),
            NeonSettingsButton(
              key: const ValueKey('preview_sound'),
              label: l.preview_sound,
              icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              selected: _sound,
              onPressed: _toggleSound,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    return AspectRatio(
      aspectRatio: EffectPreview.canvas.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.3),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IgnorePointer(
            child: FittedBox(
              child: SizedBox.fromSize(
                key: const ValueKey('preview_canvas'),
                size: EffectPreview.canvas,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _CheckerPainter()),
                    ),
                    Positioned.fill(
                      child: EffectStage(
                        runtime: _runtime,
                        constraints: BoxConstraints.tight(EffectPreview.canvas),
                        avatar: widget.settings.avatar,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparency checkerboard behind the preview.
class _CheckerPainter extends CustomPainter {
  static const _cell = 60.0;

  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF15172B),
    );
    final light = Paint()..color = const Color(0xFF1D2038);
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = y.isEven ? 0 : 1; x * _cell < size.width; x += 2) {
        canvas.drawRect(
          Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell),
          light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}
