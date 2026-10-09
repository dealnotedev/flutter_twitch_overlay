import 'package:obssource/pixels/pixel_rain_animator.dart';

class AvatarSettings {
  static const minResolution = 16;
  static const maxResolution = 256;
  static const minPixelSize = 2.0;
  static const maxPixelSize = 16.0;

  final int resolution;
  final double pixelSize;
  final AvatarPixelRenderer renderer;

  const AvatarSettings({
    this.resolution = 48,
    this.pixelSize = 8,
    this.renderer = AvatarPixelRenderer.rawAtlas,
  });

  factory AvatarSettings.fromJson(Map<String, dynamic> json) =>
      AvatarSettings(
        resolution: json['resolution'] is int ? json['resolution'] as int : 48,
        pixelSize:
            json['pixel_size'] is num
                ? (json['pixel_size'] as num).toDouble()
                : 8,
        renderer: switch (json['renderer']) {
          'legacy' => AvatarPixelRenderer.legacyCanvas,
          'contour_points' => AvatarPixelRenderer.contourPoints,
          _ => AvatarPixelRenderer.rawAtlas,
        },
      ).normalized();

  AvatarSettings normalized() => copyWith(
    resolution:
        resolution > 0 ? resolution.clamp(minResolution, maxResolution) : 48,
    pixelSize:
        pixelSize.isFinite
            ? (pixelSize.clamp(minPixelSize, maxPixelSize) * 2).round() / 2
            : 8,
  );

  AvatarSettings copyWith({
    int? resolution,
    double? pixelSize,
    AvatarPixelRenderer? renderer,
  }) => AvatarSettings(
    resolution: resolution ?? this.resolution,
    pixelSize: pixelSize ?? this.pixelSize,
    renderer: renderer ?? this.renderer,
  );

  Map<String, Object> toJson() => {
    'resolution': resolution,
    'pixel_size': pixelSize,
    'renderer': switch (renderer) {
      AvatarPixelRenderer.rawAtlas => 'optimized',
      AvatarPixelRenderer.legacyCanvas => 'legacy',
      AvatarPixelRenderer.contourPoints => 'contour_points',
    },
  };
}
