import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler;
import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';

import 'theme.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6800a2680008a268a6a3')
      .setSelfSigned(status: true);
  Account account = Account(client);
  runApp(MyApp(account: account));
}

class MyApp extends StatelessWidget {
  final Account account;
  const MyApp({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme =
            lightDynamic ??
            MaterialTheme(GoogleFonts.gabaritoTextTheme()).light().colorScheme;
        final darkColorScheme =
            darkDynamic ??
            MaterialTheme(GoogleFonts.gabaritoTextTheme()).dark().colorScheme;
        return MaterialApp(
          theme: ThemeData(
            colorScheme: lightColorScheme,
            textTheme: GoogleFonts.gabaritoTextTheme(),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            textTheme: GoogleFonts.gabaritoTextTheme(),
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: AuthCheck(account: account),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  final Account account;
  const AuthCheck({super.key, required this.account});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool isLoading = true;
  models.User? loggedInUser;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLoginStatusAndFetchToken();
  }

  Future<void> _checkLoginStatusAndFetchToken() async {
    try {
      final user = await widget.account.get();
      try {
        final jwt = await widget.account.createJWT();
        await _storage.write(key: 'jwt_token', value: jwt.jwt);
      } catch (e) {
        print("Failed to create JWT: $e");
        await _storage.delete(key: 'jwt_token');
      }
      setState(() {
        loggedInUser = user;
        isLoading = false;
      });
    } catch (e) {
      await _storage.delete(key: 'jwt_token');
      setState(() {
        isLoading = false;
        loggedInUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (loggedInUser != null) {
      return HomePage(account: widget.account);
    }
    return AuraOnboarding(account: widget.account);
  }
}

class AuraOnboarding extends StatefulWidget {
  final Account account;
  const AuraOnboarding({super.key, required this.account});

  @override
  State<AuraOnboarding> createState() => _AuraOnboardingState();
}

class DynamicColorSvg extends StatelessWidget {
  const DynamicColorSvg({
    super.key,
    required this.assetName,
    required this.color,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetName;
  final Color color;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(assetName),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        String svgStringToShow;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return SizedBox(width: width, height: height);
        }

        if (snapshot.hasError) {
          print('Error loading SVG $assetName: ${snapshot.error}');
          svgStringToShow =
              '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>';
        } else {
          svgStringToShow =
              snapshot.data ??
              '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>';
        }

        final String r = color.red.toRadixString(16).padLeft(2, '0');
        final String g = color.green.toRadixString(16).padLeft(2, '0');
        final String b = color.blue.toRadixString(16).padLeft(2, '0');
        final String colorHex = '#$r$g$b'.toUpperCase();

        final RegExp currentColorRegExp = RegExp(
          r'currentColor',
          caseSensitive: false,
        );
        String finalSvgString = svgStringToShow.replaceAll(
          currentColorRegExp,
          colorHex,
        );

        return SvgPicture.string(
          finalSvgString,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }
}

class _AuraOnboardingState extends State<AuraOnboarding> {
  final PageController _featureController = PageController();
  int _featurePage = 0;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  bool showSignup = false;
  bool showLogin = false;
  bool isBusy = false;
  String error = '';
  bool stopCarousel = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    Future.microtask(_autoPlayFeatures);
  }

  void _autoPlayFeatures() async {
    const int featureCount = 3;
    while (mounted && !stopCarousel) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || stopCarousel) break;
      int next = (_featurePage + 1) % featureCount;
      if (_featureController.hasClients) {
        _featureController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    setState(() => error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  Future<void> _handleSuccessfulAuth() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final bool permissionsExplained =
        prefs.getBool('permissions_explained_v1') ?? false;

    if (!permissionsExplained) {
      if (Platform.isAndroid) {
        await _showUsageStatsExplanationDialog();
        await _showBackgroundAccessExplanationDialog();
      }
      await prefs.setBool('permissions_explained_v1', true);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(account: widget.account),
        ),
      );
    }
  }

  Future<void> _showUsageStatsExplanationDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            "Usage Data Access",
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
          content: Text(
            "To track social media usage and help you manage your Aura, AuraAscend needs access to your app usage data. This data is processed locally on your device and is essential for the core functionality.",
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.primary,
              ),
              child: const Text("Later"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
              ),
              child: const Text("Grant Permission"),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (Platform.isAndroid) {
                  const AndroidIntent intent = AndroidIntent(
                    action: 'android.settings.USAGE_ACCESS_SETTINGS',
                  );
                  try {
                    await intent.launch();
                  } catch (e) {
                    print("Error launching usage access settings: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Could not open settings. Please enable manually via Android Settings > Apps > Special app access > Usage access.",
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _showBackgroundAccessExplanationDialog() async {
    if (!mounted || !Platform.isAndroid) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            "Background Activity",
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
          content: Text(
            "For AuraAscend to accurately monitor social media usage and send reminders when not actively open, please allow it to run in the background by disabling battery optimizations. Don't worry - it's pretty light on the battery!",
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.primary,
              ),
              child: const Text("Later"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
              ),
              child: const Text("Adjust Settings"),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await perm_handler.Permission.ignoreBatteryOptimizations
                    .request();
              },
            ),
          ],
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _showBackgroundAccessExplanationBottomSheet() async {
    if (!mounted || !Platform.isAndroid) return;

    bool granted =
        await perm_handler.Permission.ignoreBatteryOptimizations.isGranted;
    while (!granted) {
      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext dialogContext) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.battery_alert_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 16),
                Text(
                  "Background Activity Required",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "To accurately monitor social media usage and send reminders, AuraAscend needs to run in the background. Please disable battery optimizations for this app.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text("Allow Background Access"),
                  onPressed: () async {
                    await perm_handler.Permission.ignoreBatteryOptimizations
                        .request();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
      granted =
          await perm_handler.Permission.ignoreBatteryOptimizations.isGranted;
    }
  }

  Future<void> register() async {
    if (!mounted) return;
    setState(() => isBusy = true);
    try {
      await widget.account.create(
        userId: ID.unique(),
        email: emailController.text.trim(),
        password: passwordController.text,
        name: nameController.text.trim(),
      );

      await widget.account.createEmailPasswordSession(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final jwt = await widget.account.createJWT();
      await _storage.write(key: 'jwt_token', value: jwt.jwt);
      await _handleSuccessfulAuth();
    } catch (e) {
      showError(
        'Registration failed: ${e.toString().replaceAll('AppwriteException: ', '')}',
      );
    }
    if (mounted) {
      setState(() => isBusy = false);
    }
  }

  Future<void> login() async {
    if (!mounted) return;
    setState(() => isBusy = true);
    try {
      await widget.account.createEmailPasswordSession(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final jwt = await widget.account.createJWT();
      await _storage.write(key: 'jwt_token', value: jwt.jwt);
      await _handleSuccessfulAuth();
    } catch (e) {
      showError(
        'Login failed: ${e.toString().replaceAll('AppwriteException: ', '')}',
      );
    }
    if (mounted) {
      setState(() => isBusy = false);
    }
  }

  Widget _authHeader({required bool isSignup}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: DynamicColorSvg(
              assetName: 'assets/img/welcome.svg',
              color: Theme.of(context).colorScheme.primary,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 24),
          Text(
            isSignup ? 'Welcome Aboard!' : 'Welcome Back!',
            style: GoogleFonts.ebGaramond(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            isSignup ? 'Let\'s get you started.' : 'Continue your journey.',
            style: GoogleFonts.roboto(
              fontSize: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _featuresCarousel() {
    final features = [
      {
        'svg': 'assets/img/welcome.svg',
        'title': 'Welcome to AuraAscend',
        'desc': 'Prepare to live a better life.',
      },
      {
        'svg': 'assets/img/feature1.svg',
        'title': 'Aura Points',
        'desc': 'Earn and track your Aura as you complete tasks.',
      },
      {
        'svg': 'assets/img/feature2.svg',
        'title': 'AI Powered',
        'desc': 'Let AI verify your progress and help you grow.',
      },
    ];

    return Expanded(
      child: Stack(
        children: [
          PageView.builder(
            controller: _featureController,
            itemCount: features.length,
            onPageChanged: (i) => setState(() => _featurePage = i),
            itemBuilder:
                (context, i) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 16.0,
                        ),
                        child: DynamicColorSvg(
                          assetName: features[i]['svg']!,
                          color: Theme.of(context).colorScheme.primary,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          Text(
                            features[i]['title']!,
                            style: GoogleFonts.ebGaramond(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Text(
                            features[i]['desc']!,
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 48),
                  ],
                ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(features.length, (idx) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: _featurePage == idx ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _featurePage == idx
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signupForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: emailController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.email_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),
          TextField(
            controller: passwordController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            obscureText: true,
          ),
          SizedBox(height: 24),
          FilledButton.icon(
            icon: Icon(Icons.person_add_alt_1_rounded),
            onPressed: isBusy ? null : register,
            label:
                isBusy
                    ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      'Sign Up',
                      style: GoogleFonts.gabarito(fontSize: 18),
                    ),
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed:
                () => setState(() {
                  showSignup = false;
                  stopCarousel = false;
                  Future.microtask(_autoPlayFeatures);
                }),
            child: Text('Back', style: GoogleFonts.gabarito()),
          ),
        ],
      ),
    );
  }

  Widget _loginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          TextField(
            controller: emailController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.email_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),
          TextField(
            controller: passwordController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            obscureText: true,
          ),
          SizedBox(height: 24),
          FilledButton.icon(
            icon: Icon(Icons.login_rounded),
            onPressed: isBusy ? null : login,
            label:
                isBusy
                    ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text('Login', style: GoogleFonts.gabarito(fontSize: 18)),
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed:
                () => setState(() {
                  showLogin = false;
                  stopCarousel = false;
                  Future.microtask(_autoPlayFeatures);
                }),
            child: Text('Back', style: GoogleFonts.gabarito()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showForm = showSignup || showLogin;
            final formWidget =
                showSignup
                    ? _signupForm()
                    : showLogin
                    ? _loginForm()
                    : null;

            Widget currentScreen;
            if (!showForm) {
              currentScreen = Column(
                key: ValueKey('carousel'),
                children: [
                  Expanded(child: _featuresCarousel()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          icon: Icon(Icons.rocket_launch_rounded),
                          onPressed:
                              () => setState(() {
                                showSignup = true;
                                stopCarousel = true;
                              }),
                          label: Text(
                            'Get Started',
                            style: GoogleFonts.gabarito(fontSize: 18),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: Icon(Icons.login_rounded),
                          onPressed:
                              () => setState(() {
                                showLogin = true;
                                stopCarousel = true;
                              }),
                          label: Text(
                            'Login',
                            style: GoogleFonts.gabarito(fontSize: 18),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              currentScreen = SingleChildScrollView(
                key: ValueKey('form'),
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom + 16
                          : 16.0,
                  top: 16.0,
                ),
                child: Column(
                  children: [
                    _authHeader(isSignup: showSignup),
                    formWidget ?? SizedBox.shrink(),
                  ],
                ),
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: currentScreen,
            );
          },
        ),
      ),
    );
  }
}
