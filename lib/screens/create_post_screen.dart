import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File?  _imageFile;
  File?  _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _videoFile = null;
        _videoController?.dispose();
        _videoController = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _imageFile = null;
      });
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  Future<void> _createPost() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFile == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some text, image, or video')),
      );
      return;
    }

    setState(() => _isUploading = true);
    String? imageUrl;
    String? videoUrl;
    final apiService = context.read<ApiService>();

    try {
      if (_imageFile != null)      imageUrl = await apiService.uploadMedia(_imageFile!.path);
      else if (_videoFile != null) videoUrl = await apiService.uploadMedia(_videoFile!.path);

      final post = await apiService.createPost(content, imageUrl: imageUrl, videoUrl: videoUrl);
      if (post != null && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create post')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _isUploading ? null : _createPost,
              style: TextButton.styleFrom(
                backgroundColor: _isUploading ? kDarkSurface2 : kAccent,
                foregroundColor: kTextPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2),
                    )
                  : const Text('Post', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            Container(
              decoration: BoxDecoration(
                color: kDarkSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kDarkBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _textController,
                maxLines: null,
                minLines: 4,
                style: const TextStyle(color: kTextPrimary, fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Image preview
            if (_imageFile != null)
              _buildMediaPreview(
                child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                onRemove: () => setState(() => _imageFile = null),
              ),

            // Video preview
            if (_videoFile != null && _videoController != null && _videoController!.value.isInitialized)
              _buildMediaPreview(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                onRemove: () {
                  setState(() {
                    _videoFile = null;
                    _videoController?.dispose();
                    _videoController = null;
                  });
                },
              ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: kDarkSurface,
            border: Border(top: BorderSide(color: kDarkBorder, width: 0.8)),
          ),
          child: Row(
            children: [
              const Text('Add to post:', style: TextStyle(color: kTextSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              _mediaButton(
                icon: Icons.image_rounded,
                label: 'Photo',
                color: kAccent,
                onTap: _pickImage,
              ),
              const SizedBox(width: 10),
              _mediaButton(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: kGreen,
                onTap: _pickVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview({required Widget child, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDarkBorder),
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: kTextPrimary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
