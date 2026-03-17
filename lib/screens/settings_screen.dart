import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  String _originalEmail = "";
  bool _isLoading = false;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  // --- 1. LOAD DATA ---
  Future<void> _loadCurrentData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check Provider (Google vs Password)
    // If 'google.com' is in the list, they are a Google user.
    _isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');

    // Load Email from Auth (Most accurate)
    _emailCtrl.text = user.email ?? "";
    _originalEmail = user.email ?? "";

    // Load Phone/Address from DB
    String? path = await _findUserPath(user.uid);
    if (path != null) {
      final snapshot = await _dbRef.child(path).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if(mounted) {
          setState(() {
            _phoneCtrl.text = data['phone'] ?? "";
            _addressCtrl.text = data['address'] ?? "";
          });
        }
      }
    }
  }

  // --- 2. MAIN UPDATE ACTION ---
  Future<void> _handleSave() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if Email Changed
    final newEmail = _emailCtrl.text.trim();
    final isEmailChanged = newEmail != _originalEmail;

    if (isEmailChanged) {
      if (_isGoogleUser) {
        // CASE A: Google User -> CANNOT change email here.
        _showSnack("You are signed in with Google. Please change your email in your Google Account settings.", Colors.orange);
        setState(() => _emailCtrl.text = _originalEmail); // Revert change
      } else {
        // CASE B: Password User -> Must confirm password.
        _showPasswordConfirmDialog();
      }
    } else {
      // Only Profile changed (Phone/Address) -> Save directly
      _updateProfileData();
    }
  }

  // --- 3. SHOW PASSWORD DIALOG (For Email Change) ---
  void _showPasswordConfirmDialog() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Security Check"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("To change your email, please enter your current password."),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _updateEmailAndProfile(passCtrl.text.trim()); // Proceed
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // --- 4. EXECUTE EMAIL UPDATE (Sensitive) ---
  Future<void> _updateEmailAndProfile(String password) async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;

    if (user == null || password.isEmpty) {
      setState(() => _isLoading = false);
      _showSnack("Password required", Colors.red);
      return;
    }

    try {
      // Step A: Re-authenticate User
      // Critical: Verifies it's actually them before changing sensitive info
      AuthCredential credential = EmailAuthProvider.credential(
        email: _originalEmail, 
        password: password
      );
      
      await user.reauthenticateWithCredential(credential);

      // Step B: Update Auth Email DIRECTLY
      // This changes the login email immediately.
      await user.updateEmail(_emailCtrl.text.trim()); 
      
      // Step C: Send Verification (Optional but good practice)
      if (!user.emailVerified) {
        try {
           await user.sendEmailVerification();
        } catch (_) {} // Ignore if this fails, main update worked
      }

      // Step D: Update Database Profile AND Email field
      await _updateProfileData(emailChanged: true, showSuccess: false); 

      if (mounted) {
        _showSnack("Success! Email updated. Please verify your new address.", Colors.green);
        Navigator.pop(context, true);
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Error: ${e.message}";
      
      // SPECIFIC ERROR HANDLING
      if (e.code == 'operation-not-allowed') {
        msg = "Critical: 'Email/Password' login is disabled in Firebase Console.";
      } else if (e.code == 'wrong-password') {
        msg = "Incorrect password.";
      } else if (e.code == 'email-already-in-use') {
        msg = "This email is already taken by another account.";
      } else if (e.code == 'requires-recent-login') {
        msg = "For security, please logout and login again.";
      }
      
      debugPrint("Firebase Error: ${e.code}"); 
      _showSnack(msg, Colors.red);
      
    } catch (e) {
      _showSnack("An error occurred: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 5. EXECUTE DATA UPDATE (Non-Sensitive) ---
  Future<void> _updateProfileData({bool showSuccess = true, bool emailChanged = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    if (showSuccess) setState(() => _isLoading = true);

    try {
      String? path = await _findUserPath(user.uid);
      
      // Data to update
      Map<String, Object> updates = {
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      };
      
      // If email changed, we sync it to the database too
      if (emailChanged) {
        updates['email'] = _emailCtrl.text.trim();
      }

      if (path != null) {
        await _dbRef.child(path).update(updates);
        if (showSuccess && mounted) {
           _showSnack("Profile Updated!", Colors.green);
           Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showSnack("Failed to save profile. Check Database Rules.", Colors.red);
      debugPrint("DB Error: $e");
    } finally {
      if (showSuccess && mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _findUserPath(String uid) async {
    final roles = ['users/residents', 'users/barangay_captain', 'users/response_team', 'users'];
    for (String p in roles) {
      final snap = await _dbRef.child('$p/$uid').get();
      if (snap.exists) return '$p/$uid';
    }
    return null;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Account Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Update your personal details below.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            // EMAIL INPUT
            TextField(
              controller: _emailCtrl,
              enabled: !_isGoogleUser, // DISABLE if Google User
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _isGoogleUser ? Colors.grey[200] : Colors.white,
                helperText: _isGoogleUser 
                  ? "Signed in via Google. Cannot change email." 
                  : "Changing this requires your password.",
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // PHONE INPUT
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: "Phone Number",
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // ADDRESS INPUT
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: "Current Address",
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}