import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:appwrite/appwrite.dart'; // Assuming you might need Appwrite for user ID or JWT
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl =
      // 'http://10.0.2.2:3000'; // Android emulator localhost
      // 'http://localhost:3000'; // iOS simulator/desktop localhost
      'https://redesigned-robot-j9p7vgg64gp2r75-4000.app.github.dev'; // Prod
  final Account account; // Appwrite account instance
  final _storage = const FlutterSecureStorage();

  ApiService({required this.account});

  Future<String?> _getJwtToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getJwtToken();
    if (token == null) {
      // Handle missing token, perhaps by throwing an error or redirecting to login
      print('JWT token not found for API request.');
      throw Exception('Authentication token not found.');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/user/profile'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print(
        'Failed to load user profile: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to load user profile: ${response.body}');
    }
  }

  Future<List<dynamic>> getTasks() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load tasks: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createTask({
    required String name,
    String intensity = 'easy',
    String type = 'good',
    String taskCategory = 'normal',
    int? durationMinutes,
    bool isImageVerifiable = false,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'intensity': intensity,
        'type': type,
        'taskCategory': taskCategory,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'isImageVerifiable': isImageVerifiable,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create task: ${response.body}');
    }
  }

  Future<void> deleteTask(String taskId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/tasks/$taskId'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete task: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> completeNormalNonVerifiableTask(
    String taskId,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks/$taskId/complete-normal-non-verifiable'),
      headers: headers,
      body: jsonEncode({'verificationType': 'honor'}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to complete normal non-verifiable task: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> completeNormalImageVerifiableTask(
    String taskId,
    String imageBase64,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks/$taskId/complete'),
      headers: headers,
      body: jsonEncode({
        'verificationType': 'image',
        'imageBase64': imageBase64,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to complete normal image verifiable task: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> completeBadTask(String taskId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks/$taskId/complete-bad'),
      headers: headers,
      body: jsonEncode({'verificationType': 'bad_task_completion'}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete bad task: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> completeTimedTask(
    String taskId, {
    int? durationSpentMinutes, // Make this parameter optional (nullable)
  }) async {
    final headers = await _getHeaders();

    // Create the body and only add duration if it's provided
    final body = <String, dynamic>{'verificationType': 'timed_completion'};
    if (durationSpentMinutes != null) {
      body['durationSpentMinutes'] = durationSpentMinutes;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks/$taskId/complete-timed'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete timed task: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> markTaskAsBad(String taskId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      // Assuming PUT to update task type
      Uri.parse('$_baseUrl/api/tasks/$taskId/mark-bad'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to mark task as bad: ${response.body}');
    }
  }

  Future<Map<String, dynamic>?> getSocialBlockerData() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/social-blocker/get'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        return data;
      }
      return {}; // Blocker exists but has no data, treat as setup.
    } else if (response.statusCode == 404) {
      return null; // No blocker setup for this user.
    } else {
      throw Exception('Failed to get social blocker data: ${response.body}');
    }
  }

  Future<void> setupSocialBlocker({
    required int socialEndDays,
    required String socialPassword,
  }) async {
    final headers = await _getHeaders();
    final user = await account.get();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/social-blocker'),
      headers: headers,
      body: jsonEncode({
        'userId': user.$id,
        'socialEnd': socialEndDays, // Sending number of days
        'socialPassword': socialPassword,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to set up social blocker: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> completeSocialBlocker() async {
    final headers = await _getHeaders();
    final user = await account.get();
    final response = await http.put(
      Uri.parse('$_baseUrl/api/social-blocker/end'),
      headers: headers,
      body: jsonEncode({
        'hasEnded': true,
        'userId': user.$id,
        'email': user.email,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete social blocker: ${response.body}');
    }
  }
}
