import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart'; // Uses your app theme

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showSnack("Please enter a valid email address", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      
      if (mounted) {
        _showSnack("Reset link sent! Check your email.", Colors.green);
        // Optional: Go back to login automatically after success
        Future.delayed(const Duration(seconds: 2), () {
          if(mounted) Navigator.pop(context);
        });
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Error sending email", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Matches Login Screen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- 1. HEADER (Matches Login Style) ---
                const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),
                const SizedBox(height: 10),
                const Text("Account Recovery", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Text("Reset your password securely", style: TextStyle(color: Colors.grey)),
                
                const SizedBox(height: 40),

                // --- 2. CARD SECTION ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Forgot Password?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter the email address associated with your account and we'll send you a link to reset your password.",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "Enter your email",
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Colors.grey[100], // Matches Login Input Color
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Send Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Send Reset Link", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- 3. BACK TO LOGIN ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Remember your password?"),
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      child: const Text("Sign In", style: TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}