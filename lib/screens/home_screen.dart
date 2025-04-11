import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/book_search_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;

  late AnimationController _waveController;

  final TextEditingController _searchController = TextEditingController();
  final BookSearchService _searchService = BookSearchService();
  String? _nickname;

  bool _isSearching = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadNickname();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService().getNickname();
    setState(() {
      _nickname = nickname ?? '사용자';
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchBooks(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/challenge');
          break;
        case 2:
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/library');
          break;
        case 4:
          Navigator.pushReplacementNamed(context, '/profile');
          break;
      }
    }
  }

  void _clearFocus() {
    FocusScope.of(context).unfocus();
  }

  void _exitSearchMode() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
    _clearFocus();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double bookItemHeight = 76.0;
    final double resultsHeight = bookItemHeight * 4;

    return GestureDetector(
      onTap: _clearFocus,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '제목 또는 저자를 입력하세요.',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _exitSearchMode,
                )
                    : null,
              ),
              onSubmitted: _performSearch,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 20),
                _buildMainCard(),
                const SizedBox(height: 20),
                Expanded(child: _buildWaveBackground()),
              ],
            ),
            if (_isSearching)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white,
                  height: _isLoading || _searchResults.isEmpty ? 80 : resultsHeight,
                  child: _isLoading
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                      : _searchResults.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '"${_searchController.text}" 검색 결과가 없습니다',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return _buildSimpleBookItem(book);
                    },
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildWaveBackground() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Stack(
          children: [
            _buildWaveLayer(
              amplitude: 20,
              wavelength: 200,
              verticalOffset: 60,
              color: Colors.blue.withOpacity(0.4),
            ),
            _buildWaveLayer(
              amplitude: 25,
              wavelength: 180,
              verticalOffset: 90,
              color: Colors.blue.withOpacity(0.3),
            ),
            _buildWaveLayer(
              amplitude: 30,
              wavelength: 160,
              verticalOffset: 120,
              color: Colors.blue.withOpacity(0.2),
            ),
          ],
        );
      },
    );
  }


  Widget _buildWaveLayer({
    required double amplitude,
    required double wavelength,
    required double verticalOffset,
    required Color color,
  }) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _WavePainter(
          amplitude: amplitude,
          wavelength: wavelength,
          phase: _waveController.value * 2 * math.pi,
          verticalOffset: verticalOffset,
          color: color,
        ),
      ),
    );
  }


  Widget _buildSimpleBookItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        setState(() {
          _isSearching = false;
        });
        _clearFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${book['title']} 상세 화면은 개발 중입니다')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 40,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book['title'] ?? '제목 없음',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(book['author'] ?? '저자 미상',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Image.asset('assets/images/Sea_otter.png'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 독서 날씨: 맑음! ☀️',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      Text('$_nickname님,\n같이 책을 읽어볼까요?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text('[아몬드 3일만에 읽기] 챌린지 현황',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  width: 240,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('78%', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/newChallenge');
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE798),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(
                  child: Text('새 챌린지 시작하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double amplitude;
  final double wavelength;
  final double phase;
  final double verticalOffset;
  final Color color;

  _WavePainter({
    required this.amplitude,
    required this.wavelength,
    required this.phase,
    required this.verticalOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final dx = x;
      final dy = size.height / 2 +
          amplitude * math.sin(2 * math.pi * x / wavelength + phase) +
          verticalOffset;
      path.lineTo(dx, dy);
    }

    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}


