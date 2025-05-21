import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obssource/generated/assets.dart';

class Avatar extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final String? asset;
  final double size;

  const Avatar(
      {super.key, this.url, required this.size, this.bytes, this.asset});

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;

    final ImageProvider provider;
    if (url != null) {
      provider = CachedNetworkImageProvider(url ?? '');
    } else if (bytes != null) {
      provider = MemoryImage(bytes);
    } else {
      provider = AssetImage(asset ?? Assets.assetsIcDefaultAvatar96dp);
    }

    return CircleAvatar(
      backgroundColor: Colors.transparent,
      radius: size / 2,
      backgroundImage: provider,
    );
  }
}
