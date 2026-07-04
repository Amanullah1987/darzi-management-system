import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'take_measurement_screen.dart';
import 'new_order_screen.dart';
import 'order_management_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _customers = [];
  Map<int, Map<String, dynamic>> _customerStats = {};
  bool _isLoading = true;
  String _searchQuery = '';

  late AnimationController _listAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOut,
    );
    _listAnimationController.forward();
    _loadCustomers();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers
        .where((c) =>
    c['name']
        .toString()
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()) ||
        c['phone']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getCustomers();
    if (!mounted) return;

    // Load stats for each customer
    final Map<int, Map<String, dynamic>> stats = {};
    for (var customer in data) {
      final id = customer['id'] as int;
      try {
        final summary =
        await DatabaseHelper.instance.getCustomerFinancialSummary(id);
        final orders =
        await DatabaseHelper.instance.getCustomerOrders(id);
        int totalOrders = orders.length;
        int pendingOrders =
            orders.where((o) => o['status'] == 'Pending').length;
        int completedOrders =
            orders.where((o) => o['status'] == 'Completed').length;
        int deliveredOrders =
            orders.where((o) => o['status'] == 'Delivered').length;

        stats[id] = {
          'totalOrders': totalOrders,
          'pendingOrders': pendingOrders,
          'completedOrders': completedOrders,
          'deliveredOrders': deliveredOrders,
          'totalPurchases': summary['total_purchases'] ?? 0,
          'totalPayments': summary['total_payments'] ?? 0,
          'balance': summary['balance'] ?? 0,
        };
      } catch (e) {
        stats[id] = {
          'totalOrders': 0,
          'pendingOrders': 0,
          'completedOrders': 0,
          'deliveredOrders': 0,
          'totalPurchases': 0,
          'totalPayments': 0,
          'balance': 0,
        };
      }
    }

    if (mounted) {
      setState(() {
        _customers = data;
        _customerStats = stats;
        _isLoading = false;
      });
      _listAnimationController.forward(from: 0);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showCustomerDialog({Map<String, dynamic>? data}) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final addressCtrl = TextEditingController(text: data?['address'] ?? '');
    final isEditing = data != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isEditing
                              ? [Colors.blue.shade400, Colors.blue.shade600]
                              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEditing ? Icons.edit : Icons.person_add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEditing ? "کسٹمر میں ترمیم" : "نیا کسٹمر شامل کریں",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEditing
                          ? "کسٹمر کی معلومات اپڈیٹ کریں"
                          : "نئے کسٹمر کی تفصیلات درج کریں",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextFormField(
                        controller: nameCtrl,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        autofocus: true,
                        style: const TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 18,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'براہ کرم نام درج کریں' : null,
                        decoration: InputDecoration(
                          hintText: "کسٹمر کا نام لکھیں...",
                          hintStyle: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey[400], fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.person, color: isEditing ? Colors.blue : const Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18),
                        validator: (v) => v == null || v.trim().isEmpty ? 'براہ کرم فون نمبر درج کریں' : null,
                        decoration: InputDecoration(
                          hintText: "موبائل نمبر لکھیں...",
                          hintStyle: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey[400], fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.phone, color: isEditing ? Colors.blue : const Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextFormField(
                        controller: addressCtrl,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "پتہ لکھیں... (اختیاری)",
                          hintStyle: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey[400], fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Icon(Icons.location_on, color: isEditing ? Colors.blue : const Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text("منسوخ", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;

                              if (!isEditing) {
                                await DatabaseHelper.instance.insertCustomer(
                                  nameCtrl.text, phoneCtrl.text, addressCtrl.text,
                                );
                              } else {
                                await DatabaseHelper.instance.updateCustomer(
                                  data['id'], nameCtrl.text, phoneCtrl.text, addressCtrl.text,
                                );
                              }
                              if (!mounted) return;
                              Navigator.pop(context);
                              _showSnackBar(isEditing ? "کسٹمر اپڈیٹ ہو گیا ✅" : "کسٹمر محفوظ ہو گیا ✅");
                              _loadCustomers();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditing ? Colors.blue : const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 3,
                              shadowColor: (isEditing ? Colors.blue : const Color(0xFF6366F1)).withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              isEditing ? "اپڈیٹ کریں" : "محفوظ کریں",
                              style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onMenuSelected(String value, Map<String, dynamic> customer) async {
    if (value == "نیا آرڈر") {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => NewOrderScreen(customer: customer)));
      _loadCustomers();
    } else if (value == "نیا ناپ") {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => TakeMeasurementScreen(customer: customer)));
    } else if (value == "آرڈر کی تفصیل") {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => OrderManagementScreen(customer: customer)));
      _loadCustomers();
    } else if (value == "ایڈیٹ کریں") {
      _showCustomerDialog(data: customer);
    } else if (value == "حذف کریں") {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 36),
                ),
                const SizedBox(height: 20),
                const Text("حذف کرنے کی تصدیق", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('کیا آپ واقعی "${customer['name']}" کو حذف کرنا چاہتے ہیں؟', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("منسوخ", style: TextStyle(fontFamily: 'NotoNastaliqUrdu')))),
                    const SizedBox(width: 14),
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 3, shadowColor: Colors.red.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("حذف کریں", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirm == true) {
        await DatabaseHelper.instance.deleteCustomer(customer['id']);
        _showSnackBar("کسٹمر حذف ہو گیا ✅");
        _loadCustomers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text("کسٹمرز", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 15),
                decoration: InputDecoration(
                  hintText: "نام یا فون نمبر سے تلاش کریں...",
                  hintStyle: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400]), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))]),
        child: FloatingActionButton.extended(
          onPressed: () => _showCustomerDialog(),
          backgroundColor: const Color(0xFF6366F1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add, color: Colors.white, size: 22),
          label: const Text("نیا کسٹمر", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))]), child: const CircularProgressIndicator(color: Color(0xFF1A1A2E), strokeWidth: 3)),
          const SizedBox(height: 20),
          const Text("ڈیٹا لوڈ ہو رہا ہے...", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey, fontSize: 15)),
        ]),
      )
          : _filteredCustomers.isEmpty
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline, size: 60, color: Colors.grey[400])),
          const SizedBox(height: 20),
          Text(_searchQuery.isNotEmpty ? "کوئی نتیجہ نہیں ملا" : "کوئی کسٹمر موجود نہیں", style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(_searchQuery.isNotEmpty ? "براہ کرم مختلف الفاظ استعمال کریں" : "نیا کسٹمر شامل کرنے کے لیے نیچے دیئے گئے بٹن پر کلک کریں", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: Colors.grey[400])),
        ]),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _filteredCustomers.length,
          itemBuilder: (_, index) {
            final customer = _filteredCustomers[index];
            final stats = _customerStats[customer['id']] ?? {};
            final totalOrders = stats['totalOrders'] ?? 0;
            final pendingOrders = stats['pendingOrders'] ?? 0;
            final completedOrders = stats['completedOrders'] ?? 0;
            final deliveredOrders = stats['deliveredOrders'] ?? 0;
            final balance = (stats['balance'] is num) ? (stats['balance'] as num).toDouble() : 0.0;
            final totalPurchases = (stats['totalPurchases'] is num) ? (stats['totalPurchases'] as num).toDouble() : 0.0;

            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _listAnimationController, curve: Interval(index * 0.05, 1.0, curve: Curves.easeOut))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderManagementScreen(customer: customer))).then((_) => _loadCustomers()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Name, Phone, Menu
                          Row(
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: balance > 0 ? [Colors.red.shade300, Colors.red.shade500] : [const Color(0xFF10B981), const Color(0xFF059669)]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    customer['name']?.toString().isNotEmpty == true ? customer['name'].toString()[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'NotoNastaliqUrdu', color: Color(0xFF1A1A2E))),
                                    const SizedBox(height: 3),
                                    Row(children: [const Icon(Icons.phone, size: 13, color: Colors.grey), const SizedBox(width: 4), Text(customer['phone'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13))]),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onSelected: (value) => _onMenuSelected(value, customer),
                                itemBuilder: (context) => [
                                  _popupItem("نیا آرڈر", Icons.add_shopping_cart, Colors.green),
                                  _popupItem("نیا ناپ", Icons.straighten, Colors.cyan),
                                  _popupItem("آرڈر کی تفصیل", Icons.list_alt, Colors.blue),
                                  _popupItem("ایڈیٹ کریں", Icons.edit, Colors.orange),
                                  _popupItem("حذف کریں", Icons.delete, Colors.red),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Divider
                          Container(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 14),
                          // Stats Row
                          Row(
                            children: [
                              _statChip('کل آرڈرز', '$totalOrders', Icons.receipt_long, const Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              _statChip('زیر التواء', '$pendingOrders', Icons.hourglass_empty, Colors.orange),
                              const SizedBox(width: 8),
                              _statChip('مکمل', '$completedOrders', Icons.check_circle, Colors.green),
                              const SizedBox(width: 8),
                              _statChip('ڈیلیور', '$deliveredOrders', Icons.local_shipping, Colors.blue),
                            ].expand((widget) => [widget, if (widget.key != 'ڈیلیور') const Spacer()]).toList(),
                          ),
                          const SizedBox(height: 12),
                          // Financial Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                                  child: Column(children: [
                                    Text('کل رقم', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'NotoNastaliqUrdu')),
                                    const SizedBox(height: 2),
                                    FittedBox(child: Text('₨ ${totalPurchases.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6366F1)))),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Column(children: [
                                    Text('بقایا', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'NotoNastaliqUrdu')),
                                    const SizedBox(height: 2),
                                    FittedBox(child: Text('₨ ${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: balance > 0 ? Colors.red : Colors.green))),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontFamily: 'NotoNastaliqUrdu')),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(String text, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: text,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14)),
        ],
      ),
    );
  }
}