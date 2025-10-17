import 'package:flutter/material.dart';
import 'package:obssource/pixels/pixel.dart';

class Graffity {
  final Size size;
  final Offset start;
  final List<Pixel> pixels;

  Graffity({required this.size, required this.pixels, required this.start});

  static Graffity empty = Graffity(
    size: Size.zero,
    pixels: [],
    start: Offset.zero,
  );
}
