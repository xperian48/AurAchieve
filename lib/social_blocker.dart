import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../widgets/dynamic_color_svg.dart';

class SocialMediaBlockerScreen extends StatefulWidget {
  final ApiService apiService;
  const SocialMediaBlockerScreen({super.key, required this.apiService});

  @override
  State<SocialMediaBlockerScreen> createState() =>
      _SocialMediaBlockerScreenState();
}

class _SocialMediaBlockerScreenState extends State<SocialMediaBlockerScreen> {
  final PageController _pageController = PageController();
  late ConfettiController _confettiController;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSetupComplete = false;
  bool _isChallengeFinished = false;
  bool _isTimeUp = false;
  bool _isCompleting = false;

  String? _generatedPassword;
  String? _finishedPassword;
  DateTime? _timeoutDate;
  DateTime? _setupDate;
  int? _blockerDays;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    _loadBlockerState();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockerState() async {
    print("SOCIAL_BLOCKER: Checking blocker status...");
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final isFinished = prefs.getBool('sm_blocker_is_finished') ?? false;

    if (isFinished) {
      print("SOCIAL_BLOCKER: Challenge is already finished. Showing result.");
      if (mounted) {
        setState(() {
          _finishedPassword = prefs.getString('sm_blocker_finished_password');
          _isChallengeFinished = true;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await widget.apiService.getSocialBlockerData();

      // Case 1: Blocker is already set up on the server.
      if (data != null &&
          data.containsKey('socialEnd') &&
          data.containsKey('socialStart')) {
        print(
          "SOCIAL_BLOCKER: Existing setup found. Displaying progress view.",
        );
        _timeoutDate = DateTime.parse(data['socialEnd']);
        _setupDate = DateTime.parse(data['socialStart']);
        _generatedPassword = data['socialPassword'];

        if (mounted) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          setState(() {
            _isSetupComplete = true;
            // Compare date parts only. Time is up if today is *after* the timeout date.
            _isTimeUp = today.isAfter(_timeoutDate!);
            _isLoading = false;
          });
        }

        // If time is up, automatically call the completion logic.
        // The server will handle not giving the reward twice.
        if (_isTimeUp) {
          print("SOCIAL_BLOCKER: Time is up. Completing challenge...");
          await _completeBlocker();
        }
      }
      // Case 2: No blocker is set up (API returned 404 or empty data).
      else {
        print("SOCIAL_BLOCKER: No setup found. Displaying onboarding view.");
        if (mounted) {
          setState(() {
            _isSetupComplete = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("SOCIAL_BLOCKER: Error loading blocker state: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load blocker data: $e')),
        );
        setState(() {
          _isSetupComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeBlocker() async {
    // Prevent multiple calls
    if (_isCompleting || _isChallengeFinished) return;

    print("SOCIAL_BLOCKER: Completing challenge...");
    setState(() => _isCompleting = true);

    try {
      final result = await widget.apiService.completeSocialBlocker();
      final auraGained = result['aura'] ?? 0;
      final finishedPassword = result['socialPassword'] as String?;

      if (finishedPassword == null) {
        throw Exception("Password not received from server on completion.");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sm_blocker_is_finished', true);
      await prefs.setString('sm_blocker_finished_password', finishedPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations! You have gained $auraGained aura.'),
            backgroundColor: Colors.green,
          ),
        );
        _confettiController.play();
        // Set all final states at once to trigger switch to the finished view
        setState(() {
          _isChallengeFinished = true;
          _finishedPassword = finishedPassword;
          _isCompleting = false; // Turn off spinner
        });
      }
    } catch (e) {
      print("SOCIAL_BLOCKER: Error completing challenge: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing challenge: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Ensure spinner is turned off on failure
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _setupBlocker() async {
    print("SOCIAL_BLOCKER: _setupBlocker function has been called.");
    if (_blockerDays == null || _generatedPassword == null) {
      print("SOCIAL_BLOCKER: Aborting setup, days or password is null.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.setupSocialBlocker(
        socialEndDays: _blockerDays!,
        socialPassword: _generatedPassword!,
      );

      // No longer need to save to SharedPreferences.
      final setupTime = DateTime.now();
      // Set local dates for immediate UI update to progress view
      final timeoutDate = setupTime.add(Duration(days: _blockerDays!));

      setState(() {
        _isSetupComplete = true;
        _isTimeUp = false;
        _setupDate = setupTime;
        _timeoutDate = timeoutDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to setup blocker: $e')));
    }
  }

  Future<void> _showRestartDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restart Challenge?'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Please copy your current password before restarting. It will be permanently replaced with a new one and cannot be recovered.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text('Restart Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetBlocker();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetBlocker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sm_blocker_is_finished');
    await prefs.remove('sm_blocker_finished_password');

    setState(() {
      _isSetupComplete = false;
      _isChallengeFinished = false;
      _isTimeUp = false;
      _generatedPassword = null;
      _finishedPassword = null;
      _timeoutDate = null;
      _setupDate = null;
      _blockerDays = null;
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    setState(() {
      _generatedPassword = String.fromCharCodes(
        Iterable.generate(
          14,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_isChallengeFinished) {
      return _buildFinishedView();
    }
    return _isSetupComplete ? _buildProgressView() : _buildOnboardingView();
  }

  Widget _buildOnboardingView() {
    final features = [
      {
        'svg': 'assets/img/social.svg',
        'title': 'Welcome to Social Media Blocker!',
        'desc':
            'This effective social media blocker allows you to remain consistent with your work.',
      },
      {
        'svg': 'assets/img/password.svg',
        'title': 'We\'ll give you a new password',
        'desc':
            'You have to change the password of your social media accounts to what we give and log out.',
      },
      {
        'svg': 'assets/img/timeout.svg',
        'title': 'You\'ll set a timeout',
        'desc':
            "You'll let us know how many days you want to stay away from social media. We'll give you aura and your password after these days are over.",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup Blocker"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          _buildFeaturePage(
            features[0]['svg']!,
            features[0]['title']!,
            features[0]['desc']!,
          ),
          _buildFeaturePage(
            features[1]['svg']!,
            features[1]['title']!,
            features[1]['desc']!,
          ),
          _buildFeaturePage(
            features[2]['svg']!,
            features[2]['title']!,
            features[2]['desc']!,
          ),
          _buildDurationPickerPage(),
          _buildPasswordPage(),
        ],
      ),
      bottomNavigationBar: _buildNavigationControls(),
    );
  }

  Widget _buildFeaturePage(String asset, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: DynamicColorSvg(
              assetName: asset,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            flex: 1,
            child: Column(
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPickerPage() {
    int auraGain = (_blockerDays ?? 0) * 15;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Set a duration',
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'For how many days do you want to block social media?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (value) {
              setState(() {
                _blockerDays = int.tryParse(value);
              });
            },
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: GoogleFonts.gabarito(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: '7',
              border: UnderlineInputBorder(),
              suffixText: 'days',
            ),
          ),
          const SizedBox(height: 24),
          if ((_blockerDays ?? 0) > 0)
            Text(
              'Approximate aura gain: $auraGain',
              style: GoogleFonts.gabarito(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordPage() {
    if (_generatedPassword == null) {
      _generatePassword();
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.password_rounded, size: 64),
          const SizedBox(height: 24),
          Text(
            'Here\'s your password',
            style: GoogleFonts.gabarito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Change your social media password to this and log out. Once your timeout ends, we'll show you the password again.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _generatedPassword ?? '',
              style: GoogleFonts.sourceCodePro(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Password'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedPassword!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password copied to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentPage > 0
              ? TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
                child: const Text('Back'),
              )
              : const SizedBox(width: 60), // Placeholder for alignment
          FilledButton(
            onPressed: () {
              if (_currentPage == 3 &&
                  (_blockerDays == null || _blockerDays! <= 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of days.'),
                  ),
                );
                return;
              }
              if (_currentPage < 4) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              } else {
                // This is the only place _setupBlocker() is called from the UI
                _setupBlocker();
              }
            },
            child: Text(_currentPage < 4 ? 'Next' : 'Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    double progress = 0.0;
    String timeRemaining = "Time's up!";

    if (!_isTimeUp && _setupDate != null && _timeoutDate != null) {
      final totalDuration = _timeoutDate!.difference(_setupDate!).inSeconds;
      if (totalDuration > 0) {
        final elapsedDuration =
            DateTime.now().difference(_setupDate!).inSeconds;
        progress = (elapsedDuration / totalDuration).clamp(0.0, 1.0);
      }

      final remaining = _timeoutDate!.difference(DateTime.now());
      if (remaining.isNegative) {
        timeRemaining = "Time's up!";
      } else {
        final d = remaining.inDays;
        final h = remaining.inHours % 24;
        final m = remaining.inMinutes % 60;
        timeRemaining = '${d}d ${h}h ${m}m remaining';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Social Media Lock")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child:
              _isTimeUp
                  ? _buildCongratulationsView()
                  : _buildInProgressView(progress, timeRemaining),
        ),
      ),
    );
  }

  Widget _buildInProgressView(double progress, String timeRemaining) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              Center(
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.gabarito(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(timeRemaining, style: GoogleFonts.gabarito(fontSize: 22)),
      ],
    );
  }

  Widget _buildCongratulationsView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.celebration_rounded, size: 64, color: Colors.amber),
        const SizedBox(height: 24),
        Text(
          "Congratulations!",
          style: GoogleFonts.gabarito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "You've completed the challenge. Here is your password:",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (_isCompleting)
          const CircularProgressIndicator()
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    _generatedPassword ?? "...",
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Password'),
                    onPressed:
                        _generatedPassword == null
                            ? null
                            : () {
                              Clipboard.setData(
                                ClipboardData(text: _generatedPassword!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password copied!'),
                                ),
                              );
                            },
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Challenge'),
          onPressed: _showRestartDialog,
        ),
      ],
    );
  }

  Widget _buildFinishedView() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("Challenge Complete!")),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    size: 64,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Congratulations!",
                    style: GoogleFonts.gabarito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You've completed the challenge. Here is your password:",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            _finishedPassword ?? "Error: No password found.",
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Password'),
                            onPressed:
                                _finishedPassword == null
                                    ? null
                                    : () {
                                      Clipboard.setData(
                                        ClipboardData(text: _finishedPassword!),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Password copied!'),
                                        ),
                                      );
                                    },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Start New Challenge'),
                    onPressed: _showRestartDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
          ],
        ),
      ],
    );
  }
}
