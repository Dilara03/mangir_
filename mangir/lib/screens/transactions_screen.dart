import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'edit_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String selectedFilter = 'Tümü';
  bool _isLoading = true;
  List<dynamic> _allTransactions = [];
  List<dynamic> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getTransactions(skip: 0, limit: 100);
      if (result['success']) {
        setState(() {
          _allTransactions = result['data'];
          _applyFilter();
        });
      }
    } catch (e) {
      print('İşlemler yüklenemedi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'Tümü') {
      _filteredTransactions = _allTransactions;
    } else if (selectedFilter == 'Gelir') {
      _filteredTransactions = _allTransactions
          .where((t) => t['category']['type'] == 'income')
          .toList();
    } else if (selectedFilter == 'Gider') {
      _filteredTransactions = _allTransactions
          .where((t) => t['category']['type'] == 'expense')
          .toList();
    }
  }

  Future<void> _deleteTransaction(int transactionId) async {
    final result = await ApiService.deleteTransaction(transactionId);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İşlem silindi'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTransactions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Silme başarısız'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final transactionDate = DateTime(date.year, date.month, date.day);

      if (transactionDate == today) {
        return 'Bugün';
      } else if (transactionDate == yesterday) {
        return 'Dün';
      } else if (now.difference(date).inDays < 7) {
        return '${now.difference(date).inDays} gün önce';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '';
    }
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
        return Colors.grey;
    }
  }

  Map<String, List<dynamic>> _groupByDate() {
    final Map<String, List<dynamic>> grouped = {};

    for (var transaction in _filteredTransactions) {
      final dateKey = _formatDate(transaction['transaction_date']);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped;
  }

  List<MapEntry<String, List<dynamic>>> _sortGroupedTransactions(
    Map<String, List<dynamic>> grouped,
  ) {
    final entries = grouped.entries.toList();

    // Tarih gruplarını sırala
    entries.sort((a, b) {
      // "Bugün" her zaman en üstte
      if (a.key == 'Bugün') return -1;
      if (b.key == 'Bugün') return 1;

      // "Dün" ikinci sırada
      if (a.key == 'Dün') return -1;
      if (b.key == 'Dün') return 1;

      // "X gün önce" formatındakiler
      final aMatch = RegExp(r'(\d+) gün önce').firstMatch(a.key);
      final bMatch = RegExp(r'(\d+) gün önce').firstMatch(b.key);

      if (aMatch != null && bMatch != null) {
        final aDays = int.parse(aMatch.group(1)!);
        final bDays = int.parse(bMatch.group(1)!);
        return aDays.compareTo(bDays);
      }

      // Tam tarih formatındakiler (dd/MM/yyyy)
      try {
        final aDate = DateFormat('dd/MM/yyyy').parse(a.key);
        final bDate = DateFormat('dd/MM/yyyy').parse(b.key);
        return bDate.compareTo(aDate); // Yeni tarihler üstte
      } catch (e) {
        return 0;
      }
    });

    return entries;
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
          'İşlemler',
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
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('Tümü', selectedFilter == 'Tümü', () {
                  setState(() {
                    selectedFilter = 'Tümü';
                    _applyFilter();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Gelir', selectedFilter == 'Gelir', () {
                  setState(() {
                    selectedFilter = 'Gelir';
                    _applyFilter();
                  });
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Gider', selectedFilter == 'Gider', () {
                  setState(() {
                    selectedFilter = 'Gider';
                    _applyFilter();
                  });
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz işlem yok',
                      style: TextStyle(color: Color(0xFF7A8B9A)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: _buildGroupedTransactions(),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1),
    );
  }

  List<Widget> _buildGroupedTransactions() {
    final grouped = _groupByDate();
    final sortedEntries = _sortGroupedTransactions(grouped); // ← EKLE
    final List<Widget> widgets = [];

    for (var entry in sortedEntries) {
      // ← DEĞİŞTİR
      final date = entry.key;
      final transactions = entry.value;

      widgets.add(_buildDateHeader(date));
      widgets.add(const SizedBox(height: 12));

      for (var transaction in transactions) {
        final category = transaction['category'];
        if (category == null) continue;

        final amount = (transaction['amount'] ?? 0.0).toDouble();
        final isIncome = category['type'] == 'income';

        widgets.add(
          _buildTransactionCard(
            transaction: transaction,
            transactionId: transaction['id'],
            icon: null,
            iconColor: _getCategoryColor(category['name']),
            title: category['name'],
            description: transaction['description'] ?? '',
            amount: '${isIncome ? '+' : '-'}${amount.toStringAsFixed(2)}₺',
            amountColor: isIncome
                ? const Color(0xFF6BCF9E)
                : const Color(0xFFFF9A76),
            date: _formatTime(transaction['created_at']),
            isExpense: !isIncome,
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }

      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildDateHeader(String date) {
    return Text(
      date,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7A8B9A),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B8DEF) : const Color(0xFFEEF3F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF7A8B9A),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required Map<String, dynamic> transaction,
    required int transactionId,
    IconData? icon,
    required Color iconColor,
    required String title,
    required String description,
    required String amount,
    required Color amountColor,
    required String date,
    required bool isExpense,
  }) {
    return Dismissible(
      key: Key(transactionId.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('İşlemi Sil'),
            content: const Text(
              'Bu işlemi silmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        _deleteTransaction(transactionId);
      },
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                transaction['category']['icon'] ?? '📦',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A8B9A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8B9A),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditTransactionScreen(transaction: transaction),
                  ),
                );

                if (result == true) {
                  _loadTransactions();
                }
              },
              child: Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
          ],
        ),
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
              _buildNavItem(Icons.home, currentIndex == 0, () {
                Navigator.pushReplacementNamed(context, '/home');
              }),
              _buildNavItem(Icons.list_alt, currentIndex == 1, () {}),
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
          _loadTransactions();
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}
