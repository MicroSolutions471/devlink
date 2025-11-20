import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final List<String>? allImageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.allImageUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final images = (allImageUrls == null || allImageUrls!.isEmpty)
        ? <String>[imageUrl]
        : allImageUrls!;

    int startIndex = 0;
    if (images.length == 1) {
      startIndex = 0;
    } else {
      final idx = images.indexOf(imageUrl);
      if (idx >= 0) {
        startIndex = idx;
      } else {
        startIndex = initialIndex.clamp(0, images.length - 1);
      }
    }

    final pageController = PageController(initialPage: startIndex);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: PageView.builder(
                controller: pageController,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final url = images[index];
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: url.contains('assets')
                        ? Image.asset(url, fit: BoxFit.contain)
                        : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                color: scheme.onSurface,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
