import 'package:flutter/material.dart';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

const appId = "30e1225ad640464f847561b9c1470b8b";

class LiveRoomScreen extends StatefulWidget {
  final int roomId;

  const LiveRoomScreen({super.key, this.roomId = 1});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  late final RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isBroadcaster = true;
  String _statusMessage = "Инициализация...";
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _judgeSeats = [];
  List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _currentPerformer;
  int? _userId;
  int get _roomId => widget.roomId;

  bool _isPerforming = false;
  bool _showReadyQuestion = false;
  bool _readyAsked = false;
  bool _showCountdown = false;
  bool _showInAir = false;
  bool _showEndText = false;
  int _countdownSeconds = 5;
  int _performanceSeconds = 90;
  String _endText = "";
  Timer? _countdownTimer;
  Timer? _performanceTimer;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _loadUser();
    _loadMessages();
    _loadJudgeSeats();
    _loadQueue();
    _loadCurrentPerformer();
    _startQueueCheck();
  }

  void _startQueueCheck() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      _checkMyTurn();
    });
  }

  Future<void> _checkMyTurn() async {
    if (_userId == null) return;
    if (_isPerforming || _showReadyQuestion || _readyAsked) return;

    final queue = await ApiService.getQueue(_roomId);
    if (queue == null || queue.isEmpty) return;

    final first = queue[0];
    if (first['user_id'] == _userId) {
      final performer = await ApiService.getCurrentPerformer(_roomId);
      if (performer == null) {
        setState(() => _showReadyQuestion = true);
      }
    }
  }

  Future<void> _loadUser() async {
    final id = await UserService.getUserId();
    setState(() => _userId = id);
  }

  Future<void> _loadMessages() async {
    final messages = await ApiService.getMessages(_roomId);
    if (messages != null) {
      setState(() {
        _messages = messages
            .map((m) => {
                  'user': m['user_id'] == _userId
                      ? 'Вы'
                      : (m['user_name'] ?? 'User ${m['user_id']}'),
                  'text': m['text'],
                  'isMe': m['user_id'] == _userId,
                })
            .toList();
      });
    }
  }

  Future<void> _loadJudgeSeats() async {
    final seats = await ApiService.getJudgeSeats(_roomId);
    if (seats != null) {
      setState(() {
        _judgeSeats = seats.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _loadQueue() async {
    final queue = await ApiService.getQueue(_roomId);
    if (queue != null) {
      setState(() {
        _queue = queue.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _loadCurrentPerformer() async {
    final performer = await ApiService.getCurrentPerformer(_roomId);
    setState(() {
      _currentPerformer = performer;
    });
  }

  Future<void> _joinQueue() async {
    if (_userId == null) return;
    final result =
        await ApiService.joinQueue(roomId: _roomId, userId: _userId!);

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения к серверу')),
        );
      }
      return;
    }

    if (result['success'] == true) {
      await _loadQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы в очереди!')),
        );
      }
    } else if (result['limitReached'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Лимит выступлений исчерпан'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onReadyYes() {
    setState(() {
      _readyAsked = true;
      _showReadyQuestion = false;
      _showCountdown = true;
      _countdownSeconds = 5;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        _countdownTimer?.cancel();
        _onCountdownFinished();
      }
    });
  }

  Future<void> _onCountdownFinished() async {
    setState(() {
      _showCountdown = false;
      _showInAir = true;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _showInAir = false;
      _isPerforming = true;
      _performanceSeconds = 90;
    });

    await ApiService.startPerformance(
      roomId: _roomId,
      userId: _userId!,
    );
    await _loadCurrentPerformer();
    await _loadQueue();

    _startPerformanceTimer();
  }

  void _startPerformanceTimer() {
    _performanceTimer?.cancel();
    _performanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_performanceSeconds > 0) {
        setState(() => _performanceSeconds--);
      } else {
        _endPerformance();
      }
    });
  }

  Future<void> _endPerformance() async {
    _performanceTimer?.cancel();
    await ApiService.endPerformance(_roomId);

    final openedCount =
        _judgeSeats.where((s) => s['occupied_by_user_id'] != null).length;

    String text;
    if (openedCount == 0) {
      text = "Не расстраивайтесь!\nВ следующий раз получится лучше 💪";
    } else if (openedCount == 1) {
      text = "Поздравляю!\nК вам повернулся 1 судья 🎉";
    } else if (openedCount == 2) {
      text = "Поздравляю!\nК вам повернулись 2 судьи 🎉";
    } else {
      text = "Поздравляю!\nК вам повернулись все 3 судьи! 🔥";
    }

    setState(() {
      _isPerforming = false;
      _showEndText = true;
      _endText = text;
      _performanceSeconds = 90;
    });

    await _loadCurrentPerformer();
    await _loadQueue();

    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    setState(() {
      _showEndText = false;
      _readyAsked = false;
    });
  }

  Future<void> _occupySeat(int seatNumber) async {
    if (_userId == null) return;
    final result = await ApiService.occupyJudgeSeat(
      roomId: _roomId,
      seatNumber: seatNumber,
      userId: _userId!,
      coins: 500,
    );
    if (result != null && result['success'] == true) {
      await _loadJudgeSeats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы заняли место судьи!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Недостаточно монет или место занято')),
        );
      }
    }
  }

  Future<void> _initAgora() async {
    try {
      setState(() => _statusMessage = "Запрос разрешений...");
      final micStatus = await Permission.microphone.request();
      final camStatus = await Permission.camera.request();

      if (micStatus != PermissionStatus.granted ||
          camStatus != PermissionStatus.granted) {
        setState(() => _statusMessage = "❌ Нет разрешений");
        return;
      }

      setState(() => _statusMessage = "Создание движка...");
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(appId: appId));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() {
              _localUserJoined = true;
              _statusMessage = "В эфире";
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            setState(() => _remoteUid = null);
          },
          onError: (err, msg) {
            setState(() => _statusMessage = "❌ Ошибка: $msg");
          },
          onLocalVideoStateChanged: (source, state, reason) {
            if (state == LocalVideoStreamState.localVideoStreamStateCapturing) {
              setState(() => _statusMessage = "✅ Камера работает");
            } else if (state ==
                LocalVideoStreamState.localVideoStreamStateFailed) {
              setState(() => _statusMessage = "❌ Ошибка камеры: $reason");
            }
          },
        ),
      );

      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine.joinChannel(
        token: '',
        channelId: 'room_${widget.roomId}',
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      setState(() => _statusMessage = "❌ Ошибка: $e");
    }
  }

  // ===== ОТПРАВКА СООБЩЕНИЯ С МОДЕРАЦИЕЙ =====

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty || _userId == null) return;

    final text = _chatController.text.trim();
    _chatController.clear();

    final result = await ApiService.sendMessage(
      roomId: _roomId,
      userId: _userId!,
      text: text,
    );

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения')),
        );
      }
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _messages.add({'user': 'Вы', 'text': text, 'isMe': true});
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else if (result['blocked'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сообщение содержит запрещённые слова'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _performanceTimer?.cancel();
    _engine.leaveChannel();
    _engine.release();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      if (_isPerforming)
                        Text(
                          '⏱ $_performanceSeconds',
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: _currentPerformer != null
                        ? _buildPerformerVideo()
                        : (_isBroadcaster
                            ? _buildLocalVideo()
                            : _buildRemoteVideo()),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (index) => _buildJudge(index)),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📋 ОЧЕРЕДЬ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                        const SizedBox(height: 2),
                        Expanded(
                          child: _queue.isEmpty
                              ? const Text('Пока пусто',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 10))
                              : ListView.builder(
                                  itemCount: _queue.length,
                                  itemBuilder: (context, index) {
                                    final item = _queue[index];
                                    final isMe = item['user_id'] == _userId;
                                    final isPerforming =
                                        item['is_performing'] == true;
                                    return Text(
                                      '${index + 1}. ${item['user_name']}${isMe ? ' (Вы)' : ''}${isPerforming ? ' 🎤' : ''}',
                                      style: TextStyle(
                                        color: isPerforming
                                            ? const Color(0xFF2ECC71)
                                            : (isMe
                                                ? const Color(0xFFFFD700)
                                                : Colors.white70),
                                        fontSize: 10,
                                        fontWeight: isPerforming
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_userId != null &&
                            !_isPerforming &&
                            !_showReadyQuestion)
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _joinQueue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text('ВСТАТЬ В ОЧЕРЕДЬ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: const Row(
                            children: [
                              Icon(Icons.chat,
                                  color: Color(0xFFFFD700), size: 12),
                              SizedBox(width: 4),
                              Text('ЧАТ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _chatScrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['isMe'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${msg['user']}: ',
                                        style: TextStyle(
                                          color: isMe
                                              ? const Color(0xFFFFD700)
                                              : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg['text'],
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                  decoration: InputDecoration(
                                    hintText: 'Написать...',
                                    hintStyle: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: _sendMessage,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD700),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.send,
                                      color: Colors.black, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            if (_showReadyQuestion)
              _buildOverlay(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFFD700), width: 3),
                        ),
                        child: const Icon(Icons.mic,
                            color: Color(0xFFFFD700), size: 50),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Ты готов?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Твоё время пришло!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 220,
                        height: 65,
                        child: ElevatedButton(
                          onPressed: _onReadyYes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(35)),
                            elevation: 10,
                            shadowColor: const Color(0xFF2ECC71),
                          ),
                          child: const Text('ДА!',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showCountdown)
              _buildOverlay(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ПРИГОТОВЬСЯ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 18,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
                        },
                        child: Text(
                          '$_countdownSeconds',
                          key: ValueKey<int>(_countdownSeconds),
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 180,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showInAir)
              _buildOverlay(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFD700),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic,
                            color: Colors.black, size: 60),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'ТЫ В ЭФИРЕ!',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (_showEndText)
              _buildOverlay(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events,
                              color: Color(0xFFFFD700), size: 60),
                          const SizedBox(height: 15),
                          Text(
                            _endText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFF1A2A3A).withOpacity(0.98),
            Colors.black.withOpacity(0.98),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildPerformerVideo() {
    return Stack(
      children: [
        _buildLocalVideo(),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '🎤 ${_currentPerformer?['user_name'] ?? 'Выступает'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalVideo() {
    if (!_localUserJoined) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFD700)),
            const SizedBox(height: 10),
            Text(_statusMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(
              uid: 0, sourceType: VideoSourceType.videoSourceCamera),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid == null) {
      return const Center(
        child: Text('Ожидание участника...',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: 'room_${widget.roomId}'),
        ),
      ),
    );
  }

  Widget _buildJudge(int index) {
    final seatNumber = index + 1;
    final seat = _judgeSeats.firstWhere(
      (s) => s['seat_number'] == seatNumber,
      orElse: () => {},
    );
    final occupiedBy = seat['occupied_by_user_id'];
    final isHuman = occupiedBy != null;
    final isMe = occupiedBy == _userId;

    return GestureDetector(
      onTap: () {
        if (!isHuman) _occupySeat(seatNumber);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: 55,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                isHuman
                    ? (isMe ? 'Вы' : 'Кит')
                    : (seat['ai_judge_name'] ?? 'Судья $seatNumber'),
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 7,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
