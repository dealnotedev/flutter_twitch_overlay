import 'package:obssource/pixels/pixel_rain_animator.dart';

class AvatarSettings {
  static const minResolution = 16;
  static const maxResolution = 128;

  final int resolution;
  final AvatarPixelRenderer renderer;

  const AvatarSettings({
    this.resolution = 48,
    this.renderer = AvatarPixelRenderer.rawAtlas,
  });

  factory AvatarSettings.fromJson(Map<String, dynamic> json) =>
      AvatarSettings(
        resolution: json['resolution'] is int ? json['resolution'] as int : 48,
        renderer:
            json['renderer'] == 'legacy'
                ? AvatarPixelRenderer.legacyCanvas
                : AvatarPixelRenderer.rawAtlas,
      ).normalized();

  AvatarSettings normalized() => copyWith(
    resolution:
        resolution > 0 ? resolution.clamp(minResolution, maxResolution) : 48,
  );

  AvatarSettings copyWith({int? resolution, AvatarPixelRenderer? renderer}) =>
      AvatarSettings(
        resolution: resolution ?? this.resolution,
        renderer: renderer ?? this.renderer,
      );

  Map<String, Object> toJson() => {
    'resolution': resolution,
    'renderer':
        renderer == AvatarPixelRenderer.legacyCanvas ? 'legacy' : 'optimized',
  };
}
