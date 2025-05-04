import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '/services/auth_service.dart'; // 서비스 경로 맞춰줘
import 'package:cloud_firestore/cloud_firestore.dart';
import '/utils/validators.dart';

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
  bool _isPasswordValid = false;

  // 이메일 인증 팝업
  void _showVerificationDialog({required bool success, String errorMessage = ''}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(success ? "이메일 인증 안내" : "인증 실패"),
          content: Text(success
              ? "입력한 이메일로 인증 메일이 발송되었습니다.\n인증을 완료하신 후 다시 로그인해 주세요."
              : "메일 인증을 실패했습니다. 다시 시도해보세요: $errorMessage"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 팝업 닫기
              },
              child: Text("확인"),
            ),
          ],
        );
      },
    );
  }

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

    if (!isValidEmail(_emailController.text)) {
      setState(() =>_isEmailChecked = false); {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('올바른 이메일 형식이 아닙니다.')));
        return;
      }
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (snapshot.docs.isEmpty) {
        setState(() => _isEmailChecked = true);
    } else {
      setState(() => _isEmailChecked = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미 사용 중인 이메일입니다.')));
    }
  }

  //비번 형식 확인
  // 비밀번호 형식 체크
  Future<String?> _checkPassword() async {
    final password = _passwordController.text.trim();

    // 비밀번호 길이 체크
    if (password.length < 8 || password.length > 16) {
      setState(() {
        _isPasswordValid = false;// 유효하지않을때
      });
      return '비밀번호는 8~16자로 입력해주세요.';
    }

    // 특수문자 포함 체크
    final pwdFormat = RegExp(r'^(?=.*[!@#\$&*~]).{8,16}$');
    if (!pwdFormat.hasMatch(password)) {
      setState(() {
        _isPasswordValid = false;// 유효하지않을때
      });
      return '비밀번호는 특수문자를 하나 이상 포함해야 합니다.';
    }
    _isPasswordValid=true;
    return null;
  }

  Future<void> _sendVerificationEmail() async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text.trim();

    if (email.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    // 인증 메일 보내기 전 이메일 형식 확인
    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일을 올바른 형식으로 입력해주세요.')),
      );
      return;
    }

    try {
      // 이미 유저가 로그인되어 있으면 인증 메일만 재발송
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pwd,
        );
      }

      await _authService.sendVerificationEmailAndSaveTempUsers(email: email, pwd: pwd);

      setState(() {
        _isEmailChecked = true; // 이메일 인증 발송 완료 상태
      });

      _showVerificationDialog(success: true);
    } on FirebaseAuthException catch (e) {
      _showVerificationDialog(success: false, errorMessage: e.message ?? '에러 발생');
    }
  }


  // 가입하기 버튼 누를 때 실행
  Future<void> _completeSignUp() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final pwd = _passwordController.text.trim();
    final birthday = _birthdayController.text.trim();
    final gender = _selectedGender;

    if (!_isNicknameChecked && !_isEmailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('닉네임 중복 확인과 이메일 인증이 필요합니다.')));
      return;
    } else if (!_isEmailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이메일 인증이 필요합니다.')));
      return;
    } else if (!_isNicknameChecked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('닉네임 중복 확인이 필요합니다.')));
    }

    final passwordError = await _checkPassword();
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(passwordError)));
      return;
    }

    // 모든 필수 항목 입력 확인
    if (nickname.isEmpty || email.isEmpty || pwd.isEmpty || birthday.isEmpty || gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    // 이메일 인증이 되어 있는지 확인
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.reload();
      _showVerificationDialog(success: false, errorMessage: '이메일 인증이 필요합니다.'); // 이메일 인증이 안 된 경우 안내
      return;
    }

    await _authService.CompleteSignUp(email: email, pwd: pwd,
        nickname: nickname, userId: email,
        birthday: birthday, gender: gender);

    Navigator.pop(context);
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
            _buildInputField('이메일', '이메일 입력', _emailController, _sendVerificationEmail,
            checkButtonText: '인증 메일 발송', onBeforeCheck: _checkEmail),
            _buildPasswordField('비밀번호', '8~16자, 특수문자 포함', _passwordController),
            _buildBirthdayField('생년월일', 'YYYY/MM/DD', _birthdayController, isValidBirthday),
            _buildGenderField(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _completeSignUp,
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

  Widget _buildInputField(String label, String hint, TextEditingController controller,
      VoidCallback? onCheck, {String checkButtonText='중복확인',  Future<void> Function()? onBeforeCheck,}) {
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
                onPressed: () async {
                  if (onBeforeCheck != null) await onBeforeCheck();
                  onCheck.call();
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xF3F3F3FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
                child: Text(checkButtonText),
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
          onChanged: (value) {
            setState(() {
              _checkPassword(); // 사용자가 비밀번호를 입력할 때마다 체크
            });
            if (value.length > 16) {
              // 비밀번호 16자 이상 입력 못하게 처리
              controller.text = value.substring(0, 16);
              controller.selection = TextSelection.collapsed(offset: 16);
            }
          },

          decoration: InputDecoration(
            suffixIcon: Icon(
              _isPasswordValid ? Icons.check_circle : Icons.cancel,
              color: _isPasswordValid ? Colors.green : Colors.red,
            ),
            hintText: hint,
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            suffixText: '${controller.text.length}/16',  // 비밀번호 길이 표시
            suffixStyle: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildBirthdayField(
      String label,
      String hint,
      TextEditingController controller,
      bool Function(String) validator,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 10, // YYYY/MM/DD 형식
          decoration: InputDecoration(
            hintText: hint,
            counterText: "", // 글자 수 표시 숨김
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
          onChanged: (value) {
            // 숫자만 남기기
            String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

            // 자동 슬래시 삽입
            String formatted = '';
            for (int i = 0; i < digits.length && i < 8; i++) {
              formatted += digits[i];
              if (i == 3 || i == 5) formatted += '/';
            }

            // 커서가 뒤로 가는 현상 방지
            final oldText = controller.text;
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );

            // 유효성 검사
            if (formatted.length == 10) {
              final raw = formatted.replaceAll('/', '');
              if (!validator(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('생년월일 형식이 올바르지 않습니다. (예: 19990101)')),
                );
              }
            }
          },
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