import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

class HomePage extends StatefulWidget {
  final Account account;

  const HomePage({
    super.key,
    required this.account,
  }); // Accept the Appwrite Account object

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = 'User'; // Default name while loading
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final models.User user =
          await widget.account.get(); // Fetch user details from Appwrite
      setState(() {
        userName = user.name; // Set the user's name
        isLoading = false; // Stop loading
      });
    } catch (e) {
      print('Failed to load user: $e');
      setState(() {
        isLoading = false; // Stop loading even if there's an error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AuraAscend',
          style: GoogleFonts.gabarito(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings), // Add a settings icon
            onPressed: () {
              print('settings'); // Print "settings" to the console
            },
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child:
                    CircularProgressIndicator(), // Show a spinner while loading
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ), // Add padding at the top
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.ebGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // Default color for "Hi,"
                        ),
                        children: [
                          TextSpan(text: 'Good Afternoon, '),
                          TextSpan(
                            text: userName,
                            style: TextStyle(
                              color: Color(
                                0xFF4CAF50,
                              ), // Light green color for the user's name
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Your Aura: 977'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      print('hi baby');
                    },
                    child: Text('Sign Out'),
                  ),
                  ListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      ListTile(
                        title: Text('Profile'),
                        onTap: () {
                          print('Profile tapped');
                        },
                      ),
                      ListTile(
                        title: Text('Settings'),
                        onTap: () {
                          print('Settings tapped');
                        },
                      ),
                      ListTile(
                        title: Text('Logout'),
                        onTap: () {
                          print('Logout tapped');
                        },
                      ),
                    ],
                  ),
                ],
              ),
    );
  }
}
