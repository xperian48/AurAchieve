import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';

class HabitsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Habits', style: GoogleFonts.lato())),
      body: Center(
        child: Text(
          'Your habits will be displayed here.',
          style: GoogleFonts.lato(fontSize: 20),
        ),
      ),
    );
  }
}
