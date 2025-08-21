import 'main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'screens/habit_setup.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HabitsPage extends StatefulWidget {
  final ApiService apiService;
  const HabitsPage({super.key, required this.apiService});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);
    try {
      final list = await widget.apiService.getHabits();
      final normalized = <Map<String, dynamic>>[];
      for (final h in list) {
        if (h is! Map) continue;
        final m = Map<String, dynamic>.from(h);
        final id = m[r'$id'] ?? m['id'] ?? m['habitId'];
        List<String>? localRem = [];
        if (id != null) {
          localRem = await widget.apiService.getHabitReminderLocal(id.toString());
        }
        if (localRem != null && localRem.isNotEmpty) {
          m['habitReminder'] = localRem;
        }
        m['completedTimes'] = m['completedTimes'] ?? 0;
        normalized.add(m);
      }
      if (mounted) setState(() => _habits = normalized);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load habits: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ShapeBorder _shapeForIndex(int i) {
    switch (i % 5) {
      case 0:
        return const StadiumBorder();
      case 1:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
      case 2:
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(36)),
        );
      case 3:
        return BeveledRectangleBorder(borderRadius: BorderRadius.circular(18));
      default:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(32),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(8),
            bottomRight: const Radius.circular(24),
          ),
        );
    }
  }

  Future<void> _incrementCompleted(String habitId, int index) async {
    try {
      final updated = await widget.apiService.incrementHabitCompletedTimes(
        habitId,
      );
      if (mounted) {
        setState(() {
          final ct =
              (updated['completedTimes'] ??
                      _habits[index]['completedTimes'] ??
                      0)
                  as int;
          _habits[index]['completedTimes'] = ct;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    final boxColor = scheme.secondaryContainer;
    final onBox = scheme.onSecondaryContainer;

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/img/habit.svg',
                        height: 160,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No habits yet',
                        style: GoogleFonts.gabarito(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _habits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final h = _habits[index];
                    final id = (h[r'$id'] ?? h['id'] ?? h['habitId'] ?? '').toString();
                    final name = (h['habitName'] ?? h['habit'] ?? '').toString();
                    final goal = (h['habitGoal'] ?? h['goal'] ?? '').toString();
                    final reminders = (h['habitReminder'] is List)
                        ? List<String>.from((h['habitReminder'] as List).map((e) => e.toString()))
                        : const <String>[];
                    final ct = (h['completedTimes'] ?? 0) as int;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Material(
                          color: boxColor,
                          shape: _shapeForIndex(index),
                          child: InkWell(
                            customBorder: _shapeForIndex(index),
                            onLongPress: id.isEmpty ? null : () => _incrementCompleted(id, index),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'I will',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.gabarito(
                                      fontSize: 14,
                                      color: onBox.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.gabarito(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: onBox,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'so that I can become a',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.gabarito(
                                      fontSize: 14,
                                      color: onBox.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    goal,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.gabarito(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (reminders.isNotEmpty)
                                        Chip(
                                          label: Text(
                                            reminders.join(' • '),
                                            style: GoogleFonts.gabarito(fontSize: 12),
                                          ),
                                        ),
                                      Chip(
                                        label: Text(
                                          'Done $ct',
                                          style: GoogleFonts.gabarito(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_habit_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HabitSetup(userName: 'You', apiService: widget.apiService),
            ),
          );
          if (result != null && mounted) {
            await _loadHabits();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Habit'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
