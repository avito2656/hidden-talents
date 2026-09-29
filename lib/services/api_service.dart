import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  static Future<Map<String, dynamic>?> registerUser({
    required String name,
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'name': name, 'email': email}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка регистрации: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/users'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['users'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка сети: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required int roomId,
    required int userId,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'room_id': roomId, 'user_id': userId, 'text': text}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка отправки: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getMessages(int roomId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/messages/$roomId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['messages'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getJudgeSeats(int roomId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/judge-seats/$roomId'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['seats'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка мест: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> occupyJudgeSeat({
    required int roomId,
    required int seatNumber,
    required int userId,
    required int coins,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/judge-seats/occupy'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'room_id': roomId,
          'seat_number': seatNumber,
          'user_id': userId,
          'coins': coins,
        }),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка места: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> joinQueue({
    required int roomId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/queue/join'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'room_id': roomId, 'user_id': userId}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка очереди: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getQueue(int roomId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/queue/$roomId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['queue'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка очереди: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> startPerformance({
    required int roomId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/queue/start-performance'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'room_id': roomId, 'user_id': userId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('❌ Ошибка старта: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> endPerformance(int roomId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/queue/end-performance'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'room_id': roomId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('❌ Ошибка окончания: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentPerformer(int roomId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/queue/current/$roomId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['performer'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка текущего: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentSeason() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/seasons/current'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['season'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка сезона: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> getLeaderboard(int seasonId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/seasons/$seasonId/leaderboard'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['leaderboard'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка лидерборда: $e');
      return null;
    }
  }

  // ===== SHORTS =====

  static Future<List<dynamic>?> getShorts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/shorts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['shorts'];
      }
      return null;
    } catch (e) {
      print('❌ Ошибка shorts: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> likeShort({
    required int shortId,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/shorts/$shortId/like'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'user_id': userId}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка лайка: $e');
      return null;
    }
  }

  // ===== МОДЕРАЦИЯ =====

  static Future<Map<String, dynamic>?> checkText(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/moderate/check'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'text': text}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('❌ Ошибка модерации: $e');
      return null;
    }
  }
}
