import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CategoryStatsScreen extends StatefulWidget {
  final String period;
  final int year;
  final int? month;
  final String? weekStart;

  const CategoryStatsScreen({
    Key? key,
    required this.period,
    required this.year,
    this.month,
    this.weekStart,
  }) : super(key: key);

  @override
  State<CategoryStatsScreen> createState() => _CategoryStatsScreenState();
}

class _CategoryStatsScreenState extends State<CategoryStatsScreen> {
  bool _isLoading = true;
  List<dynamic> _categoryStats = [];

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
      final categoryResult = await ApiService.getStatsByCategoryPeriod(
        period: widget.period,
        year: widget.year,
        month: widget.month,
        weekStart: widget.weekStart,
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
      print('Kategoriler yüklenemedi: $e');
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
          'Tüm Kategoriler',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryStats.isEmpty
          ? const Center(
              child: Text(
                'Henüz işlem yok',
                style: TextStyle(color: Color(0xFF7A8B9A)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _categoryStats.length,
                itemBuilder: (context, index) {
                  final cat = _categoryStats[index];
                  final color = _getCategoryColorFromHex(cat['color']);
                  final percentage = (cat['percentage'] ?? 0.0).toDouble();
                  final total = (cat['total'] ?? 0.0).toDouble();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              cat['icon'] ?? '📦',
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['category_name'] ?? 'Bilinmeyen',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${total.toStringAsFixed(2)}₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF7A8B9A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
