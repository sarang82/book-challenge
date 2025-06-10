import 'dart:math';

class MissionRecommendationService {
  final Random _random = Random();

  // 카테고리와 난이도 기반으로 동적으로 미션 생성
  Map<String, List<String>> _missionTemplates = {
    '독서': [
      '하루에 {minutes}분 독서하기',
      '하루에 {page}쪽 독서하기',
      '{genre} 장르 책 10쪽 읽기',
      '아침에 10분간 책 읽기',
      '아침에 20분간 책 읽기',
      '잠들기 전 10분간 독서하기',
      '잠들기 전 20분간 독서하기',
      '책 읽고 인상 깊은 문장 3개 기록하기',
      '책 읽고 인상 깊은 문장 1개 기록하기',
      '하루동안 1시간 이상 독서하기',
      '하루동안 30분 이상 독서하기',
      '책을 친구에게 추천하는 메모 작성하기',
      '챌린지 시작하기',
    ],
  };

  Map<String, List<String>> _genreOptions = {
    '독서': ['소설', '자기계발', '역사', '과학', '에세이', '수학',],
  };

  Future<Map<String, String>> getRandomMission(String category, String difficulty) async {
    List<String> templates = _missionTemplates[category] ?? [];

    if (templates.isEmpty) {
      return {'title': '기본 독서 미션', 'description': ''};
    }

    String template = templates[_random.nextInt(templates.length)];
    String title = _fillTemplate(template, category, difficulty);

    return {
      'title': title,
      'description': '',
    };
  }

  String _fillTemplate(String template, String category, String difficulty) {
    int minutes = _random.nextInt(30) + 10;
    int days = _random.nextInt(7) + 3;
    int count = _random.nextInt(3) + 1;
    int page = _random.nextInt(20) + 5;
    String genre = (_genreOptions[category] ?? ['책'])[_random.nextInt((_genreOptions[category]?.length ?? 1))];

    return template
        .replaceAll('{minutes}', minutes.toString())
        .replaceAll('{days}', days.toString())
        .replaceAll('{count}', count.toString())
        .replaceAll('{genre}', genre)
        .replaceAll('{page}', page.toString());
  }
}
