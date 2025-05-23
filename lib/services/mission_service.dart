import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 미션 추가 (userId, status 필드 포함)
  Future<void> addMission({
    required String userId,
    required String title,
    required String description,
    String? category,
    String? difficulty,
    String status = 'ongoing', // 기본값은 진행 중
  }) async {
    try {
      await _firestore.collection('missions').add({
        'userId': userId,
        'title': title,
        'description': description,
        'category': category ?? '',
        'difficulty': difficulty ?? '',
        'status': status,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('미션 추가에 실패했습니다: $e');
    }
  }

  // 사용자별 미션 조회 (필요 시 상태 필터링도 가능)
  Future<List<Mission>> getUserMissions({required String userId, String? status}) async {
    try {
      Query query = _firestore
          .collection('missions')
          .where('userId', isEqualTo: userId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Mission.fromDocument(doc)).toList();
    } catch (e) {
      throw Exception('사용자 미션을 불러오는 데 실패했습니다: $e');
    }
  }

  // 전체 미션 목록 조회 (사용하지 않아도 됨)
  Future<List<Mission>> getMissions() async {
    try {
      final snapshot = await _firestore.collection('missions').get();
      return snapshot.docs
          .map((doc) => Mission.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('미션 목록을 가져오는 데 실패했습니다: $e');
    }
  }

  // 랜덤 미션 추천
  Future<Mission?> getRandomMission() async {
    try {
      final missions = await getMissions();
      if (missions.isEmpty) return null;

      final randomIndex = DateTime.now().millisecondsSinceEpoch % missions.length;
      return missions[randomIndex];
    } catch (e) {
      throw Exception('랜덤 미션을 가져오는 데 실패했습니다: $e');
    }
  }
}

// 미션 데이터 모델
class Mission {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final DateTime createdAt;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.createdAt,
  });

  factory Mission.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Mission(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      difficulty: data['difficulty'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}