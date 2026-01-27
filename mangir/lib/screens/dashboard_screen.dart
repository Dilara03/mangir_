import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _userName = 'Kullanıcı';
  double _income = 0.0;
  double _expense = 0.0;
  double _balance = 0.0;
  List<dynamic> _recentTransactions = [];
  DateTime _selectedDate = DateTime.now();
  String? _profileImage;

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
      // Kullanıcı bilgilerini al
      final userResult = await ApiService.getCurrentUser();
      if (userResult['success']) {
        setState(() {
          _userName = userResult['data']['full_name'];
          _profileImage = userResult['data']['profile_image'];
        });
      }

      // Aylık istatistikleri al
      final statsResult = await ApiService.getPeriodStats(
        year: _selectedDate.year,
        month: _selectedDate.month,
      );

      if (statsResult['success']) {
        setState(() {
          _income = (statsResult['data']['income'] ?? 0.0).toDouble();
          _expense = (statsResult['data']['expense'] ?? 0.0).toDouble();
          _balance = (statsResult['data']['balance'] ?? 0.0).toDouble();
        });
      }

      // Son 5 işlemi al
      final transactionsResult = await ApiService.getTransactions(
        skip: 0,
        limit: 5,
        year: _selectedDate.year,
        month: _selectedDate.month,
      );
      if (transactionsResult['success']) {
        setState(() {
          _recentTransactions = transactionsResult['data'];
        });
      }
    } catch (e) {
      print('Veri yükleme hatası: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + delta,
        1,
      );
    });
    _loadData();
  }

  String _getMonthName() {
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
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'maaş':
        return Colors.green;
      case 'yemek':
        return Colors.orange;
      case 'ulaşım':
        return Colors.blue;
      case 'eğlence':
        return Colors.purple;
      case 'faturalar':
        return Colors.amber;
      case 'sağlık':
        return Colors.red;
      case 'alışveriş':
        return Colors.pink;
      case 'kira':
        return Colors.brown;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildProfileAvatar() {
    if (_profileImage == null || _profileImage!.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xFFEEF3F8),
        child: Icon(Icons.person, color: Color(0xFF7A8B9A), size: 20),
      );
    }

    try {
      if (_profileImage!.startsWith('data:image')) {
        final base64String = _profileImage!.split(',')[1];
        final bytes = base64Decode(base64String);
        return CircleAvatar(radius: 20, backgroundImage: MemoryImage(bytes));
      } else {
        return CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(_profileImage!),
        );
      }
    } catch (e) {
      print('Avatar yükleme hatası: $e');
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xFFEEF3F8),
        child: Icon(Icons.person, color: Color(0xFF7A8B9A), size: 20),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildProfileAvatar(),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merhaba, $_userName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Ay seçici
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Color(0xFF7A8B9A),
                                ),
                                onPressed: () => _changeMonth(-1),
                              ),
                              Text(
                                _getMonthName(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7A8B9A),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF7A8B9A),
                                ),
                                onPressed: () => _changeMonth(1),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Gelir/Gider/Bakiye
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryItem(
                                'Toplam Gelir :',
                                '+${_income.toStringAsFixed(2)}₺',
                                Colors.green,
                              ),
                              _buildSummaryItem(
                                'Toplam Gider :',
                                '-${_expense.toStringAsFixed(2)}₺',
                                Colors.red,
                              ),
                              _buildSummaryItem(
                                'Kalan Bakiye :',
                                '${_balance.toStringAsFixed(2)}₺',
                                _balance >= 0 ? Colors.orange : Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Son İşlemler
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Son İşlemler',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/transactions',
                                    );
                                  },
                                  child: const Text(
                                    'Tümünü Gör',
                                    style: TextStyle(
                                      color: Color(0xFF5B8DEF),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Expanded(
                              child: _recentTransactions.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Henüz işlem yok',
                                        style: TextStyle(
                                          color: Color(0xFF7A8B9A),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _recentTransactions.length,
                                      itemBuilder: (context, index) {
                                        final transaction =
                                            _recentTransactions[index];
                                        final category =
                                            transaction['category'];
                                        final amount =
                                            (transaction['amount'] ?? 0.0)
                                                .toDouble();
                                        if (category == null)
                                          return Container();
                                        final isIncome =
                                            category['type'] == 'income';

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _buildTransactionItem(
                                            icon: null,
                                            emoji: category['icon'] ?? '📦',
                                            iconColor: _getCategoryColor(
                                              category['name'],
                                            ).withOpacity(0.2),
                                            iconMain: _getCategoryColor(
                                              category['name'],
                                            ),
                                            title: category['name'],
                                            amount:
                                                '${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)}₺',
                                            amountColor: isIncome
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
    );
  }

  Widget _buildSummaryItem(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B9A)),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
    String? emoji,
    IconData? icon,
    required Color iconColor,
    required Color iconMain,
    required String title,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: emoji != null
                ? Text(emoji, style: const TextStyle(fontSize: 24))
                : Icon(icon, color: iconMain, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
          const Spacer(),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        ],
      ),
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
              _buildNavItem(Icons.home, currentIndex == 0, () {}),
              _buildNavItem(Icons.list_alt, currentIndex == 1, () {
                Navigator.pushNamed(context, '/transactions');
              }),
              _buildAddButton(context),
              _buildNavItem(Icons.bar_chart, currentIndex == 3, () {
                Navigator.pushNamed(context, '/statistics');
              }),
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
          _loadData(); // İşlem eklendikten sonra verileri yenile
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}
