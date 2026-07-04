import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class TakeMeasurementScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const TakeMeasurementScreen({super.key, required this.customer});

  @override
  State<TakeMeasurementScreen> createState() => _TakeMeasurementScreenState();
}

class _TakeMeasurementScreenState extends State<TakeMeasurementScreen>
    with TickerProviderStateMixin {

  // ═══════════════════════════════════════
  //  DATA
  // ═══════════════════════════════════════
  List<Map<String, dynamic>> _silaiTypes = [];
  List<Map<String, dynamic>> _naapTypes = [];
  Map<int, TextEditingController> _controllers = {};
  Map<int, FocusNode> _focusNodes = {};
  Map<int, bool> _fieldErrors = {};

  int? _selectedSilaiId;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // ═══════════════════════════════════════
  //  ANIMATIONS
  // ═══════════════════════════════════════
  late AnimationController _mainAnimController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final ScrollController _scrollController = ScrollController();

  // ═══════════════════════════════════════
  //  CONSTANTS
  // ═══════════════════════════════════════
  static const _primaryColor = Color(0xFF4F6EF7);
  static const _accentColor = Color(0xFF10B981);
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _cardColor = Colors.white;
  static const _textDark = Color(0xFF0F172A);
  static const _textMedium = Color(0xFF475569);
  static const _textLight = Color(0xFF94A3B8);
  static const _dangerColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    _mainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _mainAnimController,
      curve: Curves.easeOut,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainAnimController.forward();
    _loadSilaiTypes();
  }

  @override
  void dispose() {
    _mainAnimController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    for (var c in _controllers.values) { c.dispose(); }
    for (var f in _focusNodes.values) { f.dispose(); }
    super.dispose();
  }

  // ═══════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════
  Future<void> _loadSilaiTypes() async {
    try {
      final data = await DatabaseHelper.instance.getSilaiTypes();
      if (mounted) setState(() => _silaiTypes = data);
    } catch (e) {
      debugPrint('Error loading silai types: $e');
    }
  }

  Future<void> _loadNaapData() async {
    if (_selectedSilaiId == null) return;
    setState(() => _isLoading = true);

    for (var c in _controllers.values) { c.dispose(); }
    for (var f in _focusNodes.values) { f.dispose(); }
    _controllers.clear();
    _focusNodes.clear();
    _fieldErrors.clear();

    try {
      final naapTypes = await DatabaseHelper.instance.getNaapTypesBySilai(_selectedSilaiId!);
      final savedValues = await DatabaseHelper.instance.getCustomerMeasurements(
        widget.customer['id'],
        _selectedSilaiId!,
      );

      for (var type in naapTypes) {
        String val = savedValues[type['id']] ?? '';
        _controllers[type['id']] = TextEditingController(text: val);
        _focusNodes[type['id']] = FocusNode();
        _fieldErrors[type['id']] = false;

        _controllers[type['id']]!.addListener(() {
          if (!_hasUnsavedChanges && mounted) {
            setState(() => _hasUnsavedChanges = true);
          }
        });
      }

      if (mounted) {
        setState(() {
          _naapTypes = naapTypes;
          _isLoading = false;
          _hasUnsavedChanges = false;
        });
        _mainAnimController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Error loading naap data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════
  //  SAVE FUNCTIONALITY
  // ═══════════════════════════════════════
  Future<void> _saveData() async {
    if (_selectedSilaiId == null) return;

    // Validate fields
    bool hasErrors = false;
    Map<int, bool> tempErrors = {};
    for (var entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        tempErrors[entry.key] = true;
        hasErrors = true;
      } else {
        tempErrors[entry.key] = false;
      }
    }

    if (hasErrors) {
      setState(() => _fieldErrors = tempErrors);
      _showSnackBar('براہ کرم تمام خالی فیلڈز کو پُر کریں', true);
      return;
    }

    setState(() {
      _isSaving = true;
      _fieldErrors = tempErrors;
    });

    try {
      for (var entry in _controllers.entries) {
        await DatabaseHelper.instance.saveMeasurement(
          widget.customer['id'],
          _selectedSilaiId!,
          entry.key,
          entry.value.text.trim(),
        );
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
        });
        _showSaveSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error saving measurements: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('محفوظ کرنے میں خرابی۔ دوبارہ کوشش کریں', true);
      }
    }
  }

  void _showSaveSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentColor, Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'کامیابی! 🎉',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.customer['name'] ?? 'کسٹمر'} کی پیمائش کامیابی سے محفوظ ہو گئی',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 15,
                  color: _textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getSelectedSilaiName(),
                  style: const TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 13,
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'واپس جائیں',
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'غیر محفوظ شدہ تبدیلیاں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'کیا آپ واقعی واپس جانا چاہتے ہیں؟ آپ کی تبدیلیاں محفوظ نہیں ہوں گی۔',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 14,
                    color: _textMedium,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: _textLight),
                        ),
                        child: const Text(
                          'رہیں',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontWeight: FontWeight.w600,
                            color: _textMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dangerColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'چھوڑیں',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return result ?? false;
    }
    return true;
  }

  // ═══════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════
  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? _dangerColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String _getSelectedSilaiName() {
    if (_selectedSilaiId == null) return '';
    final silai = _silaiTypes.firstWhere(
          (s) => s['id'] == _selectedSilaiId,
      orElse: () => {'name': ''},
    );
    return silai['name'] ?? '';
  }

  double _getCompletionPercentage() {
    if (_controllers.isEmpty) return 0.0;
    int filled = 0;
    for (var entry in _controllers.entries) {
      if (entry.value.text.trim().isNotEmpty) filled++;
    }
    return filled / _controllers.length;
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final customerName = widget.customer['name']?.toString() ?? 'کسٹمر';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _surfaceColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(customerName),
              _buildSilaiSelector(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _naapTypes.isEmpty
                    ? _buildEmptyState()
                    : _buildMeasurementsList(),
              ),
              if (_naapTypes.isNotEmpty) _buildSaveBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════
  Widget _buildHeader(String customerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () async {
                final canPop = await _onWillPop();
                if (canPop && mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(width: 12),
          // Customer info
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_selectedSilaiId != null)
                  Text(
                    _getSelectedSilaiName(),
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 11,
                      color: _accentColor,
                    ),
                  ),
              ],
            ),
          ),
          // Unsaved indicator
          if (_hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: Colors.amber.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'غیر محفوظ',
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 10,
                      color: Colors.amber.shade300,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  SILAI SELECTOR
  // ═══════════════════════════════════════
  Widget _buildSilaiSelector() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedSilaiId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor, size: 22),
          style: const TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          hint: Row(
            children: [
              Icon(Icons.style_rounded, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'سلائی کی قسم منتخب کریں',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  color: _textLight,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          items: _silaiTypes.map((type) {
            return DropdownMenuItem<int>(
              value: type['id'],
              child: Row(
                children: [
                  Icon(Icons.checkroom_rounded, size: 16, color: _primaryColor.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    type['name'] ?? '',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != _selectedSilaiId) {
              if (_hasUnsavedChanges) {
                _showUnsavedChangesDialog(() {
                  setState(() {
                    _selectedSilaiId = val;
                    _hasUnsavedChanges = false;
                  });
                  _loadNaapData();
                });
              } else {
                setState(() => _selectedSilaiId = val);
                _loadNaapData();
              }
            }
          },
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog(VoidCallback onContinue) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'تبدیلیاں محفوظ نہیں',
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سلائی تبدیل کرنے سے موجودہ غیر محفوظ شدہ تبدیلیاں ضائع ہو جائیں گی۔',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 14,
                  color: _textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: _textLight),
                      ),
                      child: const Text(
                        'منسوخ',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontWeight: FontWeight.w600,
                          color: _textMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onContinue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'جاری رکھیں',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  LOADING STATE
  // ═══════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'پیمائش لوڈ ہو رہی ہے...',
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 15,
              color: _textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedSilaiId == null ? Icons.touch_app_rounded : Icons.inventory_2_outlined,
                size: 52,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedSilaiId == null
                  ? 'براہ کرم سلائی کی قسم منتخب کریں'
                  : 'اس سلائی کے لیے کوئی ناپ موجود نہیں',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textMedium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedSilaiId == null
                  ? 'اوپر دیے گئے ڈراپ ڈاؤن سے سلائی کی قسم منتخب کریں'
                  : 'براہ کرم پہلے ناپ کی اقسام شامل کریں',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 12,
                color: _textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  MEASUREMENTS LIST
  // ═══════════════════════════════════════
  Widget _buildMeasurementsList() {
    return Column(
      children: [
        if (_controllers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _buildCompletionBar(),
          ),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: _naapTypes.length,
              itemBuilder: (context, index) {
                final type = _naapTypes[index];
                final typeId = type['id'] as int;
                final controller = _controllers[typeId];
                final focusNode = _focusNodes[typeId];
                final hasError = _fieldErrors[typeId] ?? false;

                return _buildMeasurementTile(
                  index: index,
                  name: type['name'] ?? 'ناپ ${index + 1}',
                  controller: controller,
                  focusNode: focusNode,
                  hasError: hasError,
                  typeId: typeId,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionBar() {
    final percentage = _getCompletionPercentage();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            percentage >= 1.0 ? Icons.check_circle : Icons.radio_button_unchecked,
            color: percentage >= 1.0 ? _accentColor : _textLight,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 1.0 ? _accentColor : _primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(percentage * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: percentage >= 1.0 ? _accentColor : _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  MEASUREMENT TILE - RTL Layout
  // ═══════════════════════════════════════
  Widget _buildMeasurementTile({
    required int index,
    required String name,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required bool hasError,
    required int typeId,
  }) {
    final isFilled = controller != null && controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? _dangerColor.withOpacity(0.5)
              : isFilled
              ? _accentColor.withOpacity(0.2)
              : Colors.grey.shade100,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => focusNode?.requestFocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isFilled
                      ? _accentColor.withOpacity(0.1)
                      : hasError
                      ? _dangerColor.withOpacity(0.1)
                      : _primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isFilled
                      ? const Icon(Icons.check_rounded, color: _accentColor, size: 18)
                      : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasError ? _dangerColor : _primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasError ? _dangerColor : _textDark,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'ضروری ہے',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 10,
                            color: _dangerColor.withOpacity(0.7),
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Input
              Container(
                width: 110,
                height: 44,
                decoration: BoxDecoration(
                  color: isFilled
                      ? _accentColor.withOpacity(0.04)
                      : hasError
                      ? _dangerColor.withOpacity(0.04)
                      : _surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: focusNode?.hasFocus == true
                        ? (hasError ? _dangerColor : _primaryColor)
                        : (hasError ? _dangerColor.withOpacity(0.3) : Colors.transparent),
                    width: focusNode?.hasFocus == true ? 1.5 : 0,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isFilled ? _accentColor : _textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  onChanged: (_) {
                    if (hasError && mounted) {
                      setState(() => _fieldErrors[typeId] = false);
                    }
                    if (!_hasUnsavedChanges && mounted) {
                      setState(() => _hasUnsavedChanges = true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  SAVE BAR
  // ═══════════════════════════════════════
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _hasUnsavedChanges ? _pulseAnimation.value : 1.0,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasUnsavedChanges ? _accentColor : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: _hasUnsavedChanges ? 4 : 0,
                  shadowColor: _accentColor.withOpacity(0.3),
                  padding: EdgeInsets.zero,
                ),
                child: _isSaving
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'محفوظ ہو رہا ہے...',
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasUnsavedChanges ? Icons.save_rounded : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasUnsavedChanges ? 'پیمائش محفوظ کریں' : 'تمام پیمائشیں محفوظ ہیں ✓',
                      style: const TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}