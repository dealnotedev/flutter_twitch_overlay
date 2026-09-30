import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/twitch_reward_picker.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'package:obssource/twitch/twitch_api.dart';

class TtsSettingsPane extends StatefulWidget {
  final Settings settings;
  final TwitchRewardCatalog? catalog;
  final TtsController? controller;
  const TtsSettingsPane({
    super.key,
    required this.settings,
    this.catalog,
    this.controller,
  });
  @override
  State<TtsSettingsPane> createState() => _TtsSettingsPaneState();
}

class _TtsSettingsPaneState extends State<TtsSettingsPane> {
  late final TextEditingController _url;
  final _testText = TextEditingController();
  late final StreamSubscription<TtsSettings> _settingsSubscription;
  List<TwitchCustomReward> _rewards = [];
  bool _loading = false;
  bool _saving = false;
  bool _creating = false;
  int? _volumeDraft;
  TtsIssue? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.settings.tts.baseUrl);
    widget.controller?.addListener(_changed);
    _settingsSubscription = widget.settings.ttsChanges.listen(
      (_) => _changed(),
    );
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_testText.text.isEmpty) {
      _testText.text = context.localizations.tts_test_default;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_volumeDraft != null) {
      widget.controller?.previewVolume(widget.settings.tts.volumePercent);
    }
    widget.controller?.removeListener(_changed);
    unawaited(_settingsSubscription.cancel());
    _url.dispose();
    _testText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.catalog == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rewards = await widget.catalog!.load();
      if (mounted) setState(() => _rewards = rewards);
    } catch (_) {
      if (mounted) setState(() => _error = TtsIssue.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(TtsSettings options) async {
    final updateUrl = options.baseUrl != widget.settings.tts.baseUrl;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.settings.saveTts(options);
      if (mounted && updateUrl) _url.text = widget.settings.tts.baseUrl;
    } on FormatException {
      if (mounted) _error = TtsIssue.invalidUrl;
    } catch (_) {
      if (mounted) _error = TtsIssue.operationFailed;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _create() async {
    final catalog = widget.catalog;
    if (catalog == null || _saving) return;
    setState(() {
      _saving = true;
      _creating = true;
      _error = null;
    });
    try {
      final reward = await catalog.createDefault();
      final channel = widget.settings.twitchAuth!.broadcasterId;
      if (catalog is TtsRewardCatalog) {
        await catalog.publishPaused(reward);
      }
      await widget.settings.saveTts(
        widget.settings.tts.copyWith(
          rewardId: reward.id,
          broadcasterId: channel,
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) _error = TtsIssue.operationFailed;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _creating = false;
        });
      }
    }
  }

  Future<void> _saveVolume() async {
    final percent = _volumeDraft ?? widget.settings.tts.volumePercent;
    await _save(widget.settings.tts.copyWith(volumePercent: percent));
    widget.controller?.previewVolume(widget.settings.tts.volumePercent);
    if (mounted) setState(() => _volumeDraft = null);
  }

  void _select(TwitchCustomReward? reward) {
    unawaited(
      _save(
        reward == null
            ? widget.settings.tts.copyWith(clearReward: true)
            : widget.settings.tts.copyWith(
              rewardId: reward.id,
              broadcasterId: widget.settings.twitchAuth?.broadcasterId,
            ),
      ),
    );
  }

  Future<void> _test() async {
    try {
      await widget.controller?.testSpeech(_testText.text);
    } catch (_) {
      if (mounted) setState(() => _error = TtsIssue.operationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final options = widget.settings.tts;
    final volumePercent = _volumeDraft ?? options.volumePercent;
    final controller = widget.controller;
    final health = controller?.health;
    final checked = health?.checkedAt;
    final error =
        _error == TtsIssue.loadFailed
            ? controller?.lastError
            : _error ?? controller?.lastError;
    return SingleChildScrollView(
      key: const ValueKey('tts_settings_scroll'),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TTS',
                  style: TextStyle(
                    color: MusicPlayerPalette.neonPinkBright,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    shadows: MusicPlayerPalette.pinkTextGlow,
                  ),
                ),
              ),
              Text(l.tts_enabled, style: _secondary),
              const SizedBox(width: 12),
              NeonSettingsButton(
                key: const ValueKey('tts_enabled'),
                label: options.enabled ? l.tts_on : l.tts_off,
                icon:
                    options.enabled
                        ? Icons.check_circle_outline
                        : Icons.power_settings_new,
                selected: options.enabled,
                onPressed:
                    _saving
                        ? null
                        : () =>
                            _save(options.copyWith(enabled: !options.enabled)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.tts_description, style: _secondary),
          const SizedBox(height: 18),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(l.tts_base_url),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: NeonSettingsInput(
                        key: const ValueKey('tts_base_url'),
                        controller: _url,
                        label: l.tts_base_url,
                        enabled: !_saving,
                        onSubmitted:
                            () => _save(options.copyWith(baseUrl: _url.text)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    NeonSettingsButton(
                      key: const ValueKey('tts_apply_url'),
                      label: l.tts_apply,
                      icon: Icons.check_rounded,
                      onPressed:
                          _saving
                              ? null
                              : () =>
                                  _save(options.copyWith(baseUrl: _url.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(l.tts_url_hint, style: _secondary.copyWith(fontSize: 11)),
                const SizedBox(height: 16),
                _label(l.tts_mood),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final mood in TtsMood.values)
                      NeonSettingsButton(
                        key: ValueKey('tts_mood_${mood.apiValue}'),
                        label: switch (mood) {
                          TtsMood.calm => l.tts_calm,
                          TtsMood.lively => l.tts_lively,
                          TtsMood.neutral => l.tts_neutral,
                        },
                        selected: options.mood == mood,
                        onPressed:
                            _saving
                                ? null
                                : () => _save(options.copyWith(mood: mood)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _label(l.tts_volume),
                Row(
                  children: [
                    Icon(
                      volumePercent == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 22,
                      color: MusicPlayerPalette.neonPinkBright,
                    ),
                    Expanded(
                      child: Slider(
                        key: const ValueKey('tts_volume_slider'),
                        value: volumePercent.toDouble(),
                        min: 0,
                        max: TtsSettings.maxVolumePercent.toDouble(),
                        divisions: TtsSettings.maxVolumePercent,
                        label: '$volumePercent%',
                        semanticFormatterCallback:
                            (value) => '${value.round()}%',
                        activeColor: MusicPlayerPalette.neonPinkBright,
                        inactiveColor: MusicPlayerPalette.neonPink.withValues(
                          alpha: 0.15,
                        ),
                        onChanged:
                            _saving
                                ? null
                                : (value) {
                                  final percent = value.round();
                                  setState(() => _volumeDraft = percent);
                                  controller?.previewVolume(percent);
                                },
                        onChangeEnd:
                            _saving ? null : (_) => unawaited(_saveVolume()),
                      ),
                    ),
                    Container(
                      width: 62,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: MusicPlayerPalette.neonPink.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$volumePercent%',
                        style: const TextStyle(
                          color: MusicPlayerPalette.neonPinkBright,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l.tts_volume_hint,
                  style: _secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color:
                          health == null
                              ? MusicPlayerPalette.textSecondary
                              : health.available
                              ? const Color(0xFF74E4B4)
                              : MusicPlayerPalette.error,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _label(
                        '${l.tts_service}: ${health == null
                            ? l.tts_unknown
                            : health.available
                            ? l.tts_available
                            : l.tts_unavailable}',
                      ),
                    ),
                    NeonSettingsButton(
                      key: const ValueKey('tts_check'),
                      label: l.tts_check,
                      icon: Icons.refresh,
                      busy: controller?.checking ?? false,
                      onPressed:
                          controller == null || controller.checking
                              ? null
                              : () => unawaited(controller.checkNow()),
                    ),
                  ],
                ),
                if (health != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    health.reason == TtsIssue.serviceUnavailable
                        ? l.tts_agents_unknown
                        : l.tts_agents(
                          health.healthyAgents,
                          health.connectedAgents,
                        ),
                    style: _secondary,
                  ),
                ],
                if (checked != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    l.tts_last_check(
                      DateFormat('HH:mm:ss').format(checked.toLocal()),
                    ),
                    style: _secondary.copyWith(fontSize: 11),
                  ),
                ],
                if (controller?.pauseReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ttsStatusText(l, controller!.pauseReason!),
                    style: _secondary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TwitchRewardPicker(
            rewards: _rewards,
            selectedId: options.rewardId,
            description: l.tts_reward_description,
            emptyDescription: l.tts_reward_empty,
            keyPrefix: 'tts',
            rewardIcon: Icons.record_voice_over_rounded,
            loading: _loading,
            creating: _creating,
            enabled: !_saving,
            error:
                _error == TtsIssue.loadFailed
                    ? l.overlay_settings_load_error
                    : null,
            blockedReason:
                (reward) =>
                    reward.id == widget.settings.musicRewardId
                        ? l.tts_music_conflict
                        : null,
            onSelected: _select,
            onCreate: widget.catalog == null ? null : _create,
            onRefresh: widget.catalog == null ? null : _load,
          ),
          const SizedBox(height: 14),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.tts_announcement, style: _secondary),
                const SizedBox(height: 12),
                NeonSettingsInput(
                  key: const ValueKey('tts_test_text'),
                  controller: _testText,
                  label: l.tts_test_text,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    NeonSettingsButton(
                      key: const ValueKey('tts_test'),
                      label: l.tts_test,
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          controller == null || controller.busy ? null : _test,
                    ),
                    if (controller?.busy == true)
                      NeonSettingsButton(
                        label: l.tts_stop,
                        icon: Icons.stop,
                        onPressed: controller!.stopCurrent,
                      ),
                  ],
                ),
                if (controller?.currentRequester != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      l.tts_working(controller!.currentRequester!),
                      style: _secondary,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                ttsStatusText(l, error),
                style: const TextStyle(
                  color: MusicPlayerPalette.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _secondary = TextStyle(
    color: MusicPlayerPalette.textSecondary,
    fontSize: 12,
    height: 1.4,
  );
  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: MusicPlayerPalette.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: MusicPlayerPalette.midnight.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.18),
      ),
    ),
    child: child,
  );
}

String ttsStatusText(AppLocalizations l, TtsIssue code) => switch (code) {
  TtsIssue.canceled => l.tts_canceled,
  TtsIssue.invalidUrl => l.tts_invalid_url,
  TtsIssue.loadFailed => l.overlay_settings_load_error,
  TtsIssue.disabled => l.tts_disabled,
  TtsIssue.noReward => l.tts_no_reward,
  TtsIssue.twitchUnavailable => l.tts_twitch_unavailable,
  TtsIssue.audioUnavailable => l.tts_audio_unavailable,
  TtsIssue.queueFull => l.tts_queue_full,
  TtsIssue.rewardUnavailable => l.tts_reward_unavailable,
  TtsIssue.noAgentsAvailable => l.tts_no_agents,
  TtsIssue.serviceUnavailable => l.tts_unavailable,
  TtsIssue.timeout => l.tts_timeout,
  TtsIssue.invalidText => l.tts_invalid_text,
  TtsIssue.generationFailed || TtsIssue.invalidAudio => l.tts_failed,
  TtsIssue.settlementFailed => l.tts_settlement_failed,
  TtsIssue.operationFailed => l.tts_operation_failed,
};
