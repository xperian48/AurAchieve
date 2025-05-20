import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:appwrite/appwrite.dart';

class ApiService {
  final String _baseUrl =
      "https://auraascend-fgf4aqf5gubgacb3.centralindia-01.azurewebsites.net/api";
  final _storage = const FlutterSecureStorage();
  final Account account;

  ApiService({required this.account});

  Future<String?> _getAuthToken() async {
    String? token = await _storage.read(key: 'jwt_token');
    if (token == null || _isJwtExpired(token)) {
      try {
        final jwt = await account.createJWT();
        token = jwt.jwt;
        await _storage.write(key: 'jwt_token', value: token);
      } catch (e) {
        await _storage.delete(key: 'jwt_token');
        return null;
      }
    }
    return token;
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload['exp'];
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp is int ? exp < now : true;
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    String? token = await _getAuthToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/profile'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load user profile: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<dynamic>> getTasks() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tasks'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load tasks: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> createTask({
    required String name,
    required String taskCategory,
    int? durationMinutes,
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
      'taskCategory': taskCategory,
    };
    if (taskCategory == 'timed' && durationMinutes != null) {
      body['durationMinutes'] = durationMinutes;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tasks'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to create task';
      String rawErrorBody = response.body;
      print("Create Task API Error Body: $rawErrorBody");
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception(
        '$errorMessage (Status: ${response.statusCode}, Body: $rawErrorBody)',
      );
    }
  }

  Future<Map<String, dynamic>> completeNormalImageVerifiableTask(
    String taskId,
    String imageBase64,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete'),
      headers: await _getHeaders(),
      body: jsonEncode({'imageBase64': imageBase64}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to complete image verifiable task';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception('$errorMessage (Status: ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> completeNormalNonVerifiableTask(
    String taskId,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete-normal-non-verifiable'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to complete non-verifiable task';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception('$errorMessage (Status: ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> completeTimedTask(
    String taskId, {
    int? actualDurationSpentMinutes,
  }) async {
    final Map<String, dynamic> body = {};
    if (actualDurationSpentMinutes != null) {
      body['actualDurationSpentMinutes'] = actualDurationSpentMinutes;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete-timed'),
      headers: await _getHeaders(),

      body: body.isNotEmpty ? jsonEncode(body) : null,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to complete timed task';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception(
        '$errorMessage (Status: ${response.statusCode}, Body: ${response.body})',
      );
    }
  }

  Future<Map<String, dynamic>> completeBadTask(String taskId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete-bad'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to complete bad task';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception('$errorMessage (Status: ${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> markTaskAsBad(String taskId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/tasks/$taskId/mark-bad'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to mark task as bad: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/tasks/$taskId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete task: ${response.statusCode} ${response.body}',
      );
    }
  }
}
