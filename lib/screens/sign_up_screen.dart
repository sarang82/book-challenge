import 'package:flutter/material.dart';
import '/services/auth_service.dart'; // 서비스 경로 맞춰줘
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthdayController = TextEditingController();

  String _selectedGender = '선택하지 않음';

  // 중복 확인 플래그
  bool _isNicknameChecked = false;
  bool _isEmailChecked = false;

  // 닉네임 중복 확인
  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _isNicknameChecked = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사용 가능한 닉네임입니다.')));
    } else {
      setState(() => _isNicknameChecked = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
    }
  }

  // 이메일 중복 확인
  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _isEmailChecked = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사용 가능한 이메일입니다.')));
    } else {
      setState(() => _isEmailChecked = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미 사용 중인 이메일입니다.')));
    }
  }

  // 가입하기 버튼 누를 때 실행
  Future<void> _signUp() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final birthday = _birthdayController.text.trim();
    final gender = _selectedGender;

    if (!_isNicknameChecked || !_isEmailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('닉네임과 이메일 중복확인을 해주세요.')));
      return;
    }

    try {
      await _authService.signUp(
        email: email,
        password: password,
        nickname: nickname,
        userId: email,
        birthday: birthday,
        gender: gender,
      );
      Navigator.pop(context); // 회원가입 완료 후 화면 닫기
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(color: Color(0xDDDDDDFF), thickness: 1),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField('닉네임', '닉네임 입력', _nicknameController, _checkNickname),
            _buildInputField('이메일', '이메일 입력', _emailController, _checkEmail),
            _buildPasswordField('비밀번호', '비밀번호 입력', _passwordController),
            _buildInputField('생년월일', 'ex) 19990101', _birthdayController, null),
            _buildGenderField(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Color(0xFF6CBFFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('가입하기', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller, VoidCallback? onCheck) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
            ),
            if (onCheck != null) ...[
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xF3F3F3FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
                child: const Text('중복확인'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildPasswordField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('성별', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              items: ['선택하지 않음', '남성', '여성']
                  .map((gender) => DropdownMenuItem(
                value: gender,
                child: Text(gender, style: TextStyle(color: Colors.black)),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}