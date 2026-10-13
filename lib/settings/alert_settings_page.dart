import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/preview/effect_preview.dart';
import 'package:obssource/settings/preview/effect_samples.dart';
import 'package:obssource/settings/settings_page_layout.dart';

enum AlertPage { follow, raid, subscriptions, rewardCards, chat }

/// Settings of one alert type with its preview. Changes are saved at once,
/// like the other settings pages.
class AlertSettingsPage extends StatefulWidget {
  final AlertPage page;
  final Settings settings;

  const AlertSettingsPage({
    super.key,
    required this.page,
    required this.settings,
  });

  @override
  State<AlertSettingsPage> createState() => _AlertSettingsPageState();
}

class _AlertSettingsPageState extends State<AlertSettingsPage> {
  late final StreamSubscription<AlertsSettings> _subscription;
  final _drafts = <String, int>{};
  bool _saving = false;
  bool _saveError = false;

  AlertsSettings get _alerts => widget.settings.alerts;

  @override
  void initState() {
    super.initState();
    _subscription = widget.settings.alertsChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Future<void> _save(AlertsSettings Function(AlertsSettings) update) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      await widget.settings.saveAlerts(update(_alerts));
    } catch (_) {
      if (mounted) _saveError = true;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _drafts.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final (title, description) = switch (widget.page) {
      AlertPage.follow => (l.settings_follow, l.settings_follow_description),
      AlertPage.raid => (l.settings_raid, l.settings_raid_description),
      AlertPage.subscriptions => (
        l.settings_subscriptions,
        l.settings_subscriptions_description,
      ),
      AlertPage.rewardCards => (
        l.settings_reward_cards,
        l.settings_reward_cards_description,
      ),
      AlertPage.chat => (l.settings_chat, l.settings_chat_description),
    };

    return SettingsPageLayout(
      scrollKey: ValueKey('alert_settings_${widget.page.name}'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonSettingsHeader(title: title, description: description),
          const Gap(18),
          NeonSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _fields(l),
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
        samples: switch (widget.page) {
          AlertPage.follow => EffectSamples.follow(l),
          AlertPage.raid => EffectSamples.raid(),
          AlertPage.subscriptions => EffectSamples.subscriptions(l),
          AlertPage.rewardCards => EffectSamples.rewardCards(l),
          AlertPage.chat => EffectSamples.chat(l),
        },
        samplesLabel: widget.page == AlertPage.raid ? l.preview_viewers : null,
        rewardCards: widget.page == AlertPage.rewardCards,
      ),
    );
  }

  List<Widget> _fields(AppLocalizations l) {
    final alerts = _alerts;
    return switch (widget.page) {
      AlertPage.follow => [
        _switch(
          'follow_enabled',
          l.settings_enabled,
          alerts.follow.enabled,
          (a, v) => a.copyWith(follow: a.follow.copyWith(enabled: v)),
        ),
        const Gap(10),
        _choice('follow_style', l.settings_style, alerts.follow.style, {
          FollowStyle.pixel: l.settings_style_pixel,
          FollowStyle.balloons: l.follow_style_balloons,
        }, (a, v) => a.copyWith(follow: a.follow.copyWith(style: v))),
        const Gap(14),
        _holdSlider(
          'follow_hold',
          alerts.follow.style == FollowStyle.pixel
              ? l.settings_hold
              : l.settings_flight_time,
          alerts.follow.holdSeconds,
          l,
          (a, v) => a.copyWith(follow: a.follow.copyWith(holdSeconds: v)),
        ),
        const Gap(6),
        _choice('follow_sound', l.settings_sound, alerts.follow.sound, {
          FollowSound.modern: l.follow_sound_modern,
          FollowSound.classic: l.settings_sound_classic,
          FollowSound.none: l.settings_sound_none,
        }, (a, v) => a.copyWith(follow: a.follow.copyWith(sound: v))),
        const Gap(14),
        _volumeSlider(
          'follow_volume',
          alerts.follow.volumePercent,
          l,
          (a, v) => a.copyWith(follow: a.follow.copyWith(volumePercent: v)),
        ),
      ],
      AlertPage.raid => [
        _switch(
          'raid_enabled',
          l.settings_enabled,
          alerts.raid.enabled,
          (a, v) => a.copyWith(raid: a.raid.copyWith(enabled: v)),
        ),
        const Gap(10),
        _choice('raid_style', l.settings_style, alerts.raid.style, {
          RaidStyle.pixel: l.settings_style_pixel,
          RaidStyle.classic: l.raid_style_classic,
        }, (a, v) => a.copyWith(raid: a.raid.copyWith(style: v))),
        const Gap(14),
        _slider(
          'raid_min_viewers',
          l.raid_min_viewers,
          alerts.raid.minViewers,
          1,
          100,
          (value) => '$value',
          (a, v) => a.copyWith(raid: a.raid.copyWith(minViewers: v)),
        ),
        if (alerts.raid.style == RaidStyle.pixel)
          _holdSlider(
            'raid_hold',
            l.settings_hold,
            alerts.raid.holdSeconds,
            l,
            (a, v) => a.copyWith(raid: a.raid.copyWith(holdSeconds: v)),
          )
        else ...[
          _slider(
            'raid_max_animals',
            l.raid_max_animals,
            alerts.raid.maxAnimals,
            0,
            RaidAlertSettings.maxAnimalsLimit,
            (value) => '$value',
            (a, v) => a.copyWith(raid: a.raid.copyWith(maxAnimals: v)),
          ),
          Text(l.raid_max_animals_hint, style: _secondary),
        ],
        const Gap(10),
        _choice('raid_sound', l.settings_sound, alerts.raid.sound, {
          RaidSound.voice: l.raid_sound_voice,
          RaidSound.classic: l.settings_sound_classic,
          RaidSound.none: l.settings_sound_none,
        }, (a, v) => a.copyWith(raid: a.raid.copyWith(sound: v))),
        const Gap(14),
        _volumeSlider(
          'raid_volume',
          alerts.raid.volumePercent,
          l,
          (a, v) => a.copyWith(raid: a.raid.copyWith(volumePercent: v)),
        ),
      ],
      AlertPage.subscriptions => [
        _switch(
          'subscriptions_new',
          l.subscriptions_new,
          alerts.subscriptions.subscribe,
          (a, v) =>
              a.copyWith(subscriptions: a.subscriptions.copyWith(subscribe: v)),
        ),
        _switch(
          'subscriptions_resub',
          l.subscriptions_resub,
          alerts.subscriptions.resubscribe,
          (a, v) => a.copyWith(
            subscriptions: a.subscriptions.copyWith(resubscribe: v),
          ),
        ),
        _switch(
          'subscriptions_gift',
          l.subscriptions_gift,
          alerts.subscriptions.gift,
          (a, v) =>
              a.copyWith(subscriptions: a.subscriptions.copyWith(gift: v)),
        ),
        _switch(
          'subscriptions_avatar',
          l.subscriptions_show_avatar,
          alerts.subscriptions.showAvatar,
          (a, v) => a.copyWith(
            subscriptions: a.subscriptions.copyWith(showAvatar: v),
          ),
        ),
        const Gap(10),
        _holdSlider(
          'subscriptions_hold',
          l.settings_hold,
          alerts.subscriptions.holdSeconds,
          l,
          (a, v) => a.copyWith(
            subscriptions: a.subscriptions.copyWith(holdSeconds: v),
          ),
        ),
        const Gap(6),
        _choice(
          'subscriptions_sound',
          l.settings_sound,
          alerts.subscriptions.sound,
          {
            SubscriptionSound.distinct: l.subscriptions_sound_distinct,
            SubscriptionSound.classic: l.settings_sound_classic,
            SubscriptionSound.none: l.settings_sound_none,
          },
          (a, v) =>
              a.copyWith(subscriptions: a.subscriptions.copyWith(sound: v)),
        ),
        const Gap(14),
        _volumeSlider(
          'subscriptions_volume',
          alerts.subscriptions.volumePercent,
          l,
          (a, v) => a.copyWith(
            subscriptions: a.subscriptions.copyWith(volumePercent: v),
          ),
        ),
      ],
      AlertPage.rewardCards => [
        _switch(
          'reward_cards_enabled',
          l.settings_enabled,
          alerts.rewardCard.enabled,
          (a, v) => a.copyWith(rewardCard: a.rewardCard.copyWith(enabled: v)),
        ),
        const Gap(10),
        _slider(
          'reward_cards_seconds',
          l.settings_duration,
          alerts.rewardCard.seconds,
          RewardCardSettings.minSeconds,
          RewardCardSettings.maxSeconds,
          l.overlay_settings_seconds,
          (a, v) => a.copyWith(rewardCard: a.rewardCard.copyWith(seconds: v)),
        ),
      ],
      AlertPage.chat => [
        _switch(
          'chat_highlighted',
          l.chat_highlighted,
          alerts.chat.highlighted,
          (a, v) => a.copyWith(chat: a.chat.copyWith(highlighted: v)),
        ),
        _switch(
          'chat_first_message',
          l.chat_first_message,
          alerts.chat.firstMessage,
          (a, v) => a.copyWith(chat: a.chat.copyWith(firstMessage: v)),
        ),
        const Gap(10),
        _slider(
          'chat_seconds',
          l.settings_duration,
          alerts.chat.seconds,
          ChatAlertSettings.minSeconds,
          ChatAlertSettings.maxSeconds,
          l.overlay_settings_seconds,
          (a, v) => a.copyWith(chat: a.chat.copyWith(seconds: v)),
        ),
      ],
    };
  }

  Widget _switch(
    String key,
    String label,
    bool value,
    AlertsSettings Function(AlertsSettings, bool) update,
  ) => NeonSettingsSwitch(
    switchKey: ValueKey(key),
    label: label,
    value: value,
    onChanged: _saving ? null : (v) => unawaited(_save((a) => update(a, v))),
  );

  Widget _choice<T extends Enum>(
    String key,
    String label,
    T value,
    Map<T, String> options,
    AlertsSettings Function(AlertsSettings, T) update,
  ) => NeonSettingsChoice<T>(
    keyPrefix: key,
    label: label,
    value: value,
    options: options,
    onChanged: _saving ? null : (v) => unawaited(_save((a) => update(a, v))),
  );

  Widget _slider(
    String key,
    String label,
    int value,
    int min,
    int max,
    String Function(int) format,
    AlertsSettings Function(AlertsSettings, int) update, {
    int step = 1,
  }) => NeonSettingsSlider(
    sliderKey: ValueKey(key),
    label: label,
    value: (_drafts[key] ?? value).clamp(min, max),
    min: min,
    max: max,
    step: step,
    formatValue: format,
    onChanged: _saving ? null : (v) => setState(() => _drafts[key] = v),
    onChangeEnd: _saving ? null : (v) => unawaited(_save((a) => update(a, v))),
  );

  Widget _holdSlider(
    String key,
    String label,
    int value,
    AppLocalizations l,
    AlertsSettings Function(AlertsSettings, int) update,
  ) => _slider(
    key,
    label,
    value,
    AlertLimits.minHoldSeconds,
    AlertLimits.maxHoldSeconds,
    l.overlay_settings_seconds,
    update,
  );

  Widget _volumeSlider(
    String key,
    int value,
    AppLocalizations l,
    AlertsSettings Function(AlertsSettings, int) update,
  ) => _slider(
    key,
    l.settings_volume,
    value,
    0,
    AlertLimits.maxVolumePercent,
    (v) => l.settings_percent(v),
    update,
    step: 5,
  );

  static const _secondary = TextStyle(
    color: MusicPlayerPalette.textSecondary,
    fontSize: 12,
  );
}
