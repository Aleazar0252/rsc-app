import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// --- UTILS & SCREENS ---
import '../../utils/theme.dart';
import 'register_screen.dart';
import 'pending_screen.dart';
import 'forgot_password_screen.dart';

// --- DASHBOARDS ---
import '../captain_dashboard.dart'; // Admin
import '../responder/responder_home.dart'; // Responder
import '../resident/resident_home.dart'; // Resident WRAPPER (Fixed!)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = false;
  bool _isObscure = true;

  // ---------------------------------------------------------
  // LOGIN LOGIC (UPDATED FOR NEW SCHEMA)
  // ---------------------------------------------------------
  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter your email and password.");
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Authenticate with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // 2. CHECK EMAIL VERIFICATION (The Security Check)
      if (!userCredential.user!.emailVerified) {
        _showError(
          "Please check your email and click the verification link before logging in.",
        );
        await _auth.signOut(); // Log them back out
        setState(() => _isLoading = false);
        return;
      }

      final uid = userCredential.user!.uid;

      // 3. Fetch User Routing Data (NEW SCHEMA)
      final snapshot = await _dbRef.child('users/$uid').get();

      if (!snapshot.exists) {
        throw "User record missing in database. Please contact support.";
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      // 4. Extract Role & Status
      final String role = data['role'] ?? 'resident';
      final String status = data['status'] ?? 'pending';

      if (!mounted) return;

      // 5. Status Check (Optional: Admins might still be pending approval)
      if (status == 'pending_admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingScreen()),
        );
        return;
      } else if (status == 'rejected') {
        _showError("Account rejected. Contact support.");
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // 6. ROLE-BASED REDIRECTION
      Widget destination;

      switch (role) {
        case 'captain':
        case 'official':
          destination = const CaptainDashboard();
          break;

        case 'response_team':
        case 'responder':
          destination = const ResponderHome();
          break;

        case 'resident':
        default:
          // FIXED: Now navigating to ResidentHome to keep the Navigation Bar
          destination = const ResidentHome();
          break;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = "Login Failed";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = "Incorrect email or password.";
      }
      if (e.code == 'wrong-password') message = "Incorrect email or password.";
      if (e.code == 'invalid-email') message = "Invalid email format.";
      if (e.code == 'too-many-requests') {
        message = "Too many attempts. Try again later.";
      }
      _showError(message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ---------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.4, 0.4],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "RSC",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  "Ready to Serve the Community",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),

                Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Welcome Back",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sign in to continue",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildModernInput(
                          controller: _emailController,
                          hint: "Email Address",
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 20),

                        _buildModernInput(
                          controller: _passwordController,
                          hint: "Password",
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SIGN IN",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        "Create Account",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _isObscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
