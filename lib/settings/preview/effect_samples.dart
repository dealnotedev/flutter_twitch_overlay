import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/effects/screen_attack_game.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/settings/preview/effect_preview.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';

/// Sample events for every settings page with a preview.
abstract final class EffectSamples {
  static const _shortName = 'Freya';
  static const _longName = 'TheVeryLongNickname_2026';

  static List<PreviewSample> follow(AppLocalizations l) => [
    _event('short', l.preview_short_name, () => _follow(_shortName)),
    _event('long', l.preview_long_name, () => _follow(_longName)),
  ];

  static List<PreviewSample> raid() => [
    for (final viewers in const [1, 2, 5, 21, 100, 101, 1000])
      _event(
        'raid_$viewers',
        '$viewers',
        () => RaidEvent(from: PreviewData.user(_shortName), viewers: viewers),
      ),
  ];

  static List<PreviewSample> subscriptions(AppLocalizations l) => [
    for (final tier in const [1, 3])
      _event(
        'new_t$tier',
        l.preview_new_subscription(tier),
        () => _subscription(SubscriptionEventType.subscribe, tier: tier),
      ),
    _event(
      'resub',
      l.preview_resubscription(15),
      () => _subscription(SubscriptionEventType.message, tier: 2, months: 15),
    ),
    for (final count in const [1, 5])
      _event(
        'gift_$count',
        l.preview_gift(count),
        () => _subscription(SubscriptionEventType.gift, count: count),
      ),
    _event(
      'anonymous',
      l.preview_anonymous_gift,
      () =>
          _subscription(SubscriptionEventType.gift, count: 5, anonymous: true),
    ),
  ];

  static List<PreviewSample> rewardCards(AppLocalizations l) => [
    _event('short', l.preview_short_title, () => _redemption(null, 'Hydrate')),
    _event(
      'long',
      l.preview_long_title,
      () => _redemption(
        null,
        'Choose the next game for the whole evening stream',
        cost: 125000,
      ),
    ),
  ];

  static List<PreviewSample> chat(AppLocalizations l) => [
    _event(
      'highlighted',
      l.chat_message_highlighted,
      () => _chat('Привіт, чат! Як справи?', highlighted: true),
    ),
    _event(
      'first',
      l.chat_message_first,
      () => _chat('Вперше тут, гарного стріму!', name: _longName),
    ),
    _event(
      'emote',
      l.preview_emote,
      () => _chat('GG ', highlighted: true, emote: true),
    ),
  ];

  static List<PreviewSample> flashbang(AppLocalizations l) => [
    for (final (id, label, pro) in [
      ('normal', l.preview_normal, false),
      ('golden', l.preview_golden, true),
    ])
      PreviewSample(
        id: id,
        label: label,
        play: (target) {
          target.flashbangPro = pro;
          target.runtime.handle(_redemption(RewardAction.flashbang, 'Bang'));
        },
      ),
  ];

  static List<PreviewSample> crt(AppLocalizations l) => [
    _event(
      'off',
      l.settings_crt,
      () => _redemption(RewardAction.crt, RewardAction.crt.legacyTitle),
    ),
  ];

  static List<PreviewSample> pause(AppLocalizations l) => [
    for (final input in const ['2', '1:30 Скоро повернуся'])
      _event(
        input,
        input,
        () => _redemption(RewardAction.pause, 'Pause', input: input),
      ),
    _event(
      'remove',
      l.preview_remove,
      () => _redemption(RewardAction.pause, 'Pause', input: '0'),
    ),
  ];

  static List<PreviewSample> stickers(AppLocalizations l) => [
    _event(
      'crosshair',
      l.preview_crosshair,
      () => _redemption(RewardAction.crosshair, 'Aim'),
    ),
    _event(
      'random',
      l.preview_random_sticker,
      () => _redemption(RewardAction.sticker, 'Spit'),
    ),
    for (final (index, asset) in ScreenAttackGameWidget.stickers.indexed)
      PreviewSample(
        id: 'sticker_${index + 1}',
        label: '${index + 1}',
        play: (target) => target.runtime.screenAttack.sticker(asset),
      ),
  ];

  static List<PreviewSample> kills(AppLocalizations l) => [
    for (final (streak, text) in const [
      (1, 'First blood'),
      (3, 'Triple kill'),
      (5, 'Rampage'),
      (12, 'Godlike'),
    ])
      _event(
        'streak_$streak',
        l.preview_streak(streak),
        () => KillEvent(
          KillInfo(
            text: text,
            inMatch: streak,
            inMatchStreak: streak,
            totalStreak: streak,
          ),
        ),
      ),
  ];

  static PreviewSample _event(
    String id,
    String label,
    AlertEvent Function() event,
  ) => PreviewSample(
    id: id,
    label: label,
    play: (target) => target.runtime.handle(event()),
  );

  static FollowEvent _follow(String name) =>
      FollowEvent(user: PreviewData.user(name));

  static SubscriptionEvent _subscription(
    SubscriptionEventType type, {
    int tier = 1,
    int? months,
    int? count,
    bool anonymous = false,
  }) => SubscriptionEvent(
    subscription: WsSubscription(
      type: type,
      tier: tier,
      months: months,
      count: count,
      isAnonymous: anonymous,
    ),
    user: anonymous ? null : PreviewData.user(_shortName),
  );

  static RedemptionEvent _redemption(
    RewardAction? action,
    String title, {
    int cost = 1000,
    String? input,
  }) => RedemptionEvent(
    id: PreviewData.nextId(),
    rewardId: action != null ? PreviewData.rewardId(action) : null,
    rewardTitle: title,
    cost: cost,
    user: PreviewData.user(_shortName),
    input: input,
  );

  static ChatEvent _chat(
    String text, {
    String name = _shortName,
    bool highlighted = false,
    bool emote = false,
  }) => ChatEvent(
    messageId: PreviewData.nextId(),
    // A new chatter ID each time, so the first-message card always shows.
    chatter: UserInfo(
      id: PreviewData.nextId(),
      login: name.toLowerCase(),
      name: name,
    ),
    messageType: highlighted ? ChatEvent.highlightedType : 'text',
    message: WsChatMessage(
      text: text,
      fragments: [
        WsChatMessageFragment(type: WsFragmentType.text, text: text),
        if (emote)
          const WsChatMessageFragment(
            type: WsFragmentType.emote,
            text: 'Kappa',
            emote: WsChatEmote(id: '25', format: ['static']),
          ),
      ],
    ),
  );
}
