// 닉네임, 아이디, 비번 유효성 검사 파일 따로 빼둠

final RegExp emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

final RegExp passwordRegex = RegExp(
  r'^(?=.*[!@#\$&*~]).{8,16}$',
);

final RegExp birthdayRegex = RegExp(
    r'^(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])$'
);

bool isValidEmail(String email) {
  return emailRegex.hasMatch(email);
}

bool isValidPassword(String pwd) {
  return passwordRegex.hasMatch(pwd);
}

bool isValidBirthday(String birthday){
  return birthdayRegex.hasMatch(birthday);
}
