import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/youtube_browser_session.dart';
import 'package:obssource/music/youtube_connection_controller.dart';
import 'package:obssource/settings/neon_settings_controls.dart';

class MusicSettingsControls extends StatefulWidget {
  final Settings settings;
  final MusicControlServerController? server;
  final MusicRewardController? rewardController;
  final YoutubeConnectionController? youtubeConnection;
  final MusicRequestManager? musicRequests;
  final Widget presentationSettings;
  final Widget rewardSettings;

  const MusicSettingsControls({
    super.key,
    required this.settings,
    required this.presentationSettings,
    required this.rewardSettings,
    this.server,
    this.rewardController,
    this.youtubeConnection,
    this.musicRequests,
  });

  @override
  State<MusicSettingsControls> createState() => _MusicSettingsControlsState();
}

class _MusicSettingsControlsState extends State<MusicSettingsControls> {
  bool _showYoutubeDetails = false;
  bool _confirmYoutubeDisconnect = false;
  late final TextEditingController _port;
  late final StreamSubscription<MusicSettings> _subscription;
  StreamSubscription<MusicQueueSnapshot>? _requestsSubscription;
  String? _holdSignature;
  bool _invalidPort = false;
  bool _saving = false;
  bool _saveError = false;
  int? _volumeDraft;
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
    widget.youtubeConnection?.addListener(_changed);
    // Rebuild only when the pause notice changes, not on download progress.
    _requestsSubscription = widget.musicRequests?.states.listen((snapshot) {
      final signature = _holdSignatureOf(snapshot);
      if (signature == _holdSignature) return;
      _holdSignature = signature;
      _changed();
    });
  }

  static String? _holdSignatureOf(MusicQueueSnapshot snapshot) {
    final hold = snapshot.hold;
    if (hold == null) return null;
    final waiting =
        snapshot.queue
            .where((item) => item.phase == MusicQueueItemPhase.resolving)
            .length;
    return '${hold.name}|$waiting';
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_requestsSubscription?.cancel());
    unawaited(_subscription.cancel());
    widget.server?.removeListener(_changed);
    widget.rewardController?.removeListener(_changed);
    widget.youtubeConnection?.removeListener(_changed);
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
        if (widget.youtubeConnection != null) ...[
          _youtubePanel(),
          const Gap(16),
        ],
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
        ]),
        const Gap(16),
        _panel([
          Text(l.music_settings_player_style, style: _title),
          const Gap(12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final style in MusicPlayerStyle.values)
                NeonSettingsButton(
                  key: ValueKey('music_player_style_${style.name}'),
                  label:
                      style == MusicPlayerStyle.cosmic
                          ? l.music_settings_style_cosmic
                          : l.music_settings_style_turntable,
                  icon:
                      style == MusicPlayerStyle.cosmic
                          ? Icons.auto_awesome_rounded
                          : Icons.album_rounded,
                  selected: value.playerStyle == style,
                  onPressed:
                      _saving
                          ? null
                          : () => _save(value.copyWith(playerStyle: style)),
                ),
            ],
          ),
          const Gap(8),
          Text(l.music_settings_style_hint, style: _secondary),
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

  Widget _toggleButton(String key, bool value, VoidCallback save) =>
      NeonSettingsButton(
        key: ValueKey(key),
        label:
            value
                ? context.localizations.settings_on
                : context.localizations.settings_off,
        icon: value ? Icons.check_circle_outline : Icons.power_settings_new,
        selected: value,
        onPressed: _saving ? null : save,
      );

  Widget _youtubePanel() {
    final connection = widget.youtubeConnection!;
    final requests = widget.musicRequests;
    final l = context.localizations;
    final status = connection.status;
    final waiting = status == YoutubeConnectionStatus.awaitingVerification;
    final checking = status == YoutubeConnectionStatus.checking;
    return _panel([
      Text(l.music_youtube_title, style: _title),
      const Gap(6),
      Text(l.music_youtube_description, style: _secondary),
      if (requests != null && requests.current.hold != null) ...[
        const Gap(12),
        _holdNotice(requests),
      ],
      // Without a session, the reason below replaces the general hint.
      if (switch (status) {
            YoutubeConnectionStatus.disconnected
                when connection.issue != null =>
              null,
            YoutubeConnectionStatus.disconnected =>
              l.music_youtube_disconnected,
            YoutubeConnectionStatus.opening => l.music_youtube_opening,
            YoutubeConnectionStatus.awaitingVerification =>
              l.music_youtube_instructions,
            YoutubeConnectionStatus.checking => l.music_youtube_checking,
            YoutubeConnectionStatus.connected when connection.issue != null =>
              l.music_youtube_saved_attention,
            YoutubeConnectionStatus.connected =>
              connection.verifiedThisSession
                  ? l.music_youtube_connected
                  : l.music_youtube_saved,
          }
          case final statusText?) ...[
        const Gap(10),
        Text(
          statusText,
          key: const ValueKey('music_youtube_status'),
          style: _secondary,
        ),
      ],
      if (checking) ...[
        const Gap(8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            key: const ValueKey('music_youtube_progress'),
            value: connection.checkProgress,
            minHeight: 3,
            color: MusicPlayerPalette.neonPink,
            backgroundColor: MusicPlayerPalette.neonPink.withValues(
              alpha: 0.15,
            ),
          ),
        ),
      ],
      if (waiting) ...[
        const Gap(8),
        Text(
          l.music_youtube_account_warning,
          key: const ValueKey('music_youtube_account_warning'),
          style: _secondary,
        ),
      ],
      if (connection.issue case final issue?) ...[
        const Gap(8),
        Text(
          switch (issue) {
            YoutubeConnectionIssue.browserUnavailable =>
              l.music_youtube_no_browser,
            YoutubeConnectionIssue.browserClosed =>
              l.music_youtube_browser_closed,
            YoutubeConnectionIssue.verificationRequired =>
              l.music_youtube_verification_required,
            YoutubeConnectionIssue.downloadBlocked =>
              l.music_youtube_download_blocked,
            YoutubeConnectionIssue.rateLimited => l.music_youtube_rate_limited,
            YoutubeConnectionIssue.chooseVideo => l.music_youtube_choose_video,
            YoutubeConnectionIssue.videoUnavailable =>
              l.music_youtube_video_unavailable,
            YoutubeConnectionIssue.videoTooLongOrLive =>
              l.music_youtube_video_too_long,
            YoutubeConnectionIssue.networkUnavailable =>
              l.music_youtube_network_error,
            YoutubeConnectionIssue.toolsUnavailable =>
              l.music_youtube_tools_error,
            YoutubeConnectionIssue.storageUnavailable =>
              l.music_youtube_storage_error,
            YoutubeConnectionIssue.checkFailed => l.music_youtube_check_error,
          },
          key: const ValueKey('music_youtube_issue'),
          style: _errorStyle,
        ),
      ],
      if (connection.checkedVideoUrl case final url?) ...[
        const Gap(8),
        SelectableText(
          l.music_youtube_checked_video(url.toString()),
          style: _secondary,
        ),
      ],
      if (connection.diagnostic case final diagnostic?) ...[
        const Gap(8),
        NeonSettingsButton(
          key: const ValueKey('music_youtube_diagnostic'),
          label: l.music_youtube_error_details,
          icon: _showYoutubeDetails ? Icons.expand_less : Icons.expand_more,
          selected: _showYoutubeDetails,
          onPressed:
              () => setState(() => _showYoutubeDetails = !_showYoutubeDetails),
        ),
        if (_showYoutubeDetails) ...[
          const Gap(8),
          SelectableText(diagnostic, style: _secondary),
        ],
      ],
      const Gap(12),
      if (_confirmYoutubeDisconnect &&
          connection.hasSession &&
          !connection.busy)
        _youtubeDisconnectConfirmation(connection)
      else
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (!checking)
              NeonSettingsButton(
                key: const ValueKey('music_youtube_connect'),
                label:
                    waiting
                        ? l.music_youtube_reopen
                        : connection.hasSession
                        ? l.music_youtube_reconnect
                        : l.music_youtube_connect,
                icon: Icons.open_in_new_rounded,
                onPressed:
                    connection.busy
                        ? null
                        : () => unawaited(connection.connect()),
              ),
            if (waiting)
              NeonSettingsButton(
                key: const ValueKey('music_youtube_verify'),
                label: l.music_youtube_verify,
                icon: Icons.check_circle_outline,
                onPressed: () => unawaited(connection.verify()),
              ),
            // Cancelling only stops this attempt; the saved session stays.
            if (waiting || checking)
              NeonSettingsButton(
                key: const ValueKey('music_youtube_cancel'),
                label: l.music_youtube_cancel,
                icon: Icons.close_rounded,
                onPressed: () => unawaited(connection.cancel()),
              )
            else if (connection.hasSession)
              NeonSettingsButton(
                key: const ValueKey('music_youtube_disconnect'),
                label: l.music_youtube_disconnect,
                icon: Icons.link_off_rounded,
                onPressed:
                    connection.busy
                        ? null
                        : () =>
                            setState(() => _confirmYoutubeDisconnect = true),
              ),
          ],
        ),
    ]);
  }

  Widget _holdNotice(MusicRequestManager requests) {
    final l = context.localizations;
    final waitingRequests =
        requests.current.queue
            .where((item) => item.phase == MusicQueueItemPhase.resolving)
            .length;
    return Container(
      key: const ValueKey('music_youtube_hold'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MusicPlayerPalette.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MusicPlayerPalette.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.music_youtube_hold_title,
            style: _title.copyWith(color: MusicPlayerPalette.error),
          ),
          const Gap(4),
          Text(
            l.music_youtube_hold_body(
              waitingRequests,
              requests.heldRequestTimeout.inMinutes,
            ),
            style: _secondary,
          ),
          const Gap(10),
          NeonSettingsButton(
            key: const ValueKey('music_youtube_resume'),
            label: l.music_youtube_resume,
            icon: Icons.play_arrow_rounded,
            onPressed: requests.resumePreparation,
          ),
        ],
      ),
    );
  }

  Widget _youtubeDisconnectConfirmation(
    YoutubeConnectionController connection,
  ) {
    final l = context.localizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.music_youtube_disconnect_confirm, style: _errorStyle),
        const Gap(8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            NeonSettingsButton(
              key: const ValueKey('music_youtube_disconnect_remove'),
              label: l.music_youtube_disconnect_remove,
              icon: Icons.delete_outline_rounded,
              onPressed: () {
                setState(() => _confirmYoutubeDisconnect = false);
                unawaited(connection.disconnect());
              },
            ),
            NeonSettingsButton(
              key: const ValueKey('music_youtube_disconnect_keep'),
              label: l.music_youtube_disconnect_keep,
              icon: Icons.undo_rounded,
              onPressed:
                  () => setState(() => _confirmYoutubeDisconnect = false),
            ),
          ],
        ),
      ],
    );
  }

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
