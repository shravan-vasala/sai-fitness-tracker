import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';

class PhotoItem {
  final String path;
  final String date;
  final String poseTag;

  PhotoItem({required this.path, required this.date, required this.poseTag});
}

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final List<PhotoItem> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _deleteCurrentPhoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this photo?'),
        content: Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final item = widget.photos[_currentIndex];
              
              await ref.read(mediaRepoProvider).deletePhoto(item.date, item.path);
              
              if (!mounted) return;
              
              setState(() {
                widget.photos.removeAt(_currentIndex);
                if (widget.photos.isEmpty) {
                  Navigator.pop(context);
                } else {
                  if (_currentIndex >= widget.photos.length) {
                    _currentIndex = widget.photos.length - 1;
                  }
                  // We just let the pageview rebuild with the current index
                }
              });
            },
            child: Text('Delete', style: TextStyle(color: context.colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEE, dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _poseLabel(String tag) {
    if (tag == 'none' || tag.isEmpty) return '';
    switch (tag) {
      case 'front':
        return 'Front';
      case 'side':
        return 'Side';
      case 'back':
        return 'Back';
      default:
        return tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return Scaffold(backgroundColor: Colors.black);

    final currentPhoto = widget.photos[_currentIndex];
    final poseLabel = _poseLabel(currentPhoto.poseTag);
    final dateLabel = _formatDate(currentPhoto.date);
    
    final titleText = poseLabel.isNotEmpty ? '$dateLabel · $poseLabel' : dateLabel;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          children: [
            Dismissible(
              key: Key('viewer_dismiss'),
              direction: DismissDirection.vertical,
              onDismissed: (_) => Navigator.pop(context),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  return _ZoomablePhoto(photoPath: widget.photos[index].path);
                },
              ),
            ),
            
            // Top Overlay
            if (_showOverlay)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 16,
                    left: 8,
                    right: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          titleText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.white),
                        onPressed: _deleteCurrentPhoto,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final String photoPath;
  const _ZoomablePhoto({required this.photoPath});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;
    
    final Matrix4 endMatrix;
    if (_transformationController.value.isIdentity()) {
      final position = _doubleTapDetails!.localPosition;
      // Zoom in
      endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.5);
    } else {
      // Zoom out to normal
      endMatrix = Matrix4.identity();
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeOut).animate(_animationController));
    
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Hero(
            tag: widget.photoPath, // Optional: if we want to do hero animations
            child: kIsWeb
                ? Image.network(
                    widget.photoPath,
                    fit: BoxFit.contain,
                  )
                : Image.file(
                    File(widget.photoPath),
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
