import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'social_blocker.dart';
import 'stats.dart';
import 'api_service.dart';
import 'widgets/dynamic_color_svg.dart';
import 'screens/auth_check_screen.dart';
import 'timer_page.dart';

enum AuraHistoryView { day, month, year }

class HomePage extends StatefulWidget {
  final Account account;
  const HomePage({super.key, required this.account});

  @override
  _HomePageState createState() => _HomePageState();
}

class Task {
  final String id;
  final String name;
  final String intensity;
  final String type;
  final String taskCategory;
  final int? durationMinutes;
  final bool isImageVerifiable;
  final String status;
  final String userId;
  final String createdAt;
  final String? completedAt;

  Task({
    required this.id,
    required this.name,
    required this.intensity,
    required this.type,
    required this.taskCategory,
    this.durationMinutes,
    required this.isImageVerifiable,
    required this.status,
    required this.userId,
    required this.createdAt,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json[r'$id'] ?? '',
      name: json['name'] ?? 'Unnamed Task',
      intensity: json['intensity'] ?? 'easy',
      type: json['type'] ?? 'good',
      taskCategory: json['taskCategory'] ?? 'normal',
      durationMinutes:
          json['durationMinutes'] is int
              ? json['durationMinutes']
              : (json['durationMinutes'] is String
                  ? int.tryParse(json['durationMinutes'])
                  : null),
      isImageVerifiable: json['isImageVerifiable'] ?? false,
      status: json['status'] ?? 'pending',
      userId: json['userId'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      completedAt: json['completedAt'] as String?,
    );
  }
}

class _HomePageState extends State<HomePage> {
  String userName = 'User';
  bool isLoading = true;
  List<Task> tasks = [];
  List<Task> completedTasks = [];
  int aura = 50;
  List<int> auraHistory = [50];
  List<DateTime?> auraDates = [];
  AuraHistoryView auraHistoryView = AuraHistoryView.day;
  Map<String, dynamic>? _userProfile;

  List<DateTime?> auraDatesForView = [];

  late final ApiService _apiService;
  final _storage = const FlutterSecureStorage();
  String? _currentFcmToken;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(account: widget.account);
    _initializePageData();
  }

  Future<void> _initializePageData() async {
    await _initApp();
    if (mounted) {
      _initPushNotifications();
    }
  }

  Future<void> _initApp() async {
    setState(() => isLoading = true);
    await _loadUserName();
    await _fetchDataFromServer();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadUserName() async {
    try {
      final models.User user = await widget.account.get();
      if (mounted) {
        setState(() => userName = user.name.isNotEmpty ? user.name : "User");
      }
    } catch (e) {
      if (mounted) setState(() => userName = "User");
    }
  }

  Future<void> _fetchDataFromServer() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final fetchedTasks = await _apiService.getTasks();
      final fetchedProfile = await _apiService.getUserProfile();
      print("Debug: _fetchDataFromServer: fetchedProfile = $fetchedProfile");

      if (mounted) {
        setState(() {
          tasks =
              fetchedTasks
                  .map((taskJson) => Task.fromJson(taskJson))
                  .where((task) => task.status == 'pending')
                  .toList();
          completedTasks =
              fetchedTasks
                  .map((taskJson) => Task.fromJson(taskJson))
                  .where((task) => task.status == 'completed')
                  .toList();

          _userProfile = fetchedProfile;
          aura = fetchedProfile['aura'] ?? 50;

          if (auraHistory.isEmpty || auraHistory.last != aura) {
            auraHistory.add(aura);
            if (auraHistory.length > 8) {
              auraHistory = auraHistory.sublist(auraHistory.length - 8);
            }
          }
          auraDates =
              completedTasks
                  .map(
                    (t) =>
                        t.completedAt != null
                            ? DateTime.tryParse(t.completedAt!)
                            : null,
                  )
                  .where((d) => d != null)
                  .toList();
        });
      }
    } catch (e, s) {
      print("Debug: _fetchDataFromServer: Exception caught: $e");
      print("Debug: _fetchDataFromServer: Stacktrace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: ${e.toString()}')),
        );
        _userProfile = null;
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> logout() async {
    try {
      await widget.account.deleteSession(sessionId: 'current');
      await _storage.delete(key: 'jwt_token');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AuthCheckScreen(account: widget.account),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {}
  }

  void _addTask() async {
    final taskNameController = TextEditingController();
    final durationController = TextEditingController();
    String selectedTaskCategory = 'normal';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Task',
                    style: GoogleFonts.gabarito(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Task Category:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  RadioListTile<String>(
                    title: const Text('Normal Task'),
                    value: 'normal',
                    groupValue: selectedTaskCategory,
                    onChanged:
                        (value) =>
                            modalSetState(() => selectedTaskCategory = value!),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  RadioListTile<String>(
                    title: const Text('Timed Task'),
                    value: 'timed',
                    groupValue: selectedTaskCategory,
                    onChanged:
                        (value) =>
                            modalSetState(() => selectedTaskCategory = value!),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taskNameController,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter task name',
                      labelText: 'Task Name',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (selectedTaskCategory == 'timed') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter duration in minutes',
                        labelText: 'Duration (minutes)',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final name = taskNameController.text.trim();
                            if (name.isEmpty) return;
                            Map<String, dynamic> data = {
                              'name': name,
                              'category': selectedTaskCategory,
                            };
                            if (selectedTaskCategory == 'timed') {
                              final duration = int.tryParse(
                                durationController.text.trim(),
                              );
                              if (duration == null || duration <= 0) {
                                return;
                              }
                              data['duration'] = duration;
                            }
                            Navigator.pop(context, data);
                          },
                          child: const Text('Add Task'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final String name = result['name'];
      final String category = result['category'];
      final int? duration = result['duration'];

      try {
        setState(() => isLoading = true);
        final newTaskData = await _apiService.createTask(
          name: name,
          taskCategory: category,
          durationMinutes: duration,
        );
        await _fetchDataFromServer();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add task: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteTask(int index) async {
    final pendingTasks = tasks.where((t) => t.status == 'pending').toList();
    if (index < 0 || index >= pendingTasks.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Task index out of bounds.')),
      );
      return;
    }
    final Task taskToDelete = pendingTasks[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete Task?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: Text(
              'Are you sure you want to delete "${taskToDelete.name}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      try {
        setState(() => isLoading = true);
        await _apiService.deleteTask(taskToDelete.id);
        if (mounted) {
          setState(() {
            tasks.remove(taskToDelete);
            isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete task: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _completeTask(int index) async {
    if (index < 0 || index >= tasks.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error completing task: Invalid index.")),
      );
      return;
    }
    final Task task = tasks[index];
    Map<String, dynamic>? apiCallResult;

    bool dialogWasShown = false;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      dialogWasShown = true;
    }

    try {
      if (task.type == "bad") {
        if (task.taskCategory == 'timed') {
          apiCallResult = await _apiService.completeTimedTask(task.id);
        } else {
          apiCallResult = await _apiService.completeBadTask(task.id);
        }
      } else {
        if (task.taskCategory == "normal") {
          if (task.isImageVerifiable) {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.rear,
            );
            if (pickedFile == null) {
              if (dialogWasShown && mounted) Navigator.pop(context);
              return;
            }
            final bytes = await File(pickedFile.path).readAsBytes();
            final base64Image = base64Encode(bytes);
            apiCallResult = await _apiService.completeNormalImageVerifiableTask(
              task.id,
              base64Image,
            );
          } else {
            apiCallResult = await _apiService.completeNormalNonVerifiableTask(
              task.id,
            );
          }
        } else if (task.taskCategory == 'timed') {
          apiCallResult = await _apiService.completeTimedTask(task.id);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Unsupported task completion for ${task.name}."),
              ),
            );
          }
          if (dialogWasShown && mounted) Navigator.pop(context);
          return;
        }
      }

      if (mounted) {
        await _fetchDataFromServer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${apiCallResult?['message'] ?? 'Task status updated.'} Aura change: ${apiCallResult?['auraChange'] ?? 0}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else if (apiCallResult == null && mounted) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task completion failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (dialogWasShown && mounted) Navigator.pop(context);
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _markTaskAsBadClientSide(int index) async {
    final Task task = tasks[index];
    if (task.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot change type of a completed task.')),
      );
      return;
    }
    try {
      setState(() => isLoading = true);
      final updatedTaskData = await _apiService.markTaskAsBad(task.id);
      if (mounted) {
        setState(() {
          tasks[index] = Task.fromJson(updatedTaskData);
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task "${task.name}" marked as bad.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark task as bad: ${e.toString()}'),
          ),
        );
      }
    }
  }

  List<int> getAuraHistoryForView() {
    if (auraHistoryView == AuraHistoryView.day) return auraHistory;
    if (auraHistoryView == AuraHistoryView.month) {
      Map<String, int> monthMap = {};
      Map<String, DateTime> monthDateMap = {};
      for (int i = 0; i < auraDates.length; i++) {
        final d = auraDates[i];
        if (d == null) continue;
        final key = "${d.year}-${d.month}";
        monthMap[key] = auraHistory[i];
        monthDateMap[key] = DateTime(d.year, d.month, 1);
      }
      auraDatesForView = monthDateMap.values.toList();
      return monthMap.values.toList();
    }
    if (auraHistoryView == AuraHistoryView.year) {
      Map<int, int> yearMap = {};
      Map<int, DateTime> yearDateMap = {};
      for (int i = 0; i < auraDates.length; i++) {
        final d = auraDates[i];
        if (d == null) continue;
        yearMap[d.year] = auraHistory[i];
        yearDateMap[d.year] = DateTime(d.year, 1, 1);
      }
      auraDatesForView = yearDateMap.values.toList();
      return yearMap.values.toList();
    }
    return auraHistory;
  }

  List<DateTime?> getAuraDatesForView() {
    if (auraHistoryView == AuraHistoryView.day) return auraDates;
    return auraDatesForView;
  }

  void _initPushNotifications() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
      if (mounted) {
        setState(() {
          _currentFcmToken = token;
        });
      }
    } catch (e, s) {
      print("Debug: _initPushNotifications: Exception caught: $e");
      print("Debug: _initPushNotifications: Stacktrace: $s");
      if (mounted) {
        setState(() {
          _currentFcmToken = null;
        });
      }
      return;
    }

    if (token != null && _userProfile != null) {
      final String? currentUserId = _userProfile!['userId'];
      if (currentUserId != null) {
        try {
          Account authenticatedAccount = widget.account;
          await authenticatedAccount.createPushTarget(
            targetId: currentUserId,
            identifier: token,
            providerId:
                '682f36330001ecdab2e5', // Ensure this is your Appwrite FCM provider ID
          );

          print(
            'FCM token $token successfully registered with Appwrite for user $currentUserId',
          );
        } catch (e) {
          print('Error registering FCM token with Appwrite: $e');
          if (e is AppwriteException) {
            print(
              'AppwriteException details: ${e.message}, code: ${e.code}, response: ${e.response}',
            );
          }
        }
      } else {
        print(
          "User ID is null in _initPushNotifications, cannot register FCM token with Appwrite.",
        );
      }
    } else {
      if (token == null) print("FCM token is null in _initPushNotifications.");
      if (_userProfile == null) {
        print(
          "_userProfile is null in _initPushNotifications, cannot get User ID for FCM registration.",
        );
      }
    }
  }

  @override
  void dispose() {
    // ... existing dispose code ...
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'AuraAscend',
          style: GoogleFonts.gabarito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.no_cell_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Social Media Blocker',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) =>
                          SocialMediaBlockerScreen(apiService: _apiService),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.bar_chart_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Stats',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => StatsPage(
                        aura: aura,
                        tasks:
                            tasks.where((t) => t.status == 'pending').toList(),
                        auraHistory: getAuraHistoryForView(),
                        auraDates: getAuraDatesForView(),
                        completedTasks: completedTasks,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _fetchDataFromServer,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.ebGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          children: [
                            const TextSpan(text: 'Hi, '),
                            TextSpan(
                              text: userName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const TextSpan(text: '!'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Aura: $aura',
                            style: GoogleFonts.gabarito(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 18,
                              ),
                              textStyle: GoogleFonts.gabarito(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign Out'),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // ... Your existing SliverList for normal tasks ...
                  (tasks.where((t) => t.status == 'pending').toList().isEmpty)
                      ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DynamicColorSvg(
                                assetName:
                                    'assets/img/empty_tasks.svg', // Ensure you have this asset
                                height: 180,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No active tasks.',
                                style: GoogleFonts.gabarito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add new tasks to get started.',
                                style: GoogleFonts.gabarito(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : SliverList.separated(
                        itemCount:
                            tasks
                                .where((t) => t.status == 'pending')
                                .toList()
                                .length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final pendingTasks =
                              tasks
                                  .where((t) => t.status == 'pending')
                                  .toList();
                          final task = pendingTasks[index];
                          final originalTaskIndex = tasks.indexOf(task);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 4,
                            ),
                            child: GestureDetector(
                              onLongPress:
                                  () => _deleteTask(
                                    originalTaskIndex,
                                  ), // Make sure originalTaskIndex is correct for the `tasks` list
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(18),
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                child: ListTile(
                                  onTap: () {
                                    if (task.taskCategory == "timed" &&
                                        task.type == "good" &&
                                        task.status == "pending") {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => TimerPage(
                                                task: task,
                                                apiService: _apiService,
                                                onTaskCompleted: () {
                                                  _fetchDataFromServer();
                                                },
                                              ),
                                        ),
                                      );
                                    } else if (task.status == "pending") {
                                      _completeTask(
                                        originalTaskIndex,
                                      ); // Make sure originalTaskIndex is correct
                                    }
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  leading: _buildTaskIcon(task, context),
                                  title: Text(
                                    task.name,
                                    style: GoogleFonts.gabarito(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: _buildTaskSubtitle(task, context),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        // ... existing FAB code ...
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildTaskIcon(Task task, BuildContext context) {
    if (task.type == "bad") {
      return CircleAvatar(
        backgroundColor: Colors.purple.shade100,
        child: Icon(
          Icons.warning_amber_rounded,
          color: Colors.purple,
          size: 26,
        ),
      );
    }
    if (task.taskCategory == "timed") {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        child: Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
          size: 26,
        ),
      );
    }
    return _materialYouTaskIcon(task.intensity, context);
  }

  Widget _buildTaskSubtitle(Task task, BuildContext context) {
    List<Widget> subtitleChildren = [];

    if (task.type == "bad") {
      subtitleChildren.add(
        Text(
          "Bad Task - ${_capitalize(task.intensity)}",
          style: GoogleFonts.gabarito(
            fontSize: 13,
            color: Colors.purple,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      if (task.taskCategory == 'timed' && task.durationMinutes != null) {
        subtitleChildren.add(
          Text(
            " (${task.durationMinutes} min)",
            style: GoogleFonts.gabarito(
              fontSize: 12,
              color: Colors.purple.withOpacity(0.8),
            ),
          ),
        );
      }
    } else {
      subtitleChildren.add(
        Text(
          _capitalize(task.intensity),
          style: GoogleFonts.gabarito(
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

      if (task.taskCategory == 'timed' && task.durationMinutes != null) {
        subtitleChildren.add(
          Text(
            " - Timed (${task.durationMinutes} min)",
            style: GoogleFonts.gabarito(
              fontSize: 12,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        );
      } else {
        subtitleChildren.add(SizedBox(width: 4));
        subtitleChildren.add(
          Icon(
            task.isImageVerifiable
                ? Icons.camera_alt_outlined
                : Icons.check_circle_outline,
            size: 14,
            color:
                task.isImageVerifiable
                    ? Colors.blueGrey
                    : Colors.green.shade700,
          ),
        );
        subtitleChildren.add(SizedBox(width: 2));
        subtitleChildren.add(
          Text(
            task.isImageVerifiable ? "Photo" : "Honor",
            style: GoogleFonts.gabarito(
              fontSize: 11,
              color:
                  task.isImageVerifiable
                      ? Colors.blueGrey
                      : Colors.green.shade700,
            ),
          ),
        );

        subtitleChildren.add(Spacer());
        subtitleChildren.add(
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: Size(0, 0),
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: Icon(
              Icons.flag_outlined,
              size: 16,
              color: Colors.orange.shade700,
            ),
            label: Text(
              "Flag as Bad",
              style: GoogleFonts.gabarito(
                fontSize: 11,
                color: Colors.orange.shade700,
              ),
            ),
            onPressed: () => _markTaskAsBadClientSide(tasks.indexOf(task)),
          ),
        );
      }
    }
    return Row(children: subtitleChildren);
  }

  Widget _materialYouTaskIcon(String intensity, BuildContext context) {
    switch (intensity.toLowerCase()) {
      case 'easy':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.eco_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 26,
          ),
        );
      case 'medium':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.bolt_rounded,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            size: 26,
          ),
        );
      case 'hard':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.whatshot_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 26,
          ),
        );
      default:
        return CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.task_alt_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 26,
          ),
        );
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
