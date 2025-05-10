// 생략된 import 생략 없이 포함
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedIndex = 4;
  final _nicknameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdateController = TextEditingController();
  String _gender = '선택하지 않음';
  bool _isEditing = false;
  String? _photoUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userInfo = await AuthService().getUserInfo();
    if (userInfo != null) {
      setState(() {
        _nicknameController.text = userInfo['nickname'] ?? '';
        _userIdController.text = userInfo['userId'] ?? user.uid;
        _emailController.text = userInfo['email'] ?? '';
        _birthdateController.text = userInfo['birthday'] ?? '';
        _gender = userInfo['gender'] ?? '선택하지 않음';
        _photoUrl = userInfo['photoUrl'];
      });
    }
  }

  Future<void> _saveUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final dataToUpdate = {
      'nickname': _nicknameController.text,
      'userId': _userIdController.text,
      'email': _emailController.text,
      'birthday': _birthdateController.text,
      'gender': _gender,
    };

    if (_photoUrl != null) {
      dataToUpdate['photoUrl'] = _photoUrl!;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      dataToUpdate,
      SetOptions(merge: true),
    );

    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정보가 저장되었습니다.')),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _photoUrl = picked.path; // Firebase Storage 연동 전 임시 저장
      });
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      Navigator.pushReplacementNamed(context, [
        '/timer',
        '/challenge',
        '/home',
        '/library',
        '/profile',
      ][index]);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool enabled = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final genders = ['선택하지 않음', '남성', '여성'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: const InputDecoration(
          labelText: '성별',
          border: OutlineInputBorder(),
        ),
        items: genders
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: _isEditing ? (val) => setState(() => _gender = val!) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('내 정보'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () => _isEditing ? _saveUserData() : setState(() => _isEditing = true),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_photoUrl?.startsWith('http') == true
                      ? NetworkImage(_photoUrl!)
                      : null) as ImageProvider?,
                  child: (_photoUrl == null || _photoUrl == '')
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField('닉네임', _nicknameController, enabled: _isEditing),
            _buildTextField('아이디', _userIdController, enabled: _isEditing),
            _buildTextField('이메일', _emailController, enabled: _isEditing),
            _buildTextField('생년월일', _birthdateController, enabled: _isEditing),
            _buildGenderSelector(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
