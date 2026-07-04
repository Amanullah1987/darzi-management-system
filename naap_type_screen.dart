import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class NaapTypeScreen extends StatefulWidget {
  const NaapTypeScreen({super.key});

  @override
  State<NaapTypeScreen> createState() => _NaapTypeScreenState();
}

class _NaapTypeScreenState extends State<NaapTypeScreen>
    with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> silaiTypes = [];
  List<Map<String, dynamic>> naapTypes = [];
  int? selectedSilaiId;
  bool isLoading = true;
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
    _loadSilaiTypes();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredNaapTypes {
    if (_searchQuery.isEmpty) return naapTypes;
    return naapTypes
        .where((n) => n['name']
        .toString()
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _loadSilaiTypes() async {
    final types = await dbHelper.getSilaiTypes();
    if (mounted) {
      setState(() {
        silaiTypes = types;
        if (silaiTypes.isNotEmpty) {
          selectedSilaiId = silaiTypes.first['id'];
          _loadNaapTypes();
        } else {
          isLoading = false;
        }
      });
    }
  }

  Future<void> _loadNaapTypes() async {
    if (selectedSilaiId == null) return;
    setState(() => isLoading = true);
    final data = await dbHelper.getNaapTypesBySilai(selectedSilaiId!);
    if (mounted) {
      setState(() {
        naapTypes = data;
        isLoading = false;
      });
      _listAnimationController.forward(from: 0);
    }
  }

  String _getSelectedSilaiName() {
    if (selectedSilaiId == null) return '';
    final silai = silaiTypes.firstWhere(
          (s) => s['id'] == selectedSilaiId,
      orElse: () => {'name': ''},
    );
    return silai['name'] ?? '';
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

  void _showNaapDialog({Map<String, dynamic>? existing}) {
    final controller = TextEditingController(text: existing?['name'] ?? '');
    final isEditing = existing != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEditing
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.straighten,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    isEditing ? "ناپ میں ترمیم" : "نیا ناپ شامل کریں",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing ? "موجودہ ناپ کی تفصیل اپڈیٹ کریں" : "نئی ناپ کی قسم کا نام درج کریں",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (selectedSilaiId != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'سلائی: ${_getSelectedSilaiName()}',
                        style: const TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 12,
                          color: Color(0xFF06B6D4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextFormField(
                      controller: controller,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 18,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'براہ کرم ناپ کا نام درج کریں';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: "ناپ کا نام لکھیں...",
                        hintStyle: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.straighten,
                          color: isEditing ? Colors.blue : const Color(0xFF06B6D4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "منسوخ",
                            style: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final name = controller.text.trim();
                            if (name.isEmpty || selectedSilaiId == null) return;

                            if (!isEditing) {
                              await dbHelper.insertNaapType(selectedSilaiId!, name);
                            } else {
                              await dbHelper.updateNaapType(
                                existing['id'],
                                selectedSilaiId!,
                                name,
                              );
                            }

                            if (!mounted) return;
                            Navigator.pop(context);
                            _showSnackBar(
                              isEditing
                                  ? "ناپ کامیابی سے اپڈیٹ ہو گیا ✅"
                                  : "ناپ کامیابی سے شامل ہو گیا ✅",
                            );
                            _loadNaapTypes();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            isEditing ? Colors.blue : const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 3,
                            shadowColor: (isEditing
                                ? Colors.blue
                                : const Color(0xFF06B6D4))
                                .withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEditing ? "اپڈیٹ کریں" : "محفوظ کریں",
                            style: const TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Future<void> _deleteNaapType(Map<String, dynamic> naap) async {
    final confirmed = await showDialog<bool>(
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
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                "حذف کرنے کی تصدیق",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'کیا آپ واقعی "${naap['name']}" کو حذف کرنا چاہتے ہیں؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "منسوخ",
                        style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 3,
                        shadowColor: Colors.red.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "حذف کریں",
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontWeight: FontWeight.bold,
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

    if (confirmed == true) {
      await dbHelper.deleteNaapType(naap['id']);
      _showSnackBar("ناپ کامیابی سے حذف ہو گیا");
      _loadNaapTypes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          "ناپ کی اقسام",
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: "ناپ تلاش کریں...",
                      hintStyle: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Silai Type Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<int>(
                    value: selectedSilaiId,
                    decoration: InputDecoration(
                      labelText: "سلائی کی قسم منتخب کریں",
                      labelStyle: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: Icon(
                        Icons.style,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: silaiTypes.map((type) {
                      return DropdownMenuItem<int>(
                        value: type['id'],
                        child: Text(
                          type['name'] ?? '',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 15,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedSilaiId = val);
                      _loadNaapTypes();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showNaapDialog(),
          backgroundColor: const Color(0xFF06B6D4),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add, color: Colors.white, size: 22),
          label: const Text(
            "نیا ناپ",
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF1A1A2E),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "ڈیٹا لوڈ ہو رہا ہے...",
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
          ],
        ),
      )
          : _filteredNaapTypes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off
                    : Icons.straighten,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? "کوئی نتیجہ نہیں ملا"
                  : "کوئی ناپ موجود نہیں",
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "براہ کرم مختلف الفاظ استعمال کریں"
                  : "نیا ناپ شامل کرنے کے لیے نیچے دیئے گئے بٹن پر کلک کریں",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _filteredNaapTypes.length,
          itemBuilder: (_, index) {
            final n = _filteredNaapTypes[index];
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _listAnimationController,
                  curve: Interval(
                    index * 0.05,
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF06B6D4),
                                const Color(0xFF06B6D4).withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.straighten,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['name'] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'NotoNastaliqUrdu',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "ناپ کی قسم",
                                style: TextStyle(
                                  fontFamily: 'NotoNastaliqUrdu',
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showNaapDialog(existing: n),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _deleteNaapType(n),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
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
              ),
            );
          },
        ),
      ),
    );
  }
}