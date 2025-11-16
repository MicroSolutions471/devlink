import 'package:flutter/material.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';

class SinglePostImage extends StatelessWidget {
  final String imageUrl;
  final String postId;

  const SinglePostImage({
    super.key,
    required this.imageUrl,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'post_${postId}_img_single';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  FullscreenImageViewer(imageUrl: imageUrl, heroTag: heroTag),
            ),
          );
        },
        child: Hero(
          tag: heroTag,
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class MultiplePostImages extends StatelessWidget {
  final List<String> imageUrls;
  final String postId;

  const MultiplePostImages({
    super.key,
    required this.imageUrls,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 2) {
      return _buildTwoImagesLayout();
    } else if (imageUrls.length == 3) {
      return _buildThreeImagesLayout();
    } else {
      return _buildFourPlusImagesLayout();
    }
  }

  Widget _buildTwoImagesLayout() {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: _buildImageContainer(
              0,
              BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildImageContainer(
              1,
              BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImagesLayout() {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildImageContainer(
              0,
              BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildImageContainer(
                    1,
                    BorderRadius.only(topRight: Radius.circular(10)),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _buildImageContainer(
                    2,
                    BorderRadius.only(bottomRight: Radius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlusImagesLayout() {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildImageContainer(
              0,
              BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildImageContainer(
                    1,
                    BorderRadius.only(topRight: Radius.circular(10)),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Stack(
                    children: [
                      _buildImageContainer(
                        2,
                        BorderRadius.only(bottomRight: Radius.circular(10)),
                      ),
                      if (imageUrls.length > 3)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+${imageUrls.length - 3} More',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer(int index, BorderRadius borderRadius) {
    final imageUrl = imageUrls[index];
    final heroTag = 'post_${postId}_img_$index';

    return Builder(
      builder: (context) => ClipRRect(
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FullscreenImageViewer(imageUrl: imageUrl, heroTag: heroTag),
              ),
            );
          },
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
