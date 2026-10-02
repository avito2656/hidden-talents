import 'package:flutter/material.dart';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

const appId = "30e1225ad640464f847561b9c1470b8b";

// ===== РЕЖИМЫ КОМНАТЫ =====

enum LiveRoomMode {
  performer, // выступающий (камера включена)
  viewer, // зритель (только смотрит)
  judge, // судья (смотрит + голосует)
}

class LiveRoomScreen extends StatefulWidget {
  final int roomId;
  final String mode;

  const LiveRoomScreen({
    super.key,
    this.roomId = 1,
    this.mode = 'viewer',
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  late final RtcEngine _engine;
  bool _engineReady = false;
  int? _remoteUid;
  bool _localUserJoined = false;
  String _statusMessage = "Инициализация...";
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _judgeSeats = [];
  List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _currentPerformer;
  int? _userId;
  int? _userCoins = 0;
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
  List<Map<String, dynamic>> _aiVotes = [];
  Timer? _countdownTimer;
  Timer? _performanceTimer;
  Timer? _chatPollTimer;

  LiveRoomMode get _mode {
    switch (widget.mode) {
      case 'performer':
        return LiveRoomMode.performer;
      case 'judge':
        return LiveRoomMode.judge;
      default:
        return LiveRoomMode.viewer;
    }
  }

  bool get _isBroadcaster => _mode == LiveRoomMode.performer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUser();
    await _loadUserCoins();
    await _initAgora();

    _loadMessages();
    _loadJudgeSeats();
    _loadQueue();
    _loadCurrentPerformer();
    _startQueueCheck();

    _chatPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadMessages();
    });
  }

  void _startQueueCheck() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      _checkMyTurn();
    });
  }

  Future<void> _checkMyTurn() async {
    if (!_isBroadcaster) return;
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
    debugPrint('🔑 USER ID: $id');
    if (mounted) setState(() => _userId = id);
  }

  Future<void> _loadUserCoins() async {
    if (_userId == null) return;
    final user = await ApiService.getUser(_userId!);
    if (user != null && mounted) {
      setState(() => _userCoins = user['coins_balance'] ?? 0);
    }
  }

  Future<void> _loadMessages() async {
    final messages = await ApiService.getMessages(_roomId);
    if (messages != null) {
      setState(() {
        _messages = messages
            .map(
              (m) => {
                'user': m['user_id'] == _userId
                    ? 'Вы'
                    : (m['user_name'] ?? 'User ${m['user_id']}'),
                'text': m['text'],
                'isMe': m['user_id'] == _userId,
              },
            )
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
    if (_userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Вы не зарегистрированы')));
      return;
    }
    final result = await ApiService.joinQueue(
      roomId: _roomId,
      userId: _userId!,
    );

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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Вы в очереди!')));
      }
    } else if (result['limitReached'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Лимит выступлений исчерпан'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Не удалось встать в очередь'),
            backgroundColor: Colors.red,
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

    await ApiService.startPerformance(roomId: _roomId, userId: _userId!);
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

    setState(() => _isPerforming = false);

    await ApiService.endPerformance(_roomId);

    final result = await ApiService.autoVote(
      roomId: _roomId,
      performerUserId: _userId!,
    );

    if (result != null && result['success'] == true) {
      final votes = (result['votes'] as List).cast<Map<String, dynamic>>();
      final resultText = result['result_text'] ?? '';

      setState(() {
        _aiVotes = votes;
        _endText = resultText;
        _showEndText = true;
        _performanceSeconds = 90;
      });
    } else {
      setState(() {
        _endText = 'Ошибка голосования';
        _showEndText = true;
      });
    }

    await _loadCurrentPerformer();
    await _loadQueue();
  }

  Future<void> _closeEndDialog() async {
    setState(() {
      _showEndText = false;
      _readyAsked = false;
      _aiVotes = [];
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
      await _loadUserCoins();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Вы заняли место судьи!')));
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
        if (mounted) {
          setState(
            () => _statusMessage = "❌ Нет разрешений на камеру или микрофон",
          );
        }
        return;
      }

      if (mounted) setState(() => _statusMessage = "Создание движка...");

      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        const RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engineReady = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint(
                '✅ AGORA вход в канал: ${connection.channelId}, uid: ${connection.localUid}');
            if (!mounted) return;
            setState(() {
              _localUserJoined = true;
              _statusMessage = "В эфире";
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _remoteUid = null);
          },
          onError: (err, msg) {
            debugPrint('❌ AGORA ошибка: $err | $msg');
            if (!mounted) return;
            setState(() => _statusMessage = "❌ Ошибка Agora: $err $msg");
          },
          onConnectionStateChanged: (connection, state, reason) {
            debugPrint('🔌 AGORA соединение: $state, причина: $reason');
          },
          onLocalVideoStateChanged: (source, state, reason) {
            debugPrint('📷 AGORA камера: $state, причина: $reason');
            if (!mounted) return;
            if (state == LocalVideoStreamState.localVideoStreamStateCapturing) {
              setState(
                () => _statusMessage = "✅ Камера работает, подключаюсь...",
              );
            } else if (state ==
                LocalVideoStreamState.localVideoStreamStateFailed) {
              setState(() => _statusMessage = "❌ Ошибка камеры: $reason");
            }
          },
        ),
      );

      if (_isBroadcaster) {
        await _engine.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
      } else {
        await _engine.setClientRole(
          role: ClientRoleType.clientRoleAudience,
        );
      }

      if (_isBroadcaster) {
        await _engine.enableVideo();
        await _engine.startPreview();
      }

      final uid = _userId ?? 0;
      final channelName = 'room_${widget.roomId}';

      debugPrint('🚀 AGORA запрашиваю токен: channel=$channelName, uid=$uid');

      final token = await ApiService.getAgoraToken(
        channelName: channelName,
        uid: uid,
      );

      if (token == null) {
        debugPrint('❌ AGORA токен не получен');
        if (mounted) {
          setState(() => _statusMessage = "❌ Не удалось получить Agora-токен");
        }
        return;
      }

      debugPrint('✅ AGORA токен получен');

      final options = _isBroadcaster
          ? const ChannelMediaOptions(
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            )
          : const ChannelMediaOptions(
              publishCameraTrack: false,
              publishMicrophoneTrack: false,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            );

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: options,
      );

      if (_isBroadcaster) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await _engine.startPreview();
        }
      }
    } catch (e) {
      debugPrint('❌ AGORA исключение: $e');
      if (mounted) setState(() => _statusMessage = "❌ Ошибка: $e");
    }
  }

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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка подключения')));
      }
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _messages.add({'user': 'Вы', 'text': text, 'isMe': true});
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else if (result['blocked'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сообщение содержит запрещённые слова'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _performanceTimer?.cancel();
    _chatPollTimer?.cancel();
    if (_engineReady) {
      _engine.leaveChannel();
      _engine.release();
    }
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
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _mode == LiveRoomMode.performer
                              ? Colors.red
                              : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _mode == LiveRoomMode.performer
                                  ? Icons.circle
                                  : Icons.visibility,
                              color: Colors.white,
                              size: 8,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _mode == LiveRoomMode.performer
                                  ? 'LIVE'
                                  : (_mode == LiveRoomMode.judge
                                      ? 'СУДЬЯ'
                                      : 'СМОТРЮ'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isPerforming)
                        Text(
                          '⏱ $_performanceSeconds',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                    child: _buildVideoArea(),
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
                        const Text(
                          '📋 ОЧЕРЕДЬ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: _queue.isEmpty
                              ? const Text(
                                  'Пока пусто',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                )
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
                        if (_isBroadcaster &&
                            _userId != null &&
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
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'ВСТАТЬ В ОЧЕРЕДЬ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (_mode == LiveRoomMode.viewer)
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: () => _occupySeat(1),
                              icon: const Icon(Icons.gavel, size: 14),
                              label: Text(
                                'СТАТЬ СУДЬЁЙ (500) · У вас $_userCoins',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
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
                              Icon(
                                Icons.chat,
                                color: Color(0xFFFFD700),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ЧАТ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
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
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
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
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Написать...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
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
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.black,
                                    size: 14,
                                  ),
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
            if (_showReadyQuestion) _buildReadyOverlay(),
            if (_showCountdown) _buildCountdownOverlay(),
            if (_showInAir) _buildInAirOverlay(),
            if (_showEndText) _buildEndOverlay(),
          ],
        ),
      ),
    );
  }

  // ===== ВИДЕО-ОБЛАСТЬ (ИСПРАВЛЕНО!) =====

  Widget _buildVideoArea() {
    // ПРИОРИТЕТ 1: если Я выступаю — показываю СВОЮ камеру
    if (_isBroadcaster && _isPerforming) {
      return _buildLocalVideo();
    }

    // ПРИОРИТЕТ 2: если кто-то ДРУГОЙ выступает — показываю его
    if (_currentPerformer != null) {
      final performerId = _currentPerformer!['user_id'];
      if (performerId != _userId) {
        return _buildRemoteVideo();
      }
    }

    // Иначе — заглушка
    return _buildWaitingPlaceholder();
  }

  Widget _buildWaitingPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isBroadcaster ? Icons.mic : Icons.visibility,
            size: 60,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            _isBroadcaster
                ? 'Встаньте в очередь,\nчтобы выступить'
                : 'Ожидание выступающего...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
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
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid == null) {
      return const Center(
        child: Text(
          'Ожидание видео...',
          style: TextStyle(color: Colors.white54),
        ),
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

  Widget _buildReadyOverlay() {
    return _buildOverlay(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.mic,
                color: Color(0xFFFFD700),
                size: 50,
              ),
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
                    borderRadius: BorderRadius.circular(35),
                  ),
                  elevation: 10,
                  shadowColor: const Color(0xFF2ECC71),
                ),
                child: const Text(
                  'ДА!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return _buildOverlay(
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
                  scale: animation,
                  child: child,
                );
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
    );
  }

  Widget _buildInAirOverlay() {
    return _buildOverlay(
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
              child: const Icon(
                Icons.mic,
                color: Colors.black,
                size: 60,
              ),
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
    );
  }

  Widget _buildEndOverlay() {
    return _buildOverlay(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700),
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _endText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ..._aiVotes.map((vote) {
                    final opened = vote['video_opened'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: opened
                            ? const Color(0xFF2ECC71).withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: opened ? const Color(0xFF2ECC71) : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                opened ? Icons.check_circle : Icons.cancel,
                                color: opened
                                    ? const Color(0xFF2ECC71)
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vote['judge_name'] ?? 'Судья',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            vote['comment'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _closeEndDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'ЗАКРЫТЬ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildJudge(int index) {
    final seatNumber = index + 1;
    final seat = _judgeSeats.firstWhere(
      (s) => s['seat_number'] == seatNumber,
      orElse: () => {},
    );
    final occupiedBy = seat['occupied_by_user_id'];
    final isHuman = occupiedBy != null;
    final isMe = occupiedBy == _userId;
    final aiName = seat['ai_judge_name'] ?? 'Судья $seatNumber';

    return GestureDetector(
      onTap: () {
        if (_mode == LiveRoomMode.viewer && !isHuman) {
          _occupySeat(seatNumber);
        }
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                isHuman ? (isMe ? 'Вы' : 'Гость') : aiName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
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
