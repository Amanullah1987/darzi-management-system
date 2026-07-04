import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../db/database_helper.dart';

// ═══════════════════════════════════════════════════════════════
//  MAIN EXPENSES SCREEN
// ═══════════════════════════════════════════════════════════════
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'اخراجات',
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_rounded, size: 22),
              text: 'ڈیش بورڈ',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_rounded, size: 22),
              text: 'اخراجات',
            ),
            Tab(
              icon: Icon(Icons.person_rounded, size: 22),
              text: 'کاریگر',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ExpenseDashboardTab(),
          ExpensesListWithAddTab(),
          KarigarPaymentsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CATEGORY NAME TRANSLATION MAP - ALL URDU
// ═══════════════════════════════════════════════════════════════
const Map<String, String> _categoryUrduTranslations = {
  'Karigar Payment': 'کاریگر ادائیگی',
  'Materials': 'سامان',
  'Fabrics': 'کپڑا',
  'Food & Tea': 'کھانا اور چائے',
  'Food and Tea': 'کھانا اور چائے',
  'Electricity Bill': 'بجلی کا بل',
  'Shop Rent': 'دکان کا کرایہ',
  'Transport': 'ٹرانسپورٹیشن',
  'Other Expenses': 'دیگر اخراجات',
  'Other': 'دیگر اخراجات',
};

String _translateCategoryName(String englishName) {
  return _categoryUrduTranslations[englishName] ?? englishName;
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1: DASHBOARD
// ═══════════════════════════════════════════════════════════════
class ExpenseDashboardTab extends StatefulWidget {
  const ExpenseDashboardTab({super.key});
  @override
  State<ExpenseDashboardTab> createState() => _ExpenseDashboardTabState();
}

class _ExpenseDashboardTabState extends State<ExpenseDashboardTab> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  double _totalMonthlyAll = 0;
  double _totalTodayAll = 0;
  double _totalWeekAll = 0;
  double _totalKarigarPendingAmount = 0;
  int _totalKarigarPendingCount = 0;
  double _totalKarigarPaidThisMonth = 0;
  double _totalKarigarPaidToday = 0;
  double _totalKarigarPaidThisWeek = 0;

  List<Map<String, dynamic>> _recentExpenses = [];
  List<Map<String, dynamic>> _recentKarigarPayments = [];
  List<Map<String, dynamic>> _workersWithPendingPayments = [];
  Map<String, double> _combinedCategorySummary = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final todayString = DateFormat('yyyy-MM-dd').format(now);
      final weekStartString = DateFormat('yyyy-MM-dd')
          .format(now.subtract(Duration(days: now.weekday - 1)));
      final monthStartString =
      DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      final monthEndString = DateFormat('yyyy-MM-dd')
          .format(DateTime(now.year, now.month + 1, 0));

      final results = await Future.wait([
        _db.getTotalExpenses(
            startDate: monthStartString, endDate: monthEndString),
        _db.getTotalExpenses(startDate: todayString, endDate: todayString),
        _db.getTotalExpenses(
            startDate: weekStartString, endDate: todayString),
        _db.getTotalKarigarPayments(
            startDate: monthStartString, endDate: monthEndString),
        _db.getTotalKarigarPayments(
            startDate: todayString, endDate: todayString),
        _db.getTotalKarigarPayments(
            startDate: weekStartString, endDate: todayString),
        _db.getPendingKarigarPayments(),
        _db.getPendingKarigarPaymentsCount(),
        _db.getExpenses(startDate: monthStartString, endDate: monthEndString),
        _db.getExpensesByCategory(
            startDate: monthStartString, endDate: monthEndString),
        _db.getKarigarPayments(),
        _db.getWorkersWithPendingSuits(),
      ]);

      if (mounted) {
        final double monthlyExpenses = (results[0] as num).toDouble();
        final double todayExpenses = (results[1] as num).toDouble();
        final double weekExpenses = (results[2] as num).toDouble();
        final double monthlyKarigar = (results[3] as num).toDouble();
        final double todayKarigar = (results[4] as num).toDouble();
        final double weekKarigar = (results[5] as num).toDouble();

        final double combinedMonthly = monthlyExpenses + monthlyKarigar;
        final double combinedToday = todayExpenses + todayKarigar;
        final double combinedWeek = weekExpenses + weekKarigar;

        final Map<String, double> expenseCategorySummary =
        results[9] as Map<String, double>;

        final Map<String, double> combinedCategories = {};

        expenseCategorySummary.forEach((key, value) {
          final String urduKey = _translateCategoryName(key);
          if (combinedCategories.containsKey(urduKey)) {
            combinedCategories[urduKey] =
                (combinedCategories[urduKey] ?? 0) + value;
          } else {
            combinedCategories[urduKey] = value;
          }
        });

        if (monthlyKarigar > 0) {
          const String karigarCategoryUrdu = 'کاریگر ادائیگی';
          if (combinedCategories.containsKey(karigarCategoryUrdu)) {
            combinedCategories[karigarCategoryUrdu] =
                (combinedCategories[karigarCategoryUrdu] ?? 0) +
                    monthlyKarigar;
          } else {
            combinedCategories[karigarCategoryUrdu] = monthlyKarigar;
          }
        }

        setState(() {
          _totalMonthlyAll = combinedMonthly;
          _totalTodayAll = combinedToday;
          _totalWeekAll = combinedWeek;
          _totalKarigarPaidThisMonth = monthlyKarigar;
          _totalKarigarPaidToday = todayKarigar;
          _totalKarigarPaidThisWeek = weekKarigar;
          _totalKarigarPendingAmount = (results[6] as num).toDouble();
          _totalKarigarPendingCount = results[7] as int;
          _recentExpenses = (results[8] as List)
              .take(8)
              .cast<Map<String, dynamic>>()
              .toList();
          _combinedCategorySummary = combinedCategories;
          _recentKarigarPayments = (results[10] as List)
              .take(6)
              .cast<Map<String, dynamic>>()
              .toList();
          _workersWithPendingPayments =
              (results[11] as List).cast<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ڈیٹا لوڈ کرنے میں خرابی: $e';
        });
      }
    }
  }

  Color _parseColorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final cleanHex = hexString.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return Colors.grey;
  }

  IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'checkroom':
        return Icons.checkroom;
      case 'coffee':
        return Icons.coffee;
      case 'bolt':
        return Icons.bolt;
      case 'store':
        return Icons.store;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text(
              'ڈیٹا لوڈ ہو رہا ہے...',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.red,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'دوبارہ کوشش کریں',
                style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF1B5E20),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCardsRow1(),
            const SizedBox(height: 12),
            _buildSummaryCardsRow2(),
            const SizedBox(height: 12),
            _buildSummaryCardsRow3(),
            const SizedBox(height: 28),
            if (_workersWithPendingPayments.isNotEmpty) ...[
              _buildWorkersWithPendingSection(),
              const SizedBox(height: 24),
            ],
            if (_recentKarigarPayments.isNotEmpty) ...[
              _buildRecentKarigarPaymentsSection(),
              const SizedBox(height: 24),
            ],
            _buildCategoryWiseSection(),
            const SizedBox(height: 24),
            _buildRecentExpensesSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCardsRow1() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'ماہانہ کل خرچہ',
            value: 'Rs ${_totalMonthlyAll.toStringAsFixed(0)}',
            iconData: Icons.calendar_month,
            cardColor: Colors.blue,
            subtitle: 'ماہانہ اخراجات اور کاریگر ادائیگی',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'آج کا کل خرچہ',
            value: 'Rs ${_totalTodayAll.toStringAsFixed(0)}',
            iconData: Icons.today,
            cardColor: Colors.orange,
            subtitle: 'آج کے اخراجات اور کاریگر ادائیگی',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCardsRow2() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'ہفتہ وار کل خرچہ',
            value: 'Rs ${_totalWeekAll.toStringAsFixed(0)}',
            iconData: Icons.date_range,
            cardColor: Colors.green,
            subtitle: 'ہفتہ وار اخراجات اور کاریگر ادائیگی',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'کاریگر بقایا',
            value: 'Rs ${_totalKarigarPendingAmount.toStringAsFixed(0)}',
            iconData: Icons.person,
            cardColor: Colors.red,
            subtitle: '$_totalKarigarPendingCount بقایا ادائیگیاں',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCardsRow3() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'کاریگر کو ادائیگی (ماہ)',
            value: 'Rs ${_totalKarigarPaidThisMonth.toStringAsFixed(0)}',
            iconData: Icons.payments,
            cardColor: Colors.purple,
            subtitle: 'اس ماہ کاریگر کو کی گئی ادائیگی',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'بقایا کاریگر',
            value: '${_workersWithPendingPayments.length}',
            iconData: Icons.people_alt,
            cardColor: Colors.deepOrange,
            subtitle: 'بقایا والے کاریگر',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData iconData,
    required Color cardColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: cardColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: cardColor, size: 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: 'NotoNastaliqUrdu',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
                fontFamily: 'NotoNastaliqUrdu',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkersWithPendingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people_alt_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text(
                'بقایا کاریگر',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'یہ وہ کاریگر ہیں جن کی ادائیگی باقی ہے',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          ..._workersWithPendingPayments.map((worker) {
            final int totalSuits = (worker['total_suits'] as int?) ?? 0;
            final int paidSuits = (worker['paid_suits'] as int?) ?? 0;
            final int pendingSuits =
                (worker['pending_suits'] as int?) ?? (totalSuits - paidSuits);
            final double ratePerSuit =
                (worker['rate_per_suit'] as num?)?.toDouble() ?? 0;
            final double pendingAmount = pendingSuits * ratePerSuit;
            final String workerName = worker['name'] ?? 'نامعلوم';
            final String workerPhone = worker['phone']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.red, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workerName,
                              style: const TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (workerPhone.isNotEmpty)
                              Text(
                                workerPhone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$pendingSuits بقایا سوٹ',
                            style: const TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs ${pendingAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'پیش رفت: ',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value:
                            totalSuits > 0 ? paidSuits / totalSuits : 0,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$paidSuits/$totalSuits',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'فی سوٹ: Rs ${ratePerSuit.toStringAsFixed(0)} • کل بقایا رقم: Rs ${pendingAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentKarigarPaymentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_rounded,
                  color: Color(0xFF1B5E20), size: 22),
              SizedBox(width: 8),
              Text(
                'حالیہ کاریگر ادائیگیاں',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'کاریگر کو کی گئی حالیہ ادائیگیوں کی تفصیل',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          ..._recentKarigarPayments.map((payment) {
            final String workerName = payment['worker_name'] ?? 'نامعلوم';
            final String paymentStatus = payment['status'] ?? 'بقایا';
            final bool isPaid = paymentStatus == 'ادا شدہ';
            final bool isPartial = paymentStatus == 'جزوی';
            final Color statusColor = isPaid
                ? Colors.green
                : (isPartial ? Colors.orange : Colors.red);
            final String suitsRange = payment['suits_range'] ?? '';
            final int numberOfSuits =
                (payment['number_of_suits'] as num?)?.toInt() ?? 0;
            final double ratePerSuit =
                (payment['rate_per_suit'] as num?)?.toDouble() ?? 0;
            final double totalAmount =
                (payment['total_amount'] as num?)?.toDouble() ?? 0;
            final double paidAmount =
                (payment['paid_amount'] as num?)?.toDouble() ?? 0;
            final String paymentDate = payment['payment_date'] ?? '';
            final String notes = payment['notes']?.toString() ?? '';

            String formattedDate = '';
            try {
              final dateTime = DateTime.tryParse(paymentDate);
              if (dateTime != null) {
                formattedDate = DateFormat('dd MMMM, yyyy').format(dateTime);
              }
            } catch (_) {
              formattedDate = paymentDate;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.person,
                            color: statusColor, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workerName,
                              style: const TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (suitsRange.isNotEmpty)
                              Text(
                                'سوٹ نمبر: $suitsRange',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          paymentStatus,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontFamily: 'NotoNastaliqUrdu',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$numberOfSuits سوٹ × Rs ${ratePerSuit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'کل: Rs ${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ادا کردہ: Rs ${paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'نوٹ: $notes',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontFamily: 'NotoNastaliqUrdu',
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryWiseSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: Color(0xFF1B5E20), size: 22),
              SizedBox(width: 8),
              Text(
                'زمرہ وار خلاصہ',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اس ماہ کے تمام اخراجات کا زمرہ وار خلاصہ (اردو میں)',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          if (_combinedCategorySummary.isEmpty)
            _buildEmptyState(
              'کوئی ڈیٹا نہیں',
              'اس مہینے کا کوئی خرچہ ریکارڈ نہیں ہوا',
            )
          else ...[
            ..._combinedCategorySummary.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value))
          ].map((entry) {
            final String categoryName = entry.key;
            final double categoryAmount = entry.value;
            final double maxAmount = _combinedCategorySummary.values.isEmpty
                ? 1.0
                : _combinedCategorySummary.values
                .reduce((a, b) => a > b ? a : b);
            final double progressRatio =
            maxAmount > 0 ? categoryAmount / maxAmount : 0.0;
            final double totalSum = _combinedCategorySummary.values
                .fold(0.0, (sum, val) => sum + val);
            final double percentage =
            totalSum > 0 ? (categoryAmount / totalSum) * 100 : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'Rs ${categoryAmount.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}٪)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentExpensesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded,
                  color: Color(0xFF1B5E20), size: 22),
              SizedBox(width: 8),
              Text(
                'حالیہ اخراجات',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'حالیہ ریکارڈ کیے گئے اخراجات',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          if (_recentExpenses.isEmpty)
            _buildEmptyState(
              'کوئی خرچ نہیں',
              'ابھی تک کوئی خرچہ ریکارڈ نہیں ہوا',
            )
          else
            ..._recentExpenses.map((expense) {
              final Color categoryColor =
              _parseColorFromHex(expense['category_color']);
              final String expenseTitle = expense['title'] ?? 'بے عنوان';
              final String rawCategoryName =
                  expense['category_name'] ?? 'نامعلوم';
              final String categoryNameUrdu =
              _translateCategoryName(rawCategoryName);
              final String expenseDate = expense['expense_date'] ?? '';
              final double expenseAmount =
                  (expense['amount'] as num?)?.toDouble() ?? 0;
              final String paymentMethod =
                  expense['payment_method'] ?? 'نقد';
              final IconData categoryIcon =
              _getIconFromName(expense['category_icon']);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(categoryIcon,
                          color: categoryColor, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expenseTitle,
                            style: const TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$categoryNameUrdu • $expenseDate',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs ${expenseAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paymentMethod,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2: EXPENSES LIST WITH ADD FUNCTIONALITY
// ═══════════════════════════════════════════════════════════════
class ExpensesListWithAddTab extends StatefulWidget {
  const ExpensesListWithAddTab({super.key});
  @override
  State<ExpensesListWithAddTab> createState() =>
      _ExpensesListWithAddTabState();
}

class _ExpensesListWithAddTabState extends State<ExpensesListWithAddTab> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;
  int? _selectedCategoryFilter;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _loadExpensesAndCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearchActive = _searchController.text.isNotEmpty;
    });
    _applyFilters();
  }

  Future<void> _loadExpensesAndCategories() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.getExpenses(),
        _db.getExpenseCategories(),
      ]);
      if (mounted) {
        setState(() {
          _expenses = results[0] as List<Map<String, dynamic>>;
          _categories = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);

    String? startDate;
    String? endDate;
    final now = DateTime.now();

    switch (_selectedDateFilter) {
      case 'آج':
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
        break;
      case 'ہفتہ':
        startDate = DateFormat('yyyy-MM-dd')
            .format(now.subtract(Duration(days: now.weekday - 1)));
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;
      case 'ماہ':
        startDate = DateFormat('yyyy-MM-dd')
            .format(DateTime(now.year, now.month, 1));
        endDate = DateFormat('yyyy-MM-dd')
            .format(DateTime(now.year, now.month + 1, 0));
        break;
      case 'سال':
        startDate =
            DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
        endDate =
            DateFormat('yyyy-MM-dd').format(DateTime(now.year, 12, 31));
        break;
    }

    final filteredExpenses = await _db.getExpenses(
      startDate: startDate,
      endDate: endDate,
      categoryId: _selectedCategoryFilter,
      searchQuery:
      _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    if (mounted) {
      setState(() {
        _expenses = filteredExpenses;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف کی تصدیق',
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'کیا آپ واقعی یہ خرچ حذف کرنا چاہتے ہیں؟',
          style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'نہیں',
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'ہاں',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      await _db.deleteExpense(expenseId);
      _loadExpensesAndCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'خرچ حذف ہو گیا',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ═══════════════ PROFESSIONAL ADD EXPENSE DIALOG ═══════════════
  Future<void> _showAddExpenseDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final imagePicker = ImagePicker();
    int? selectedCategoryId =
    _categories.isNotEmpty ? _categories.first['id'] : null;
    DateTime selectedDate = DateTime.now();
    String selectedPaymentMethod = 'نقد';
    File? selectedImage;
    bool isSaving = false;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'نیا خرچ',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'نیا خرچہ ریکارڈ کرنے کے لیے درج ذیل معلومات پُر کریں',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // عنوان
                  _buildProfessionalFormField(
                    controller: titleController,
                    labelText: 'عنوان',
                    hintText: 'خرچ کا عنوان لکھیں',
                    icon: Icons.title_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'عنوان ضروری ہے';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // زمرہ
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey),
                      decoration: const InputDecoration(
                        labelText: 'زمرہ',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.category_rounded,
                            color: Color(0xFF1B5E20), size: 20),
                      ),
                      items: _categories
                          .map((category) => DropdownMenuItem<int>(
                          value: category['id'],
                          child: Text(
                            _translateCategoryName(
                                category['name'] ?? ''),
                            style: const TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontSize: 14),
                          )))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCategoryId = value),
                      validator: (value) {
                        if (value == null) {
                          return 'زمرہ منتخب کریں';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // رقم
                  _buildProfessionalFormField(
                    controller: amountController,
                    labelText: 'رقم',
                    hintText: '0',
                    prefixText: 'Rs ',
                    icon: Icons.money_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'رقم ضروری ہے';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'درست رقم لکھیں';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // تاریخ
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF1B5E20),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setDialogState(() => selectedDate = pickedDate);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 20, color: Color(0xFF1B5E20)),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM, yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_rounded,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // طریقہ ادائیگی
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payment_rounded,
                                color: Color(0xFF1B5E20), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'طریقہ ادائیگی',
                              style: TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildPaymentMethodChip(
                              label: 'نقد',
                              icon: Icons.money_rounded,
                              isSelected: selectedPaymentMethod == 'نقد',
                              onSelected: () => setDialogState(
                                      () => selectedPaymentMethod = 'نقد'),
                            ),
                            _buildPaymentMethodChip(
                              label: 'بینک',
                              icon: Icons.account_balance_rounded,
                              isSelected: selectedPaymentMethod == 'بینک',
                              onSelected: () => setDialogState(
                                      () => selectedPaymentMethod = 'بینک'),
                            ),
                            _buildPaymentMethodChip(
                              label: 'جازکیش',
                              icon: Icons.smartphone_rounded,
                              isSelected:
                              selectedPaymentMethod == 'جازکیش',
                              onSelected: () => setDialogState(
                                      () => selectedPaymentMethod = 'جازکیش'),
                            ),
                            _buildPaymentMethodChip(
                              label: 'ایزی پیسہ',
                              icon: Icons.phone_android_rounded,
                              isSelected:
                              selectedPaymentMethod == 'ایزی پیسہ',
                              onSelected: () => setDialogState(
                                      () =>
                                  selectedPaymentMethod = 'ایزی پیسہ'),
                            ),
                            _buildPaymentMethodChip(
                              label: 'آن لائن',
                              icon: Icons.wifi_rounded,
                              isSelected: selectedPaymentMethod == 'آن لائن',
                              onSelected: () => setDialogState(
                                      () => selectedPaymentMethod = 'آن لائن'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // تفصیل
                  _buildProfessionalFormField(
                    controller: descriptionController,
                    labelText: 'تفصیل (اختیاری)',
                    hintText: 'کوئی اضافی معلومات لکھیں',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // تصویر
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.image_rounded,
                                color: Color(0xFF1B5E20), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تصویر (اختیاری)',
                              style: TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final pickedFile = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70);
                            if (pickedFile != null) {
                              setDialogState(() =>
                              selectedImage = File(pickedFile.path));
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid),
                            ),
                            child: selectedImage != null
                                ? ClipRRect(
                              borderRadius:
                              BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(selectedImage!,
                                      fit: BoxFit.cover),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setDialogState(
                                              () => selectedImage = null),
                                      child: Container(
                                        padding:
                                        const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    color: Colors.grey.shade400,
                                    size: 36),
                                const SizedBox(height: 6),
                                Text(
                                  'تصویر منتخب کرنے کے لیے کلک کریں',
                                  style: TextStyle(
                                    fontFamily: 'NotoNastaliqUrdu',
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'منسوخ',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                if (titleController.text.trim().isEmpty ||
                    amountController.text.isEmpty ||
                    selectedCategoryId == null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(
                    content: Text(
                      'براہ کرم تمام ضروری معلومات پُر کریں',
                      style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu'),
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  await _db.addExpense({
                    'category_id': selectedCategoryId,
                    'title': titleController.text.trim(),
                    'amount':
                    double.parse(amountController.text),
                    'expense_date':
                    DateFormat('yyyy-MM-dd').format(selectedDate),
                    'description':
                    descriptionController.text.trim(),
                    'payment_method': selectedPaymentMethod,
                    'image_path': selectedImage?.path,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(
                      'خرابی: $e',
                      style: const TextStyle(
                          fontFamily: 'NotoNastaliqUrdu'),
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: isSaving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'محفوظ کریں',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadExpensesAndCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'خرچ محفوظ ہو گیا',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildPaymentMethodChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFF1B5E20).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    String? prefixText,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        fontFamily: 'NotoNastaliqUrdu',
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixText: prefixText,
        hintStyle: const TextStyle(
          fontFamily: 'NotoNastaliqUrdu',
          color: Colors.grey,
          fontSize: 13,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF1B5E20), size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF1B5E20), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Color _parseColorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final cleanHex = hexString.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(
                    fontFamily: 'NotoNastaliqUrdu', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اخراجات میں تلاش کریں...',
                  hintStyle: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.grey, size: 22),
                  suffixIcon: _isSearchActive
                      ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('سب', null, isDateChip: true),
                    _buildFilterChip('آج', 'آج', isDateChip: true),
                    _buildFilterChip('ہفتہ', 'ہفتہ', isDateChip: true),
                    _buildFilterChip('ماہ', 'ماہ', isDateChip: true),
                    _buildFilterChip('سال', 'سال', isDateChip: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('تمام زمرے', null, isDateChip: false),
                    ..._categories.map((category) => _buildFilterChip(
                        _translateCategoryName(category['name'] ?? ''),
                        category['id'],
                        isDateChip: false)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expense list
        Expanded(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1B5E20)))
              : _expenses.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'کوئی خرچ موجود نہیں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'نیا خرچ شامل کرنے کے لیے نیچے دیے گئے بٹن پر کلک کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _showAddExpenseDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'نیا خرچ شامل کریں',
                    style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          )
              : Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _expenses.length,
                itemBuilder: (_, index) {
                  final expense = _expenses[index];
                  final color = _parseColorFromHex(
                      expense['category_color']);
                  final title =
                      expense['title'] ?? 'بے عنوان';
                  final rawCategoryName =
                      expense['category_name'] ?? 'نامعلوم';
                  final categoryNameUrdu =
                  _translateCategoryName(
                      rawCategoryName);
                  final date = expense['expense_date'] ?? '';
                  final amount =
                      (expense['amount'] as num?)
                          ?.toDouble() ??
                          0;
                  final method =
                      expense['payment_method'] ?? 'نقد';

                  return Dismissible(
                    key: Key('exp_${expense['id']}'),
                    direction:
                    DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(
                          right: 28),
                      margin: const EdgeInsets.only(
                          bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete,
                          color: Colors.white, size: 26),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) =>
                            AlertDialog(
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(16),
                              ),
                              title: const Text(
                                'حذف کی تصدیق',
                                style: TextStyle(
                                  fontFamily:
                                  'NotoNastaliqUrdu',
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              content: const Text(
                                'کیا آپ یہ خرچ حذف کرنا چاہتے ہیں؟',
                                style: TextStyle(
                                  fontFamily:
                                  'NotoNastaliqUrdu',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                          ctx, false),
                                  child: const Text(
                                    'نہیں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                          ctx, true),
                                  style: ElevatedButton
                                      .styleFrom(
                                    backgroundColor:
                                    Colors.red,
                                    shape:
                                    RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          10),
                                    ),
                                  ),
                                  child: const Text(
                                    'ہاں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      color:
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ) ??
                          false;
                    },
                    onDismissed: (_) =>
                        _deleteExpense(expense['id']),
                    child: Container(
                      margin: const EdgeInsets.only(
                          bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(16),
                        border: Border.all(
                            color:
                            Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.03),
                            blurRadius: 6,
                            offset:
                            const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: color
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius
                                  .circular(14),
                            ),
                            child: Icon(
                                Icons.receipt_long,
                                color: color,
                                size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily:
                                    'NotoNastaliqUrdu',
                                    fontWeight:
                                    FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(
                                    height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        categoryNameUrdu,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors
                                                .grey),
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 6),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                          color: Colors
                                              .grey
                                              .shade400,
                                          shape: BoxShape
                                              .circle),
                                    ),
                                    const SizedBox(
                                        width: 6),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors
                                              .grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs ${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                method,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _showAddExpenseDialog,
                  backgroundColor:
                  const Color(0xFF1B5E20),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, dynamic value,
      {required bool isDateChip}) {
    final bool isSelected = isDateChip
        ? _selectedDateFilter == value
        : _selectedCategoryFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isDateChip) {
              _selectedDateFilter = (_selectedDateFilter == value
                  ? null
                  : value as String?);
            } else {
              _selectedCategoryFilter = (_selectedCategoryFilter == value
                  ? null
                  : value as int?);
            }
          });
          _applyFilters();
        },
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDateChip ? Colors.blue : Colors.green)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDateChip ? Colors.blue : Colors.green)
                  : Colors.grey.shade200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontFamily: 'NotoNastaliqUrdu',
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3: KARIGAR PAYMENTS - WITH EDIT, DELETE & CUSTOM RATE
// ═══════════════════════════════════════════════════════════════
class KarigarPaymentsTab extends StatefulWidget {
  const KarigarPaymentsTab({super.key});
  @override
  State<KarigarPaymentsTab> createState() => _KarigarPaymentsTabState();
}

class _KarigarPaymentsTabState extends State<KarigarPaymentsTab> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for Add Worker dialog
  final TextEditingController _workerNameController = TextEditingController();
  final TextEditingController _workerPhoneController = TextEditingController();
  final TextEditingController _workerRateController = TextEditingController();

  // Controllers for Edit Worker dialog
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editRateController = TextEditingController();

  // Controllers for Worker Detail / Add Suits dialog
  final TextEditingController _newSuitsController = TextEditingController();

  // Controllers for Payment dialog
  final TextEditingController _paySuitsController = TextEditingController();
  final TextEditingController _payRateController = TextEditingController();
  final TextEditingController _payAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _workerNameController.dispose();
    _workerPhoneController.dispose();
    _workerRateController.dispose();
    _editNameController.dispose();
    _editPhoneController.dispose();
    _editRateController.dispose();
    _newSuitsController.dispose();
    _paySuitsController.dispose();
    _payRateController.dispose();
    _payAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _db.getWorkers(),
        _db.getKarigarPayments(),
      ]);
      if (mounted) {
        setState(() {
          _workers = results[0] as List<Map<String, dynamic>>;
          _payments = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ڈیٹا لوڈ کرنے میں خرابی: $e';
        });
      }
    }
  }

  // ═══════════════ ADD WORKER DIALOG ═══════════════
  Future<void> _showAddWorkerDialog() async {
    _workerNameController.clear();
    _workerPhoneController.clear();
    _workerRateController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text(
              'نیا کاریگر',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: _workerNameController,
                label: 'نام',
                hint: 'کاریگر کا نام لکھیں',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _buildDialogTextField(
                controller: _workerPhoneController,
                label: 'فون نمبر',
                hint: '03XXXXXXXXX',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _buildDialogTextField(
                controller: _workerRateController,
                label: 'فی سوٹ ریٹ',
                prefix: 'Rs ',
                hint: '0',
                icon: Icons.money_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'منسوخ',
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_workerNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text(
                    'براہ کرم نام لکھیں',
                    style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'محفوظ',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && _workerNameController.text.isNotEmpty) {
      await _db.addWorker({
        'name': _workerNameController.text.trim(),
        'phone': _workerPhoneController.text.trim(),
        'rate_per_suit':
        double.tryParse(_workerRateController.text) ?? 0,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'کاریگر شامل ہو گیا',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ═══════════════ EDIT WORKER DIALOG ═══════════════
  Future<void> _showEditWorkerDialog(Map<String, dynamic> worker) async {
    final int workerId = worker['id'] as int;
    _editNameController.text = worker['name'] ?? '';
    _editPhoneController.text = worker['phone']?.toString() ?? '';
    _editRateController.text =
        ((worker['rate_per_suit'] as num?)?.toDouble() ?? 0).toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'کاریگر میں ترمیم',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'نوٹ: ریٹ تبدیل کرنے سے پچھلی ادائیگیوں پر کوئی اثر نہیں پڑے گا۔',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDialogTextField(
                controller: _editNameController,
                label: 'نام',
                hint: 'کاریگر کا نام',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _buildDialogTextField(
                controller: _editPhoneController,
                label: 'فون نمبر',
                hint: '03XXXXXXXXX',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _buildDialogTextField(
                controller: _editRateController,
                label: 'فی سوٹ ریٹ',
                prefix: 'Rs ',
                hint: '0',
                icon: Icons.money_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'منسوخ',
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_editNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text(
                    'براہ کرم نام لکھیں',
                    style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'اپڈیٹ کریں',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && _editNameController.text.isNotEmpty) {
      await _db.updateWorker(workerId, {
        'name': _editNameController.text.trim(),
        'phone': _editPhoneController.text.trim(),
        'rate_per_suit': double.tryParse(_editRateController.text) ?? 0,
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'کاریگر اپڈیٹ ہو گیا',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ═══════════════ DELETE WORKER DIALOG ═══════════════
  Future<void> _showDeleteWorkerDialog(Map<String, dynamic> worker) async {
    final int workerId = worker['id'] as int;
    final String workerName = worker['name'] ?? 'نامعلوم';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'کاریگر حذف کریں؟',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'کیا آپ "$workerName" کو مستقل طور پر حذف کرنا چاہتے ہیں؟\n\n'
              'اس کاریگر سے متعلق تمام ادائیگیوں کا ریکارڈ بھی حذف ہو جائے گا۔',
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'منسوخ',
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'حذف کریں',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteWorker(workerId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'کاریگر حذف ہو گیا',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ═══════════════ WORKER DETAIL DIALOG ═══════════════
  Future<void> _showWorkerDetailDialog(Map<String, dynamic> worker) async {
    final int workerId = worker['id'] as int;
    final String workerName = worker['name'] ?? 'نامعلوم';
    final double ratePerSuit =
        (worker['rate_per_suit'] as num?)?.toDouble() ?? 0;
    final int totalSuits = (worker['total_suits'] as int?) ?? 0;
    final int paidSuits = (worker['paid_suits'] as int?) ?? 0;
    final int pendingSuits = totalSuits - paidSuits;

    _newSuitsController.clear();

    final List<Map<String, dynamic>> workerPayments =
    await _db.getKarigarPayments(workerId: workerId);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final int newSuitsToAdd =
              int.tryParse(_newSuitsController.text) ?? 0;
          final int futureTotalSuits = totalSuits + newSuitsToAdd;
          final int futurePendingSuits = pendingSuits + newSuitsToAdd;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    workerName,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditWorkerDialog(worker);
                  },
                  icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 22),
                  tooltip: 'ترمیم کریں',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeleteWorkerDialog(worker);
                  },
                  icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                  tooltip: 'حذف کریں',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoColumn(
                                'کل سوٹ', '$totalSuits', Colors.white),
                            _buildInfoColumn('ادا شدہ', '$paidSuits',
                                Colors.green.shade200),
                            _buildInfoColumn('بقایا', '$pendingSuits',
                                Colors.orange.shade200),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoColumn('فی سوٹ ریٹ',
                                'Rs ${ratePerSuit.toStringAsFixed(0)}', Colors.white70),
                            _buildInfoColumn('بقایا رقم',
                                'Rs ${(pendingSuits * ratePerSuit).toStringAsFixed(0)}',
                                Colors.red.shade200),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'سوٹ کی تفصیل',
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (totalSuits > 0) ...[
                    Row(
                      children: [
                        const Text(
                          'پیش رفت: ',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: totalSuits > 0
                                  ? paidSuits / totalSuits
                                  : 0,
                              minHeight: 18,
                              backgroundColor: Colors.red.shade100,
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Colors.green),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$paidSuits/$totalSuits',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLegendDot(Colors.green, 'ادا شدہ'),
                        const SizedBox(width: 16),
                        _buildLegendDot(Colors.red, 'بقایا'),
                      ],
                    ),
                  ] else
                    const Text(
                      'ابھی تک کوئی سوٹ شامل نہیں',
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  const Divider(height: 28),
                  const Text(
                    'نئے سوٹ شامل کریں',
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pendingSuits > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'فی الحال $pendingSuits سوٹ بقایا ہیں۔ نئے سوٹ شامل کرنے سے بقایا بڑھ جائے گا۔',
                              style: const TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildDialogTextField(
                    controller: _newSuitsController,
                    label: 'نئے سوٹ کی تعداد',
                    hint: 'کتنی سوٹ شامل کرنی ہیں؟',
                    icon: Icons.add_circle_outline_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (newSuitsToAdd > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewRow(
                              'موجودہ بقایا سوٹ', '$pendingSuits سوٹ'),
                          const SizedBox(height: 5),
                          _buildPreviewRow('نئے سوٹ', '$newSuitsToAdd سوٹ'),
                          const Divider(height: 16),
                          _buildPreviewRow('کل بقایا ہو جائیں گے',
                              '$futurePendingSuits سوٹ',
                              isBold: true),
                          const SizedBox(height: 5),
                          _buildPreviewRow('کل سوٹ ہو جائیں گے',
                              '$futureTotalSuits سوٹ'),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ادائیگی کی تاریخ',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${workerPayments.length} ادائیگیاں',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (workerPayments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'کوئی ادائیگی ریکارڈ نہیں',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ...workerPayments.take(10).map((payment) {
                      final String status = payment['status'] ?? 'بقایا';
                      final bool isPaid = status == 'ادا شدہ';
                      final String suitsRange =
                          payment['suits_range'] ?? '';
                      final int numberOfSuits =
                          (payment['number_of_suits'] as num?)
                              ?.toInt() ??
                              0;
                      final double paidAmount =
                          (payment['paid_amount'] as num?)
                              ?.toDouble() ??
                              0;
                      final double totalAmount =
                          (payment['total_amount'] as num?)
                              ?.toDouble() ??
                              0;
                      final String paymentDate =
                          payment['payment_date'] ?? '';
                      String formattedDate = '';
                      try {
                        final dateTime =
                        DateTime.tryParse(paymentDate);
                        if (dateTime != null) {
                          formattedDate = DateFormat('dd/MM/yyyy')
                              .format(dateTime);
                        }
                      } catch (_) {
                        formattedDate = paymentDate;
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'سوٹ: $suitsRange • $numberOfSuits سوٹ',
                                    style: const TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Rs ${paidAmount.toStringAsFixed(0)} / Rs ${totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'بند کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: newSuitsToAdd > 0
                    ? () async {
                  await _db.updateWorkerSuits(
                      workerId, newSuitsToAdd);
                  Navigator.pop(ctx);
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(
                        '$newSuitsToAdd نئے سوٹ شامل ہو گئے',
                        style: const TextStyle(
                            fontFamily:
                            'NotoNastaliqUrdu'),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'سوٹ محفوظ کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════ ADD PAYMENT DIALOG WITH CUSTOM RATE ═══════════════
  Future<void> _showAddPaymentDialog() async {
    if (_workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'پہلے کاریگر شامل کریں',
          style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    int? selectedWorkerId = _workers.first['id'];
    double defaultRatePerSuit =
        (_workers.first['rate_per_suit'] as num?)?.toDouble() ?? 0;
    double currentRatePerSuit = defaultRatePerSuit;
    int pendingSuits = ((_workers.first['total_suits'] as int?) ?? 0) -
        ((_workers.first['paid_suits'] as int?) ?? 0);
    _paySuitsController.clear();
    _payRateController.text = defaultRatePerSuit.toString();
    _payAmountController.clear();
    _notesController.clear();
    bool isRateChanged = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int suitsToPay =
              int.tryParse(_paySuitsController.text) ?? 0;
          double calculatedTotal = suitsToPay * currentRatePerSuit;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.payments_rounded,
                    color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  'کاریگر ادائیگی',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedWorkerId,
                    isExpanded: true,
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey),
                    decoration: InputDecoration(
                      labelText: 'کاریگر منتخب کریں',
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.person_rounded,
                          color: Color(0xFF1B5E20)),
                    ),
                    items: _workers.map((worker) {
                      int pending =
                          ((worker['total_suits'] as int?) ?? 0) -
                              ((worker['paid_suits'] as int?) ?? 0);
                      return DropdownMenuItem<int>(
                        value: worker['id'],
                        child: Text(
                          '${worker['name']} (بقایا سوٹ: $pending)',
                          style: const TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedWorkerId = value;
                        final selectedWorker = _workers
                            .firstWhere((w) => w['id'] == value);
                        defaultRatePerSuit =
                            (selectedWorker['rate_per_suit']
                            as num?)
                                ?.toDouble() ??
                                0;
                        currentRatePerSuit = defaultRatePerSuit;
                        pendingSuits =
                            ((selectedWorker['total_suits']
                            as int?) ??
                                0) -
                                ((selectedWorker['paid_suits']
                                as int?) ??
                                    0);
                        _paySuitsController.clear();
                        _payRateController.text =
                            defaultRatePerSuit.toString();
                        _payAmountController.clear();
                        suitsToPay = 0;
                        calculatedTotal = 0;
                        isRateChanged = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Default rate info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'طے شدہ ریٹ:',
                              style: TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'Rs ${defaultRatePerSuit.toStringAsFixed(0)} فی سوٹ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pending suits
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pendingSuits > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pendingSuits > 0
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'بقایا سوٹ:',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$pendingSuits سوٹ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: pendingSuits > 0
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pendingSuits == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'اس کاریگر کے تمام سوٹ ادا ہو چکے ہیں',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Number of suits to pay
                  _buildDialogTextField(
                    controller: _paySuitsController,
                    label: 'ادا کیے جانے والے سوٹ',
                    hint: 'تعداد لکھیں',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setDialogState(() {
                        suitsToPay = int.tryParse(
                            _paySuitsController.text) ??
                            0;
                        calculatedTotal =
                            suitsToPay * currentRatePerSuit;
                        if (calculatedTotal > 0) {
                          _payAmountController.text =
                              calculatedTotal
                                  .toStringAsFixed(0);
                        } else {
                          _payAmountController.clear();
                        }
                      });
                    },
                  ),

                  // ═══════ CUSTOM RATE PER SUIT ═══════
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRateChanged
                          ? Colors.purple.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRateChanged
                            ? Colors.purple.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isRateChanged
                                  ? Icons.change_circle_rounded
                                  : Icons.price_change_rounded,
                              color: isRateChanged
                                  ? Colors.purple
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'فی سوٹ قیمت (اختیاری)',
                              style: TextStyle(
                                fontFamily: 'NotoNastaliqUrdu',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isRateChanged
                                    ? Colors.purple
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (isRateChanged)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'تبدیل شدہ',
                                  style: TextStyle(
                                    fontFamily: 'NotoNastaliqUrdu',
                                    fontSize: 9,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اگر قیمت کم یا زیادہ ہوئی تو یہاں نئی قیمت لکھیں',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _payRateController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontFamily: 'NotoNastaliqUrdu',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isRateChanged
                                      ? Colors.purple
                                      : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  prefixText: 'Rs ',
                                  hintText: defaultRatePerSuit
                                      .toString(),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    final newRate =
                                    double.tryParse(value);
                                    if (newRate != null &&
                                        newRate > 0) {
                                      currentRatePerSuit = newRate;
                                      isRateChanged =
                                          currentRatePerSuit !=
                                              defaultRatePerSuit;
                                      calculatedTotal = suitsToPay *
                                          currentRatePerSuit;
                                      if (calculatedTotal > 0) {
                                        _payAmountController.text =
                                            calculatedTotal
                                                .toStringAsFixed(
                                                0);
                                      }
                                    } else {
                                      currentRatePerSuit =
                                          defaultRatePerSuit;
                                      isRateChanged = false;
                                      calculatedTotal = suitsToPay *
                                          currentRatePerSuit;
                                      if (calculatedTotal > 0) {
                                        _payAmountController.text =
                                            calculatedTotal
                                                .toStringAsFixed(
                                                0);
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isRateChanged)
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    currentRatePerSuit =
                                        defaultRatePerSuit;
                                    isRateChanged = false;
                                    _payRateController.text =
                                        defaultRatePerSuit
                                            .toString();
                                    calculatedTotal = suitsToPay *
                                        currentRatePerSuit;
                                    if (calculatedTotal > 0) {
                                      _payAmountController.text =
                                          calculatedTotal
                                              .toStringAsFixed(0);
                                    }
                                  });
                                },
                                icon: const Icon(
                                  Icons.restore_rounded,
                                  color: Colors.purple,
                                ),
                                tooltip: 'اصل ریٹ بحال کریں',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (suitsToPay > pendingSuits && pendingSuits > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'آپ بقایا سوٹ ($pendingSuits) سے زیادہ ادائیگی نہیں کر سکتے',
                        style: const TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),

                  if (calculatedTotal > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRateChanged
                            ? Colors.purple.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isRateChanged
                              ? Colors.purple.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'کل رقم:',
                                style: TextStyle(
                                  fontFamily:
                                  'NotoNastaliqUrdu',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (isRateChanged)
                                Text(
                                  '($suitsToPay سوٹ × Rs ${currentRatePerSuit.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontFamily:
                                    'NotoNastaliqUrdu',
                                    fontSize: 10,
                                    color: Colors.purple,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            'Rs ${calculatedTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: isRateChanged
                                  ? Colors.purple
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isRateChanged)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          currentRatePerSuit > defaultRatePerSuit
                              ? 'قیمت میں اضافہ: Rs ${(currentRatePerSuit - defaultRatePerSuit).toStringAsFixed(0)} فی سوٹ'
                              : 'قیمت میں کمی: Rs ${(defaultRatePerSuit - currentRatePerSuit).toStringAsFixed(0)} فی سوٹ',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 11,
                            color: currentRatePerSuit >
                                defaultRatePerSuit
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 16),

                  // Paid amount
                  _buildDialogTextField(
                    controller: _payAmountController,
                    label: 'ادا کردہ رقم',
                    prefix: 'Rs ',
                    hint: calculatedTotal > 0
                        ? calculatedTotal.toStringAsFixed(0)
                        : '0',
                    icon: Icons.money_rounded,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  // Notes
                  _buildDialogTextField(
                    controller: _notesController,
                    label: 'نوٹس (اختیاری)',
                    hint: 'کوئی اضافی معلومات لکھیں',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _paySuitsController.clear();
                  _payRateController.text =
                      defaultRatePerSuit.toString();
                  _payAmountController.clear();
                  _notesController.clear();
                  Navigator.pop(ctx, false);
                },
                child: const Text(
                  'منسوخ',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: suitsToPay > 0 &&
                    selectedWorkerId != null &&
                    suitsToPay <= pendingSuits
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ادائیگی محفوظ کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == true &&
        selectedWorkerId != null &&
        _paySuitsController.text.isNotEmpty) {
      final worker =
      _workers.firstWhere((w) => w['id'] == selectedWorkerId);
      final double finalRate =
          double.tryParse(_payRateController.text) ??
              (worker['rate_per_suit'] as num?)?.toDouble() ??
              0;
      int suits = int.tryParse(_paySuitsController.text) ?? 0;
      double total = finalRate * suits;
      double paid =
          double.tryParse(_payAmountController.text) ?? total;
      String status =
      paid >= total ? 'ادا شدہ' : (paid > 0 ? 'جزوی' : 'بقایا');

      await _db.addKarigarPayment({
        'worker_id': selectedWorkerId,
        'number_of_suits': suits,
        'rate_per_suit': finalRate,
        'total_amount': total,
        'paid_amount': paid,
        'payment_date':
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'status': status,
        'notes': _notesController.text.trim(),
      });

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'ادائیگی محفوظ ہو گئی',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildPreviewRow(String label, String value,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.blue.shade900 : Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.9),
            fontFamily: 'NotoNastaliqUrdu',
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'NotoNastaliqUrdu', fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        hintStyle: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu', color: Colors.grey),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF1B5E20), size: 20)
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFF1B5E20), width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 52, color: Colors.red),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  color: Colors.red,
                  fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'دوبارہ کوشش کریں',
                style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  onPressed: _showAddWorkerDialog,
                  icon: Icons.person_add_rounded,
                  label: 'نیا کاریگر',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  onPressed: _showAddPaymentDialog,
                  icon: Icons.payments_rounded,
                  label: 'ادائیگی',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'کاریگر',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'کسی بھی کاریگر پر کلک کر کے تفصیلات دیکھیں۔ دیر تک دبا کر ترمیم یا حذف کریں۔',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          if (_workers.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off_rounded,
                        size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'کوئی کاریگر موجود نہیں',
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'نیا کاریگر شامل کرنے کے لیے اوپر دیا گیا بٹن استعمال کریں',
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._workers.map((worker) {
              final int totalSuits =
                  (worker['total_suits'] as int?) ?? 0;
              final int paidSuits =
                  (worker['paid_suits'] as int?) ?? 0;
              final int pendingSuits = totalSuits - paidSuits;
              final double rate =
                  (worker['rate_per_suit'] as num?)?.toDouble() ??
                      0;
              final double pendingAmount = pendingSuits * rate;
              final String name = worker['name'] ?? 'نامعلوم';
              final String phone =
                  worker['phone']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () =>
                        _showWorkerDetailDialog(worker),
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (sheetCtx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 50,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'NotoNastaliqUrdu',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.edit_rounded,
                                        color: Colors.orange),
                                  ),
                                  title: const Text(
                                    'ترمیم کریں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'نام، فون یا ریٹ تبدیل کریں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    _showEditWorkerDialog(worker);
                                  },
                                ),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.delete_rounded,
                                        color: Colors.red),
                                  ),
                                  title: const Text(
                                    'حذف کریں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'کاریگر اور اس کی ادائیگیاں حذف کریں',
                                    style: TextStyle(
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    _showDeleteWorkerDialog(worker);
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1B5E20),
                                      Color(0xFF2E7D32)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily:
                                        'NotoNastaliqUrdu',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          if (totalSuits > 0) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text(
                                  'سوٹ: ',
                                  style: TextStyle(
                                    fontFamily:
                                    'NotoNastaliqUrdu',
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: totalSuits > 0
                                          ? paidSuits / totalSuits
                                          : 0,
                                      minHeight: 12,
                                      backgroundColor:
                                      Colors.red.shade100,
                                      valueColor:
                                      const AlwaysStoppedAnimation<
                                          Color>(Colors.green),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$paidSuits/$totalSuits',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rs ${rate.toStringAsFixed(0)} فی سوٹ',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (pendingSuits > 0)
                                  Text(
                                    'بقایا: $pendingSuits سوٹ • Rs ${pendingAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  const Text(
                                    'تمام ادا شدہ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontFamily:
                                      'NotoNastaliqUrdu',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                'ابھی تک کوئی سوٹ شامل نہیں',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'حالیہ ادائیگیاں',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (_payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'کوئی ادائیگی ریکارڈ نہیں',
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._payments.take(15).map((payment) {
              final String status = payment['status'] ?? 'بقایا';
              final bool isPaid = status == 'ادا شدہ';
              final bool isPartial = status == 'جزوی';
              final Color borderColor = isPaid
                  ? Colors.green
                  : (isPartial ? Colors.orange : Colors.red);
              final Color bgColor = isPaid
                  ? Colors.green.shade50
                  : (isPartial
                  ? Colors.orange.shade50
                  : Colors.red.shade50);
              final Color textColor = isPaid
                  ? Colors.green
                  : (isPartial ? Colors.orange : Colors.red);
              final String workerName =
                  payment['worker_name'] ?? 'نامعلوم';
              final String suitsRange =
                  payment['suits_range'] ?? '';
              final int numberOfSuits =
                  (payment['number_of_suits'] as num?)?.toInt() ?? 0;
              final double ratePerSuit =
                  (payment['rate_per_suit'] as num?)?.toDouble() ?? 0;
              final double totalAmount =
                  (payment['total_amount'] as num?)?.toDouble() ?? 0;
              final double paidAmount =
                  (payment['paid_amount'] as num?)?.toDouble() ?? 0;
              final String notes =
                  payment['notes']?.toString() ?? '';
              final String paymentDate = payment['payment_date'] ?? '';
              String formattedDate = '';
              try {
                final dateTime = DateTime.tryParse(paymentDate);
                if (dateTime != null) {
                  formattedDate =
                      DateFormat('dd MMMM, yyyy').format(dateTime);
                }
              } catch (_) {
                formattedDate = paymentDate;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                  Border.all(color: borderColor.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            workerName,
                            style: const TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor,
                              fontFamily: 'NotoNastaliqUrdu',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (suitsRange.isNotEmpty)
                      Text(
                        'سوٹ نمبر: $suitsRange',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      '$numberOfSuits سوٹ × Rs ${ratePerSuit.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'کل: Rs ${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'ادا: Rs ${paidAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'نوٹ: $notes',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'NotoNastaliqUrdu',
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'NotoNastaliqUrdu',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 3,
      ),
    );
  }
}