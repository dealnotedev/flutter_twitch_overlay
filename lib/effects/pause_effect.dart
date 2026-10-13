import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel_rain_avatar.dart';

/// Viewer input of the pause reward: `minutes` or `m:ss`, optionally
/// followed by a message, e.g. `5` or `1:30 Back soon`.
class PauseRequest {
  final Duration duration;
  final String? message;

  const PauseRequest({required this.duration, this.message});

  /// A zero duration or empty input removes the pause.
  bool get clears => duration == Duration.zero;

  /// Returns `null` when the time is malformed; the redemption is ignored.
  static PauseRequest? parse(String? input, {required Duration max}) {
    final parts = (input ?? '').trim().split(RegExp(r'\s+'));
    final time = parts.first;
    if (time.isEmpty) return const PauseRequest(duration: Duration.zero);

    final Duration duration;
    final minutesAndSeconds = RegExp(r'^(\d{1,3}):(\d{1,2})$').firstMatch(time);
    if (minutesAndSeconds != null) {
      duration = Duration(
        minutes: int.parse(minutesAndSeconds.group(1)!),
        seconds: int.parse(minutesAndSeconds.group(2)!),
      );
    } else if (RegExp(r'^\d{1,4}$').hasMatch(time)) {
      duration = Duration(minutes: int.parse(time));
    } else {
      return null;
    }

    final message = parts.skip(1).join(' ');
    return PauseRequest(
      duration: duration > max ? max : duration,
      message: message.isEmpty ? null : message,
    );
  }
}

class PauseEffect {
  final img.Image image;
  final Duration duration;
  final String? message;

  const PauseEffect({
    required this.image,
    required this.duration,
    required this.message,
  });
}

/// Pixel picture that assembles over the pause duration, with a message.
class PauseEffectWidget extends StatelessWidget {
  final PauseEffect effect;
  final BoxConstraints constraints;

  const PauseEffectWidget({
    super.key,
    required this.effect,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final message = effect.message;
    return Stack(
      children: [
        RainyAvatar(
          pixelSize: 12,
          verticalOffset: message != null ? -64 : 0,
          fallDuration: const Duration(milliseconds: 1500),
          duration: effect.duration,
          image: effect.image,
          constraints: constraints,
        ),
        if (message != null)
          Positioned(
            left: 320,
            right: 320,
            bottom: 48,
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
