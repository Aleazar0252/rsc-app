import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// --- UTILS & SCREENS ---
import '../../utils/theme.dart';
import 'login_screen.dart'; // Redirect here after registration

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- KEYS FOR VALIDATION ---
  final _nameKey = GlobalKey<FormFieldState>();
  final _usernameKey = GlobalKey<FormFieldState>();
  final _phoneKey = GlobalKey<FormFieldState>();
  final _addressKey = GlobalKey<FormFieldState>();
  final _emailKey = GlobalKey<FormFieldState>();
  final _passKey = GlobalKey<FormFieldState>();

  int _currentStep = 0; 
  bool _isLoading = false;
  bool _isObscure = true;

  // --- CONTROLLERS ---
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _selectedAddress;

  final List<String> _addresses = [
    "Bacalan", "Bangkerohan", "Buluan", "Caparan", "Domandan",
    "Don Andres", "Doña Josefa", "Guituan", "Ipil Heights", "Labe",
    "Logan", "Tirso Babiera (Lower Ipil Heights)", "Lower Taway",
    "Lumbia", "Maasin", "Magdaup", "Makilas", "Pangi", "Poblacion",
    "Sanito", "Suclema", "Taway", "Tenan", "Tiayon", "Timalang",
    "Tomitom", "Upper Pangi", "Veteran's Village"
  ];

  // ---------------------------------------------------------
  // STEP 1: MOVE TO STEP 2
  // ---------------------------------------------------------
  void _nextStep() {
    if (!_nameKey.currentState!.validate()) return;
    if (!_usernameKey.currentState!.validate()) return;
    if (!_addressKey.currentState!.validate()) return;
    if (!_phoneKey.currentState!.validate()) return;

    setState(() => _currentStep = 1);
  }

  // ---------------------------------------------------------
  // STEP 2: REGISTER & SEND EMAIL VERIFICATION
  // ---------------------------------------------------------
  Future<void> _register() async {
    if (!_emailKey.currentState!.validate()) return;
    if (!_passKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create User with Email & Password
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = userCred.user;
      if (user != null) {
        // 2. Send Verification Email
        await user.sendEmailVerification();
        await user.updateDisplayName(_nameCtrl.text.trim());

        final uid = user.uid;

        // 3. Write to 'users' node (Lightweight Auth Data)
        DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$uid");
        await userRef.set({
          "role": "resident",
          // CHANGED: Instantly verified. No captain approval needed.
          "status": "verified", 
          "trust_level": 80, // Full app privileges granted immediately
          "createdAt": ServerValue.timestamp,
        });

        // 4. Write to 'profiles' node (Detailed Data)
        DatabaseReference profileRef = FirebaseDatabase.instance.ref("profiles/$uid");
        await profileRef.set({
          "fullname": _nameCtrl.text.trim(),
          "username": _usernameCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(), 
          "email": _emailCtrl.text.trim(),
          "address": _selectedAddress,
          "verified_address": {
            // CHANGED: Automatically considered verified
            "is_verified": true 
          }
        });

        // 5. Success! Show message and redirect to Login
        if (mounted) {
          _showSuccess("Account created! Please check your email to verify your account.");
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Registration failed.");
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green, duration: const Duration(seconds: 4)));
  }

  void _goToStep(int step) {
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    }
  }

  // ---------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8), Colors.white],
            stops: const [0.0, 0.3, 0.3], 
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepDot(0),
                  Container(width: 40, height: 2, color: Colors.white30),
                  _buildStepDot(1),
                ],
              ),
              const SizedBox(height: 20),
              
              const Text("Resident Registration", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(_currentStep == 0 ? "Step 1: Personal Details" : "Step 2: Account Security", 
                style: const TextStyle(color: Colors.white70)),
              
              const SizedBox(height: 30),

              Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentStep == 0 ? _buildProfileStep() : _buildAccountStep(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ", style: TextStyle(color: Colors.grey[600])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text("Sign In", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 1 LAYOUT: DETAILS ---
  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Tell us about yourself", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 16)),
        const SizedBox(height: 20),

        _buildInput(
          fieldKey: _nameKey,
          controller: _nameCtrl, 
          hint: "Full Name", 
          icon: Icons.person_outline,
          validator: (val) => (val == null || val.length < 3) ? "Please enter your full name" : null
        ),
        const SizedBox(height: 16),
        
        _buildInput(
          fieldKey: _usernameKey,
          controller: _usernameCtrl, 
          hint: "Username (for community posts)", 
          icon: Icons.alternate_email,
          validator: (val) => (val == null || val.length < 4) ? "Username must be at least 4 chars" : null
        ),
        const SizedBox(height: 16),

        _buildDropdown(
          fieldKey: _addressKey,
          hint: "Select Barangay Area",
          icon: Icons.location_on_outlined,
          value: _selectedAddress,
          items: _addresses,
          onChanged: (val) => setState(() => _selectedAddress = val),
          validator: (val) => val == null ? "Address is required" : null
        ),
        const SizedBox(height: 16),
        
        _buildInput(
          fieldKey: _phoneKey,
          controller: _phoneCtrl, 
          hint: "Phone (e.g. 09123456789)", 
          icon: Icons.phone_android, 
          isPhone: true,
          validator: (val) {
            if (val == null || val.isEmpty) return "Phone number is required";
            if (val.length != 11) return "Must be 11 digits";
            if (!val.startsWith('09')) return "Must start with 09";
            return null;
          }
        ),
        
        const SizedBox(height: 30),

        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _nextStep, 
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Next Step", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2 LAYOUT: EMAIL & PASSWORD ---
  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Secure your account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 16)),
        const SizedBox(height: 20),

        _buildInput(
          fieldKey: _emailKey,
          controller: _emailCtrl, 
          hint: "Email Address", 
          icon: Icons.email_outlined,
          validator: (val) {
            if (val == null || val.isEmpty) return "Email is required";
            if (!val.contains('@') || !val.contains('.')) return "Enter a valid email";
            return null;
          }
        ),
        const SizedBox(height: 16),

        _buildInput(
          fieldKey: _passKey,
          controller: _passCtrl, 
          hint: "Password", 
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (val) => (val == null || val.length < 6) ? "Password must be at least 6 characters" : null
        ),

        const SizedBox(height: 30),

        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _register,
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("COMPLETE REGISTRATION", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot(int stepIndex) {
    bool isActive = _currentStep >= stepIndex;
    return GestureDetector(
      onTap: () => _goToStep(stepIndex),
      child: Container(
        width: 35, height: 35,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text("${stepIndex + 1}", style: TextStyle(color: isActive ? AppColors.primary : Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- REUSABLE INPUT ---
  Widget _buildInput({
    required GlobalKey<FormFieldState> fieldKey, 
    required TextEditingController controller, 
    required String hint, 
    required IconData icon, 
    bool isPhone = false,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: TextFormField(
        key: fieldKey, 
        controller: controller,
        obscureText: isPassword && _isObscure,
        keyboardType: isPhone ? TextInputType.phone : (isPassword ? TextInputType.visiblePassword : TextInputType.text),
        autovalidateMode: AutovalidateMode.onUserInteraction, 
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ) 
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(height: 0.8),
        ),
      ),
    );
  }

  // --- REUSABLE DROPDOWN ---
  Widget _buildDropdown({
    required GlobalKey<FormFieldState> fieldKey, 
    required String hint, 
    required IconData icon, 
    required String? value, 
    required List<String> items, 
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonFormField<String>(
        key: fieldKey, 
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(prefixIcon: Icon(icon, color: Colors.grey[500], size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        hint: Text(hint, style: TextStyle(color: Colors.grey[400])),
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}