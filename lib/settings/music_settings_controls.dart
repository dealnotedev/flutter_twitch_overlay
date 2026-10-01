import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/settings/neon_settings_controls.dart';

class MusicSettingsControls extends StatefulWidget {
  final Settings settings;
  final MusicControlServerController? server;
  final MusicRewardController? rewardController;
  final Widget presentationSettings;
  final Widget rewardSettings;

  const MusicSettingsControls({
    super.key,
    required this.settings,
    required this.presentationSettings,
    required this.rewardSettings,
    this.server,
    this.rewardController,
  });

  @override
  State<MusicSettingsControls> createState() => _MusicSettingsControlsState();
}

class _MusicSettingsControlsState extends State<MusicSettingsControls> {
  late final TextEditingController _port;
  late final StreamSubscription<MusicSettings> _subscription;
  bool _invalidPort = false;
  bool _saving = false;
  bool _saveError = false;
  int? _volumeDraft;
  int? _ttsVolumeDraft;
  int? _cacheDraft;
  int? _queueDraft;
  int? _durationDraft;

  @override
  void initState() {
    super.initState();
    final value = widget.settings.music;
    _port = TextEditingController(text: '${value.controlServerPort}');
    _subscription = widget.settings.musicChanges.listen((_) => _changed());
    widget.server?.addListener(_changed);
    widget.rewardController?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    widget.server?.removeListener(_changed);
    widget.rewardController?.removeListener(_changed);
    _port.dispose();
    super.dispose();
  }

  Future<void> _save(MusicSettings options) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      await widget.settings.saveMusic(options);
    } catch (_) {
      if (mounted) _saveError = true;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _volumeDraft = null;
          _ttsVolumeDraft = null;
          _cacheDraft = null;
          _queueDraft = null;
          _durationDraft = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final value = widget.settings.music;
    final server = widget.server;
    final reward = widget.rewardController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.overlay_settings_player,
                style: const TextStyle(
                  color: MusicPlayerPalette.neonPinkBright,
                  fontFamily: 'Segoe Script',
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  shadows: MusicPlayerPalette.pinkTextGlow,
                ),
              ),
            ),
            Text(l.music_settings_enabled, style: _secondary),
            const Gap(12),
            Tooltip(
              message: l.music_settings_enabled_hint,
              child: _toggleButton(
                'music_enabled',
                value.enabled,
                () => _save(value.copyWith(enabled: !value.enabled)),
              ),
            ),
          ],
        ),
        const Gap(6),
        Text(l.overlay_settings_player_description, style: _secondary),
        if (_saveError) Text(l.overlay_settings_save_error, style: _errorStyle),
        if (reward?.error != null) ...[
          const Gap(8),
          Text(l.music_settings_reward_error, style: _errorStyle),
          NeonSettingsButton(
            label: l.music_settings_retry,
            icon: Icons.refresh_rounded,
            onPressed: () => unawaited(reward!.refresh()),
          ),
        ],
        const Gap(18),
        _panel([
          NeonSettingsSlider(
            sliderKey: const ValueKey('music_volume'),
            label: l.music_settings_volume,
            value: _volumeDraft ?? value.volumePercent,
            min: 0,
            max: 100,
            step: 5,
            formatValue: (value) => '$value%',
            onChanged:
                _saving
                    ? null
                    : (percent) => setState(() => _volumeDraft = percent),
            onChangeEnd:
                _saving
                    ? null
                    : (percent) => _save(
                      widget.settings.music.copyWith(volumePercent: percent),
                    ),
          ),
          NeonSettingsSlider(
            sliderKey: const ValueKey('music_tts_volume'),
            label: l.music_settings_tts_volume,
            value: _ttsVolumeDraft ?? value.ttsVolumePercent,
            min: 0,
            max: 100,
            step: 5,
            formatValue: (value) => '$value%',
            onChanged:
                _saving
                    ? null
                    : (percent) => setState(() => _ttsVolumeDraft = percent),
            onChangeEnd:
                _saving
                    ? null
                    : (percent) => _save(
                      widget.settings.music.copyWith(ttsVolumePercent: percent),
                    ),
          ),
          Text(l.music_settings_tts_volume_hint, style: _secondary),
        ]),
        const Gap(16),
        widget.presentationSettings,
        const Gap(16),
        widget.rewardSettings,
        const Gap(16),
        _panel([
          Text(l.music_settings_limits, style: _title),
          const Gap(12),
          NeonSettingsSlider(
            sliderKey: const ValueKey('music_max_queue'),
            label: l.music_settings_queue,
            value: _queueDraft ?? value.maxQueue,
            min: MusicSettings.minQueueLength,
            max: MusicSettings.maxQueueLength,
            formatValue: (value) => '$value',
            onChanged:
                _saving
                    ? null
                    : (number) => setState(() => _queueDraft = number),
            onChangeEnd:
                _saving
                    ? null
                    : (number) =>
                        _save(widget.settings.music.copyWith(maxQueue: number)),
          ),
          Text(l.music_settings_queue_hint, style: _secondary),
          const Gap(16),
          NeonSettingsSlider(
            sliderKey: const ValueKey('music_max_duration'),
            label: l.music_settings_duration,
            value: _durationDraft ?? value.maxDurationSeconds,
            min: MusicSettings.minTrackDurationSeconds,
            max: MusicSettings.maxTrackDurationSeconds,
            step: 5,
            formatValue: l.overlay_settings_seconds,
            onChanged:
                _saving
                    ? null
                    : (number) => setState(() => _durationDraft = number),
            onChangeEnd:
                _saving
                    ? null
                    : (number) => _save(
                      widget.settings.music.copyWith(
                        maxDurationSeconds: number,
                      ),
                    ),
          ),
          Text(l.music_settings_duration_hint, style: _secondary),
          const Gap(16),
          NeonSettingsSlider(
            sliderKey: const ValueKey('music_cache_max_mb'),
            label: l.music_settings_cache,
            value: _cacheDraft ?? value.cacheMaxMb,
            min: MusicSettings.minCacheMb,
            max: MusicSettings.maxCacheMb,
            step: 128,
            formatValue:
                (number) =>
                    number % 1024 == 0
                        ? l.music_settings_cache_gb(number ~/ 1024)
                        : l.music_settings_cache_mb(number),
            onChanged:
                _saving
                    ? null
                    : (number) => setState(() => _cacheDraft = number),
            onChangeEnd:
                _saving
                    ? null
                    : (number) => _save(
                      widget.settings.music.copyWith(cacheMaxMb: number),
                    ),
          ),
          Text(l.music_settings_cache_hint, style: _secondary),
        ]),
        const Gap(16),
        _panel([
          Row(
            children: [
              Expanded(child: Text(l.music_settings_server, style: _title)),
              const Gap(12),
              _toggleButton(
                'music_server_enabled',
                value.controlServerEnabled,
                () => _save(
                  value.copyWith(
                    controlServerEnabled: !value.controlServerEnabled,
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(l.music_settings_server_hint, style: _secondary),
          const Gap(12),
          _portInput(),
          if (server != null) ...[
            SelectableText(switch (server.status) {
              MusicControlServerStatus.stopped =>
                l.music_settings_server_stopped,
              MusicControlServerStatus.starting =>
                l.music_settings_server_starting,
              MusicControlServerStatus.running => l
                  .music_settings_server_running(
                    'http://127.0.0.1:${server.port}',
                  ),
              MusicControlServerStatus.failed => l.music_settings_server_failed,
            }, style: server.error == null ? _secondary : _errorStyle),
            if (server.error != null)
              NeonSettingsButton(
                key: const ValueKey('music_server_retry'),
                label: l.music_settings_retry,
                icon: Icons.refresh_rounded,
                onPressed:
                    () => unawaited(
                      server.configure(
                        enabled: widget.settings.music.controlServerEnabled,
                        port: widget.settings.music.controlServerPort,
                      ),
                    ),
              ),
          ],
        ]),
      ],
    );
  }

  Widget _toggleButton(
    String key,
    bool value,
    VoidCallback save,
  ) => NeonSettingsButton(
    key: ValueKey(key),
    label: value ? context.localizations.tts_on : context.localizations.tts_off,
    icon: value ? Icons.check_circle_outline : Icons.power_settings_new,
    selected: value,
    onPressed: _saving ? null : save,
  );

  Widget _portInput() {
    Future<void> submit() async {
      if (_saving) return;
      final number = int.tryParse(_port.text.trim());
      if (number == null || number < 1 || number > 65535) {
        setState(() => _invalidPort = true);
        return;
      }
      setState(() => _invalidPort = false);
      await _save(widget.settings.music.copyWith(controlServerPort: number));
    }

    final l = context.localizations;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.music_settings_port, style: _title),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: NeonSettingsInput(
                  key: const ValueKey('music_server_port'),
                  label: l.music_settings_port,
                  controller: _port,
                  enabled: !_saving,
                  onSubmitted: submit,
                ),
              ),
              const Gap(12),
              NeonSettingsButton(
                key: const ValueKey('music_server_port_apply'),
                label: l.music_settings_apply,
                icon: Icons.check_rounded,
                onPressed: _saving ? null : submit,
              ),
            ],
          ),
          const Gap(6),
          Text(l.music_settings_port_hint, style: _secondary),
          if (_invalidPort)
            Text(l.music_settings_invalid_port, style: _errorStyle),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> children) => Container(
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
      children: children,
    ),
  );

  static const _title = TextStyle(
    color: MusicPlayerPalette.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const _secondary = TextStyle(
    color: MusicPlayerPalette.textSecondary,
    fontSize: 12,
  );
  static const _errorStyle = TextStyle(
    color: MusicPlayerPalette.error,
    fontSize: 12,
  );
}
