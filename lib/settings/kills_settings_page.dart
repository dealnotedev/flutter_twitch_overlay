import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/kills/kill_server.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/preview/effect_preview.dart';
import 'package:obssource/settings/preview/effect_samples.dart';
import 'package:obssource/settings/settings_page_layout.dart';

/// Local kill tracker endpoint and the kill text preview.
class KillsSettingsPage extends StatefulWidget {
  final Settings settings;

  /// Running server, for its real state; absent in tests.
  final KillServer? killServer;

  const KillsSettingsPage({super.key, required this.settings, this.killServer});

  @override
  State<KillsSettingsPage> createState() => _KillsSettingsPageState();
}

class _KillsSettingsPageState extends State<KillsSettingsPage> {
  late final _address = TextEditingController(
    text: widget.settings.kills.address,
  );
  late final _port = TextEditingController(
    text: '${widget.settings.kills.port}',
  );
  int? _secondsDraft;
  bool _saving = false;
  bool _saveError = false;
  bool _invalid = false;

  KillsSettings get _kills => widget.settings.kills;

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _save(KillsSettings value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      await widget.settings.saveKills(value);
    } catch (_) {
      if (mounted) _saveError = true;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _secondsDraft = null;
        });
      }
    }
  }

  void _applyAddress() {
    final address = _address.text.trim();
    final port = int.tryParse(_port.text.trim());
    final valid =
        InternetAddress.tryParse(address) != null &&
        port != null &&
        port > 0 &&
        port <= 65535;
    setState(() => _invalid = !valid);
    if (valid) unawaited(_save(_kills.copyWith(address: address, port: port)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final kills = _kills;
    return SettingsPageLayout(
      scrollKey: const ValueKey('kills_settings'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonSettingsHeader(
            title: l.settings_kills,
            description: l.settings_kills_description,
          ),
          const Gap(18),
          NeonSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeonSettingsSwitch(
                  switchKey: const ValueKey('kills_enabled'),
                  label: l.settings_enabled,
                  value: kills.enabled,
                  onChanged:
                      _saving
                          ? null
                          : (value) =>
                              unawaited(_save(_kills.copyWith(enabled: value))),
                ),
                const Gap(12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _labeled(
                        l.kills_address,
                        NeonSettingsInput(
                          key: const ValueKey('kills_address'),
                          controller: _address,
                          label: l.kills_address,
                          enabled: !_saving,
                          onSubmitted: _applyAddress,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 2,
                      child: _labeled(
                        l.kills_port,
                        NeonSettingsInput(
                          key: const ValueKey('kills_port'),
                          controller: _port,
                          label: l.kills_port,
                          enabled: !_saving,
                          onSubmitted: _applyAddress,
                        ),
                      ),
                    ),
                    const Gap(12),
                    NeonSettingsButton(
                      key: const ValueKey('kills_apply'),
                      label: l.kills_apply,
                      icon: Icons.check_rounded,
                      onPressed: _saving ? null : _applyAddress,
                    ),
                  ],
                ),
                const Gap(8),
                if (_invalid)
                  _status(l.kills_invalid, error: true)
                else if (widget.killServer case final server?)
                  ValueListenableBuilder(
                    valueListenable: server.state,
                    builder:
                        (context, state, _) => switch (state) {
                          KillServerState.listening => _status(
                            l.kills_listening(
                              _endpoint(kills.address, server.port),
                            ),
                          ),
                          KillServerState.failed => _status(
                            l.kills_failed(
                              _endpoint(kills.address, kills.port),
                            ),
                            error: true,
                          ),
                          KillServerState.stopped => _status(l.kills_stopped),
                        },
                  )
                else
                  _status(
                    kills.enabled
                        ? l.kills_listening(
                          _endpoint(kills.address, kills.port),
                        )
                        : l.kills_stopped,
                  ),
                const Gap(14),
                NeonSettingsSlider(
                  sliderKey: const ValueKey('kills_seconds'),
                  label: l.settings_duration,
                  value: _secondsDraft ?? kills.seconds,
                  min: KillsSettings.minSeconds,
                  max: KillsSettings.maxSeconds,
                  formatValue: l.overlay_settings_seconds,
                  onChanged:
                      _saving
                          ? null
                          : (value) => setState(() => _secondsDraft = value),
                  onChangeEnd:
                      _saving
                          ? null
                          : (value) =>
                              unawaited(_save(_kills.copyWith(seconds: value))),
                ),
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
      ),
      preview: EffectPreview(
        settings: widget.settings,
        samples: EffectSamples.kills(l),
      ),
    );
  }

  static String _endpoint(String address, int? port) {
    final host = address.contains(':') ? '[$address]' : address;
    return 'http://$host:${port ?? ''}/kill';
  }

  static Widget _status(String text, {bool error = false}) => Text(
    text,
    style: TextStyle(
      color:
          error ? MusicPlayerPalette.error : MusicPlayerPalette.textSecondary,
      fontSize: 12,
    ),
  );

  static Widget _labeled(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: MusicPlayerPalette.textSecondary,
          fontSize: 12,
        ),
      ),
      const Gap(6),
      child,
    ],
  );
}
