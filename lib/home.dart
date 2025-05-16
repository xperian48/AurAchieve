import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'stats.dart';

class HomePage extends StatefulWidget {
  final Account account;

  const HomePage({super.key, required this.account});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = 'User';
  bool isLoading = true;
  List<_Task> tasks = [];
  List<_Task> completedTasks = [];
  int aura = 50; // Default startup Aura is now 50
  String? apiKey;
  List<int> auraHistory = [];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadUserName();
    await _loadApiKey();
    await _loadTasksAndAura();
    await _loadCompletedTasks();
    await _loadAuraHistory();
    setState(() {
      isLoading = false;
    });
    if (apiKey == null) {
      _askForApiKey();
    }
  }

  Future<void> _loadUserName() async {
    try {
      final models.User user = await widget.account.get();
      setState(() {
        userName = user.name;
      });
    } catch (e) {
      print('Failed to load user: $e');
    }
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      apiKey = prefs.getString('gemini_api_key');
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      apiKey = key;
    });
  }

  Future<void> _askForApiKey() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Enter Gemini API Key'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Paste your Gemini API Key',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    _saveApiKey(controller.text.trim());
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveTasksAndAura() async {
    final prefs = await SharedPreferences.getInstance();
    final taskList = tasks.map((t) => jsonEncode(t.toJson())).toList();
    final completedList =
        completedTasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('tasks', taskList);
    await prefs.setStringList('completed_tasks', completedList);
    await prefs.setInt('aura', aura);
    await _saveAuraHistory();
  }

  Future<void> _loadTasksAndAura() async {
    final prefs = await SharedPreferences.getInstance();
    final taskList = prefs.getStringList('tasks') ?? [];
    setState(() {
      tasks = taskList.map((t) => _Task.fromJson(jsonDecode(t))).toList();
      aura = prefs.getInt('aura') ?? 50;
    });
  }

  Future<void> _loadCompletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final completedList = prefs.getStringList('completed_tasks') ?? [];
    setState(() {
      completedTasks =
          completedList.map((t) => _Task.fromJson(jsonDecode(t))).toList();
    });
  }

  Future<void> _saveAuraHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Only add if different from last or if it's a new day
    if (auraHistory.isEmpty || auraHistory.last != aura) {
      auraHistory.add(aura);
      if (auraHistory.length > 8) {
        auraHistory = auraHistory.sublist(auraHistory.length - 8);
      }
      await prefs.setStringList(
        'aura_history',
        auraHistory.map((e) => e.toString()).toList(),
      );
    }
  }

  Future<void> _loadAuraHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('aura_history') ?? [];
    setState(() {
      auraHistory = history.map((e) => int.tryParse(e) ?? 50).toList();
      if (auraHistory.isEmpty) auraHistory = [aura];
    });
  }

  Future<void> logout() async {
    try {
      await widget.account.deleteSession(sessionId: 'current');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      print('Logout failed: $e');
    }
  }

  void _addTask() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Task',
                  style: GoogleFonts.gabarito(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your task',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            () =>
                                Navigator.pop(context, controller.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    if (result != null && result.isNotEmpty) {
      final classification = await _classifyTaskWithGemini(result);
      if (classification != null) {
        setState(() {
          tasks.add(
            _Task(
              result,
              classification['intensity'] ?? '', // Ensure non-null String
              classification['type'] ?? '', // Ensure non-null String
            ),
          );
        });
        await _saveTasksAndAura();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not classify task. Please try again.')),
        );
      }
    }
  }

  Future<Map<String, String>?> _classifyTaskWithGemini(String task) async {
    final key = apiKey;
    if (key == null) return null;
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key';

    final prompt = '''
Classify the following task as "good" or "bad" (type), and as "easy", "medium", or "hard" (intensity). 
Reply in JSON: {"type":"good|bad","intensity":"easy|medium|hard"}.
Task: $task
''';

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      try {
        final json = jsonDecode(text);
        if (json is Map &&
            json.containsKey('type') &&
            json.containsKey('intensity')) {
          return {'type': json['type'], 'intensity': json['intensity']};
        }
      } catch (_) {}
    }
    return null;
  }

  void _removePrefixedTasks() async {
    setState(() {
      tasks =
          tasks.where((task) => !task.name.trimLeft().startsWith('-')).toList();
    });
    await _saveTasksAndAura();
  }

  Future<void> _deleteTask(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Task?'),
            content: Text(
              'Are you sure you want to delete "${tasks[index].name}"?',
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
      setState(() {
        tasks.removeAt(index);
      });
      await _saveTasksAndAura();
    }
  }

  Future<void> _completeTask(int index) async {
    final task = tasks[index];
    if (task.type == "bad") {
      setState(() {
        aura -= _getAuraForIntensity(task.intensity);
        completedTasks.add(tasks[index]);
        tasks.removeAt(index);
      });
      await _saveTasksAndAura();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bad task completed. Aura -${_getAuraForIntensity(task.intensity)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedFile == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    final isValid = await _verifyTaskWithGemini2Flash(
      File(pickedFile.path),
      tasks[index].name,
    );

    Navigator.pop(context); // Remove loading dialog

    if (isValid) {
      setState(() {
        aura += _getAuraForIntensity(tasks[index].intensity);
        completedTasks.add(tasks[index]);
        tasks.removeAt(index);
      });
      await _saveTasksAndAura();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task marked as complete! Aura +${_getAuraForIntensity(tasks[index].intensity)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gemini could not verify the task as complete.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  int _getAuraForIntensity(String intensity) {
    switch (intensity) {
      case 'easy':
        return 5;
      case 'medium':
        return 10;
      case 'hard':
        return 15;
      default:
        return 5;
    }
  }

  Future<bool> _verifyTaskWithGemini2Flash(File image, String task) async {
    final key = apiKey;
    if (key == null) return false;
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key';

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "text":
                  "Does this photo show that the following task is completed? Task: $task. Reply only with yes or no.",
            },
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString()
              .toLowerCase() ??
          '';
      return text.contains('yes');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _removePrefixedTasks();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                        tasks: tasks,
                        auraHistory: auraHistory,
                        completedTasks: completedTasks,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              print('settings');
            },
            tooltip: 'Settings',
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
                              color: Theme.of(context).colorScheme.secondary,
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
                  tasks.isEmpty
                      ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/img/empty_tasks.svg',
                                height: 180,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No tasks added yet.',
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
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 4,
                            ),
                            child: GestureDetector(
                              onLongPress: () => _deleteTask(index),
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(18),
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceVariant,
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  leading:
                                      task.type == "bad"
                                          ? CircleAvatar(
                                            backgroundColor:
                                                Colors.purple.shade100,
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.purple,
                                              size: 26,
                                            ),
                                          )
                                          : _materialYouTaskIcon(
                                            task.intensity,
                                            context,
                                          ),
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
                                  subtitle:
                                      task.type == "bad"
                                          ? Text(
                                            "Bad Task",
                                            style: GoogleFonts.gabarito(
                                              fontSize: 13,
                                              color: Colors.purple,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                          : Row(
                                            children: [
                                              Text(
                                                _capitalize(task.intensity),
                                                style: GoogleFonts.gabarito(
                                                  fontSize: 13,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  minimumSize: Size(0, 0),
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 0,
                                                  ),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                icon: Icon(
                                                  Icons.flag,
                                                  size: 16,
                                                  color: Colors.purple,
                                                ),
                                                label: Text(
                                                  "Mark as Bad",
                                                  style: GoogleFonts.gabarito(
                                                    fontSize: 12,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  setState(() {
                                                    tasks[index] = _Task(
                                                      task.name,
                                                      task.intensity,
                                                      "bad",
                                                    );
                                                  });
                                                  await _saveTasksAndAura();
                                                },
                                              ),
                                            ],
                                          ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.check_circle_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    tooltip: 'Mark as complete',
                                    onPressed: () => _completeTask(index),
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

  Widget _materialYouTaskIcon(String intensity, BuildContext context) {
    switch (intensity) {
      case 'easy':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.eco_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 26,
          ),
        );
      case 'medium':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.bolt_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 26,
          ),
        );
      case 'hard':
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.whatshot_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 26,
          ),
        );
      default:
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          child: Icon(
            Icons.task_alt_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 26,
          ),
        );
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Task {
  final String name;
  final String intensity;
  final String type; // "good" or "bad"
  _Task(this.name, this.intensity, this.type);

  Map<String, dynamic> toJson() => {
    'name': name,
    'intensity': intensity,
    'type': type,
  };

  static _Task fromJson(Map<String, dynamic> map) =>
      _Task(map['name'], map['intensity'], map['type']);
}
