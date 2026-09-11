import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/generated/assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subscription sounds are packaged as WAV assets', () async {
    for (final asset in [
      Assets.subscriptionsSubscriptionPurchase,
      Assets.subscriptionsSubscriptionRenewal,
      Assets.subscriptionsSubscriptionGift,
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(44), reason: asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF', reason: asset);
      expect(
        String.fromCharCodes(bytes.skip(8).take(4)),
        'WAVE',
        reason: asset,
      );
    }
  });
}
