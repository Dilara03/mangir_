import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:math' as math;
import 'category_stats_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int selectedTab = 1; // 0: Haftalık, 1: Aylık, 2: Yıllık
  bool _isLoading = true;
  double _income = 0.0;
  double _expense = 0.0;
  double _balance = 0.0;
  List<dynamic> _categoryStats = [];
  DateTime _selectedDate = DateTime.now();

  // ↓ Hafta için yardımcı fonksiyonlar
  DateTime _getWeekStart(DateTime date) {
    // Haftanın Pazartesi gününü bul
    final weekday = date.weekday; // 1=Pazartesi, 7=Pazar
    return date.subtract(Duration(days: weekday - 1));
  }

  DateTime _getWeekEnd(DateTime date) {
    final weekStart = _getWeekStart(date);
    return weekStart.add(const Duration(days: 6));
  }

  String _getDisplayDate() {
    if (selectedTab == 0) {
      //Haftalık: Pazartesi - Pazar
      final startDate = _getWeekStart(_selectedDate);
      final endDate = _getWeekEnd(_selectedDate);
      return '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}/${endDate.year}';
    } else if (selectedTab == 1) {
      // Aylık
      const months = [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık',
      ];
      return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    } else {
      // Yıllık
      return '${_selectedDate.year}';
    }
  }

  void _changeDate(int delta) {
    setState(() {
      if (selectedTab == 0) {
        // Haftalık: 7 gün ekle/çıkar (bir sonraki/önceki hafta)
        _selectedDate = _selectedDate.add(Duration(days: 7 * delta));
      } else if (selectedTab == 1) {
        // Aylık: 1 ay ekle/çıkar
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + delta,
          1,
        );
      } else {
        // Yıllık: 1 yıl ekle/çıkar
        _selectedDate = DateTime(_selectedDate.year + delta, 1, 1);
      }
    });
    _loadData();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String period;
      String? weekStart;

      if (selectedTab == 0) {
        period = 'weekly';
        // Haftanın Pazartesi'sini YYYY-MM-DD formatında gönder
        final weekStartDate = _getWeekStart(_selectedDate);
        weekStart =
            '${weekStartDate.year}-${weekStartDate.month.toString().padLeft(2, '0')}-${weekStartDate.day.toString().padLeft(2, '0')}';
      } else if (selectedTab == 1) {
        period = 'monthly';
      } else {
        period = 'yearly';
      }

      // İstatistikleri al
      final statsResult = await ApiService.getPeriodStats(
        period: period,
        year: _selectedDate.year,
        month: selectedTab == 1 ? _selectedDate.month : null,
        weekStart: weekStart,
      );

      if (statsResult['success']) {
        setState(() {
          _income = (statsResult['data']['income'] ?? 0.0).toDouble();
          _expense = (statsResult['data']['expense'] ?? 0.0).toDouble();
          _balance = (statsResult['data']['balance'] ?? 0.0).toDouble();
        });
      }

      // Kategori istatistikleri
      final categoryResult = await ApiService.getStatsByCategoryPeriod(
        period: period,
        year: _selectedDate.year,
        month: selectedTab == 1 ? _selectedDate.month : null,
        weekStart: weekStart,
      );

      if (categoryResult['success']) {
        setState(() {
          _categoryStats = categoryResult['data'];
          _categoryStats =
              _categoryStats.where((cat) => cat['total'] > 0).toList()..sort(
                (a, b) =>
                    (b['percentage'] as num).compareTo(a['percentage'] as num),
              );
        });
      }
    } catch (e) {
      print('İstatistikler yüklenemedi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getCategoryColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'İstatistikler',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildTab('Haftalık', 0),
                const SizedBox(width: 12),
                _buildTab('Aylık', 1),
                const SizedBox(width: 12),
                _buildTab('Yıllık', 2),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF7A8B9A),
                  ),
                  onPressed: () => _changeDate(-1),
                ),
                Text(
                  _getDisplayDate(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF7A8B9A),
                  ),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Gelir',
                                  '${_income.toStringAsFixed(2)}₺',
                                  const Color(0xFF6BCF9E),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Gider',
                                  '${_expense.toStringAsFixed(2)}₺',
                                  const Color(0xFFFF9A76),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Bakiye',
                                  '${_balance.toStringAsFixed(2)}₺',
                                  _balance >= 0
                                      ? const Color(0xFF5B8DEF)
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Harcama Dağılımı
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bütçe Dağılımı',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Pasta Grafik
                                if (_categoryStats.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(40),
                                      child: Text(
                                        'Henüz işlem yok',
                                        style: TextStyle(
                                          color: Color(0xFF7A8B9A),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Center(
                                    child: SizedBox(
                                      height: 200,
                                      width: 200,
                                      child: CustomPaint(
                                        size: const Size(200, 200),
                                        painter: DynamicPieChartPainter(
                                          data: _categoryStats,
                                        ),
                                      ),
                                    ),
                                  ),

                                if (_categoryStats.isNotEmpty) ...[
                                  const SizedBox(height: 24),

                                  const Text(
                                    'Kategori Dağılımı',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Kategori listesi
                                  ...(_categoryStats.take(5).map((cat) {
                                    final color = _getCategoryColorFromHex(
                                      cat['color'],
                                    );
                                    final percentage =
                                        (cat['percentage'] ?? 0.0).toDouble();
                                    final total = (cat['total'] ?? 0.0)
                                        .toDouble();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildCategoryItem(
                                        cat['category_name'] ?? 'Bilinmeyen',
                                        cat['icon'] ?? '📦',
                                        color,
                                        '${percentage.toStringAsFixed(1)}%',
                                        '${total.toStringAsFixed(2)}₺',
                                      ),
                                    );
                                  }).toList()),

                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CategoryStatsScreen(
                                                  period: selectedTab == 0
                                                      ? 'weekly'
                                                      : selectedTab == 1
                                                      ? 'monthly'
                                                      : 'yearly',
                                                  year: _selectedDate.year,
                                                  month: selectedTab == 1
                                                      ? _selectedDate.month
                                                      : null,
                                                  weekStart: selectedTab == 0
                                                      ? (() {
                                                          final weekStartDate =
                                                              _getWeekStart(
                                                                _selectedDate,
                                                              );
                                                          return '${weekStartDate.year}-${weekStartDate.month.toString().padLeft(2, '0')}-${weekStartDate.day.toString().padLeft(2, '0')}';
                                                        })()
                                                      : null,
                                                ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF5B8DEF),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Tümünü Gör',
                                        style: TextStyle(
                                          color: Color(0xFF5B8DEF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 3),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5B8DEF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF7A8B9A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B9A)),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    String title,
    String emoji,
    Color color,
    String percentage,
    String amount,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B9A)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            percentage,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, currentIndex == 0, () {
                Navigator.pushReplacementNamed(context, '/home');
              }),
              _buildNavItem(Icons.list_alt, currentIndex == 1, () {
                Navigator.pushNamed(context, '/transactions');
              }),
              _buildAddButton(context),
              _buildNavItem(Icons.bar_chart, currentIndex == 3, () {}),
              _buildNavItem(Icons.person, currentIndex == 4, () {
                Navigator.pushNamed(context, '/profile');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isActive, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: isActive ? const Color(0xFF5B8DEF) : const Color(0xFFA0AEC0),
        size: 28,
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B8DEF), Color(0xFF7EB8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEF).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_transaction');
          _loadData();
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}

// Dinamik Pasta Grafik Çizici
class DynamicPieChartPainter extends CustomPainter {
  final List<dynamic> data;

  DynamicPieChartPainter({required this.data});

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -math.pi / 2; // -90 derece (üstten başla)

    for (var category in data) {
      final percentage = (category['percentage'] ?? 0.0).toDouble();
      final sweepAngle = (percentage / 100) * 2 * math.pi;
      final color = _getColorFromHex(category['color']);

      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
