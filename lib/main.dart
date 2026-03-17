import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/captain_dashboard.dart';
import 'screens/responder/responder_home.dart';
import 'screens/resident/resident_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:camera/camera.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_screen.dart';
import 'utils/theme.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBuSq8Us328QBpV3dQk5OkII4I5h0zZYWw",
      appId: "1:298335903283:android:4aed266d9e902885b74d46",
      messagingSenderId: "298335903283",
      projectId: "fire-4881b",
      storageBucket: "fire-4881b.firebasestorage.app",

      databaseURL: "https://fire-4881b-default-rtdb.firebaseio.com/",
    ),
  );

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing camera: $e');
  }

  await Supabase.initialize(
    url: 'https://ptgxqezqawepjaxbqgsx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0Z3hxZXpxYXdlcGpheGJxZ3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyNTg2MjcsImV4cCI6MjA3MzgzNDYyN30.QRGrptqfLc1ezkSSBCSNAAJxmqXOEDCqDds_xKIDgOE',
  );

  runApp(const RSCApp());
}

class RSCApp extends StatelessWidget {
  const RSCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSC Mobile',
      debugShowCheckedModeBanner: false,
      
      // 3. Global Theme (Matching your CSS)
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.poppinsTextTheme(), // Use Poppins or Roboto
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          secondary: AppColors.accent,
        ),
        useMaterial3: true,
      ),
      
      // 4. The Entry Point
      home: const AuthWrapper(),
    );
  }
}

/// The Traffic Cop: Decides which screen to show on launch
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // A. Waiting for connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // B. User is NOT logged in
        if (!snapshot.hasData) {
          return LoginScreen();
        }

        // C. User IS logged in - Fetch Role & Status
        return FutureBuilder<DataSnapshot>(
          future: FirebaseDatabase.instance
              .ref("users/${snapshot.data!.uid}")
              .get(),
          builder: (context, dbSnapshot) {
            if (dbSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text("Verifying Access..."),
                    ],
                  ),
                ),
              );
            }

            if (dbSnapshot.hasData && dbSnapshot.data!.value != null) {
              final data = dbSnapshot.data!.value as Map;
              final String role = data['role'] ?? 'resident';
              final String status = data['status'] ?? 'pending';

              // Logic copied from your session.js
              if (status == 'pending') {
                return PendingScreen();
              }
              
              switch (role) {
                case 'captain':
                  return const CaptainDashboard(); // To be built
                case 'responder':
                  return const ResponderHome();    // To be built
                default:
                  return const ResidentHome(); // To be built
              }
            }
            
            // Fallback if data is missing (or user deleted from DB but Auth exists)
            return LoginScreen();
          },
        );
      },
    );
  }
}
