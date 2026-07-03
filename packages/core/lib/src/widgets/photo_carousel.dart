// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';

/// 出品詳細の写真スワイプ+インジケータ。
/// 写真配信は Phase 5a まではプレースホルダ表示。
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({super.key, required this.photos});

  final List<ListingPhoto> photos;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.photos.isEmpty ? 1 : widget.photos.length;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Container(
              color: const Color(0xFFEFEBDE),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.grass, color: SeedColors.disabled, size: 64),
            ),
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? SeedColors.green
                            : SeedColors.disabled,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
