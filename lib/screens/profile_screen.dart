import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/bottom_nav_bar.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    if (data != null) {
      setState(() {
        _nicknameController.text = data['nickname'] ?? '';
        _userIdController.text = data['userId'] ?? '';
        _emailController.text = data['email'] ?? '';
        _birthdateController.text = data['birthday'] ?? '';
        _gender = data['gender'] ?? '선택하지 않음';
        _photoUrl = data['photoUrl'];
      });
    }
  }

  Future<void> _saveUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 필수 항목 체크 (성별은 제외)
    if (_nicknameController.text.isEmpty ||
        _userIdController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _birthdateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    final dataToUpdate = {
      'nickname': _nicknameController.text,
      'userId': _userIdController.text,
      'email': _emailController.text,
      'birthday': _birthdateController.text,
    };

    // 성별 저장 (단, "선택하지 않음"은 저장 안함)
    if (_gender != '선택하지 않음') {
      dataToUpdate['gender'] = _gender;
    }

    // 사진 저장
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      dataToUpdate['photoUrl'] = _photoUrl!;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update(dataToUpdate);

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정보가 저장되었습니다.')),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/challenge');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/library');
          break;
        case 4:
          break;
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _photoUrl = picked.path; // Firebase Storage 연동 시 수정 필요
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
    enabledBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.black),
    ),
    focusedBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.black, width: 2),
        ),
      ),
    ),
    );
  }

  Widget _buildGenderSelector() {
    final genders = ['선택하지 않음', '남성', '여성'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: const InputDecoration(
          labelText: '성별',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        dropdownColor: Colors.white,
        items: genders.map((g) {
          return DropdownMenuItem(value: g, child: Text(g));
        }).toList(),
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
        title: const Text('내 정보', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: _isEditing
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isEditing = false;
            _loadUserData();
          }),
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveUserData();
              } else {
                setState(() => _isEditing = true);
              }
            },
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
                  backgroundColor: Colors.blue[100],
                  backgroundImage:
                  _selectedImage != null ? FileImage(_selectedImage!) : null,
                  child: _selectedImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.black54)
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
            const SizedBox(height: 24),
            _buildTextField('닉네임', _nicknameController, enabled: _isEditing),
            _buildTextField('아이디', _userIdController, enabled: _isEditing),
            _buildTextField('이메일', _emailController, enabled: _isEditing),
            _buildTextField('생년월일', _birthdateController, enabled: _isEditing),
            _buildGenderSelector(),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
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