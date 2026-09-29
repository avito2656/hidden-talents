import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

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
    setState(() => _userId = id);
  }

  Future<void> _loadShorts() async {
    final shorts = await ApiService.getShorts();
    setState(() {
      _shorts = shorts ?? [];
      _isLoading = false;
    });
  }

  Future<void> _likeShort(int shortId) async {
    if (_userId == null) return;
    final result =
        await ApiService.likeShort(shortId: shortId, userId: _userId!);
    if (result != null) {
      await _loadShorts();
    }
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
        // Фон-заглушка
        Container(
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
        ),

        // Информация внизу
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

        // Кнопки справа
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
                label: '${short['coins_earned'] ?? 0}',
                color: const Color(0xFFFFD700),
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.comment,
                label: '${short['comments_count'] ?? 0}',
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.share,
                label: 'Поделиться',
                color: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
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
