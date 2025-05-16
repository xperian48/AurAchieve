import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'home.dart';

class OnBoard extends StatelessWidget {
  final Account account; // Accept the Appwrite Account object

  const OnBoard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
          children: [
            // Empty Spacer at the top
            SizedBox(height: 20),

            // SVG in the middle
            SvgPicture.asset(
              'assets/img/welcome.svg', // Ensure you have this asset in your project
              height: 300,
            ),

            // Text column at the bottom
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Welcome to AuraAscend',
                  style: GoogleFonts.ebGaramond(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Prepare to live a better life.',
                  style: GoogleFonts.roboto(fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to HomePage and pass the Account object
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(account: account),
                      ),
                    );
                  },
                  child: Text('Get Started'),
                ),
                SizedBox(height: 12), // Add some padding at the bottom
              ],
            ),
          ],
        ),
      ),
    );
  }
}
