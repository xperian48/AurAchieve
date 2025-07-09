import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math';

import 'widgets/dynamic_color_svg.dart';
import 'api_service.dart';

class Subject {
  String name;
  IconData icon;
  Color color;

  Subject({required this.name, required this.icon, required this.color});

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon_code_point': icon.codePoint,
    'icon_font_family': icon.fontFamily,
    'icon_font_package': icon.fontPackage,
    'color_value': color.value,
  };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      name: json['name'],
      icon: IconData(
        json['icon_code_point'],
        fontFamily: json['icon_font_family'],
        fontPackage: json['icon_font_package'],
      ),

      color: Color(json['color_value'] ?? Colors.blue.value),
    );
  }
}

class StudyPlannerScreen extends StatefulWidget {
  final Function(bool) onSetupStateChanged;
  final ApiService apiService;

  const StudyPlannerScreen({
    super.key,
    required this.onSetupStateChanged,
    required this.apiService,
  });

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSetupComplete = false;
  bool _isLoading = true;
  bool _isGenerating = false;

  List<Subject> _subjects = [];
  Map<String, List<Map<String, String>>> _chapters = {};
  DateTime? _deadline;
  List<Map<String, dynamic>> _generatedTimetable = [];

  final TextEditingController _subjectController = TextEditingController();
  IconData _currentSubjectIcon = Icons.subject;
  bool _showFullSchedule = false;

  static final List<Color> _subjectColors = [
    Colors.green[200]!,
    Colors.purple[200]!,
    Colors.blue[200]!,
    Colors.red[200]!,
    Colors.orange[200]!,
    Colors.teal[200]!,
    Colors.pink[100]!,
    Colors.amber[200]!,
    Colors.indigo[100]!,
    Colors.cyan[200]!,
  ];

  static const Map<String, IconData> _subjectIconMapping = {
    'math': Icons.calculate,
    'physic': Icons.rocket_launch_outlined,
    'chem': Icons.science_outlined,
    'bio': Icons.biotech_outlined,
    'hist': Icons.history_edu_outlined,
    'geo': Icons.public_outlined,
    'eng': Icons.translate_outlined,
    'lang': Icons.translate_outlined,
    'comp': Icons.computer_outlined,
    'code': Icons.code,
    'art': Icons.palette_outlined,
    'music': Icons.music_note_outlined,
    'sport': Icons.sports_soccer_outlined,
    'pe': Icons.fitness_center,
    'eco': Icons.account_balance_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadTimetableData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  IconData _getIconForSubject(String subjectName) {
    final lowerCaseName = subjectName.toLowerCase();
    for (var key in _subjectIconMapping.keys) {
      if (lowerCaseName.contains(key)) {
        return _subjectIconMapping[key]!;
      }
    }
    return Icons.subject;
  }

  Future<void> _loadTimetableData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSetupComplete = prefs.getBool('studyPlannerSetupComplete') ?? false;
      if (_isSetupComplete) {
        final subjectsJson = prefs.getStringList('studyPlannerSubjects') ?? [];
        _subjects =
            subjectsJson.map((s) => Subject.fromJson(json.decode(s))).toList();

        final chaptersJson = prefs.getString('studyPlannerChapters');
        if (chaptersJson != null) {
          _chapters = (json.decode(chaptersJson) as Map<String, dynamic>).map(
            (key, value) => MapEntry(
              key,
              (value as List)
                  .map((item) => Map<String, String>.from(item))
                  .toList(),
            ),
          );
        }
        final deadlineString = prefs.getString('studyPlannerDeadline');
        if (deadlineString != null) {
          _deadline = DateTime.tryParse(deadlineString);
        }

        final timetableJson = prefs.getString('studyPlannerData');
        if (timetableJson != null) {
          final decoded = json.decode(timetableJson) as List;
          _generatedTimetable =
              decoded
                  .map(
                    (e) => {
                      'date': DateTime.parse(e['date']),
                      'tasks':
                          (e['tasks'] as List)
                              .map((t) => Map<String, dynamic>.from(t))
                              .toList(),
                    },
                  )
                  .toList();
        }
      }
      _isLoading = false;
    });
    widget.onSetupStateChanged(_isSetupComplete);
  }

  Future<void> _saveAndFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('studyPlannerSetupComplete', true);
    final subjectsJson = _subjects.map((s) => json.encode(s.toJson())).toList();
    await prefs.setStringList('studyPlannerSubjects', subjectsJson);
    await prefs.setString('studyPlannerChapters', json.encode(_chapters));
    if (_deadline != null) {
      await prefs.setString(
        'studyPlannerDeadline',
        _deadline!.toIso8601String(),
      );
    }

    final timetableToSave =
        _generatedTimetable
            .map(
              (day) => {
                'date': (day['date'] as DateTime).toIso8601String(),
                'tasks': day['tasks'],
              },
            )
            .toList();
    await prefs.setString('studyPlannerData', json.encode(timetableToSave));

    await _loadTimetableData();

    setState(() {
      _isSetupComplete = true;
    });
    widget.onSetupStateChanged(true);
  }

  Future<void> _resetTimetable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Study Plan?'),
            content: const Text(
              'Are you sure you want to delete your current study plan and start over? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('studyPlannerSetupComplete');
      await prefs.remove('studyPlannerSubjects');
      await prefs.remove('studyPlannerChapters');
      await prefs.remove('studyPlannerDeadline');
      await prefs.remove('studyPlannerData');

      setState(() {
        _isSetupComplete = false;
        _subjects.clear();
        _chapters.clear();
        _deadline = null;
        _generatedTimetable.clear();
        _currentPage = 0;
      });
      widget.onSetupStateChanged(false);
    }
  }

  void _addSubject() {
    final subjectName = _subjectController.text.trim();
    if (subjectName.isNotEmpty &&
        !_subjects.any((s) => s.name == subjectName)) {
      setState(() {
        final color = _subjectColors[_subjects.length % _subjectColors.length];
        _subjects.add(
          Subject(name: subjectName, icon: _currentSubjectIcon, color: color),
        );
        _chapters[subjectName] = [];
        _subjectController.clear();
        _currentSubjectIcon = Icons.subject;
      });
    }
  }

  void _removeSubject(Subject subject) {
    setState(() {
      _subjects.remove(subject);
      _chapters.remove(subject.name);
    });
  }

  void _changeSubjectIcon(Subject subject) async {
    final newIcon = await showDialog<IconData>(
      context: context,
      builder: (context) => SubjectIconPickerDialog(initialIcon: subject.icon),
    );
    if (newIcon != null) {
      setState(() {
        subject.icon = newIcon;
      });
    }
  }

  void _showChapterPicker(String subject) async {
    final selectedNumbers = await showDialog<Set<int>>(
      context: context,
      builder: (context) => const ChapterPickerDialog(),
    );

    if (selectedNumbers != null && selectedNumbers.isNotEmpty) {
      setState(() {
        for (var number in selectedNumbers) {
          if (!_chapters[subject]!.any(
            (chap) => chap['number'] == number.toString(),
          )) {
            _chapters[subject]!.add({'number': number.toString(), 'title': ''});
          }
        }

        _chapters[subject]!.sort(
          (a, b) => int.parse(a['number']!).compareTo(int.parse(b['number']!)),
        );
      });
    }
  }

  void _editChapterTitle(String subject, String chapterNumber) {
    final titleController = TextEditingController(
      text:
          _chapters[subject]?.firstWhere(
            (chap) => chap['number'] == chapterNumber,
          )['title'],
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Title for Ch. $chapterNumber'),
            content: TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Chapter Title (Optional)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    final chapterIndex = _chapters[subject]!.indexWhere(
                      (chap) => chap['number'] == chapterNumber,
                    );
                    if (chapterIndex != -1) {
                      _chapters[subject]![chapterIndex]['title'] =
                          titleController.text.trim();
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  List<int> _parseChapterNumbers(String input) {
    final Set<int> numbers = {};
    final parts = input
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    for (final part in parts) {
      if (part.contains('-')) {
        final range = part.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0]);
          final end = int.tryParse(range[1]);
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              numbers.add(i);
            }
          }
        }
      } else {
        final number = int.tryParse(part);
        if (number != null) {
          numbers.add(number);
        }
      }
    }
    return numbers.toList()..sort();
  }

  Future<void> _generateTimetable() async {
    setState(() {
      _isGenerating = true;
    });

    _generatedTimetable.clear();
    final allChaptersForApi = <Map<String, String>>[];
    _chapters.forEach((subject, chaps) {
      for (var chap in chaps) {
        allChaptersForApi.add({
          'subject': subject,
          'chapterNumber': chap['number']!,
        });
      }
    });

    if (allChaptersForApi.isEmpty || _deadline == null) {
      setState(() {
        _isGenerating = false;
      });
      return;
    }

    try {
      final List<dynamic> apiResponse = await widget.apiService
          .generateTimetable(chapters: allChaptersForApi, deadline: _deadline!);

      final newTimetable =
          apiResponse.map((dayData) {
            final date = DateTime.parse(dayData['date']);
            final tasks =
                (dayData['tasks'] as List<dynamic>).map((taskData) {
                  return {
                    'type': taskData['type'],
                    'content': taskData['content'],
                  };
                }).toList();
            return {'date': date, 'tasks': tasks};
          }).toList();

      setState(() {
        _generatedTimetable = newTimetable;
      });
    } catch (e) {
      print('Error generating study plan from API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate study plan: $e')),
        );
      }
      setState(() {
        _generatedTimetable = [];
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  bool _isNextEnabled() {
    if (_currentPage == 1 && _subjects.isEmpty) return false;
    if (_currentPage == 2 &&
        _chapters.values.fold<int>(0, (sum, item) => sum + item.length) < 2) {
      return false;
    }
    if (_currentPage == 3 && _deadline == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _isSetupComplete ? _buildTimetableView() : _buildOnboardingView();
  }

  Widget _buildOnboardingView() {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildIntroPage(
                'assets/img/timetable.svg',
                "Welcome to Study Planner",
                "If you're a student who needs to study and remember books, this is for you.",
              ),
              _buildSubjectsPage(),
              _buildChaptersPage(),
              _buildDeadlinePage(),
              _buildFinalPage(),
              _buildPreviewPage(),
            ],
          ),
        ),
        _buildNavigationControls(),
      ],
    );
  }

  Widget _buildTimetableView() {
    final today = DateUtils.dateOnly(DateTime.now());
    final todaySchedule = _generatedTimetable.firstWhere(
      (d) => DateUtils.isSameDay(d['date'], today),
      orElse: () => <String, Object>{'tasks': <dynamic>[]},
    );
    final futureSchedule =
        _generatedTimetable
            .where((d) => (d['date'] as DateTime).isAfter(today))
            .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            "Today's Plan",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if ((todaySchedule['tasks'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("Nothing scheduled for today. Take a break!"),
            )
          else
            ...?(todaySchedule['tasks'] as List?)?.map(
              (task) => _buildTaskTile(task),
            ),
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text("See ahead of time"),
            onExpansionChanged: (isExpanded) {
              setState(() => _showFullSchedule = isExpanded);
            },
            children: [
              if (!_showFullSchedule)
                const Center(child: Text("Expand to see future schedule."))
              else
                ...futureSchedule.map((day) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          DateFormat('EEEE, MMM d').format(day['date']),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...(day['tasks'] as List).map(
                        (task) => _buildTaskTile(task),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _resetTimetable,
        label: const Text('Reset'),
        icon: const Icon(Icons.refresh),
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> item) {
    IconData icon;
    Widget title;
    Widget? subtitle;
    Widget? trailing;
    Color avatarColor;

    switch (item['type']) {
      case 'study':
        final content = item['content'] as Map<String, dynamic>;
        final subject = _subjects.firstWhere(
          (s) => s.name == content['subject'],

          orElse:
              () => Subject(
                name: 'Unknown',
                icon: Icons.help,
                color: Colors.grey,
              ),
        );

        final chapterNumber = content['chapterNumber'] as String?;

        final chapterTitle = content['title'] as String? ?? '';

        icon = subject.icon;
        avatarColor = subject.color;
        title = Text(
          chapterTitle.isNotEmpty ? chapterTitle : "Chapter $chapterNumber",
          style: const TextStyle(fontWeight: FontWeight.w500),
        );
        subtitle = Text(subject.name);
        if (chapterTitle.isNotEmpty) {
          trailing = Text(
            "Ch. $chapterNumber",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        break;
      case 'revision':
        final content = item['content'] as Map<String, dynamic>;
        final subject = _subjects.firstWhere(
          (s) => s.name == content['subject'],

          orElse:
              () => Subject(
                name: 'Unknown',
                icon: Icons.help,
                color: Colors.grey,
              ),
        );

        final chapterNumber = content['chapterNumber'] as String?;

        icon = Icons.history_outlined;

        avatarColor = subject.color.withOpacity(0.7);
        title = Text("Revise: Chapter $chapterNumber");
        subtitle = Text(subject.name);
        break;
      default:
        icon = Icons.self_improvement_outlined;
        avatarColor = Theme.of(context).colorScheme.tertiaryContainer;
        title = const Text("Break Day");
        subtitle = const Text("Relax and recharge!");
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed:
                _currentPage == 0
                    ? null
                    : () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    ),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed:
                !_isNextEnabled()
                    ? null
                    : () {
                      if (_currentPage == 4) {
                        _generateTimetable();
                      }
                      if (_currentPage == 5) {
                        _saveAndFinish();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                      }
                    },
            child: Text(_currentPage == 5 ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPage(String asset, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DynamicColorSvg(
            assetName: asset,
            height: 180,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter your subjects",
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add subjects and pick an icon for each. We'll try to guess an icon for you!",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _currentSubjectIcon = _getIconForSubject(value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: _addSubject,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return Card(
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(subject.icon),
                      onPressed: () => _changeSubjectIcon(subject),
                      tooltip: "Change Icon",
                    ),
                    title: Text(subject.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeSubject(subject),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Now, enter your chapters for each subject!",
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select multiple chapter numbers at once, then tap a chapter to add an optional title.",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                final chapterList = _chapters[subject.name] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: Icon(subject.icon),
                    title: Text(subject.name),
                    subtitle: Text("${chapterList.length} chapters"),
                    children: [
                      ...chapterList.map(
                        (chap) => ListTile(
                          title: Text("Ch. ${chap['number']}"),
                          subtitle:
                              chap['title']!.isNotEmpty
                                  ? Text(chap['title']!)
                                  : const Text(
                                    'Tap to add title',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                          dense: true,
                          onTap:
                              () => _editChapterTitle(
                                subject.name,
                                chap['number']!,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text("Select Chapters"),
                          onPressed: () => _showChapterPicker(subject.name),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlinePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Enter your deadline",
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This could be the beginning of your exams or a date before which you want to prepare everything!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _deadline == null
                ? 'No date selected'
                : DateFormat.yMMMd().format(_deadline!),
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: const Text("Select Date"),
            onPressed: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate:
                    _deadline ?? DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (pickedDate != null) {
                setState(() {
                  _deadline = pickedDate;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage() {
    return _buildIntroPage(
      'assets/img/ai_robot.svg',
      "We'll prepare a study plan for you",
      "Based on the information you provided, we'll generate a study plan for you with the power of AI. You get aura for following the plan and lose it otherwise.",
    );
  }

  Widget _buildPreviewPage() {
    if (_isGenerating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Generating your custom schedule..."),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Here's Your Plan",
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This is a preview of the generated schedule. You can go back to make changes.",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _generatedTimetable.isEmpty
                    ? const Center(
                      child: Text(
                        "Could not generate study plan. Check deadline and chapters.",
                      ),
                    )
                    : ListView.builder(
                      itemCount: _generatedTimetable.length,
                      itemBuilder: (context, index) {
                        final day = _generatedTimetable[index];
                        final date = day['date'] as DateTime;
                        final tasks = day['tasks'] as List;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, MMM d').format(date),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const Divider(),
                                ...tasks.map((task) {
                                  final content =
                                      task['content'] as Map<String, dynamic>;
                                  String title;
                                  IconData icon;

                                  switch (task['type']) {
                                    case 'study':
                                      title =
                                          "Study ${content['subject']} - Ch. ${content['chapterNumber']}";
                                      icon = Icons.book_outlined;
                                      break;
                                    case 'revision':
                                      title =
                                          "Revise ${content['subject']} - Ch. ${content['chapterNumber']}";
                                      icon = Icons.history_edu_outlined;
                                      break;
                                    default:
                                      title = "Break Day";
                                      icon = Icons.self_improvement_outlined;
                                  }

                                  return ListTile(
                                    leading: Icon(icon),
                                    title: Text(title),
                                    dense: true,
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class SubjectIconPickerDialog extends StatelessWidget {
  final IconData initialIcon;
  const SubjectIconPickerDialog({super.key, required this.initialIcon});

  static const List<IconData> _icons = [
    Icons.subject,
    Icons.calculate,
    Icons.science_outlined,
    Icons.biotech_outlined,
    Icons.rocket_launch_outlined,
    Icons.history_edu_outlined,
    Icons.public_outlined,
    Icons.translate_outlined,
    Icons.computer_outlined,
    Icons.code,
    Icons.palette_outlined,
    Icons.music_note_outlined,
    Icons.sports_soccer_outlined,
    Icons.fitness_center,
    Icons.account_balance_outlined,
    Icons.book_outlined,
    Icons.edit_outlined,
    Icons.architecture_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose an Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final icon = _icons[index];
            return InkWell(
              onTap: () => Navigator.pop(context, icon),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        initialIcon == icon
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                    width: initialIcon == icon ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 32),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class ChapterPickerDialog extends StatefulWidget {
  const ChapterPickerDialog({super.key});

  @override
  State<ChapterPickerDialog> createState() => _ChapterPickerDialogState();
}

class _ChapterPickerDialogState extends State<ChapterPickerDialog> {
  final PageController _pageController = PageController();
  final Set<int> _selectedChapters = {};
  int _currentPage = 0;

  final int _totalPages = 6;
  final int _chaptersPerPage = 15;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Chapters'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, pageIndex) {
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _chaptersPerPage,
                    itemBuilder: (context, gridIndex) {
                      final chapterNumber =
                          pageIndex * _chaptersPerPage + gridIndex + 1;
                      final isSelected = _selectedChapters.contains(
                        chapterNumber,
                      );
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedChapters.remove(chapterNumber);
                            } else {
                              _selectedChapters.add(chapterNumber);
                            }
                          });
                        },

                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                      context,
                                    ).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: Text(
                              '$chapterNumber',
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimary
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed:
                      _currentPage == 0
                          ? null
                          : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeIn,
                          ),
                ),
                Text('Page ${_currentPage + 1} of $_totalPages'),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed:
                      _currentPage >= _totalPages - 1
                          ? null
                          : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeIn,
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedChapters),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
