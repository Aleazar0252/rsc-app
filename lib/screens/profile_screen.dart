import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../screens/auth/login_screen.dart'; 
import 'settings_screen.dart'; // Settings screen restored!
import '../../utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- CLOUDINARY CONFIG ---
  final String cloudName = "dupggv8dt"; 
  final String uploadPreset = "profiles"; 

  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  bool _isUploading = false;
  
  String _name = "Loading...";
  String _email = "Loading...";
  String _phone = "No phone";
  String _role = "resident"; 
  String _address = "Fetching location...";
  String? _profileUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. LOAD USER DATA (UPDATED TO NEW SCHEMA) ---
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _email = user.email ?? "");

    try {
      // 1. Fetch Role & Status from 'users' node
      final userSnap = await _dbRef.child('users/${user.uid}').get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        _role = userData['role'] ?? 'resident';
      }

      // 2. Fetch Detailed Info from 'profiles' node
      final profileSnap = await _dbRef.child('profiles/${user.uid}').get();
      if (profileSnap.exists) {
        final profileData = Map<String, dynamic>.from(profileSnap.value as Map);
        
        if (mounted) {
          setState(() {
            _name = profileData['fullname'] ?? "No Name";
            _phone = profileData['phone'] ?? "No Phone";
            _address = profileData['address'] ?? "No Address";
            _email = profileData['email'] ?? user.email ?? "No Email";
            _profileUrl = profileData['profileUrl']; 
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _name = "Profile Not Found"; _isLoading = false; });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. UPLOAD TO CLOUDINARY (UPDATED) ---
  Future<void> _pickAndUploadImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // A. Pick Image
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); 
    
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      File file = File(pickedFile.path);
      
      // B. Create the API URL
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // C. Create the Request
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      // D. Send Request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        
        // E. Get the URL
        final String publicUrl = jsonMap['secure_url'];

        // F. Update 'profiles' node with the new URL
        setState(() => _profileUrl = publicUrl);
        await _dbRef.child('profiles/${user.uid}').update({'profileUrl': publicUrl});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success! Profile Updated."), backgroundColor: Colors.green));
        }
      } else {
        throw "Cloudinary Error: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if(mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () async {
              // Settings screen navigation restored!
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadUserData(); // Instantly refresh data when coming back
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: _profileUrl != null ? NetworkImage(_profileUrl!) : null,
                    child: _isUploading 
                      ? const CircularProgressIndicator() 
                      : (_profileUrl == null 
                          ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : "U", style: const TextStyle(fontSize: 40, color: AppColors.primary, fontWeight: FontWeight.bold))
                          : null),
                  ),
                ),
                Positioned(
                  bottom: 0, 
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                )
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
              child: Text(_role.toUpperCase(), style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),

            const SizedBox(height: 32),

            _buildInfoCard(Icons.email_outlined, "Email", _email),
            _buildInfoCard(Icons.phone_outlined, "Phone", _phone),
            _buildInfoCard(Icons.location_on_outlined, "Address", _address),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(icon, color: Colors.grey[600], size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}