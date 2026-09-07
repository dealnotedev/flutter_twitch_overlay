import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/data/events.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/l10n/app_localizations_en.dart';
import 'package:obssource/l10n/app_localizations_uk.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/pixels/pixel_rain_text.dart';
import 'package:obssource/raid/raid_widget.dart';
import 'package:obssource/subs/subs_widget.dart';

void main() {
  test('Ukrainian raid plurals handle one, few, many and teen exceptions', () {
    final l10n = AppLocalizationsUk();
    for (final count in [1, 21, 31, 101, 121, 1001]) {
      expect(l10n.raid_viewers(count), 'привів $count глядача');
    }
    for (final count in [
      0,
      2,
      3,
      4,
      5,
      11,
      12,
      14,
      20,
      22,
      25,
      100,
      111,
      112,
      114,
    ]) {
      expect(l10n.raid_viewers(count), 'привів $count глядачів');
    }
    final english = AppLocalizationsEn();
    expect(english.raid_viewers(1), 'brought 1 viewer');
    expect(english.raid_viewers(21), 'brought 21 viewers');
  });

  for (final isRaid in [false, true]) {
    for (final renderer in AvatarPixelRenderer.values) {
      testWidgets(
        '${isRaid ? "raid" : "follow"} uses the avatar radius throughout $renderer animation',
        (tester) async {
          final avatar = img.Image(width: 8, height: 8)
            ..setPixelRgba(0, 0, 255, 255, 255, 255);
          final png = ByteData.sublistView(img.encodePng(avatar));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          rootBundle.evict(Assets.assetsHeart);
          rootBundle.evict(Assets.assetsHeartBackgroundFilled);
          messenger.setMockMessageHandler('flutter/assets', (message) {
            final asset = const StringCodec().decodeMessage(message);
            if (asset == Assets.assetsHeart ||
                asset == Assets.assetsHeartBackgroundFilled) {
              return SynchronousFuture(png);
            }
            return SynchronousFuture(null);
          });
          addTearDown(() {
            messenger.setMockMessageHandler('flutter/assets', null);
            rootBundle.evict(Assets.assetsHeart);
            rootBundle.evict(Assets.assetsHeartBackgroundFilled);
          });

          final now = DateTime.now();
          const constraints = BoxConstraints.tightFor(width: 800, height: 600);
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('uk'),
              home:
                  isRaid
                      ? RaidWidget(
                        event: UserRaidEvent(
                          userName: 'Raider',
                          viewers: 21,
                          avatar: avatar,
                        ),
                        constraints: constraints,
                        renderer: renderer,
                        avatarResolution: 8,
                      )
                      : FollowWidget(
                        event: UserFollowEvent(
                          userName: 'Follower',
                          user: null,
                          avatar: avatar,
                          time: now,
                          end: now.add(const Duration(seconds: 20)),
                        ),
                        constraints: constraints,
                        renderer: renderer,
                        avatarResolution: 8,
                      ),
            ),
          );
          await tester.pump();

          expect(
            tester.widget<SubsWidget>(find.byType(SubsWidget)).description,
            isRaid ? 'привів 21 глядача' : 'Дякую за фолов!',
          );
          expect(find.byKey(const ValueKey('name')), findsOneWidget);
          expect(find.byKey(const ValueKey('description')), findsOneWidget);
          _expectMatchingRadii(tester);

          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 10));
          expect(find.byKey(const ValueKey('heart')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('heart_background')),
            findsOneWidget,
          );
          expect(
            tester.widget<RainyAvatar>(find.byType(RainyAvatar)).direction,
            RainyPixelDirection.leaving,
          );
          _expectMatchingRadii(tester);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

void _expectMatchingRadii(WidgetTester tester) {
  final avatar = tester.widget<RainyAvatar>(find.byType(RainyAvatar));
  expect(avatar.pixelRadius, const Radius.circular(1));
  final texts =
      tester.widgetList<PixelRainText>(find.byType(PixelRainText)).toList();
  expect(texts, hasLength(2));
  for (final text in texts) {
    expect(text.pixelRadius, avatar.pixelRadius);
  }
  final renderers =
      tester.widgetList<AvatarPixelRain>(find.byType(AvatarPixelRain)).toList();
  expect(renderers, hasLength(3));
  for (final renderer in renderers) {
    expect(renderer.pixelRadius, avatar.pixelRadius);
  }
}
