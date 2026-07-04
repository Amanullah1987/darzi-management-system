import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import 'new_order_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  PROFESSIONAL DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class AppTheme {
  static const primary = Color(0xFF1B5E20);
  static const primaryLight = Color(0xFF4CAF50);
  static const primaryDark = Color(0xFF0D3B0F);
  static const accent = Color(0xFFFF6F00);
  static const accentLight = Color(0xFFFFA000);
  static const bg = Color(0xFFF5F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFF8F9FB);
  static const textPrimary = Color(0xFF1A1D26);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF0F0F0);

  static BoxShadow shadowXs = BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2, offset: const Offset(0, 1));
  static BoxShadow shadowSm = BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2));
  static BoxShadow shadowMd = BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4));
  static BoxShadow shadowLg = BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8));

  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radius2xl = 24.0;
}

// ═══════════════════════════════════════════════════════════════
//  ORDER MANAGEMENT SCREEN
// ═══════════════════════════════════════════════════════════════
class OrderManagementScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const OrderManagementScreen({super.key, required this.customer});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _customerOrders = [];
  List<Map<String, dynamic>> _ordersWithPayments = [];
  List<Map<String, dynamic>> _silaiTypes = [];
  int? _selectedSilaiId;
  List<Map<String, dynamic>> _naapTypes = [];
  Map<int, String> _measurementValues = {};
  Map<String, dynamic> _customerSummary = {};
  List<Map<String, dynamic>> _payments = [];

  bool _isLoadingOrders = true;
  bool _isLoadingMeasurements = true;
  bool _isLoadingPayments = true;
  bool _isGeneratingPdf = false;

  pw.Font? _cachedUrduFont;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadTabData(_tabController.index);
    });
    _loadAllInitialData();
    _loadUrduFontForPdf();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUrduFontForPdf() async {
    try {
      _cachedUrduFont = await PdfGoogleFonts.notoNaskhArabicRegular();
      if (mounted) setState(() {});
    } catch (e) {
      _cachedUrduFont = pw.Font.helvetica();
    }
  }

  Future<void> _loadAllInitialData() async {
    await Future.wait([_loadOrders(), _loadSilaiTypes(), _loadPayments()]);
  }

  Future<void> _loadTabData(int tabIndex) async {
    switch (tabIndex) {
      case 0: await _loadOrders(); break;
      case 1: await _loadSilaiTypes(); break;
      case 2: await _loadPayments(); break;
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final cid = widget.customer['id'];
      _customerOrders = await DatabaseHelper.instance.getCustomerOrders(cid);
      _ordersWithPayments = await DatabaseHelper.instance.getOrdersWithPayments(cid);
      setState(() => _isLoadingOrders = false);
    } catch (e) {
      setState(() => _isLoadingOrders = false);
      _snack('آرڈرز لوڈ کرنے میں خرابی', false);
    }
  }

  Future<void> _loadSilaiTypes() async {
    setState(() => _isLoadingMeasurements = true);
    try {
      _silaiTypes = await DatabaseHelper.instance.getSilaiTypes();
      if (_selectedSilaiId != null) {
        await _loadNaapTypesAndMeasurements();
      } else if (_silaiTypes.isNotEmpty) {
        _selectedSilaiId = _silaiTypes.first['id'];
        await _loadNaapTypesAndMeasurements();
      }
      setState(() => _isLoadingMeasurements = false);
    } catch (e) {
      setState(() => _isLoadingMeasurements = false);
    }
  }

  Future<void> _loadNaapTypesAndMeasurements() async {
    if (_selectedSilaiId == null) return;
    try {
      final cid = widget.customer['id'];
      _naapTypes = await DatabaseHelper.instance.getNaapTypesBySilai(_selectedSilaiId!);
      _measurementValues = await DatabaseHelper.instance.getCustomerMeasurements(cid, _selectedSilaiId!);
      for (var n in _naapTypes) {
        if (!_measurementValues.containsKey(n['id'])) _measurementValues[n['id']] = '';
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoadingPayments = true);
    try {
      final cid = widget.customer['id'];
      _customerSummary = await DatabaseHelper.instance.getCustomerFinancialSummary(cid);
      _payments = await DatabaseHelper.instance.getPaymentsByCustomer(cid);
      setState(() => _isLoadingPayments = false);
    } catch (e) {
      setState(() => _isLoadingPayments = false);
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: ok ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return double.tryParse(v.toString())?.toInt() ?? 0;
  }

  String _fmt(String? ds) {
    if (ds == null || ds.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(ds.split(' ')[0]);
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return ds;
    }
  }

  String _statusUrdu(String s) {
    switch (s.toString().toLowerCase()) {
      case 'pending': return 'زیر التواء';
      case 'completed': return 'مکمل';
      case 'delivered': return 'ڈیلیورڈ';
      case 'cancelled': return 'منسوخ';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s.toString().toLowerCase()) {
      case 'pending': return AppTheme.warning;
      case 'completed': return AppTheme.success;
      case 'delivered': return AppTheme.info;
      case 'cancelled': return AppTheme.danger;
      default: return AppTheme.textHint;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toString().toLowerCase()) {
      case 'pending': return Icons.schedule_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'delivered': return Icons.local_shipping_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ORDER SELECTION DIALOG
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>?> _showOrderSelectionDialog() async {
    if (_ordersWithPayments.isEmpty) {
      _snack('کوئی آرڈر موجود نہیں', false);
      return null;
    }

    final selected = <Map<String, dynamic>>[];
    final indices = <int>{};

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius2xl),
              boxShadow: [AppTheme.shadowLg],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 10),
                    const Text('آرڈرز منتخب کریں',
                        style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Print or Share selected orders',
                        style: TextStyle(fontSize: 11, color: Colors.white)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => setStateDialog(() {
                        if (indices.length == _ordersWithPayments.length) {
                          indices.clear(); selected.clear();
                        } else {
                          indices.clear(); selected.clear();
                          for (int i = 0; i < _ordersWithPayments.length; i++) {
                            indices.add(i);
                            selected.add(_ordersWithPayments[i]);
                          }
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: indices.length == _ordersWithPayments.length ? AppTheme.primary.withOpacity(0.1) : AppTheme.elevated,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: indices.length == _ordersWithPayments.length ? AppTheme.primary : AppTheme.border),
                        ),
                        child: Row(children: [
                          Icon(indices.length == _ordersWithPayments.length ? Icons.deselect : Icons.select_all, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(indices.length == _ordersWithPayments.length ? 'سب ہٹائیں' : 'سب منتخب کریں',
                              style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 11, color: AppTheme.primary)),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text('${indices.length}/${_ordersWithPayments.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ]),
                ),
                const Divider(height: 1, color: AppTheme.divider),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _ordersWithPayments.length,
                    itemBuilder: (_, i) {
                      final o = _ordersWithPayments[i];
                      final isSel = indices.contains(i);
                      final status = o['status'] ?? 'Pending';
                      final total = _toInt(o['total_amount']);
                      final remaining = _toInt(o['remaining_amount']);
                      final sc = _statusColor(status);

                      return GestureDetector(
                        onTap: () => setStateDialog(() {
                          if (isSel) { indices.remove(i); selected.remove(o); }
                          else { indices.add(i); selected.add(o); }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.primary.withOpacity(0.03) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: isSel ? AppTheme.primary : AppTheme.border, width: isSel ? 1.5 : 1),
                          ),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel ? AppTheme.primary : Colors.transparent,
                                border: Border.all(color: isSel ? AppTheme.primary : AppTheme.border, width: 2),
                              ),
                              child: isSel ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: sc.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Icon(_statusIcon(status), color: sc, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('آرڈر #${o['id']}', style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Text('Rs $total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(_statusUrdu(status), style: TextStyle(fontSize: 9, color: sc, fontFamily: 'NotoNastaliqUrdu')),
                                    ),
                                    if (remaining > 0) ...[
                                      const SizedBox(width: 6),
                                      Text('بقایا: $remaining', style: const TextStyle(fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.bold)),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor: AppTheme.textHint,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                        ),
                        child: Text(selected.isEmpty ? 'کوئی آرڈر نہیں' : 'جاری رکھیں (${selected.length})',
                            style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PAYMENT RECORDING DIALOG
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showPaymentRecordingDialog({int? preselectedOrderId}) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'Cash';
    int? selectedOrderId = preselectedOrderId;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius2xl),
              boxShadow: [AppTheme.shadowLg],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.success, Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
                    ),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.payment_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('نئی ادائیگی ریکارڈ کریں',
                          style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('Record New Payment', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fieldLabel('رقم / Amount'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          decoration: _inputDecoration('Rs.', hint: '0'),
                          validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'درست رقم درج کریں' : null,
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('ادائیگی کا طریقہ / Method'),
                        const SizedBox(height: 6),
                        _methodSelector(paymentMethod, (v) => setStateDialog(() => paymentMethod = v)),
                        const SizedBox(height: 16),
                        _fieldLabel('متعلقہ آرڈر (اختیاری)'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: AppTheme.elevated, borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppTheme.border)),
                          child: DropdownButtonFormField<int?>(
                            value: selectedOrderId,
                            isExpanded: true,
                            decoration: const InputDecoration(border: InputBorder.none),
                            style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, color: AppTheme.textPrimary),
                            hint: const Text('کوئی آرڈر منتخب نہیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textHint, fontSize: 13)),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('کوئی نہیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textHint))),
                              ..._ordersWithPayments.where((o) => _toInt(o['remaining_amount']) > 0).map((o) => DropdownMenuItem<int?>(
                                value: o['id'],
                                child: Text('آرڈر #${o['id']} | بقایا: Rs ${_toInt(o['remaining_amount'])}', style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13)),
                              )),
                            ],
                            onChanged: (v) => setStateDialog(() => selectedOrderId = v),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('نوٹس (اختیاری)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: AppTheme.textPrimary),
                          decoration: _inputDecoration('', hint: 'اضافی معلومات'),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)), side: const BorderSide(color: AppTheme.border)),
                          child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(ctx);
                              try {
                                await DatabaseHelper.instance.addPayment({
                                  'customer_id': widget.customer['id'],
                                  'order_id': selectedOrderId,
                                  'payment_date': DateTime.now().toIso8601String(),
                                  'amount': int.parse(amountCtrl.text),
                                  'payment_method': paymentMethod,
                                  'notes': notesCtrl.text,
                                });
                                _snack('✅ ادائیگی ریکارڈ ہو گئی', true);
                                _loadPayments();
                                _loadOrders();
                              } catch (e) {
                                _snack('خرابی: $e', false);
                              }
                            }
                          },
                          icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                          label: const Text('محفوظ کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));

  InputDecoration _inputDecoration(String prefix, {String? hint}) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textHint, fontSize: 12),
    prefixText: prefix.isNotEmpty ? '$prefix ' : null,
    prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
    filled: true, fillColor: AppTheme.elevated,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Widget _methodSelector(String current, Function(String) onChanged) {
    final methods = [
      {'icon': Icons.money_rounded, 'label': 'Cash', 'color': AppTheme.success},
      {'icon': Icons.account_balance_rounded, 'label': 'Bank', 'color': AppTheme.info},
      {'icon': Icons.phone_android_rounded, 'label': 'JazzCash', 'color': AppTheme.danger},
      {'icon': Icons.phone_android_rounded, 'label': 'EasyPaisa', 'color': AppTheme.warning},
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: methods.map((m) {
      final sel = current == m['label'];
      final color = m['color'] as Color;
      return GestureDetector(
        onTap: () => onChanged(m['label'] as String),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : AppTheme.elevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: sel ? color : AppTheme.border, width: sel ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m['icon'] as IconData, color: color, size: 18),
            const SizedBox(width: 6),
            Text(m['label'] as String, style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? color : AppTheme.textSecondary, fontSize: 13)),
          ]),
        ),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  PDF GENERATION WITH MEASUREMENT DETAILS
  // ═══════════════════════════════════════════════════════════════
  Future<Uint8List> _generatePdfForOrders(List<Map<String, dynamic>> selectedOrders) async {
    final pdf = pw.Document();
    final font = _cachedUrduFont ?? pw.Font.helvetica();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        final List<pw.Widget> pageWidgets = [];

        // HEADER
        pageWidgets.add(
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue900, width: 3),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(children: [
                pw.Text('Darzi Management System',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center),
                pw.Text('درزی مینجمنٹ سسٹم',
                    style: pw.TextStyle(font: font, fontSize: 18, color: PdfColors.blue700),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColors.blue200),
                pw.SizedBox(height: 4),
                pw.Text('منتخب آرڈرز کی تفصیلی رپورٹ',
                    style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center),
              ]),
            ),
          ),
        );
        pageWidgets.add(pw.SizedBox(height: 20));

        // CUSTOMER INFO
        pageWidgets.add(_pdfSection(font, '👤 کسٹمر کی معلومات'));
        pageWidgets.add(pw.SizedBox(height: 8));
        pageWidgets.add(
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(children: [
                _pdfInfoRow(font, 'نام', widget.customer['name'] ?? ''),
                _pdfDivider(),
                _pdfInfoRow(font, 'فون نمبر', widget.customer['phone'] ?? ''),
                if (widget.customer['address']?.toString().isNotEmpty == true) ...[
                  _pdfDivider(),
                  _pdfInfoRow(font, 'پتہ', widget.customer['address'] ?? ''),
                ],
              ]),
            ),
          ),
        );
        pageWidgets.add(pw.SizedBox(height: 16));

        // FINANCIAL SUMMARY
        pageWidgets.add(_pdfSection(font, '💰 مالی خلاصہ'));
        pageWidgets.add(pw.SizedBox(height: 8));
        pageWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: pw.BoxDecoration(color: PdfColors.green900, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Row(children: [
                _pdfSumBox(font, 'کل خریدیں', '${_customerSummary['total_purchases'] ?? 0}', PdfColors.white),
                pw.Container(height: 35, width: 1, color: PdfColors.white),
                _pdfSumBox(font, 'کل ادائیگی', '${_customerSummary['total_payments'] ?? 0}', PdfColors.white),
                pw.Container(height: 35, width: 1, color: PdfColors.white),
                _pdfSumBox(font, 'بقایا رقم', '${_customerSummary['balance'] ?? 0}', PdfColors.yellow),
              ]),
            ),
          ),
        );
        pageWidgets.add(pw.SizedBox(height: 20));

        // SELECTED ORDERS
        pageWidgets.add(_pdfSection(font, '📦 منتخب آرڈرز کی تفصیل (${selectedOrders.length})'));
        pageWidgets.add(pw.SizedBox(height: 10));

        for (final order in selectedOrders) {
          final status = order['status'] ?? 'Pending';
          final total = _toInt(order['total_amount']);
          final remaining = _toInt(order['remaining_amount']);
          final st = _statusUrdu(status);
          PdfColor sc;
          switch (status.toString().toLowerCase()) {
            case 'completed': sc = PdfColors.green; break;
            case 'delivered': sc = PdfColors.blue; break;
            case 'cancelled': sc = PdfColors.red; break;
            default: sc = PdfColors.orange;
          }

          final orderWidgets = <pw.Widget>[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('آرڈر نمبر #${order['id']}',
                  style: pw.TextStyle(font: font, fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(color: sc, borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Text(st, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
              ),
            ]),
            pw.SizedBox(height: 6),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('تاریخ: ${_fmt(order['order_date'])}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
              pw.Text('ڈیلیوری: ${_fmt(order['delivery_date'])}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Expanded(child: pw.Text('کل رقم: Rs $total', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text('بقایا: Rs $remaining', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: remaining > 0 ? PdfColors.red : PdfColors.green))),
            ]),
          ];

          // Measurements
          if (_selectedSilaiId != null && _naapTypes.isNotEmpty) {
            orderWidgets.add(pw.SizedBox(height: 8));
            orderWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey200),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('📏 پیمائش',
                      style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                    columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                        children: [
                          _pdfTableCell(font, 'پیمائش', PdfColors.blue900, bold: true),
                          _pdfTableCell(font, 'مقدار', PdfColors.blue900, bold: true),
                        ],
                      ),
                      ..._naapTypes.map((n) {
                        final v = _measurementValues[n['id']] ?? '';
                        return pw.TableRow(children: [
                          _pdfTableCell(font, n['name'] ?? '', PdfColors.black, align: pw.TextAlign.right),
                          _pdfTableCell(font, v.isNotEmpty ? v : '—', v.isNotEmpty ? PdfColors.green700 : PdfColors.grey, bold: v.isNotEmpty),
                        ]);
                      }),
                    ],
                  ),
                ]),
              ),
            );
          }

          // Notes
          if (order['notes']?.toString().isNotEmpty == true) {
            orderWidgets.add(pw.SizedBox(height: 6));
            orderWidgets.add(
              pw.Text('نوٹس: ${order['notes']}',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            );
          }

          pageWidgets.add(
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: orderWidgets),
              ),
            ),
          );
        }

        // PAYMENTS TABLE
        if (_payments.isNotEmpty) {
          pageWidgets.add(pw.SizedBox(height: 16));
          pageWidgets.add(_pdfSection(font, '💳 ادائیگیوں کا ریکارڈ'));
          pageWidgets.add(pw.SizedBox(height: 8));
          pageWidgets.add(
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    children: ['آرڈر', 'رقم', 'تاریخ', 'طریقہ']
                        .map((h) => _pdfTableCell(font, h, PdfColors.white, bold: true))
                        .toList(),
                  ),
                  ..._payments.map((p) => pw.TableRow(children: [
                    _pdfTableCell(font, '#${p['order_id'] ?? '-'}', PdfColors.black),
                    _pdfTableCell(font, 'Rs ${p['amount']}', PdfColors.green700),
                    _pdfTableCell(font, _fmt(p['payment_date'] ?? ''), PdfColors.black),
                    _pdfTableCell(font, p['payment_method'] ?? 'Cash', PdfColors.black),
                  ])),
                ],
              ),
            ),
          );
        }

        // FOOTER
        pageWidgets.add(pw.SizedBox(height: 20));
        pageWidgets.add(
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('تیار کردہ: ${_fmt(DateTime.now().toIso8601String())}',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                pw.Text('درزی مینجمنٹ سسٹم',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ]),
            ),
          ),
        );

        return pageWidgets;
      },
    ));
    return pdf.save();
  }

  pw.Widget _pdfSection(pw.Font f, String t) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2))),
        child: pw.Text(t,
            style: pw.TextStyle(font: f, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            textAlign: pw.TextAlign.right),
      ),
    );
  }

  pw.Widget _pdfInfoRow(pw.Font f, String l, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: pw.Text(v, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: f, fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 12),
        pw.Text(l, style: pw.TextStyle(font: f, fontSize: 12, color: PdfColors.grey700)),
      ]),
    );
  }

  pw.Widget _pdfDivider() => pw.Container(height: 1, color: PdfColors.grey300);

  pw.Widget _pdfSumBox(pw.Font f, String l, String v, PdfColor c) {
    return pw.Expanded(
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.FittedBox(child: pw.Text('Rs $v',
            style: pw.TextStyle(font: f, fontSize: 15, fontWeight: pw.FontWeight.bold, color: c))),
        pw.SizedBox(height: 3),
        pw.Text(l, style: pw.TextStyle(font: f, fontSize: 8, color: c), textAlign: pw.TextAlign.center),
      ]),
    );
  }

  pw.Widget _pdfTableCell(pw.Font f, String t, PdfColor c, {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(t,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: f, fontSize: 9, color: c, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          textAlign: align),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRINT / SHARE / PREVIEW ACTIONS
  // ═══════════════════════════════════════════════════════════════
  Future<void> _printSelectedOrders() async {
    final selected = await _showOrderSelectionDialog();
    if (selected == null || selected.isEmpty) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdfForOrders(selected);
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${widget.customer['name']} - آرڈرز رپورٹ');
    } catch (e) {
      if (mounted) { setState(() => _isGeneratingPdf = false); _snack('پرنٹ میں خرابی', false); }
    }
  }

  Future<void> _shareSelectedOrders() async {
    final selected = await _showOrderSelectionDialog();
    if (selected == null || selected.isEmpty) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdfForOrders(selected);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/orders_${widget.customer['id']}.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
          subject: '${widget.customer['name']} - آرڈرز رپورٹ');
    } catch (e) {
      if (mounted) { setState(() => _isGeneratingPdf = false); _snack('شیئر میں خرابی', false); }
    }
  }

  Future<void> _previewSelectedOrders() async {
    final selected = await _showOrderSelectionDialog();
    if (selected == null || selected.isEmpty) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdfForOrders(selected);
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('PDF Preview', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: PdfPreview(build: (_) => bytes, allowSharing: true, allowPrinting: true),
      )));
    } catch (e) {
      if (mounted) { setState(() => _isGeneratingPdf = false); _snack('پریویو میں خرابی', false); }
    }
  }

  void _showPdfActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
          boxShadow: [AppTheme.shadowLg],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3)),
          ),
          const Text('رپورٹ کے اختیارات',
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Print, Share or Preview selected orders',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          const SizedBox(height: 20),
          _actionTile(Icons.print_rounded, 'پرنٹ کریں', 'Print PDF', AppTheme.info,
                  () { Navigator.pop(ctx); _printSelectedOrders(); }),
          const SizedBox(height: 8),
          _actionTile(Icons.share_rounded, 'شیئر کریں', 'Share PDF', AppTheme.success,
                  () { Navigator.pop(ctx); _shareSelectedOrders(); }),
          const SizedBox(height: 8),
          _actionTile(Icons.preview_rounded, 'پریویو', 'Preview PDF', AppTheme.accent,
                  () { Navigator.pop(ctx); _previewSelectedOrders(); }),
        ]),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
          ]),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: color, size: 16),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STATUS UPDATE DIALOG
  // ═══════════════════════════════════════════════════════════════
  Future<void> _updateOrderStatus(int orderId, String currentStatus) async {
    String newStatus = currentStatus;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            boxShadow: [AppTheme.shadowLg],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.warning, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 8),
                  const Text('آرڈر کی حالت تبدیل کریں',
                      style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Update Order #$orderId Status',
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _statusOption(ctx, 'زیر التواء', 'Pending', Icons.schedule_rounded, AppTheme.warning, (s) => newStatus = s),
                  const SizedBox(height: 6),
                  _statusOption(ctx, 'مکمل', 'Completed', Icons.check_circle_rounded, AppTheme.success, (s) => newStatus = s),
                  const SizedBox(height: 6),
                  _statusOption(ctx, 'ڈیلیورڈ', 'Delivered', Icons.local_shipping_rounded, AppTheme.info, (s) => newStatus = s),
                  const SizedBox(height: 6),
                  _statusOption(ctx, 'منسوخ', 'Cancelled', Icons.cancel_rounded, AppTheme.danger, (s) => newStatus = s),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)), side: const BorderSide(color: AppTheme.border)),
                        child: const Text('بند کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textSecondary)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    if (newStatus != currentStatus) {
      try {
        await DatabaseHelper.instance.updateOrderStatus(orderId, newStatus);
        _snack('✅ حالت تبدیل ہو گئی', true);
        _loadOrders();
      } catch (e) {
        _snack('خرابی', false);
      }
    }
  }

  Widget _statusOption(BuildContext ctx, String label, String status, IconData icon, Color color, Function(String) onSelect) {
    return GestureDetector(
      onTap: () { onSelect(status); Navigator.pop(ctx); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NAVIGATION
  // ═══════════════════════════════════════════════════════════════
  Future<void> _navigateToNewOrder() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => NewOrderScreen(customer: widget.customer)));
    if (result == true) _loadOrders();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text("${widget.customer['name']}",
            style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          _isGeneratingPdf
              ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
              : IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Print / Share / Preview',
              onPressed: _showPdfActions),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'آرڈرز'),
            Tab(icon: Icon(Icons.straighten, size: 20), text: 'پیمائش'),
            Tab(icon: Icon(Icons.payment, size: 20), text: 'پیمنٹس'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOrdersTab(), _buildMeasurementsTab(), _buildPaymentsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToNewOrder,
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('نیا آرڈر', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: ORDERS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildOrdersTab() {
    if (_isLoadingOrders) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_customerOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: AppTheme.elevated, shape: BoxShape.circle, border: Border.all(color: AppTheme.border, width: 2)),
                child: Icon(Icons.receipt_long, size: 56, color: AppTheme.textHint)),
            const SizedBox(height: 16),
            const Text('کوئی آرڈر موجود نہیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('نیا آرڈر بنانے کے لیے نیچے دیئے گئے بٹن پر کلک کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: AppTheme.textHint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToNewOrder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('نیا آرڈر بنائیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
              ),
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [AppTheme.shadowMd],
        ),
        child: Row(children: [
          _sumItem('کل آرڈرز', '${_customerOrders.length}', Icons.receipt_long),
          _vDivider(),
          _sumItem('زیر التواء', '${_customerOrders.where((o) => o['status'] == 'Pending').length}', Icons.schedule_rounded),
          _vDivider(),
          _sumItem('مکمل', '${_customerOrders.where((o) => o['status'] == 'Completed').length}', Icons.check_circle_rounded),
        ]),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: _ordersWithPayments.length,
          itemBuilder: (_, i) => _orderCard(_ordersWithPayments[i]),
        ),
      ),
    ]);
  }

  Widget _sumItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'NotoNastaliqUrdu'), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _vDivider() => Container(height: 36, width: 1, color: Colors.white.withOpacity(0.25));

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final total = _toInt(order['total_amount']);
    final remaining = _toInt(order['remaining_amount']);
    final paid = total - remaining;
    final sc = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: [AppTheme.shadowXs],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          child: Icon(Icons.receipt_long, color: sc, size: 22),
        ),
        title: Text('آرڈر #${order['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
        subtitle: Row(children: [
          Text(_fmt(order['order_date'] ?? ''), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: sc.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusXs)),
            child: Text(_statusUrdu(status), style: TextStyle(fontSize: 10, color: sc, fontFamily: 'NotoNastaliqUrdu')),
          ),
        ]),
        trailing: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint, size: 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(height: 1, color: AppTheme.divider),
          const SizedBox(height: 12),
          _detailRow('کل رقم', 'Rs $total'),
          _detailRow('ادا شدہ', 'Rs $paid'),
          _detailRow('بقایا', 'Rs $remaining', color: remaining > 0 ? AppTheme.danger : AppTheme.success),
          if (order['notes']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.elevated, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: Text('📝 ${order['notes']}', textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateOrderStatus(order['id'], status),
                icon: Icon(_statusIcon(status), size: 16, color: sc),
                label: Text('حالت تبدیل کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12, color: sc)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: sc.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentRecordingDialog(preselectedOrderId: order['id']),
                  icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                  label: const Text('پیمنٹ کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? AppTheme.textPrimary)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: MEASUREMENTS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMeasurementsTab() {
    if (_isLoadingMeasurements) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
            boxShadow: [AppTheme.shadowSm],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('کسٹمر کی معلومات',
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 14),
            _infoRow('نام', widget.customer['name'] ?? ''),
            const SizedBox(height: 6),
            _infoRow('فون', widget.customer['phone'] ?? ''),
            if (widget.customer['address']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _infoRow('پتہ', widget.customer['address'] ?? ''),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
            boxShadow: [AppTheme.shadowSm],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.style_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('سلائی کی قسم منتخب کریں',
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.elevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonFormField<int>(
                value: _selectedSilaiId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon: Icon(Icons.style, color: AppTheme.primary),
                ),
                style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, color: AppTheme.textPrimary),
                items: _silaiTypes.map((t) => DropdownMenuItem<int>(
                  value: t['id'],
                  child: Text(t['name'] ?? '', style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14)),
                )).toList(),
                onChanged: (v) {
                  setState(() => _selectedSilaiId = v);
                  _loadNaapTypesAndMeasurements();
                },
              ),
            ),
          ]),
        ),
        if (_naapTypes.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
              boxShadow: [AppTheme.shadowSm],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.info, Color(0xFF60A5FA)]),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(Icons.straighten_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('پیمائش کی تفصیل',
                    style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('${_naapTypes.length} ناپ',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontFamily: 'NotoNastaliqUrdu')),
              ]),
              const SizedBox(height: 14),
              ..._naapTypes.asMap().entries.map((entry) {
                final idx = entry.key;
                final n = entry.value;
                final v = _measurementValues[n['id']] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: idx.isEven ? AppTheme.elevated : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    textDirection: TextDirection.rtl,
                    children: [
                      Row(textDirection: TextDirection.rtl, children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.info))),
                        ),
                        const SizedBox(width: 10),
                        Text(n['name'] ?? '', style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 15, color: AppTheme.textPrimary)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: v.isNotEmpty ? AppTheme.successLight : AppTheme.elevated,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: v.isNotEmpty ? AppTheme.success : AppTheme.border),
                        ),
                        child: Text(v.isNotEmpty ? v : '—',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15,
                              color: v.isNotEmpty ? AppTheme.success : AppTheme.textHint,
                            )),
                      ),
                    ],
                  ),
                );
              }),
            ]),
          ),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: AppTheme.textSecondary)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: PAYMENTS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPaymentsTab() {
    if (_isLoadingPayments) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.success, Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [AppTheme.shadowMd],
          ),
          child: Row(children: [
            _sumItem('کل خریدیں', 'Rs ${_customerSummary['total_purchases'] ?? 0}', Icons.shopping_cart_rounded),
            _vDivider(),
            _sumItem('ادائیگی', 'Rs ${_customerSummary['total_payments'] ?? 0}', Icons.payment_rounded),
            _vDivider(),
            _sumItem('بقایا', 'Rs ${_customerSummary['balance'] ?? 0}', Icons.account_balance_wallet_rounded),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPaymentRecordingDialog(),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Colors.white),
              label: const Text('نئی ادائیگی ریکارڈ کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 15, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                elevation: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_payments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppTheme.elevated, shape: BoxShape.circle, border: Border.all(color: AppTheme.border, width: 2)),
                child: Icon(Icons.payment_rounded, size: 48, color: AppTheme.textHint),
              ),
              const SizedBox(height: 14),
              const Text('کوئی پیمنٹ ریکارڈ نہیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textSecondary, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('اوپر دیئے گئے بٹن سے نئی ادائیگی ریکارڈ کریں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textHint, fontSize: 12)),
            ]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _payments.length,
            itemBuilder: (_, i) {
              final p = _payments[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [AppTheme.shadowXs],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Rs ${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        const SizedBox(width: 8),
                        if (p['order_id'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.infoLight, borderRadius: BorderRadius.circular(4)),
                            child: Text('#${p['order_id']}', style: const TextStyle(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(_fmt(p['payment_date'] ?? ''), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.elevated, borderRadius: BorderRadius.circular(4)),
                          child: Text(p['payment_method'] ?? 'Cash', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              );
            },
          ),
      ]),
    );
  }
}