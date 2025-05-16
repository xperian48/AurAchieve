import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:google_fonts/google_fonts.dart';
import 'util.dart';
import 'theme.dart';
import 'onboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6800a2680008a268a6a3')
      .setSelfSigned(
        status: true,
      ); // For self signed certificates, only use for development;
  Account account = Account(client);
  runApp(MyApp(account: account));
}

class MyApp extends StatelessWidget {
  final Account account;

  const MyApp({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: MaterialTheme(const TextTheme()).light(),
      home: AuthCheck(account: account),
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final user = await widget.account.get();
      setState(() {
        loggedInUser = user;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loggedInUser != null) {
      return OnBoard(account: widget.account); // Pass account to OnBoard
    }

    return LoginScreen(account: widget.account);
  }
}

class LoginScreen extends StatefulWidget {
  final Account account;

  const LoginScreen({super.key, required this.account});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  Future<void> login(String email, String password) async {
    try {
      await widget.account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OnBoard(account: widget.account),
        ), // Pass account to OnBoard
      );
    } catch (e) {
      print('Login failed: $e');
    }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      await widget.account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      await login(email, password);
    } catch (e) {
      print('Registration failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            children: <Widget>[
              SvgPicture.asset('assets/img/login.svg', height: 300.0),
            ],
          ),
          Text(
            "Let's begin your journey.",
            style: TextStyle(
              fontSize: 24.0,
              fontFamily: GoogleFonts.ebGaramond().fontFamily,
            ),
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'Name'),
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  login(emailController.text, passwordController.text);
                },
                child: Text('Login'),
              ),
              SizedBox(width: 16.0),
              ElevatedButton(
                onPressed: () {
                  register(
                    emailController.text,
                    passwordController.text,
                    nameController.text,
                  );
                },
                child: Text('Register'),
              ),
              SizedBox(width: 16.0),
            ],
          ),
        ],
      ),
    );
  }
}
