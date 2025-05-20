import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'home.dart' show Task;

class TimerPage extends StatefulWidget {
  final Task task;
  final ApiService apiService;
  final VoidCallback onTaskCompleted;

  const TimerPage({
    super.key,
    required this.task,
    required this.apiService,
    required this.onTaskCompleted,
  });

  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with TickerProviderStateMixin {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;

  late int _targetDurationSeconds;

  @override
  void initState() {
    super.initState();
    _targetDurationSeconds = (widget.task.durationMinutes ?? 0) * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _startTimer() {
    if (_isRunning && !_isPaused) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds >= _targetDurationSeconds) {}
        });
      }
    });
  }

  void _pauseTimer() {
    if (_isRunning && !_isPaused) {
      setState(() {
        _isPaused = true;
      });
    }
  }

  void _resumeTimer() {
    if (_isRunning && _isPaused) {
      setState(() {
        _isPaused = false;
      });
    }
  }

  Future<void> _endTask() async {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final actualDurationSpentMinutes = (_elapsedSeconds / 60).ceil();

      final result = await widget.apiService.completeTimedTask(
        widget.task.id,
        actualDurationSpentMinutes: actualDurationSpentMinutes,
      );

      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['message'] ?? 'Task ended.'} Aura change: ${result['auraChange'] ?? 0}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onTaskCompleted();
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end task: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.name, style: GoogleFonts.gabarito()),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Target: ${_formatDuration(_targetDurationSeconds)}',
                style: GoogleFonts.gabarito(
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _formatDuration(_elapsedSeconds),
                style: GoogleFonts.orbitron(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_isRunning || _isPaused)
                    ElevatedButton.icon(
                      icon: Icon(
                        _isRunning
                            ? Icons.play_arrow_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isRunning ? 'Resume' : 'Start'),
                      onPressed: _isRunning ? _resumeTimer : _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: GoogleFonts.gabarito(fontSize: 16),
                      ),
                    ),
                  if (_isRunning && !_isPaused)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause'),
                      onPressed: _pauseTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: GoogleFonts.gabarito(fontSize: 16),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop_rounded),
                label: const Text('End Task & Save'),
                onPressed:
                    (_elapsedSeconds > 0 || !_isRunning) ? _endTask : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: GoogleFonts.gabarito(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
