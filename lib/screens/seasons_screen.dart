import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'live_room_screen.dart';

class SeasonsScreen extends StatefulWidget {
  const SeasonsScreen({super.key});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  Map<String, dynamic>? _season;
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeason();
  }

  Future<void> _loadSeason() async {
    final season = await ApiService.getCurrentSeason();
    setState(() {
      _season = season;
    });

    if (season != null) {
      final leaderboard = await ApiService.getLeaderboard(season['id']);
      setState(() {
        _leaderboard = leaderboard ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _openStage(int roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveRoomScreen(roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'СЕЗОНЫ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_season != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A2A3A), Color(0xFF0A1929)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFD700), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.emoji_events,
                                    color: Color(0xFFFFD700), size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _season!['name'] ?? 'Сезон',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Colors.white54, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${_season!['start_date']?.substring(0, 10)} — ${_season!['end_date']?.substring(0, 10)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.card_giftcard,
                                    color: Color(0xFFFFD700), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _season!['prize_description'] ?? 'Приз',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),
                    const Text(
                      '🎬 ЭТАПЫ СЕЗОНА',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStageButton(
                            'Отбор',
                            Icons.mic,
                            const Color(0xFF2ECC71),
                            () => _openStage(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStageButton(
                            'Битва',
                            Icons.local_fire_department,
                            const Color(0xFFFF6B00),
                            () => _openStage(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStageButton(
                            'Дуэли',
                            Icons.sports_mma,
                            const Color(0xFF9B59B6),
                            () => _openStage(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStageButton(
                            'Финал',
                            Icons.emoji_events,
                            const Color(0xFFFFD700),
                            () => _openStage(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📅 РАСПИСАНИЕ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Пн–Чт: Отбор (20:00)\nПт: Битва недели (20:00)\nСб: Дуэли (20:00)\nВс: Финал недели (20:00)',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_leaderboard.isNotEmpty) ...[
                      const Text(
                        '🏅 ТОП-10 СЕЗОНА',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: List.generate(_leaderboard.length, (index) {
                            final item = _leaderboard[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == 0
                                          ? const Color(0xFFFFD700)
                                          : (index == 1
                                              ? Colors.grey
                                              : (index == 2
                                                  ? const Color(0xFFCD7F32)
                                                  : Colors.white24)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: index < 3
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? 'Участник',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${item['votes'] ?? 0} 🎤',
                                    style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStageButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
