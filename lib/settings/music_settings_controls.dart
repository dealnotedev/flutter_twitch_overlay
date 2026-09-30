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
  late final TextEditingController _queue;
  late final TextEditingController _duration;
  late final TextEditingController _cache;
  late final TextEditingController _port;
  late final StreamSubscription<MusicSettings> _subscription;
  final _invalid = <String>{};
  bool _saving = false;
  bool _saveError = false;
  int? _volumeDraft;
  int? _ttsVolumeDraft;

  @override
  void initState() {
    super.initState();
    final value = widget.settings.music;
    _queue = TextEditingController(text: '${value.maxQueue}');
    _duration = TextEditingController(text: '${value.maxDurationSeconds}');
    _cache = TextEditingController(text: '${value.cacheMaxMb}');
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
    for (final controller in [_queue, _duration, _cache, _port]) {
      controller.dispose();
    }
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
          _slider(
            'music_volume',
            l.music_settings_volume,
            _volumeDraft ?? value.volumePercent,
            (percent) => setState(() => _volumeDraft = percent),
            (percent) => _save(value.copyWith(volumePercent: percent)),
          ),
          _slider(
            'music_tts_volume',
            l.music_settings_tts_volume,
            _ttsVolumeDraft ?? value.ttsVolumePercent,
            (percent) => setState(() => _ttsVolumeDraft = percent),
            (percent) => _save(value.copyWith(ttsVolumePercent: percent)),
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
          _number(
            'music_max_queue',
            l.music_settings_queue,
            l.music_settings_queue_hint,
            _queue,
            1,
            null,
            (number) => widget.settings.music.copyWith(maxQueue: number),
          ),
          _number(
            'music_max_duration',
            l.music_settings_duration,
            l.music_settings_duration_hint,
            _duration,
            1,
            null,
            (number) =>
                widget.settings.music.copyWith(maxDurationSeconds: number),
          ),
          _number(
            'music_cache_max_mb',
            l.music_settings_cache,
            l.music_settings_cache_hint,
            _cache,
            0,
            null,
            (number) => widget.settings.music.copyWith(cacheMaxMb: number),
          ),
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
          _number(
            'music_server_port',
            l.music_settings_port,
            l.music_settings_port_hint,
            _port,
            1,
            65535,
            (number) =>
                widget.settings.music.copyWith(controlServerPort: number),
          ),
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

  Widget _slider(
    String key,
    String label,
    int value,
    ValueChanged<int> draft,
    ValueChanged<int> save,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _title),
      Row(
        children: [
          Expanded(
            child: Slider(
              key: ValueKey(key),
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$value%',
              semanticFormatterCallback: (value) => '${value.round()}%',
              activeColor: MusicPlayerPalette.neonPinkBright,
              inactiveColor: MusicPlayerPalette.neonPink.withValues(
                alpha: 0.15,
              ),
              onChanged: _saving ? null : (value) => draft(value.round()),
              onChangeEnd: _saving ? null : (value) => save(value.round()),
            ),
          ),
          SizedBox(width: 52, child: Text('$value%', style: _secondary)),
        ],
      ),
    ],
  );

  Widget _number(
    String key,
    String label,
    String hint,
    TextEditingController controller,
    int min,
    int? max,
    MusicSettings Function(int) update,
  ) {
    Future<void> submit() async {
      if (_saving) return;
      final number = int.tryParse(controller.text.trim());
      if (number == null || number < min || (max != null && number > max)) {
        setState(() => _invalid.add(key));
        return;
      }
      setState(() => _invalid.remove(key));
      await _save(update(number));
    }

    final l = context.localizations;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _title),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: NeonSettingsInput(
                  key: ValueKey(key),
                  label: label,
                  controller: controller,
                  enabled: !_saving,
                  onSubmitted: submit,
                ),
              ),
              const Gap(12),
              NeonSettingsButton(
                key: ValueKey('${key}_apply'),
                label: l.music_settings_apply,
                icon: Icons.check_rounded,
                onPressed: _saving ? null : submit,
              ),
            ],
          ),
          const Gap(6),
          Text(hint, style: _secondary),
          if (_invalid.contains(key))
            Text(
              max != null
                  ? l.music_settings_invalid_port
                  : min == 0
                  ? l.music_settings_invalid_nonnegative
                  : l.music_settings_invalid_positive,
              style: _errorStyle,
            ),
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
