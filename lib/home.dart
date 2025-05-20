import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter

import 'stats.dart';
import 'api_service.dart';
import 'widgets/dynamic_color_svg.dart';
import 'screens/auth_check_screen.dart';

class HomePage extends StatefulWidget {
  final Account account;
  const HomePage({super.key, required this.account});

  @override
  _HomePageState createState() => _HomePageState();
}

class _Task {
  final String id;
  final String name;
  final String intensity; // easy, medium, hard
  String type; // good, bad
  final String status; // pending, completed
  final String taskCategory; // normal, timed
  final int? durationMinutes; // For timed tasks
  final bool isImageVerifiable; // For normal tasks

  final String? createdAt;
  final String? completedAt;

  _Task({
    required this.id,
    required this.name,
    required this.intensity,
    required this.type,
    required this.status,
    required this.taskCategory,
    this.durationMinutes,
    required this.isImageVerifiable,
    this.createdAt,
    this.completedAt,
  });

  factory _Task.fromJson(Map<String, dynamic> json) {
    return _Task(
      id: json['_id'] ?? json['\$id'] ?? '',
      name: json['name'] ?? 'Unknown Task',
      intensity: json['intensity'] ?? 'easy',
      type: json['type'] ?? 'good',
      status: json['status'] ?? 'pending',
      taskCategory: json['taskCategory'] ?? 'normal',
      durationMinutes: json['durationMinutes'] as int?,
      isImageVerifiable: json['isImageVerifiable'] ?? false,
      createdAt: json['createdAt'],
      completedAt: json['completedAt'],
    );
  }
}

class _HomePageState extends State<HomePage> {
  String userName = 'User';
  bool isLoading = true;
  List<_Task> tasks = [];
  int aura = 50;
  List<int> auraHistory = [50];

  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initApp();
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
      if (mounted)
        setState(() => userName = user.name.isNotEmpty ? user.name : "User");
    } catch (e) {
      print('Failed to load user name: $e');
      if (mounted) setState(() => userName = "User");
    }
  }

  Future<void> _fetchDataFromServer() async {
    try {
      final profileData = await _apiService.getUserProfile();
      final tasksData = await _apiService.getTasks();
      if (mounted) {
        setState(() {
          aura = profileData['aura'] ?? 50;
          if (auraHistory.isEmpty || auraHistory.last != aura) {
            auraHistory.add(aura);
            if (auraHistory.length > 8) {
              auraHistory = auraHistory.sublist(auraHistory.length - 8);
            }
          }
          tasks =
              tasksData.map((taskJson) => _Task.fromJson(taskJson)).toList();
          tasks =
              tasks
                  .where((task) => !task.name.trimLeft().startsWith('-'))
                  .toList();
        });
      }
    } catch (e) {
      print('Failed to fetch data from server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
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
    } catch (e) {
      print('Logout failed: $e');
    }
  }

  void _addTask() async {
    final taskNameController = TextEditingController();
    final durationController = TextEditingController();
    String selectedTaskCategory = 'normal'; // Default category

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return StatefulBuilder(
          // For managing local state of the modal
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
                    decoration: InputDecoration(
                      hintText: 'Enter task name',
                      labelText: 'Task Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (selectedTaskCategory == 'timed') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      decoration: InputDecoration(
                        hintText: 'Enter duration in minutes',
                        labelText: 'Duration (minutes)',
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
                              if (duration == null || duration <= 0)
                                return; // Basic validation
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
      final int? duration = result['duration']; // Will be null if not timed

      try {
        setState(() => isLoading = true);
        final newTaskData = await _apiService.createTask(
          name: name,
          taskCategory: category,
          durationMinutes: duration,
        );
        if (mounted) {
          setState(() {
            tasks.add(_Task.fromJson(newTaskData));
            isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add task: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteTask(int index) async {
    // ... (remains the same)
    final taskToDelete = tasks[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Task?'),
            content: Text(
              'Are you sure you want to delete "${taskToDelete.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text('Delete'),
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
            tasks.removeAt(index);
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
    final task = tasks[index];
    Map<String, dynamic>? apiCallResult;

    bool dialogWasShown = false;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      dialogWasShown = true;
    }

    try {
      if (task.type == "bad") {
        // Handle tasks explicitly marked or classified as 'bad'
        // Bad tasks (regardless of category 'normal' or 'timed') might have specific completion logic
        // If a timed task is 'bad', it uses completeTimedTask which handles negative aura.
        // If a normal task is 'bad', it uses completeBadTask.
        if (task.taskCategory == 'timed') {
          apiCallResult = await _apiService.completeTimedTask(task.id);
        } else {
          // Normal 'bad' task
          apiCallResult = await _apiService.completeBadTask(task.id);
        }
      } else {
        // Task type is "good"
        if (task.taskCategory == "timed") {
          apiCallResult = await _apiService.completeTimedTask(task.id);
        } else {
          // Normal "good" task
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
            // Normal, good, but not image verifiable
            apiCallResult = await _apiService.completeNormalNonVerifiableTask(
              task.id,
            );
          }
        }
      }

      if (apiCallResult != null) {
        if (mounted) {
          setState(() {
            aura = apiCallResult!['newAura'];
            if (auraHistory.isEmpty || auraHistory.last != aura) {
              auraHistory.add(aura);
              if (auraHistory.length > 8)
                auraHistory = auraHistory.sublist(auraHistory.length - 8);
            }
            tasks.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${apiCallResult['message']} Aura change: ${apiCallResult['auraChange']}',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
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
    }
  }

  Future<void> _markTaskAsBadClientSide(int index) async {
    // ... (remains the same)
    final task = tasks[index];
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
          // The API returns the full updated task, so we can re-parse it
          tasks[index] = _Task.fromJson(updatedTaskData);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        // ... (AppBar remains the same) ...
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
                        auraHistory: auraHistory,
                        completedTasks:
                            tasks
                                .where((t) => t.status == 'completed')
                                .toList(),
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
                  // ... (Header slivers remain the same) ...
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.ebGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
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
                          ), // Adjusted color
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
                      child: FilledButton.icon(
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
                    ),
                  ),
                  (tasks.where((t) => t.status == 'pending').toList().isEmpty)
                      ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DynamicColorSvg(
                                assetName: 'assets/img/empty_tasks.svg',
                                height: 180,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No active tasks.',
                                style: GoogleFonts.roboto(
                                  fontSize: 20,
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 4,
                            ),
                            child: GestureDetector(
                              onLongPress:
                                  () => _deleteTask(tasks.indexOf(task)),
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(18),
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                child: ListTile(
                                  onTap:
                                      () => _completeTask(tasks.indexOf(task)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  leading: _buildTaskIcon(
                                    task,
                                    context,
                                  ), // Updated leading icon
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
                                  subtitle: _buildTaskSubtitle(
                                    task,
                                    context,
                                  ), // Updated subtitle
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
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildTaskIcon(_Task task, BuildContext context) {
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
    // Normal, good task
    return _materialYouTaskIcon(task.intensity, context);
  }

  Widget _buildTaskSubtitle(_Task task, BuildContext context) {
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
      // Good task
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
        // Normal good task
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

        // Only show "Mark as Bad" for good, normal tasks that are not yet bad
        subtitleChildren.add(Spacer()); // Pushes the button to the right
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
    // ... (remains the same)
    switch (intensity) {
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
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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
