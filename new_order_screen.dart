import 'dart:io';
import 'dart:typed_data';
import 'package:darzi_management_system/db/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  PROFESSIONAL LIGHT THEME DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class AppTheme {
  static const primary = Color(0xFF1B5E20);
  static const primaryLight = Color(0xFF4CAF50);
  static const accent = Color(0xFFFF6F00);
  static const bg = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFF1F3F5);
  static const textPrimary = Color(0xFF212529);
  static const textSecondary = Color(0xFF6C757D);
  static const textLight = Color(0xFFADB5BD);
  static const success = Color(0xFF28A745);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFDC3545);
  static const info = Color(0xFF17A2B8);
  static const border = Color(0xFFDEE2E6);
  static const borderLight = Color(0xFFE9ECEF);
  static const gradient1 = Color(0xFF1B5E20);
  static const gradient2 = Color(0xFF4CAF50);

  static BoxShadow shadowSmall = BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 6,
    offset: const Offset(0, 2),
  );
  static BoxShadow shadowMedium = BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 16.0;
  static const radiusXLarge = 20.0;
}

// ═══════════════════════════════════════════════════════════════
//  NEW ORDER SCREEN
// ═══════════════════════════════════════════════════════════════
class NewOrderScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const NewOrderScreen({super.key, required this.customer});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with TickerProviderStateMixin {

  final PageController _pageController = PageController();
  int _currentStep = 0;

  List<Map<String, dynamic>> _silaiTypes = [];
  List<Map<String, dynamic>> _naapTypes = [];
  List<Map<String, dynamic>> _extraInfoList = [];
  Map<int, String> _measurementValues = {};
  final Map<String, String> _selectedDesignOptions = {};

  int? _selectedSilaiId;
  bool _isLoadingExtras = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final _priceCtrl = TextEditingController();
  final _fabricCtrl = TextEditingController(text: '0');
  final _extraCtrl = TextEditingController(text: '0');
  final _advanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  int _total = 0;
  int _remaining = 0;

  DateTime _orderDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 7));

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadSilaiTypes();
    for (var c in [_priceCtrl, _fabricCtrl, _extraCtrl, _advanceCtrl]) {
      c.addListener(_calc);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _priceCtrl.dispose();
    _fabricCtrl.dispose();
    _extraCtrl.dispose();
    _advanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final p = int.tryParse(_priceCtrl.text) ?? 0;
    final f = int.tryParse(_fabricCtrl.text) ?? 0;
    final e = int.tryParse(_extraCtrl.text) ?? 0;
    final a = int.tryParse(_advanceCtrl.text) ?? 0;
    setState(() {
      _total = p + f + e;
      _remaining = _total - a;
    });
  }

  /// Splits a comma/separator-delimited string into individual options
  List<String> _parseOptions(String rawValue) {
    if (rawValue.isEmpty) return [];

    // First try splitting by common Urdu/English separators
    List<String> options = [];

    // Split by multiple separators: comma, Urdu comma, pipe, forward slash, dash
    List<String> parts = rawValue
        .split(RegExp(r'[،,\|/\-]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return parts;
  }

  Future<void> _loadSilaiTypes() async {
    final data = await DatabaseHelper.instance.getSilaiTypes();
    if (mounted) setState(() => _silaiTypes = data);
  }

  Future<void> _loadSilaiData() async {
    if (_selectedSilaiId == null) return;
    setState(() => _isLoadingExtras = true);
    try {
      final naap = await DatabaseHelper.instance.getNaapTypesBySilai(_selectedSilaiId!);
      final vals = await DatabaseHelper.instance.getCustomerMeasurements(
        widget.customer['id'],
        _selectedSilaiId!,
      );
      final extras = await DatabaseHelper.instance.getNaapExtraInfoBySilai();
      if (mounted) {
        setState(() {
          _naapTypes = naap;
          _measurementValues = vals;
          _extraInfoList = extras;
          _selectedDesignOptions.clear();
          _isLoadingExtras = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingExtras = false);
    }
  }

  Future<void> _pickCamera() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (f != null && mounted) setState(() => _selectedImage = File(f.path));
    } catch (_) {
      _snack('کیمرہ کھولنے میں خرابی', false);
    }
  }

  Future<void> _pickGallery() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (f != null && mounted) setState(() => _selectedImage = File(f.path));
    } catch (_) {
      _snack('گیلری کھولنے میں خرابی', false);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
          boxShadow: [AppTheme.shadowMedium],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('تصویر کا انتخاب کریں',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _imgBtn(Icons.camera_alt_rounded, 'کیمرہ', AppTheme.primary,
                    () { Navigator.pop(context); _pickCamera(); })),
            const SizedBox(width: 12),
            Expanded(child: _imgBtn(Icons.photo_library_rounded, 'گیلری', AppTheme.accent,
                    () { Navigator.pop(context); _pickGallery(); })),
          ]),
        ]),
      ),
    );
  }

  Widget _imgBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ]),
        ),
      );

  void _next() {
    if (_currentStep == 0 && _selectedSilaiId == null) {
      _snack('پہلے سلائی کی قسم منتخب کریں', false);
      return;
    }
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ok ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _saveOrder() async {
    if (_selectedSilaiId == null) {
      _snack('سلائی کی قسم منتخب کریں', false);
      return;
    }

    final price = int.tryParse(_priceCtrl.text) ?? 0;
    final fabric = int.tryParse(_fabricCtrl.text) ?? 0;
    final extra = int.tryParse(_extraCtrl.text) ?? 0;
    final advance = int.tryParse(_advanceCtrl.text) ?? 0;
    final total = price + fabric + extra;

    final notes = StringBuffer();
    if (_selectedDesignOptions.isNotEmpty) {
      notes.writeln('--- ڈیزائن کی تفصیل ---');
      _selectedDesignOptions.forEach((k, v) => notes.writeln('$k: $v'));
      notes.writeln('----------------------');
    }
    if (_notesCtrl.text.isNotEmpty) notes.write(_notesCtrl.text);

    final order = {
      'customer_id': widget.customer['id'],
      'silai_id': _selectedSilaiId,
      'order_date': _orderDate.toIso8601String(),
      'delivery_date': _deliveryDate.toIso8601String(),
      'price': price,
      'fabric_cost': fabric,
      'extra_cost': extra,
      'advance': advance,
      'notes': notes.toString(),
      'status': 'Pending',
      'image_path': _selectedImage?.path,
    };

    _showLoading();
    try {
      final orderId = await DatabaseHelper.instance.createOrder(order);
      await DatabaseHelper.instance.updateOrder(orderId, {'remaining_amount': total});

      if (advance > 0) {
        await DatabaseHelper.instance.addPayment({
          'customer_id': widget.customer['id'],
          'order_id': orderId,
          'payment_date': _orderDate.toIso8601String(),
          'amount': advance,
          'payment_method': 'Cash',
          'notes': 'ایڈوانس رقم - آرڈر نمبر $orderId',
        });
      }

      final created = await DatabaseHelper.instance.getOrderById(orderId);
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            orderId: orderId,
            orderData: created!,
            customer: widget.customer,
            silaiName: _getSilaiName(_selectedSilaiId),
            naapTypes: _naapTypes,
            measurementValues: _measurementValues,
            designOptions: _selectedDesignOptions,
            totalAmount: total,
            remainingAmount: total - advance,
            advanceAmount: advance,
            priceAmount: price,
            fabricAmount: fabric,
            extraAmount: extra,
            orderDate: _orderDate,
            deliveryDate: _deliveryDate,
            notes: _notesCtrl.text,
            selectedImage: _selectedImage,
          ),
        )).then((_) => Navigator.pop(context, true));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _snack('آرڈر محفوظ کرنے میں خرابی: $e', false);
      }
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            boxShadow: [AppTheme.shadowMedium],
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text('آرڈر محفوظ ہو رہا ہے...',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _getSilaiName(int? id) {
    if (id == null) return '—';
    return _silaiTypes.firstWhere(
          (s) => s['id'] == id,
      orElse: () => {'name': '—'},
    )['name']?.toString() ?? '—';
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildStepper(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_step1(), _step2(), _step3(), _step4()],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final name = widget.customer['name']?.toString() ?? 'کسٹمر';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: Row(children: [
        _iconBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.gradient1, AppTheme.gradient2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [AppTheme.shadowSmall],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(widget.customer['phone']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6F00), Color(0xFFFFA000)],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [AppTheme.shadowSmall],
          ),
          child: const Text('نیا آرڈر',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 18),
    ),
  );

  Widget _buildStepper() {
    final labels = ['سلائی', 'ڈیزائن', 'قیمت', 'تصدیق'];
    final icons = [
      Icons.style_rounded,
      Icons.design_services_rounded,
      Icons.payments_rounded,
      Icons.check_circle_outline_rounded,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AppTheme.surface,
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < _currentStep;
          final active = i == _currentStep;
          return Expanded(
            child: Row(children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: done || active
                          ? const LinearGradient(
                          colors: [AppTheme.gradient1, AppTheme.gradient2])
                          : null,
                      color: done || active ? null : AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active
                        ? const LinearGradient(
                        colors: [AppTheme.gradient1, AppTheme.gradient2])
                        : done
                        ? const LinearGradient(
                        colors: [AppTheme.success, Color(0xFF34D058)])
                        : null,
                    color: active || done ? null : AppTheme.elevated,
                    border: Border.all(
                      color: active
                          ? AppTheme.primary
                          : done
                          ? AppTheme.success
                          : AppTheme.borderLight,
                      width: 2,
                    ),
                    boxShadow: active ? [AppTheme.shadowSmall] : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Icon(icons[i],
                        color: active ? Colors.white : AppTheme.textLight,
                        size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i],
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 10,
                    color: active
                        ? AppTheme.primary
                        : done
                        ? AppTheme.success
                        : AppTheme.textLight,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ]),
            ]),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 1 — Silai Type + Measurements
  // ═══════════════════════════════════════════════════════════
  Widget _step1() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(Icons.style_rounded, 'سلائی کی قسم', 'Silai Type'),
          const SizedBox(height: 10),
          _dropdown(),
        ]),
      ),
      if (_isLoadingExtras)
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
        )
      else if (_naapTypes.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.straighten_rounded,
                  color: AppTheme.primary, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('پیمائش',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text('${_naapTypes.length} ناپ',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontFamily: 'NotoNastaliqUrdu',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: _naapTypes.length,
            itemBuilder: (_, i) {
              final t = _naapTypes[i];
              final val = _measurementValues[t['id']] ?? '0';
              return _measureCard(i + 1, t['name']?.toString() ?? '', '$val انچ');
            },
          ),
        ),
      ] else
        Expanded(
          child: _emptyState(
            _selectedSilaiId == null
                ? 'سلائی کی قسم منتخب کریں'
                : 'کوئی ناپ موجود نہیں',
            Icons.straighten_rounded,
          ),
        ),
      _bottomBar(null, _next, 'آگے بڑھیں', Icons.arrow_forward_ios),
    ]);
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: _selectedSilaiId != null ? AppTheme.primary : AppTheme.border,
          width: _selectedSilaiId != null ? 1.5 : 1,
        ),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedSilaiId,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.primary, size: 24),
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
          hint: Text('سلائی کی قسم منتخب کریں',
            style: const TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              color: AppTheme.textLight,
              fontSize: 14,
            ),
          ),
          items: _silaiTypes
              .map((t) => DropdownMenuItem<int>(
            value: t['id'] as int,
            child: Text(t['name'] ?? '',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
          ))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedSilaiId = val);
            _loadSilaiData();
          },
        ),
      ),
    );
  }

  Widget _measureCard(int idx, String name, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: Row(textDirection: TextDirection.rtl, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.gradient1, AppTheme.gradient2],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Center(
            child: Text('$idx',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 15,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Text(value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.success,
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 2 — Design Options (FIXED: Proper option separation)
  // ═══════════════════════════════════════════════════════════
  Widget _step2() {
    if (_isLoadingExtras) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: _sectionLabel(Icons.design_services_rounded, 'ڈیزائن کی تفصیل', 'Design Options'),
      ),
      Expanded(
        child: _extraInfoList.isEmpty
            ? _emptyState('کوئی ڈیزائن آپشن موجود نہیں', Icons.design_services_rounded)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: _extraInfoList.length,
          itemBuilder: (_, i) {
            final item = _extraInfoList[i];
            final title = item['title']?.toString() ?? '';
            final rawValue = item['value']?.toString() ?? '';
            // Use the dedicated parsing method
            final opts = _parseOptions(rawValue);
            return _designCard(title, opts);
          },
        ),
      ),
      _bottomBar(_back, _next, 'آگے', Icons.arrow_forward_ios),
    ]);
  }

  Widget _designCard(String title, List<String> opts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Title Row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.palette_outlined,
                  color: AppTheme.accent, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Show count of options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${opts.length} آپشن',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.primary,
                  fontFamily: 'NotoNastaliqUrdu',
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // Options as individual selectable chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: opts.map((opt) {
              final sel = _selectedDesignOptions[title] == opt;
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedDesignOptions.remove(title);
                  } else {
                    _selectedDesignOptions[title] = opt;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                        colors: [AppTheme.gradient1, AppTheme.gradient2])
                        : null,
                    color: sel ? null : AppTheme.elevated,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: sel ? AppTheme.primary : AppTheme.borderLight,
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel ? [AppTheme.shadowSmall] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      if (sel)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.check_circle,
                              color: Colors.white, size: 16),
                        ),
                      Text(opt,
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 14,
                          color: sel ? Colors.white : AppTheme.textSecondary,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 3 — Pricing
  // ═══════════════════════════════════════════════════════════
  Widget _step3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(children: [
        _sectionLabel(Icons.payments_rounded, 'قیمت اور تاریخیں', 'Pricing & Dates'),
        const SizedBox(height: 16),
        _priceField('سلائی کی قیمت', 'Silai Price', _priceCtrl,
            Icons.cut_rounded, AppTheme.primary),
        _priceField('فیبرک خرچہ', 'Fabric Cost', _fabricCtrl,
            Icons.shopping_bag_outlined, AppTheme.accent),
        _priceField('اضافی خرچہ', 'Extra Cost', _extraCtrl,
            Icons.add_circle_outline, AppTheme.info),
        _priceField('ایڈوانس ادائیگی', 'Advance Paid', _advanceCtrl,
            Icons.account_balance_wallet_rounded, AppTheme.success,
            highlight: true),
        const SizedBox(height: 16),
        _totalCard(),
        const SizedBox(height: 18),
        _datePicker('آرڈر کی تاریخ', 'Order Date', _orderDate,
            Icons.calendar_today_rounded, AppTheme.primary,
                (d) => setState(() => _orderDate = d)),
        const SizedBox(height: 10),
        _datePicker('ڈیلیوری کی تاریخ', 'Delivery Date', _deliveryDate,
            Icons.event_available_rounded, AppTheme.accent,
                (d) => setState(() => _deliveryDate = d)),
        const SizedBox(height: 24),
        _bottomBar(_back, _next, 'آگے', Icons.arrow_forward_ios),
      ]),
    );
  }

  Widget _priceField(String urLabel, String enLabel, TextEditingController ctrl,
      IconData icon, Color color, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: highlight ? color.withOpacity(0.4) : AppTheme.borderLight,
        ),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: highlight ? AppTheme.danger : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          label: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: urLabel,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              TextSpan(
                text: '  $enLabel',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textLight,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        boxShadow: [AppTheme.shadowMedium],
      ),
      child: Column(children: [
        _summRow('کل رقم', 'Total', '₨ $_total', AppTheme.primary, false),
        const SizedBox(height: 12),
        Container(height: 1, color: AppTheme.borderLight),
        const SizedBox(height: 12),
        _summRow('بقایا رقم', 'Remaining', '₨ $_remaining',
            _remaining > 0 ? AppTheme.danger : AppTheme.success, true),
      ]),
    );
  }

  Widget _summRow(String ur, String en, String val, Color col, bool large) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ur,
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(en,
          style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
        ),
      ]),
      Text(val,
        style: TextStyle(
          fontSize: large ? 24 : 18,
          fontWeight: FontWeight.bold,
          color: col,
        ),
      ),
    ]);
  }

  Widget _datePicker(String urLabel, String enLabel, DateTime date,
      IconData icon, Color color, Function(DateTime) onPick) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(urLabel,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(enLabel,
              style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
            ),
          ],
        ),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (_, child) => Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppTheme.primary,
                  primary: AppTheme.primary,
                  surface: AppTheme.surface,
                ),
              ),
              child: child!,
            ),
          );
          if (d != null) onPick(d);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 4 — Confirm
  // ═══════════════════════════════════════════════════════════
  Widget _step4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(children: [
        _sectionLabel(Icons.check_circle_outline_rounded, 'تصدیق', 'Confirm & Save'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _showImagePicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.elevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: _selectedImage != null
                    ? AppTheme.success
                    : AppTheme.borderLight,
                width: _selectedImage != null ? 2 : 1,
              ),
            ),
            child: _selectedImage == null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded,
                      size: 40, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                const Text('سوٹ کی تصویر شامل کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Text('Add Suit Photo',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textLight),
                ),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Image.file(_selectedImage!,
                  fit: BoxFit.cover, width: double.infinity),
            ),
          ),
        ),
        if (_selectedImage != null)
          TextButton.icon(
            onPressed: () => setState(() => _selectedImage = null),
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.danger, size: 18),
            label: const Text('ہٹائیں',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: AppTheme.danger,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [AppTheme.shadowSmall],
          ),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 4,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'اضافی نوٹ یا ہدایات... (Extra notes)',
              hintStyle: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: AppTheme.textLight,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [AppTheme.shadowMedium],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('کل رقم',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text('₨ $_total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppTheme.primary,
                  ),
                ),
              ]),
              Container(height: 40, width: 1, color: AppTheme.borderLight),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('بقایا',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text('₨ $_remaining',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: _remaining > 0 ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ]),
              Container(height: 40, width: 1, color: AppTheme.borderLight),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ڈیلیوری',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(_fmt(_deliveryDate),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(children: [
          _outlineBtn(_back, 'پیچھے', Icons.arrow_back_ios),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: ElevatedButton.icon(
                  onPressed: _saveOrder,
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 22),
                  label: const Text('آرڈر محفوظ کریں',
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    elevation: 8,
                    shadowColor: AppTheme.success.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════
  Widget _sectionLabel(IconData icon, String ur, String en) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.gradient1, AppTheme.gradient2],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ur,
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(en,
          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
        ),
      ]),
    ]);
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.elevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Icon(icon, size: 48, color: AppTheme.textLight),
          ),
          const SizedBox(height: 16),
          Text(msg,
            style: const TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(VoidCallback? onBack, VoidCallback onNext,
      String nextLabel, IconData nextIcon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [AppTheme.shadowMedium],
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(children: [
        if (onBack != null) ...[
          _outlineBtn(onBack, 'پیچھے', Icons.arrow_back_ios),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onNext,
            icon: Icon(nextIcon, size: 16, color: Colors.white),
            label: Text(nextLabel,
              style: const TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              elevation: 4,
              shadowColor: AppTheme.primary.withOpacity(0.3),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _outlineBtn(VoidCallback onTap, String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: AppTheme.textSecondary),
      label: Text(label,
        style: const TextStyle(
          fontFamily: 'NotoNastaliqUrdu',
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        side: const BorderSide(color: AppTheme.border),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFESSIONAL RECEIPT SCREEN
// ═══════════════════════════════════════════════════════════════
class ReceiptScreen extends StatefulWidget {
  final int orderId;
  final Map<String, dynamic> orderData;
  final Map<String, dynamic> customer;
  final String silaiName;
  final List<Map<String, dynamic>> naapTypes;
  final Map<int, String> measurementValues;
  final Map<String, String> designOptions;
  final int totalAmount;
  final int remainingAmount;
  final int advanceAmount;
  final int priceAmount;
  final int fabricAmount;
  final int extraAmount;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final String notes;
  final File? selectedImage;

  const ReceiptScreen({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.customer,
    required this.silaiName,
    required this.naapTypes,
    required this.measurementValues,
    required this.designOptions,
    required this.totalAmount,
    required this.remainingAmount,
    required this.advanceAmount,
    required this.priceAmount,
    required this.fabricAmount,
    required this.extraAmount,
    required this.orderDate,
    required this.deliveryDate,
    required this.notes,
    this.selectedImage,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isGeneratingPdf = false;
  pw.Font? _cachedUrduFont;

  @override
  void initState() {
    super.initState();
    _loadUrduFontForPdf();
  }

  Future<void> _loadUrduFontForPdf() async {
    try {
      _cachedUrduFont = await PdfGoogleFonts.notoNaskhArabicRegular();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Font loading failed: $e");
      _cachedUrduFont = pw.Font.helvetica();
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final font = _cachedUrduFont ?? pw.Font.helvetica();

    pw.ImageProvider? orderImg;
    if (widget.selectedImage != null) {
      try {
        final bytes = await widget.selectedImage!.readAsBytes();
        orderImg = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 3),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(children: [
                pw.Text('Darzi Management System',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center),
                pw.Text('درزی مینجمنٹ سسٹم',
                    style: pw.TextStyle(font: font, fontSize: 18, color: PdfColors.blue700),
                    textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 8),
                pw.Container(height: 2, color: PdfColors.blue200),
                pw.SizedBox(height: 6),
                pw.Text('آرڈر رسید #${widget.orderId}',
                    style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center),
              ]),
            ),
          ),
          pw.SizedBox(height: 22),
          _pdfSectionRTL(font, '👤 کسٹمر کی معلومات'),
          pw.SizedBox(height: 10),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
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
          pw.SizedBox(height: 22),
          _pdfSectionRTL(font, '📦 آرڈر کی تفصیل'),
          pw.SizedBox(height: 10),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(children: [
                _pdfInfoRow(font, 'سلائی کی قسم', widget.silaiName),
                _pdfDivider(),
                _pdfInfoRow(font, 'آرڈر کی تاریخ', _fmt(widget.orderDate)),
                _pdfDivider(),
                _pdfInfoRow(font, 'ڈیلیوری تاریخ', _fmt(widget.deliveryDate)),
                _pdfDivider(),
                _pdfInfoRow(font, 'حالت', 'زیر التواء'),
              ]),
            ),
          ),
          pw.SizedBox(height: 22),
          _pdfSectionRTL(font, '💰 ادائیگی کا خلاصہ'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: pw.BoxDecoration(color: PdfColors.green900, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Row(children: [
                _pdfSumBox(font, 'کل رقم', '${widget.totalAmount}', PdfColors.white),
                pw.Container(height: 40, width: 1, color: PdfColors.white),
                _pdfSumBox(font, 'ایڈوانس', '${widget.advanceAmount}', PdfColors.white),
                pw.Container(height: 40, width: 1, color: PdfColors.white),
                _pdfSumBox(font, 'بقایا', '${widget.remainingAmount}', PdfColors.yellow),
              ]),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(children: [
                _pdfInfoRow(font, 'سلائی قیمت', 'Rs ${widget.priceAmount}'),
                _pdfDivider(),
                _pdfInfoRow(font, 'فیبرک خرچہ', 'Rs ${widget.fabricAmount}'),
                _pdfDivider(),
                _pdfInfoRow(font, 'اضافی خرچہ', 'Rs ${widget.extraAmount}'),
              ]),
            ),
          ),
          if (widget.naapTypes.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _pdfSectionRTL(font, '📏 پیمائش'),
            pw.SizedBox(height: 10),
            _pdfMeasurementsTable(font),
          ],
          if (widget.designOptions.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _pdfSectionRTL(font, '🎨 ڈیزائن کی تفصیل'),
            pw.SizedBox(height: 10),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(children: widget.designOptions.entries.map((e) => _pdfInfoRow(font, e.key, e.value)).toList()),
              ),
            ),
          ],
          if (widget.notes.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _pdfSectionRTL(font, '📝 نوٹس'),
            pw.SizedBox(height: 10),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(widget.notes, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700), textAlign: pw.TextAlign.right),
              ),
            ),
          ],
          if (orderImg != null) ...[
            pw.SizedBox(height: 22),
            _pdfSectionRTL(font, '🖼️ سوٹ کی تصویر'),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Container(
              height: 200,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.ClipRRect(horizontalRadius: 8, verticalRadius: 8, child: pw.Image(orderImg, fit: pw.BoxFit.contain)),
            )),
          ],
          pw.SizedBox(height: 28),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1))),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('تیار کردہ: ${_fmt(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                pw.Text('درزی مینجمنٹ سسٹم', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ]),
            ),
          ),
        ];
      },
    ));
    return pdf.save();
  }

  pw.Widget _pdfSectionRTL(pw.Font f, String t) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2))),
        child: pw.Text(t, style: pw.TextStyle(font: f, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900), textAlign: pw.TextAlign.right),
      ),
    );
  }

  pw.Widget _pdfInfoRow(pw.Font f, String l, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: pw.Text(v, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: f, fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 16),
        pw.Text(l, style: pw.TextStyle(font: f, fontSize: 13, color: PdfColors.grey700)),
      ]),
    );
  }

  pw.Widget _pdfDivider() => pw.Container(height: 1, color: PdfColors.grey300);

  pw.Widget _pdfSumBox(pw.Font f, String l, String v, PdfColor c) {
    return pw.Expanded(
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.FittedBox(child: pw.Text('Rs $v', style: pw.TextStyle(font: f, fontSize: 16, fontWeight: pw.FontWeight.bold, color: c))),
        pw.SizedBox(height: 4),
        pw.Text(l, style: pw.TextStyle(font: f, fontSize: 9, color: c), textAlign: pw.TextAlign.center),
      ]),
    );
  }

  pw.Widget _pdfMeasurementsTable(pw.Font f) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.blue900),
            children: ['پیمائش', 'مقدار'].map((h) => _pCell(f, h, PdfColors.white, bold: true)).toList(),
          ),
          ...widget.naapTypes.map((n) {
            final v = widget.measurementValues[n['id']] ?? 'درج نہیں';
            return pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(n['name'] ?? '', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: f, fontSize: 11), textAlign: pw.TextAlign.right)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: f, fontSize: 11, color: v.isNotEmpty && v != 'درج نہیں' ? PdfColors.green700 : PdfColors.grey), textAlign: pw.TextAlign.center)),
            ]);
          }),
        ],
      ),
    );
  }

  pw.Widget _pCell(pw.Font f, String t, PdfColor c, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(t, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: f, fontSize: 11, color: c, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: pw.TextAlign.center),
    );
  }

  Future<File> _pdfFile() async {
    final d = await _generatePdf();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/order_receipt_${widget.orderId}.pdf');
    await f.writeAsBytes(d);
    return f;
  }

  Future<void> _sharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final f = await _pdfFile();
      if (!mounted) return;
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], subject: 'آرڈر رسید #${widget.orderId}');
    } catch (e) {
      if (mounted) _showSnackBar('PDF شیئر کرنے میں خرابی', Colors.red);
    }
    if (mounted) setState(() => _isGeneratingPdf = false);
  }

  Future<void> _printPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final d = await _generatePdf();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => d, name: 'آرڈر رسید #${widget.orderId}');
    } catch (e) {
      if (mounted) _showSnackBar('PDF پرنٹ کرنے میں خرابی', Colors.red);
    }
    if (mounted) setState(() => _isGeneratingPdf = false);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu')),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('آرڈر رسید #${widget.orderId}', style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('Order Receipt', style: TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), tooltip: 'Share', onPressed: _isGeneratingPdf ? null : _sharePdf),
        ],
      ),
      body: _isGeneratingPdf
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 16),
        Text('تیار ہو رہا ہے...', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: AppTheme.textSecondary)),
      ]))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.gradient1, AppTheme.gradient2]),
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              boxShadow: [AppTheme.shadowMedium],
            ),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40)),
              const SizedBox(height: 12),
              const Text('آرڈر کامیابی سے بن گیا!', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Order #${widget.orderId} Created Successfully', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 20),
          _buildInfoCard('👤 کسٹمر کی معلومات', 'Customer Information', [
            _buildRow('نام / Name', widget.customer['name']?.toString() ?? '—'),
            _buildRow('فون / Phone', widget.customer['phone']?.toString() ?? '—'),
          ]),
          const SizedBox(height: 12),
          _buildInfoCard('📋 آرڈر کی تفصیل', 'Order Details', [
            _buildRow('سلائی / Silai', widget.silaiName),
            _buildRow('تاریخ / Date', _fmt(widget.orderDate)),
            _buildRow('ڈیلیوری / Delivery', _fmt(widget.deliveryDate)),
            _buildRow('حالت / Status', 'زیر التواء'),
          ]),
          const SizedBox(height: 12),
          _buildPaymentCard(),
          if (widget.naapTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard('📏 پیمائش', 'Measurements', widget.naapTypes.map((t) => _buildRow(t['name']?.toString() ?? '—', '${widget.measurementValues[t['id']] ?? "0"} inch')).toList()),
          ],
          if (widget.designOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard('🎨 ڈیزائن', 'Design Options', widget.designOptions.entries.map((e) => _buildRow(e.key, e.value)).toList()),
          ],
          if (widget.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard('📝 نوٹس', 'Notes', [
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.notes, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13, color: AppTheme.textPrimary))),
            ]),
          ],
          const SizedBox(height: 24),
          const Text('رسید ڈاؤن لوڈ / پرنٹ / شیئر', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const Text('Download / Print / Share Receipt', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildActionBtn('پرنٹ کریں\nPrint', Icons.print_rounded, AppTheme.primary, _printPdf)),
            const SizedBox(width: 10),
            Expanded(child: _buildActionBtn('شیئر کریں\nShare', Icons.share_rounded, AppTheme.info, _sharePdf)),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)), side: const BorderSide(color: AppTheme.border)), child: const Text('واپس جائیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textSecondary)))),
        ]),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusLarge), border: Border.all(color: AppTheme.borderLight), boxShadow: [AppTheme.shadowSmall]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ]),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ]),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusLarge), border: Border.all(color: AppTheme.borderLight), boxShadow: [AppTheme.shadowSmall]),
      child: Column(children: [
        Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ادائیگی کا خلاصہ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text('Payment Summary', style: TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ]),
        ]),
        const SizedBox(height: 14),
        _buildRow('سلائی / Silai', '₨ ${widget.priceAmount}'),
        _buildRow('فیبرک / Fabric', '₨ ${widget.fabricAmount}'),
        _buildRow('اضافی / Extra', '₨ ${widget.extraAmount}'),
        Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 1, color: AppTheme.borderLight),
        _buildRow('کل رقم / Total', '₨ ${widget.totalAmount}'),
        _buildRow('ایڈوانس / Advance', '₨ ${widget.advanceAmount}'),
        Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 1, color: AppTheme.borderLight),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.remainingAmount > 0 ? AppTheme.danger.withOpacity(0.05) : AppTheme.success.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: widget.remainingAmount > 0 ? AppTheme.danger.withOpacity(0.2) : AppTheme.success.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('بقایا رقم / Remaining', style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 12, color: AppTheme.textSecondary)),
            Text('₨ ${widget.remainingAmount}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.remainingAmount > 0 ? AppTheme.danger : AppTheme.success)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _isGeneratingPdf ? null : onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)), elevation: 4, shadowColor: color.withOpacity(0.3)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.w600, fontSize: 11, height: 1.3)),
      ]),
    );
  }
}