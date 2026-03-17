import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../utils/theme.dart';
import 'login_screen.dart';
import '../resident/resident_home.dart'; // Import to redirect when approved

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  StreamSubscription<DatabaseEvent>? _statusListener;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _listenForApproval();
  }

  // 1. The Listener: Watches for 'approved' status in real-time
  void _listenForApproval() {
    final user = _auth.currentUser;
    if (user != null) {
      final statusRef = FirebaseDatabase.instance.ref("users/${user.uid}/status");
      
      _statusListener = statusRef.onValue.listen((event) {
        final status = event.snapshot.value as String?;
        
        // If status changes to 'approved' AND the screen is still visible
        if (status == 'approved' && mounted) {
           // Stop listening so we don't crash the next screen
           _statusListener?.cancel(); 
           
           // Go to Home
           Navigator.pushReplacement(
             context, 
             MaterialPageRoute(builder: (_) => const ResidentHome())
           );
        }
      });
    }
  }

  // 2. THE CRASH FIX: Cleanup when closing the screen
  @override
  void dispose() {
    _statusListener?.cancel(); // Stop listening to the database
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_filled, size: 60, color: Colors.orange),
              ),
              
              const SizedBox(height: 30),
              
              const Text(
                "Account Under Review", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                "Your registration is currently being processed by the Barangay Captain. \n\nYou will be automatically redirected here once approved.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 16),
              ),
              
              const SizedBox(height: 50),
              
              // Loading Indicator to show it's active
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 20),
              const Text("Waiting for approval...", style: TextStyle(color: Colors.grey, fontSize: 12)),

              const Spacer(),

              // LOGOUT BUTTON (Safe Logout)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Log Out"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.black87
                  ),
                  onPressed: () async {
                    // Cancel listener first to prevent crash
                    await _statusListener?.cancel();
                    await _auth.signOut();
                    
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}