import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

class ShortsScreen extends StatefulWidget {
  final bool isTabActive;
  const ShortsScreen({super.key, this.isTabActive = false});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  List<dynamic> _shorts = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadShorts();
  }

  Future<void> _loadUser() async {
    final id = await UserService.getUserId();
    if (mounted) setState(() => _userId = id);
  }

  Future<void> _loadShorts() async {
    final shorts = await ApiService.getShorts();
    if (mounted) {
      setState(() {
        _shorts = shorts ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _likeShort(int shortId) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы ставить лайки')),
      );
      return;
    }
    final result =
        await ApiService.likeShort(shortId: shortId, userId: _userId!);
    if (result != null) {
      await _loadShorts();
    }
  }

  Future<void> _openDonateDialog(int recipientUserId, int? shortId) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы донатить')),
      );
      return;
    }

    if (_userId == recipientUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя донатить самому себе')),
      );
      return;
    }

    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 28),
            SizedBox(width: 10),
            Text('Поддержать автора',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Выберите сумму доната:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAmountButton(10, () {
                  Navigator.pop(context, 10);
                }),
                _buildAmountButton(50, () {
                  Navigator.pop(context, 50);
                }),
                _buildAmountButton(100, () {
                  Navigator.pop(context, 100);
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    if (amount == null) return;

    final result = await ApiService.donate(
      senderUserId: _userId!,
      recipientUserId: recipientUserId,
      amount: amount,
      shortId: shortId,
    );

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Спасибо! Вы отправили $amount монет'),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    } else {
      final errorText = result?['error'] ?? 'Не удалось отправить донат';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAmountButton(int amount, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monetization_on,
                color: Color(0xFFFFD700), size: 24),
            const SizedBox(height: 4),
            Text(
              '$amount',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _shorts.isEmpty
              ? const Center(
                  child: Text(
                    'Пока нет Shorts',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: _shorts.length,
                  itemBuilder: (context, index) {
                    final short = _shorts[index];
                    return _buildShort(short);
                  },
                ),
    );
  }

  Widget _buildShort(Map<String, dynamic> short) {
    return Stack(
      children: [
        _buildVideo(short, widget.isTabActive),
        Positioned(
          bottom: 30,
          left: 20,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${short['user_name'] ?? 'Участник'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                short['title'] ?? 'Выступление',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  short['category'] ?? 'Талант',
                  style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 15,
          bottom: 30,
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.favorite,
                label: '${short['likes_count'] ?? 0}',
                color: Colors.red,
                onTap: () => _likeShort(short['id']),
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.monetization_on,
                label: 'Донат',
                color: const Color(0xFFFFD700),
                onTap: () => _openDonateDialog(
                  short['user_id'],
                  short['id'],
                ),
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.comment,
                label: '${short['comments_count'] ?? 0}',
                color: Colors.white,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Комментарии скоро!')),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.share,
                label: 'Поделиться',
                color: Colors.white,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Поделиться скоро!')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideo(Map<String, dynamic> short, bool isActive) {
    final videoUrl = short['video_url'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A3A), Color(0xFF0A1929)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.play_circle, size: 100, color: Colors.white24),
        ),
      );
    }

    return _VideoPlayerWidget(url: videoUrl, isActive: isActive);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ===== ВИДЕО-ПЛЕЕР =====

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool isActive;
  const _VideoPlayerWidget({required this.url, this.isActive = true});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          if (widget.isActive) _controller.play();
        }
      });
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
