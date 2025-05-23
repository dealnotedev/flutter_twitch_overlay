import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/twitch/ws_manager.dart';

class ScreenAttackGameWidget extends StatefulWidget {
  final ServiceLocator locator;

  const ScreenAttackGameWidget({super.key, required this.locator});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ScreenAttackGameWidget> {
  final _available = <String>[
    Assets.assetsImgSticker1,
    Assets.assetsImgSticker2,
    Assets.assetsImgSticker3,
    Assets.assetsImgSticker4,
    Assets.assetsImgSticker5,
    Assets.assetsImgSticker6,
    Assets.assetsImgSticker7,
    Assets.assetsImgSticker8,
    Assets.assetsImgSticker9,
    Assets.assetsImgSticker10,
    Assets.assetsImgSticker11,
  ];

  Ticker? _ticker;

  StreamSubscription<dynamic>? _eventsSubscription;

  late Offset velocity;

  final double speed = 400;
  final Random _rnd = Random();

  Offset crosshairPos = Offset(0, 0);
  Offset crosshairVelocity = Offset(1, 0);

  Size get fieldSize => Size(_width, _height);

  void _updateCrosshair(double dt) {
    final Size size;
    try {
      size = fieldSize;
    } catch (_) {
      return;
    }

    final double minX = margin;
    final double minY = margin;

    final double maxX = size.width - margin;
    final double maxY = size.height - margin;

    Offset next = crosshairPos + crosshairVelocity * (speed * dt);

    _Wall? wall;

    if (next.dx <= minX) {
      wall = _Wall.left;
      next = Offset(minX, next.dy);
    } else if (next.dx >= maxX) {
      wall = _Wall.right;
      next = Offset(maxX, next.dy);
    }
    if (next.dy <= minY) {
      wall = _Wall.top;
      next = Offset(next.dx, minY);
    } else if (next.dy >= maxY) {
      wall = _Wall.bottom;
      next = Offset(next.dx, maxY);
    }

    if (wall != null) {
      _reflectCrosshair(wall);
    }

    crosshairPos = Offset(next.dx.clamp(minX, maxX), next.dy.clamp(minY, maxY));
  }

  static const double margin = 64.0;

  void _reflectCrosshair(_Wall wall, {double spreadDeg = 60}) {
    final spreadRad = spreadDeg * pi / 180;
    final double minAngle, maxAngle;

    switch (wall) {
      case _Wall.left:
        minAngle = -spreadRad / 2;
        maxAngle = spreadRad / 2;
        break;

      case _Wall.right:
        minAngle = pi - spreadRad / 2;
        maxAngle = pi + spreadRad / 2;
        break;

      case _Wall.top:
        minAngle = pi / 2 - spreadRad / 2;
        maxAngle = pi / 2 + spreadRad / 2;
        break;

      case _Wall.bottom:
        minAngle = -pi / 2 - spreadRad / 2;
        maxAngle = -pi / 2 + spreadRad / 2;
        break;
    }

    final newAngle = minAngle + _rnd.nextDouble() * (maxAngle - minAngle);
    crosshairVelocity = Offset(cos(newAngle), sin(newAngle));
  }

  @override
  void initState() {
    final angle = _rnd.nextDouble() * 2 * pi;

    velocity = Offset(cos(angle), sin(angle));

    final ws = widget.locator.provide<WebSocketManager>();
    _eventsSubscription = ws.messages.listen(_handleWebsocketMessage);

    _ticker = Ticker(_handleTimerTick)..start();
    super.initState();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  static const _speed = 0.01;

  void _handleTimerTick(_) {
    if (!_crosshairVisibile && _stickers.isEmpty) {
      _updateCrosshair(_speed);
      return;
    }

    setState(() {
      _updateCrosshair(_speed);

      final removed = <_Sticker>{};

      for (var s in _stickers) {
        s.y += s.speed;

        if (s.y > _height) {
          removed.add(s);
        }
      }

      if (removed.isNotEmpty) {
        _stickers.removeWhere((s) => removed.contains(s));
      }
    });
  }

  final _random = Random();

  final _stickers = <_Sticker>[];

  late double _width;
  late double _height;

  void _addRandomStickerToScreen() async {
    final randomSticker = _available[_random.nextInt(_available.length)];

    final image = await _loadImageFromAssets(randomSticker);
    if (image == null) {
      return;
    }

    final x = crosshairPos.dx;
    final y = crosshairPos.dy;

    final speed = 0.05 + _random.nextDouble() * (0.45 - 0.05);

    final sticker = _Sticker(
      image: image,
      x: x,
      y: y,
      asset: randomSticker,
      speed: speed,
      anim: true,
    );

    setState(() {
      _crosshairVisibility = DateTime.now();
      _stickers.add(sticker);
    });

    await Future.delayed(Duration(milliseconds: 1000));

    setState(() {
      sticker.anim = false;
    });
  }

  static Future<img.Image?> _loadImageFromAssets(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final image = img.decodeImage(bytes);
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (cntx, sizes) {
        _width = sizes.maxWidth;
        _height = sizes.maxHeight;

        return SizedBox(
          width: sizes.maxWidth,
          height: sizes.maxHeight,
          child: Stack(
            children: [
              ..._stickers.map((s) {
                return _createStickerWidget(s);
              }),
              if (_crosshairVisibile) ...[
                Positioned(
                  left: crosshairPos.dx - 32,
                  top: crosshairPos.dy - 32,
                  child: HuntCrosshair(size: 64),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool get _crosshairVisibile => _crosshairVisibility.isAfter(DateTime.now());

  Widget _createStickerWidget(_Sticker s) {
    if (s.anim) {
      final size = 240.0;
      return Positioned(
        left: s.x - (size / 2.0),
        top: s.y - (size / 2.0),
        child: LottieBuilder.asset(
          Assets.assetsBoomWhite,
          width: size,
          height: size,
          frameRate: FrameRate.max,
        ),
      );
    }

    final x = s.x - (s.image.halfWidth / 2.0);
    final y = s.y - (s.image.halfHeight / 2.0);
    return Positioned(
      top: y,
      left: x,
      child: Image.asset(
        s.asset,
        width: s.image.halfWidth,
        height: s.image.halfHeight,
      ),
    );
  }

  final _receivedEventIds = <String>{};

  void _handleWebsocketMessage(dynamic event) async {
    final eventId = event['payload']?['event']?['id'] as String?;

    if (eventId != null && !_receivedEventIds.add(eventId)) {
      // Remove duplicates
      return;
    }

    final reward = event['payload']?['event']?['reward']?['title'] as String?;

    switch (reward) {
      case 'Плюнуть в екран':
        await Future.delayed(Duration(milliseconds: 500));
        _addRandomStickerToScreen();
        break;

      case 'Прицілитись':
        setState(() {
          _crosshairVisibility = DateTime.now().add(Duration(seconds: 60));
        });
        break;
    }
  }

  DateTime _crosshairVisibility = DateTime.now();
}

class _Sticker {
  //final UserDto user;

  final String asset;
  final img.Image image;
  final double speed;
  final double x;

  double y;

  bool anim;

  _Sticker({
    required this.image,
    required this.x,
    required this.y,
    required this.asset,
    required this.speed,
    required this.anim,
  });
}

enum _Wall { top, bottom, left, right }

extension _ImgExt on img.Image {
  double get halfWidth => width.toDouble() / 4.0;

  double get halfHeight => height.toDouble() / 4.0;
}

class CrosshairWidget extends StatelessWidget {
  final double size;

  const CrosshairWidget({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final circlePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.11)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.48, circlePaint);

    final outlinePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    canvas.drawCircle(center, size.width * 0.48, outlinePaint);

    final crossPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

    final short = size.width * 0.14;
    final long = size.width * 0.48;

    canvas.drawLine(
      Offset(center.dx, center.dy - long),
      Offset(center.dx, center.dy - short),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + short),
      Offset(center.dx, center.dy + long),
      crossPaint,
    );

    canvas.drawLine(
      Offset(center.dx - long, center.dy),
      Offset(center.dx - short, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx + short, center.dy),
      Offset(center.dx + long, center.dy),
      crossPaint,
    );

    final glowPaint =
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;

    canvas.drawCircle(center, size.width * 0.46, glowPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HuntCrosshair extends StatelessWidget {
  final double size;

  const HuntCrosshair({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HuntCrosshairPainter()),
    );
  }
}

class _HuntCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final lineLength = size.width * 0.48;

    final gap = size.width * 0.25;
    final stroke = size.width * 0.045;

    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.90)
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy - gap - lineLength / 2),
      Offset(center.dx, center.dy - gap),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + gap + lineLength / 2),
      linePaint,
    );

    canvas.drawLine(
      Offset(center.dx - gap - lineLength / 2, center.dy),
      Offset(center.dx - gap, center.dy),
      linePaint,
    );

    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + gap + lineLength / 2, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
