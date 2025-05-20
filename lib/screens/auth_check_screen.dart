import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../home.dart';
import './onboarding_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  final Account account;
  const AuthCheckScreen({super.key, required this.account});

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
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
      if (mounted) {
        setState(() {
          loggedInUser = user;
          isLoading = false;
        });
      }
    } catch (e) {
      await _storage.delete(key: 'jwt_token');
      if (mounted) {
        setState(() {
          isLoading = false;
          loggedInUser = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (loggedInUser != null) {
      return HomePage(account: widget.account);
    }
    return AuraOnboarding(account: widget.account);
  }
}
