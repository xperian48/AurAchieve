import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl =
      "https://redesigned-robot-j9p7vgg64gp2r75-3000.app.github.dev/api"; // Your API URL
  final _storage = const FlutterSecureStorage();

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    String? token = await _getAuthToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // User Profile
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

  // Tasks
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

  // Modified: Create task
  Future<Map<String, dynamic>> createTask({
    required String name,
    required String taskCategory, // "normal" or "timed"
    int? durationMinutes, // Optional, for timed tasks
  }) async {
    final Map<String, dynamic> body = {
      // Ensure 'body' is defined here
      'name': name,
      'taskCategory': taskCategory,
    };
    if (taskCategory == 'timed' && durationMinutes != null) {
      body['durationMinutes'] = durationMinutes;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/tasks'),
      headers: await _getHeaders(),
      body: jsonEncode(body), // Now 'body' is correctly referenced
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

  // Complete a "good" normal task (with image) - Renamed for clarity
  Future<Map<String, dynamic>> completeNormalImageVerifiableTask(
    String taskId,
    String imageBase64,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete'), // Existing endpoint
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

  // NEW: Complete a "good" normal task (NO image)
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

  // NEW: Complete a Timed Task
  Future<Map<String, dynamic>> completeTimedTask(String taskId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tasks/$taskId/complete-timed'),
      headers: await _getHeaders(),
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
      throw Exception('$errorMessage (Status: ${response.statusCode})');
    }
  }

  // Complete a "bad" task (no image) - for tasks of type 'bad'
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
