import 'main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'screens/habit_setup.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

class HabitsPage extends StatefulWidget {
  final ApiService apiService;
  const HabitsPage({super.key, required this.apiService});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _updating = false;
  List<Map<String, dynamic>> _habits = [];

  AnimationController? _holdController;
  static const Duration _holdDuration = Duration(milliseconds: 700);
  int? _holdingIndex;

  Timer? _pressDelayTimer;
  Offset? _pressStartPosition;
  static const double _moveTolerance = 8.0;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: _holdDuration)
      ..addListener(() {
        if (mounted && _holdingIndex != null) {
          setState(() {}); // repaint fill
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _holdingIndex != null) {
          final idx = _holdingIndex!;
          final h = _habits[idx];
          final id = (h[r'$id'] ?? h['id'] ?? h['habitId'] ?? '').toString();
          if (id.isNotEmpty) {
            _incrementCompleted(id, idx);
          }
          _resetHold();
        }
      });
    _loadHabits();
  }

  @override
  void dispose() {
    _pressDelayTimer?.cancel();
    _holdController?.dispose();
    super.dispose();
  }

  void _resetHold() {
    _pressDelayTimer?.cancel();
    final c = _holdController;
    if (c != null) {
      c.stop();
      c.reset();
    }
    if (mounted) {
      setState(() => _holdingIndex = null);
    }
  }

  void _startHoldAnimation(int index) {
    final c = _holdController;
    if (c == null) return;
    setState(() => _holdingIndex = index);
    c.forward(from: 0);
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
        final localRem = id != null
            ? await widget.apiService.getHabitReminderLocal(id.toString())
            : null;
        if (localRem != null && localRem.isNotEmpty) {
          m['habitReminder'] = localRem;
        }
        m['completedTimes'] = m['completedTimes'] ?? 0;
        normalized.add(m);
      }
      if (mounted) setState(() => _habits = normalized);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load habits: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ShapeBorder _shapeForIndex(int i) {
    switch (i % 6) {
      case 0:
        return const StadiumBorder();
      case 1:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(40));
      case 2:
        return const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(56)),
        );
      case 3:
        return BeveledRectangleBorder(borderRadius: BorderRadius.circular(18));
      case 4:
        return RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(48),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(8),
          ),
        );
      default:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(32));
    }
  }

  ({Color bg, Color fg}) _colorsForIndex(int i, ColorScheme s) {
    switch (i % 5) {
      case 0:
        return (bg: s.secondaryContainer, fg: s.onSecondaryContainer);
      case 1:
        return (bg: s.primaryContainer, fg: s.onPrimaryContainer);
      case 2:
        return (bg: s.tertiaryContainer, fg: s.onTertiaryContainer);
      case 3:
        return (bg: s.surfaceContainerHighest, fg: s.onSurfaceVariant);
      default:
        return (bg: s.surfaceContainerHigh, fg: s.onSurface);
    }
  }

  Future<void> _incrementCompleted(String habitId, int index) async {
    if (_updating) return;
    _updating = true;
    try {
      final updated = await widget.apiService.incrementHabitCompletedTimes(
        habitId,
      );
      if (!mounted) return;
      setState(() {
        final ct =
            (updated['completedTimes'] ?? _habits[index]['completedTimes'] ?? 0)
                as int;
        _habits[index]['completedTimes'] = ct;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text('Progress +1'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      _updating = false;
    }
  }

  bool _hasReminderToday(List<String> reminders) {
    if (reminders.isEmpty) return false;
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = days[now.weekday - 1];
    return reminders.any(
      (r) => r.startsWith(today) || r.toLowerCase().startsWith('daily'),
    );
  }

  String? _todayReminderTime(List<String> reminders) {
    if (reminders.isEmpty) return null;
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = days[now.weekday - 1];
    for (final r in reminders) {
      if (r.startsWith(today)) {
        return r.replaceFirst('$today ', '');
      }
      if (r.toLowerCase().startsWith('daily')) {
        return r.replaceFirst(RegExp('[Dd]aily ?'), '');
      }
    }
    return null;
  }

  Widget _habitCard(Map<String, dynamic> h, int index, ColorScheme scheme) {
    final c = _holdController;
    final holding = _holdingIndex == index && c != null;
    final progress = holding ? c.value : 0.0;

    final id = (h[r'$id'] ?? h['id'] ?? h['habitId'] ?? '').toString();
    final name = (h['habitName'] ?? h['habit'] ?? '').toString();
    final goal = (h['habitGoal'] ?? h['goal'] ?? '').toString();
    final reminders = (h['habitReminder'] is List)
        ? List<String>.from(
            (h['habitReminder'] as List).map((e) => e.toString()),
          )
        : const <String>[];

    final colorPair = _colorsForIndex(index, scheme);
    final shape = _shapeForIndex(index);

    final showReminder = _hasReminderToday(reminders);
    final reminderTime = showReminder ? _todayReminderTime(reminders) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (id.isEmpty) return;
          _pressStartPosition = event.position;
          _pressDelayTimer?.cancel();
          _pressDelayTimer = Timer(const Duration(milliseconds: 50), () {
            if (_pressStartPosition != null && _holdingIndex == null) {
              _startHoldAnimation(index);
            }
          });
        },
        onPointerMove: (event) {
          if (_pressStartPosition == null) return;
          final moved = (event.position - _pressStartPosition!).distance;
          if (moved > _moveTolerance) {
            if (_holdingIndex != null) {
              _resetHold();
            } else {
              _pressDelayTimer?.cancel();
            }
          }
        },
        onPointerUp: (_) => _resetHold(),
        onPointerCancel: (_) => _resetHold(),
        child: AnimatedScale(
          scale: holding ? (1 - (progress * 0.04)) : 1.0,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: colorPair.bg,
            elevation: 3,
            shadowColor: scheme.shadow.withOpacity(0.25),
            shape: shape,
            child: Stack(
              children: [
                // Fill overlay (water rising)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: progress,
                      widthFactor: 1,
                      child: Container(color: colorPair.fg.withOpacity(0.10)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'I will',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gabarito(
                            fontSize: 14,
                            color: colorPair.fg.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.gabarito(
                            fontSize: 26,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            color: colorPair.fg,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'so that I can become a',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gabarito(
                            fontSize: 14,
                            color: colorPair.fg.withOpacity(0.72),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorPair.fg.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            goal,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.gabarito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorPair.fg,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (reminderTime != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorPair.fg.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              reminderTime,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.gabarito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorPair.fg,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Completed: ${h['completedTimes']}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gabarito(
                            fontSize: 11,
                            color: colorPair.fg.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // No AppBar (per earlier customization)
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/img/habit.svg',
                    height: 150,
                    colorFilter: ColorFilter.mode(
                      scheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No habits yet',
                    style: GoogleFonts.gabarito(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap Add Habit to begin',
                    style: GoogleFonts.gabarito(
                      fontSize: 14,
                      color: scheme.outline.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHabits,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 120),
                itemCount: _habits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 22),
                itemBuilder: (context, index) =>
                    _habitCard(_habits[index], index, scheme),
              ),
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
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }
}
