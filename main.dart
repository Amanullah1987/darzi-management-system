import 'dart:io';
import 'package:darzi_management_system/screens/expenses_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'db/database_helper.dart';
import 'screens/business_info_screen.dart';
import 'screens/customer_add_screen.dart';
import 'screens/stitch_type_screen.dart';
import 'screens/naap_type_screen.dart';
import 'screens/naap_extra_info_screen.dart';
import 'screens/order_management_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/take_measurement_screen.dart';

// ═══════════════════════════════════════════════
//  THEME NOTIFIER — global dark/light mode
// ═══════════════════════════════════════════════
class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

// ═══════════════════════════════════════════════
//  APP ENTRY POINT
// ═══════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  runApp(const DarziManagementSystem());
}

class DarziManagementSystem extends StatefulWidget {
  const DarziManagementSystem({super.key});

  @override
  State<DarziManagementSystem> createState() => _DarziManagementSystemState();
}

class _DarziManagementSystemState extends State<DarziManagementSystem> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    themeNotifier.removeListener(() => setState(() {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Darzi Management System',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'NotoNastaliqUrdu',
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        fontFamily: 'NotoNastaliqUrdu',
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6EF7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const DashboardScreen(),
    );
  }
}

// ═══════════════════════════════════════════════
//  THEME CONSTANTS — light mode
// ═══════════════════════════════════════════════
const _c1 = Color(0xFF0A0F1E);
const _c2 = Color(0xFF141B35);
const _c3 = Color(0xFF1E2D5A);
const _cAccent  = Color(0xFF4F6EF7);
const _cGreen   = Color(0xFF10B981);
const _cOrange  = Color(0xFFF59E0B);
const _cRose    = Color(0xFFEF4444);
const _cTeal    = Color(0xFF06B6D4);
const _cViolet  = Color(0xFF8B5CF6);

// ═══════════════════════════════════════════════
//  DATE FILTER ENUM
// ═══════════════════════════════════════════════
enum DateFilter { today, thisWeek, thisMonth, thisYear, allTime, custom }

// ═══════════════════════════════════════════════
//  DATE HELPER
// ═══════════════════════════════════════════════
class _D {
  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try { return DateTime.parse(s.split(' ')[0]); } catch (_) {}
    final ms = int.tryParse(s);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return null;
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool orderInFilter(
      dynamic orderDateRaw,
      DateFilter filter,
      DateTime? rangeStart,
      DateTime? rangeEnd,
      ) {
    if (filter == DateFilter.allTime) return true;
    final d = parse(orderDateRaw);
    if (d == null) return false;
    final today = _today;
    switch (filter) {
      case DateFilter.today:
        return d.year == today.year && d.month == today.month && d.day == today.day;
      case DateFilter.thisWeek:
        final ws = today.subtract(Duration(days: today.weekday - 1));
        final we = ws.add(const Duration(days: 6));
        return !d.isBefore(ws) && !d.isAfter(we);
      case DateFilter.thisMonth:
        return d.year == today.year && d.month == today.month;
      case DateFilter.thisYear:
        return d.year == today.year;
      case DateFilter.custom:
        if (rangeStart != null && rangeEnd != null) {
          return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
        }
        return true;
      case DateFilter.allTime:
        return true;
    }
  }

  static bool isDeliveryDueToday(dynamic deliveryDateRaw) {
    final d = parse(deliveryDateRaw);
    if (d == null) return false;
    final today = _today;
    return !d.isAfter(today);
  }

  static bool expenseInFilter(
      dynamic dateRaw,
      DateFilter filter,
      DateTime? rangeStart,
      DateTime? rangeEnd,
      ) {
    return orderInFilter(dateRaw, filter, rangeStart, rangeEnd);
  }

  static String fmt(dynamic raw) {
    final d = parse(raw);
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ═══════════════════════════════════════════════
//  DATABASE BACKUP & RESTORE HELPER
// ═══════════════════════════════════════════════
class DatabaseBackupHelper {
  static const String _dbName = 'darzi_management.db';

  static Future<String> get _dbPath async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbName);
  }

  static Future<Directory> get _backupFolder async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'DarziBackups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  static void _showSnackBar(BuildContext context, String msg, Color color,
      {Duration duration = const Duration(seconds: 3)}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'NotoNastaliqUrdu')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(20),
      duration: duration,
    ));
  }

  // ═══════════════ BACKUP DATABASE ═══════════════
  static Future<String?> backupDatabase(BuildContext context) async {
    try {
      final sourcePath = await _dbPath;
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        if (context.mounted) {
          _showSnackBar(context, 'ڈیٹا بیس فائل موجود نہیں ہے', Colors.red);
        }
        return null;
      }

      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'darzi_backup_$dateStr.db';

      final backupDir = await _backupFolder;
      final backupPath = p.join(backupDir.path, fileName);
      final backupFile = File(backupPath);

      await sourceFile.copy(backupPath);

      if (context.mounted) {
        _showSnackBar(
          context,
          'بیک اپ کامیابی سے محفوظ ہو گیا!\nفولڈر: ${backupDir.path}\nفائل: $fileName',
          Colors.green,
          duration: const Duration(seconds: 5),
        );

        final shouldShare = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.share_rounded, color: Colors.blue, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'بیک اپ شیئر کریں؟',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'کیا آپ بیک اپ فائل شیئر کرنا چاہتے ہیں؟',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('نہیں', style: TextStyle(fontFamily: 'NotoNastaliqUrdu')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('شیئر کریں',
                    style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldShare == true) {
          await Share.shareXFiles(
            [XFile(backupPath)],
            subject: 'Darzi Management Backup',
          );
        }
      }

      return backupPath;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'بیک اپ ناکام: $e', Colors.red);
      }
      return null;
    }
  }

  // ═══════════════ RESTORE DATABASE ═══════════════
  static Future<bool> restoreDatabase(BuildContext context) async {
    try {
      final backupDir = await _backupFolder;
      final allFiles = await backupDir.list().toList();
      final backupFiles = allFiles
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      if (backupFiles.isEmpty) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'کوئی بیک اپ نہیں ملا',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'بیک اپ فولڈر میں کوئی بیک اپ فائل موجود نہیں ہے۔\n\n'
                    'بیک اپ فولڈر: ${backupDir.path}\n\n'
                    'براہ کرم بیک اپ فائل اس فولڈر میں رکھیں یا پہلے بیک اپ لیں۔',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ٹھیک ہے',
                      style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return false;
      }

      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      final selectedFile = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.restore_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'بیک اپ فائل منتخب کریں',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backupFiles.length,
              itemBuilder: (_, index) {
                final file = backupFiles[index];
                final fileName = p.basename(file.path);
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storage_rounded, color: Colors.green, size: 20),
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'فولڈر: ${backupDir.path}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  onTap: () => Navigator.pop(ctx, file.path),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu')),
            ),
          ],
        ),
      );

      if (selectedFile == null) return false;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ڈیٹا بحال کریں؟',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'کیا آپ واقعی ڈیٹا بیس کو بحال کرنا چاہتے ہیں؟\n\n'
                'موجودہ تمام ڈیٹا مٹ جائے گا اور بیک اپ فائل سے ڈیٹا بحال ہو جائے گا۔\n\n'
                'فائل: ${p.basename(selectedFile)}',
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('بحال کریں',
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return false;

      final sourceFile = File(selectedFile);
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          _showSnackBar(context, 'منتخب کردہ فائل موجود نہیں ہے', Colors.red);
        }
        return false;
      }

      await DatabaseHelper.instance.close();

      final destPath = await _dbPath;
      final destFile = File(destPath);

      if (await destFile.exists()) {
        final backupOfCurrent = '$destPath.backup_before_restore';
        await destFile.copy(backupOfCurrent);
      }

      await sourceFile.copy(destPath);

      if (context.mounted) {
        _showSnackBar(
          context,
          'ڈیٹا بیس کامیابی سے بحال ہو گیا۔ براہ کرم ایپ دوبارہ شروع کریں۔',
          Colors.green,
          duration: const Duration(seconds: 5),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'بحالی ناکام: $e', Colors.red);
      }
      return false;
    }
  }

  // ═══════════════ RESET ALL DATA ═══════════════
  static Future<bool> resetAllData(BuildContext context) async {
    try {
      final confirmFirst = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.dangerous_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تمام ڈیٹا حذف کریں؟',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'انتباہ! یہ عمل ناقابلِ واپسی ہے۔\n\n'
                'تمام کسٹمرز، آرڈرز، ادائیگیاں، اخراجات، کاریگر اور دیگر تمام ڈیٹا مستقل طور پر حذف ہو جائے گا۔\n\n'
                'براہ کرم پہلے بیک اپ لے لیں۔',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'NotoNastaliqUrdu',
              fontSize: 13,
              color: Colors.red,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('آگے بڑھیں',
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmFirst != true) return false;

      final confirmSecond = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'کیا آپ کو یقین ہے؟',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'یہ آخری انتباہ ہے۔ تمام ڈیٹا حذف ہو جائے گا اور اسے واپس نہیں لایا جا سکتا۔\n\n'
                'کیا آپ پھر بھی جاری رکھنا چاہتے ہیں؟',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('منسوخ', style: TextStyle(fontFamily: 'NotoNastaliqUrdu')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حذف کریں',
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmSecond != true) return false;

      await DatabaseHelper.instance.clearAllData();

      if (context.mounted) {
        _showSnackBar(
          context,
          'تمام ڈیٹا کامیابی سے حذف ہو گیا۔ براہ کرم ایپ دوبارہ شروع کریں۔',
          Colors.green,
          duration: const Duration(seconds: 4),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'ڈیٹا حذف کرنے میں خرابی: $e', Colors.red);
      }
      return false;
    }
  }
}

// ═══════════════════════════════════════════════
//  DATABASE MANAGEMENT DIALOG
// ═══════════════════════════════════════════════
class DatabaseManagementDialog extends StatelessWidget {
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const DatabaseManagementDialog({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cAccent, _cViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.storage_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'ڈیٹا بیس مینجمنٹ',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'بیک اپ، بحالی اور ری سیٹ',
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              context: context,
              icon: Icons.backup_rounded,
              label: 'بیک اپ لیں',
              subtitle: 'ڈیٹا بیس کی کاپی محفوظ کریں',
              color: _cGreen,
              onTap: () async {
                Navigator.pop(context);
                await DatabaseBackupHelper.backupDatabase(context);
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context: context,
              icon: Icons.restore_rounded,
              label: 'ڈیٹا بحال کریں',
              subtitle: 'پچھلے بیک اپ سے ڈیٹا بحال کریں',
              color: _cOrange,
              onTap: () async {
                Navigator.pop(context);
                await DatabaseBackupHelper.restoreDatabase(context);
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context: context,
              icon: Icons.delete_forever_rounded,
              label: 'تمام ڈیٹا حذف کریں',
              subtitle: 'ایپ کو مکمل طور پر ری سیٹ کریں',
              color: _cRose,
              onTap: () async {
                Navigator.pop(context);
                await DatabaseBackupHelper.resetAllData(context);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_c1, _c3]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'بند کریں',
                  style: TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═══════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {

  // ── Business
  String businessName    = '';
  String businessPhone   = '';
  String businessAddress = '';

  // ── Order Stats (filtered by order_date)
  int totalOrders     = 0;
  int pendingOrders   = 0;
  int completedOrders = 0;
  int deliveredOrders = 0;
  int cancelledOrders = 0;
  int totalCustomers  = 0;

  // ── Financial
  double totalRevenue      = 0;
  double pendingPayments   = 0;
  double receivedPayments  = 0;
  double totalExpenses     = 0;
  double netProfit         = 0;

  // ── Due Today
  List<Map<String, dynamic>> dueTodayOrders = [];

  // ── Date Filter
  DateFilter _selectedFilter = DateFilter.allTime;
  DateTime?  _customStartDate;
  DateTime?  _customEndDate;

  bool isLoading = true;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    _pulseController.dispose();
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════
  //  LOAD DATA - FIX: Include karigar payments in totalExpenses
  // ═══════════════════════════════════════════════
  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      // Fetch ALL data sources in parallel
      final results = await Future.wait([
        DatabaseHelper.instance.getBusinessInfo(),
        DatabaseHelper.instance.getDatabaseStats(),
        DatabaseHelper.instance.getOrdersWithCustomerDetails(),
        DatabaseHelper.instance.getExpenses(),
        DatabaseHelper.instance.getTotalKarigarPayments(), // ← NEW: Fetch karigar payments
      ]);

      final bizData          = results[0] as Map<String, dynamic>?;
      final stats            = results[1] as Map<String, int>;
      final orders           = results[2] as List<Map<String, dynamic>>;
      final expenses         = results[3] as List<Map<String, dynamic>>;
      final totalKarigarPay  = results[4] as double; // ← NEW: Total karigar payments

      int p = 0, c = 0, dv = 0, ca = 0;
      double rev = 0, pendPay = 0, recPay = 0;
      double expTotal = 0;
      final List<Map<String, dynamic>> dueList = [];

      // ── Process orders
      for (final order in orders) {
        final orderDate = order['order_date'];
        final isInFilter = _D.orderInFilter(
          orderDate, _selectedFilter, _customStartDate, _customEndDate,
        );

        if (isInFilter) {
          final status = (order['status'] ?? '').toString().toLowerCase().trim();
          final total  = double.tryParse(order['total_amount']?.toString()     ?? '0') ?? 0;
          final rem    = double.tryParse(order['remaining_amount']?.toString() ?? '0') ?? 0;
          rev     += total;
          pendPay += rem;
          recPay  += (total - rem);
          switch (status) {
            case 'pending':   p++;  break;
            case 'completed': c++;  break;
            case 'delivered': dv++; break;
            case 'cancelled': ca++; break;
          }
        }

        final status = (order['status'] ?? '').toString().toLowerCase().trim();
        if (status == 'pending' && _D.isDeliveryDueToday(order['delivery_date'])) {
          dueList.add(order);
        }
      }

      // ── Process expenses from expenses table
      for (final expense in expenses) {
        expTotal += double.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
      }

      // ── FIX: Add karigar/worker payments to total expenses
      // This ensures ALL worker payments are counted in totalExpenses
      // totalExpenses = regular expenses + karigar payments
      expTotal += totalKarigarPay;

      // ── Calculate net profit with complete expenses
      // netProfit = totalRevenue - totalExpenses (including karigar payments)
      final calculatedNetProfit = rev - expTotal;

      if (!mounted) return;
      setState(() {
        businessName    = bizData?['name']    ?? 'درزی مینجمنٹ سسٹم';
        businessPhone   = bizData?['phone']   ?? '';
        businessAddress = bizData?['address'] ?? '';
        totalCustomers  = stats['customers'] ?? 0;
        totalOrders     = p + c + dv + ca;
        pendingOrders   = p;
        completedOrders = c;
        deliveredOrders = dv;
        cancelledOrders = ca;
        totalRevenue     = rev;
        pendingPayments  = pendPay;
        receivedPayments = recPay;
        totalExpenses    = expTotal;
        netProfit        = calculatedNetProfit;
        dueTodayOrders   = dueList;
        isLoading        = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════
  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'NotoNastaliqUrdu')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 2),
    ));
  }

  String _filterLabel(DateFilter f) {
    switch (f) {
      case DateFilter.today:     return 'آج';
      case DateFilter.thisWeek:  return 'اس ہفتے';
      case DateFilter.thisMonth: return 'اس ماہ';
      case DateFilter.thisYear:  return 'اس سال';
      case DateFilter.allTime:   return 'تمام';
      case DateFilter.custom:    return 'کسٹم';
    }
  }

  String _moneyFmt(double v) {
    if (v >= 1000000) return '₨${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₨${(v / 1000).toStringAsFixed(1)}k';
    return '₨${v.toStringAsFixed(0)}';
  }

  bool get _isDark => themeNotifier.isDark;

  Color get _bgColor => _isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6FB);
  Color get _cardColor => _isDark ? const Color(0xFF161B22) : Colors.white;
  Color get _textColor => _isDark ? Colors.white : Colors.black87;
  Color get _subtitleColor => _isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  // ═══════════════════════════════════════════════
  //  SHOW DATABASE MANAGEMENT DIALOG
  // ═══════════════════════════════════════════════
  void _showDatabaseManagementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DatabaseManagementDialog(
        isDark: _isDark,
        cardColor: _cardColor,
        textColor: _textColor,
        subtitleColor: _subtitleColor,
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  DATE RANGE PICKER
  // ═══════════════════════════════════════════════
  Future<void> _showCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _cAccent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate   = picked.end;
        _selectedFilter  = DateFilter.custom;
      });
      _loadAllData();
    }
  }

  // ═══════════════════════════════════════════════
  //  DUE TODAY BOTTOM SHEET
  // ═══════════════════════════════════════════════
  void _showDueTodaySheet() {
    if (dueTodayOrders.isEmpty) {
      _toast('آج کوئی آرڈر ڈیو نہیں', _cGreen);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DueTodaySheet(orders: dueTodayOrders),
    );
  }

  // ═══════════════════════════════════════════════
  //  HOW TO USE ALERT
  // ═══════════════════════════════════════════════
  void _showHowToUseAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline_rounded, color: _cAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ایپ کا استعمال',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _howToRow(Icons.dashboard_rounded, _cAccent,
                  'ڈیش بورڈ', 'تمام آرڈرز، آمدنی، اخراجات اور منافع کا جائزہ یہاں ملتا ہے۔'),
              _howToRow(Icons.person_add_alt_1_rounded, _cGreen,
                  'کسٹمر شامل کریں', 'نیا کسٹمر شامل کرنے کے لیے "کسٹمر" بٹن دبائیں۔'),
              _howToRow(Icons.add_shopping_cart_rounded, _cOrange,
                  'نیا آرڈر', 'FAB بٹن (نیچے) سے یا "فوری رسائی" سے نیا آرڈر بنائیں۔'),
              _howToRow(Icons.straighten_rounded, _cTeal,
                  'پیمائش لیں', 'کسٹمر منتخب کریں اور پیمائش درج کریں۔'),
              _howToRow(Icons.money_off_rounded, const Color(0xFF14B8A6),
                  'اخراجات', 'کاروباری اخراجات "اخراجات" بٹن سے شامل کریں۔'),
              _howToRow(Icons.filter_alt_rounded, _cViolet,
                  'فلٹر', 'اوپر والے ٹیبز سے آج، ہفتہ، مہینہ یا کسٹم تاریخ کا فلٹر لگائیں۔'),
              _howToRow(Icons.trending_up_rounded, _cRose,
                  'خالص منافع', 'کل آمدنی میں سے کل اخراجات نکال کر خالص منافع حاصل ہوتا ہے۔'),
              _howToRow(Icons.warning_amber_rounded, Colors.red,
                  'آج ڈیلیوری', 'سرخ بینر آج کی ڈیلیوری والے آرڈرز دکھاتا ہے۔'),
              _howToRow(Icons.refresh_rounded, _cGreen,
                  'ریفریش', 'اسکرین نیچے کھینچ کر ڈیٹا دوبارہ لوڈ کریں۔'),
              _howToRow(Icons.storage_rounded, _cViolet,
                  'ڈیٹا بیس', 'سائیڈ مینو سے بیک اپ لیں، ڈیٹا بحال کریں یا ایپ ری سیٹ کریں۔'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_cAccent, _cViolet]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'سمجھ آ گیا',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'NotoNastaliqUrdu',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _howToRow(IconData icon, Color color, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _textColor)),
                const SizedBox(height: 2),
                Text(desc,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 11,
                        color: _subtitleColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  DEVELOPER INFO ALERT
  // ═══════════════════════════════════════════════
  void _showDeveloperInfoAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_cAccent, _cViolet]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.code_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ڈیولپر کی معلومات',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Developer avatar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_cAccent.withOpacity(0.15), _cViolet.withOpacity(0.15)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _cAccent.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.person_rounded, size: 40, color: _cAccent),
            ),
            const SizedBox(height: 18),
            _devInfoRow(Icons.badge_rounded,       _cAccent,  'ڈیولپر',    'امان اللہ'),
            _devInfoRow(Icons.phone_rounded,       _cGreen,   'رابطہ',     '+92 313 5377488'),
            _devInfoRow(Icons.email_rounded,       _cOrange,  'ای میل',    'khanamanullah.83@example.com'),
            _devInfoRow(Icons.business_rounded,    _cTeal,    'کمپنی',     'Software Developer'),
            _devInfoRow(Icons.info_outline_rounded,_cViolet,  'ورژن',      'v1.0.0 (2026)'),
            _devInfoRow(Icons.location_on_rounded, _cRose,    'مقام',      'اسلام آباد پاکستان'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cGreen.withOpacity(0.2)),
              ),
              child: Text(
                '© 2026 تمام حقوق محفوظ ہیں\nیہ سافٹ ویئر درزی کاروبار کے لیے خصوصی طور پر بنایا گیا ہے۔',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 11,
                  color: _cGreen,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_c1, _c3]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text('بند کریں',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'NotoNastaliqUrdu',
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devInfoRow(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 12,
                  color: _subtitleColor)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontFamily: 'NotoNastaliqUrdu',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _textColor)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  CUSTOMER PICKER SHEET
  // ═══════════════════════════════════════════════
  Future<void> _pickCustomer({
    required String title,
    String? subtitle,
    required void Function(Map<String, dynamic>) onSelect,
    IconData icon = Icons.person,
    Color iconColor = _cAccent,
  }) async {
    final customers = await DatabaseHelper.instance.getCustomers();
    if (!mounted) return;
    if (customers.isEmpty) { _toast('پہلے کسٹمر شامل کریں', _cOrange); return; }

    final ctrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(customers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, ss) => Container(
          height: MediaQuery.of(context).size.height * 0.80,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 50, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),

            Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'NotoNastaliqUrdu',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textColor)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(color: _subtitleColor, fontSize: 12, fontFamily: 'NotoNastaliqUrdu')),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${filtered.length}',
                    style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ])),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF21262D) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                ),
                child: TextField(
                  controller: ctrl,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 14, color: _textColor),
                  onChanged: (val) => ss(() {
                    filtered = customers.where((c) {
                      final q = val.toLowerCase();
                      return (c['name']?.toString().toLowerCase() ?? '').contains(q) ||
                          (c['phone']?.toString() ?? '').contains(q);
                    }).toList();
                  }),
                  decoration: InputDecoration(
                    hintText: 'نام یا فون نمبر سے تلاش کریں...',
                    hintStyle: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                    suffixIcon: ctrl.text.isNotEmpty
                        ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                        onPressed: () { ctrl.clear(); ss(() => filtered = List.from(customers)); })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text('کوئی کسٹمر نہیں ملا',
                    style: TextStyle(fontFamily: 'NotoNastaliqUrdu', color: Colors.grey, fontSize: 15)),
              ]))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c   = filtered[i];
                  final bal = double.tryParse(c['balance']?.toString() ?? '0') ?? 0;
                  final hasBalance = bal > 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () { Navigator.pop(ctx); onSelect(c); },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                gradient: LinearGradient(colors: hasBalance
                                    ? [Colors.red.shade300, Colors.red.shade500]
                                    : [Colors.green.shade300, Colors.green.shade500]),
                              ),
                              child: Center(child: Text(
                                (c['name']?.toString().isNotEmpty == true)
                                    ? c['name'].toString()[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              )),
                            ),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c['name']?.toString() ?? '',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                                      fontFamily: 'NotoNastaliqUrdu', color: _textColor)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.phone, size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(c['phone']?.toString() ?? '',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ]),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasBalance ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hasBalance ? 'بقایا: ₨${bal.toStringAsFixed(0)}' : 'کلیئر',
                                  style: TextStyle(
                                    color: hasBalance ? Colors.red.shade700 : Colors.green,
                                    fontSize: 10,
                                    fontFamily: 'NotoNastaliqUrdu',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoader();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgColor,
      drawer: _buildSideDrawer(),
      floatingActionButton: SpeedDialFAB(
        pulseAnimation: _pulseAnimation,
        onNewOrder: () => _pickCustomer(
          title: 'فوری آرڈر بنائیں',
          subtitle: 'کسٹمر منتخب کر کے نیا آرڈر بنائیں',
          icon: Icons.add_shopping_cart,
          iconColor: _cGreen,
          onSelect: (c) => Navigator.push(context,
              MaterialPageRoute(builder: (_) => NewOrderScreen(customer: c))).then((_) => _loadAllData()),
        ),
        onNewMeasure: () => _pickCustomer(
          title: 'نئی پیمائش لیں',
          subtitle: 'کسٹمر منتخب کر کے پیمائش درج کریں',
          icon: Icons.straighten,
          iconColor: _cTeal,
          onSelect: (c) => Navigator.push(context,
              MaterialPageRoute(builder: (_) => TakeMeasurementScreen(customer: c))).then((_) => _loadAllData()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: _cAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── HEADER
            _buildHeader(),

            // ── DUE TODAY BANNER
            if (dueTodayOrders.isNotEmpty) _buildDueBanner(),

            // ── DATE FILTER TABS
            _buildFilterTabs(),

            // ── STATS OVERVIEW
            _buildStatsOverview(),

            // ── FINANCIAL CARDS
            _buildFinancialCards(),

            // ── NET PROFIT CARD
            _buildNetProfitCard(),

            // ── QUICK ACTIONS
            _buildQuickActions(),

            const SizedBox(height: 110),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  SIDE DRAWER
  // ═══════════════════════════════════════════════
  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: _isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_c1, _c2, _c3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_cAccent, _cViolet]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: _cAccent.withOpacity(0.4), blurRadius: 14)],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    businessName.isEmpty ? 'درزی مینجمنٹ' : businessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'NotoNastaliqUrdu',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مینجمنٹ سسٹم v1.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontFamily: 'NotoNastaliqUrdu',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dark / Light Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF21262D) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isDark ? _cAccent.withOpacity(0.15) : _cOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: _isDark ? _cAccent : _cOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isDark ? 'ڈارک موڈ' : 'لائٹ موڈ',
                        style: TextStyle(
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isDark,
                      onChanged: (v) {
                        themeNotifier.toggle();
                      },
                      activeColor: _cAccent,
                      inactiveThumbColor: _cOrange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                color: _isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 8),

            // Menu Items
            _drawerItem(
              icon: Icons.backup_rounded,
              label: 'ڈیٹا بیس مینجمنٹ',
              color: _cTeal,
              onTap: () {
                Navigator.pop(context);
                _showDatabaseManagementDialog();
              },
            ),
            _drawerItem(
              icon: Icons.info_outline_rounded,
              label: 'ایپ کے بارے میں',
              color: _cAccent,
              onTap: () {
                Navigator.pop(context);
                _showHowToUseAlert();
              },
            ),
            _drawerItem(
              icon: Icons.code_rounded,
              label: 'ڈیولپر کی معلومات',
              color: _cViolet,
              onTap: () {
                Navigator.pop(context);
                _showDeveloperInfoAlert();
              },
            ),
            _drawerItem(
              icon: Icons.store_mall_directory_rounded,
              label: 'کاروباری معلومات',
              color: _cOrange,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BusinessInfoScreen()))
                    .then((_) => _loadAllData());
              },
            ),
            _drawerItem(
              icon: Icons.refresh_rounded,
              label: 'ڈیٹا ریفریش کریں',
              color: _cGreen,
              onTap: () {
                Navigator.pop(context);
                _loadAllData();
                _toast('ڈیٹا ریفریش ہو رہا ہے...', _cGreen);
              },
            ),

            const Spacer(),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_cAccent.withOpacity(0.08), _cViolet.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cAccent.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded, color: _cRose, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'محبت سے بنایا گیا',
                          style: TextStyle(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 11,
                            color: _subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2025 Darzi Tech Solutions',
                      style: TextStyle(
                        fontSize: 10,
                        color: _subtitleColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Colors.transparent,
        hoverColor: color.withOpacity(0.06),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        trailing: Icon(Icons.arrow_back_ios_rounded, size: 12, color: Colors.grey[400]),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  LOADER
  // ═══════════════════════════════════════════════
  Widget _buildLoader() {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cAccent, _cViolet]),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: _cAccent.withOpacity(0.4), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
        const SizedBox(height: 28),
        const Text('ڈیٹا لوڈ ہو رہا ہے...',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 17, color: Colors.grey, fontWeight: FontWeight.w500)),
      ])),
    );
  }

  // ═══════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 58, 22, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_c1, _c2, _c3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(42)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // Hamburger menu icon
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            ),
          ),

          // Title + status
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _cGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _cGreen.withOpacity(0.6), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text('آن لائن',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'NotoNastaliqUrdu')),
            ]),
            const SizedBox(height: 4),
            const Text('درزی مینجمنٹ', style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
              fontFamily: 'NotoNastaliqUrdu', letterSpacing: -0.3,
            )),
          ]),

          // Business info icon
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessInfoScreen()));
              _loadAllData();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 22),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // Business card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.13)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_cAccent, _cViolet], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _cAccent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(businessName.isEmpty ? 'کاروبار کا نام' : businessName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'NotoNastaliqUrdu')),
              if (businessPhone.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.phone_rounded, size: 11, color: Colors.white.withOpacity(0.45)),
                  const SizedBox(width: 5),
                  Text(businessPhone, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ]),
              ],
              if (businessAddress.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 11, color: Colors.white.withOpacity(0.45)),
                  const SizedBox(width: 5),
                  Flexible(child: Text(businessAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11))),
                ]),
              ],
            ])),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  DUE TODAY BANNER
  // ═══════════════════════════════════════════════
  Widget _buildDueBanner() {
    return GestureDetector(
      onTap: _showDueTodaySheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red.shade500, Colors.red.shade700]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('آج ڈیلیوری والے آرڈرز', style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'NotoNastaliqUrdu')),
            const SizedBox(height: 1),
            Text('${dueTodayOrders.length} آرڈرز کی ڈیلیوری آج ہے',
                style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12, fontFamily: 'NotoNastaliqUrdu')),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text('${dueTodayOrders.length}',
                style: TextStyle(color: Colors.red.shade600, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  DATE FILTER TABS
  // ═══════════════════════════════════════════════
  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: DateFilter.values.map((f) {
            final sel = _selectedFilter == f;
            String label = _filterLabel(f);
            if (f == DateFilter.custom && sel && _customStartDate != null) {
              label = '${_customStartDate!.day}/${_customStartDate!.month} — ${_customEndDate!.day}/${_customEndDate!.month}';
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (f == DateFilter.custom) { _showCustomDatePicker(); return; }
                  setState(() => _selectedFilter = f);
                  _loadAllData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _cAccent : (_isDark ? const Color(0xFF21262D) : Colors.white),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: sel ? _cAccent : (_isDark ? Colors.grey.shade700 : Colors.grey.shade200)),
                    boxShadow: sel
                        ? [BoxShadow(color: _cAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (f == DateFilter.custom) ...[
                      Icon(Icons.date_range_rounded, size: 13, color: sel ? Colors.white : Colors.grey[500]),
                      const SizedBox(width: 5),
                    ],
                    Text(label, style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'NotoNastaliqUrdu',
                        color: sel ? Colors.white : (_isDark ? Colors.grey.shade300 : Colors.grey[600]))),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  STATS OVERVIEW CARD
  // ═══════════════════════════════════════════════
  Widget _buildStatsOverview() {
    final completionRate = totalOrders > 0 ? (completedOrders + deliveredOrders) / totalOrders : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('آرڈرز کا جائزہ',
                style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 17, fontWeight: FontWeight.bold, color: _textColor)),
            GestureDetector(
              onTap: () => _pickCustomer(
                title: 'کسٹمر منتخب کریں',
                icon: Icons.receipt_long,
                iconColor: _cAccent,
                onSelect: (c) => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrderManagementScreen(customer: c))).then((_) => _loadAllData()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_cAccent, _cViolet]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: _cAccent.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Text('تمام آرڈرز',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            _statPill('زیر التواء', pendingOrders,   _cOrange),
            _statPill('مکمل',       completedOrders, _cGreen),
            _statPill('ڈیلیور',     deliveredOrders, _cAccent),
            _statPill('منسوخ',      cancelledOrders, _cRose),
          ]),
          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 9,
              backgroundColor: _isDark ? Colors.grey.shade700 : Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(_cGreen),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('تکمیل کی شرح',
                style: TextStyle(color: _subtitleColor, fontSize: 11, fontFamily: 'NotoNastaliqUrdu')),
            Text('${(completionRate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: _cGreen, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Expanded(child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 5),
      Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 5),
      FittedBox(child: Text(label,
          style: TextStyle(fontSize: 10, color: _subtitleColor, fontFamily: 'NotoNastaliqUrdu'))),
    ]));
  }

  // ═══════════════════════════════════════════════
  //  FINANCIAL CARDS
  // ═══════════════════════════════════════════════
  Widget _buildFinancialCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        Row(children: [
          Expanded(child: _finCard('کل آمدنی',   _moneyFmt(totalRevenue),     Icons.trending_up,          _cGreen)),
          const SizedBox(width: 12),
          Expanded(child: _finCard('وصول شدہ',   _moneyFmt(receivedPayments), Icons.check_circle_outline,  _cAccent)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _finCard('بقایا جات',  _moneyFmt(pendingPayments),  Icons.error_outline,         _cRose)),
          const SizedBox(width: 12),
          Expanded(child: _finCard('کسٹمرز',     '$totalCustomers',           Icons.people_outline,         _cOrange)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _finCard('کل اخراجات', _moneyFmt(totalExpenses),    Icons.money_off_rounded,      _cRose)),
        ]),
      ]),
    );
  }

  Widget _finCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(_isDark ? 0.15 : 0.08), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(height: 2),
          FittedBox(child: Text(label,
              style: TextStyle(fontSize: 10, color: _subtitleColor, fontFamily: 'NotoNastaliqUrdu'))),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  NET PROFIT CARD - Now includes karigar payments
  // ═══════════════════════════════════════════════
  Widget _buildNetProfitCard() {
    final isPositive = netProfit >= 0;
    final profitColor = isPositive ? _cGreen : _cRose;
    final profitIcon  = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final profitLabel = isPositive ? 'خالص منافع' : 'خالص نقصان';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPositive
                ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: profitColor.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(profitIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  profitLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'بشمول کاریگر ادائیگیاں',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 11,
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Text(
                _moneyFmt(netProfit.abs()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _profitBreakdownItem('کل آمدنی', _moneyFmt(totalRevenue), Icons.arrow_upward_rounded, Colors.green.shade300),
              Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
              _profitBreakdownItem('کل اخراجات', _moneyFmt(totalExpenses), Icons.arrow_downward_rounded, Colors.red.shade300),
              Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
              _profitBreakdownItem(profitLabel, _moneyFmt(netProfit.abs()), profitIcon, Colors.white),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'کل آمدنی (${_moneyFmt(totalRevenue)}) − کل اخراجات بشمول کاریگر ادائیگیاں (${_moneyFmt(totalExpenses)}) = $profitLabel (${_moneyFmt(netProfit.abs())})',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNastaliqUrdu',
                fontSize: 11,
                color: Colors.white.withOpacity(0.75),
                height: 1.6,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _profitBreakdownItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 9,
                fontFamily: 'NotoNastaliqUrdu')),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  //  QUICK ACTIONS
  // ═══════════════════════════════════════════════
  Widget _buildQuickActions() {
    const double gap     = 12;
    const double sidePad = 20;

    final List<_QA> items = [
      _QA('سلائی',        Icons.style_rounded,           _cViolet,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SilaiTypesScreen()))),
      _QA('ناپ',          Icons.straighten_rounded,       _cTeal,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NaapTypeScreen()))),
      _QA('کسٹمر',        Icons.person_add_alt_1_rounded, _cAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerScreen())).then((_) => _loadAllData())),
      _QA('اضافی پیمائش', Icons.eighteen_mp_rounded,      _cAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NaapExtraInfoScreen())).then((_) => _loadAllData())),
      _QA('پیمائش',       Icons.design_services_rounded,  _cTeal,
              () => _pickCustomer(
              title: 'نئی پیمائش لیں',
              subtitle: 'کسٹمر منتخب کریں',
              icon: Icons.straighten,
              iconColor: _cTeal,
              onSelect: (c) => Navigator.push(context, MaterialPageRoute(builder: (_) => TakeMeasurementScreen(customer: c))).then((_) => _loadAllData()))),
      _QA('آرڈرز',        Icons.receipt_long_rounded,     _cRose,
              () => _pickCustomer(
              title: 'کسٹمر منتخب کریں',
              icon: Icons.receipt_long,
              iconColor: _cRose,
              onSelect: (c) => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderManagementScreen(customer: c))).then((_) => _loadAllData()))),
    ];

    final lastItem = _QA(
      'اخراجات',
      Icons.money_off_rounded,
      const Color(0xFF14B8A6),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()))
          .then((_) => _loadAllData()),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(sidePad, 26, sidePad, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('فوری رسائی',
            style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 1.05,
          children: items.map(_buildQATile).toList(),
        ),

        const SizedBox(height: gap),

        // Full-width اخراجات button
        GestureDetector(
          onTap: lastItem.onTap,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: lastItem.color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: lastItem.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(lastItem.icon, color: lastItem.color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(lastItem.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      fontFamily: 'NotoNastaliqUrdu', color: _textColor)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildQATile(_QA a) {
    return GestureDetector(
      onTap: a.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: a.color.withOpacity(_isDark ? 0.12 : 0.07), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: a.color.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(a.icon, color: a.color, size: 23),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(a.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    fontFamily: 'NotoNastaliqUrdu', color: _textColor)),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  QUICK ACTION DATA CLASS
// ═══════════════════════════════════════════════
class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.label, this.icon, this.color, this.onTap);
}

// ═══════════════════════════════════════════════
//  DUE TODAY SHEET
// ═══════════════════════════════════════════════
class _DueTodaySheet extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _DueTodaySheet({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Column(children: [
        const SizedBox(height: 14),
        Container(
          width: 52, height: 5,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
        ),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('آج ڈیلیوری والے آرڈرز',
                style: TextStyle(fontFamily: 'NotoNastaliqUrdu', fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${orders.length} آرڈرز کی ڈیلیوری آج ہے',
                style: TextStyle(color: Colors.red.shade500, fontSize: 12, fontFamily: 'NotoNastaliqUrdu')),
          ])),
        ])),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o    = orders[i];
              final rem  = double.tryParse(o['remaining_amount']?.toString() ?? '0') ?? 0;
              final tot  = double.tryParse(o['total_amount']?.toString()     ?? '0') ?? 0;
              final paid = tot - rem;
              final name = o['customer_name']?.toString() ?? 'نامعلوم';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.shade100),
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.receipt_long, color: Colors.red.shade400, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('آرڈر #${o['id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'NotoNastaliqUrdu')),
                      const SizedBox(height: 2),
                      Text('کسٹمر: $name',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'NotoNastaliqUrdu')),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: rem > 0 ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(rem > 0 ? 'بقایا: ₨${rem.toStringAsFixed(0)}' : 'ادا شدہ',
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'NotoNastaliqUrdu',
                              fontWeight: FontWeight.bold,
                              color: rem > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _chip(Icons.calendar_today_rounded, 'آرڈر: ${_D.fmt(o['order_date'])}'),
                    const SizedBox(width: 8),
                    _chip(Icons.event_rounded, 'ڈیلیوری: ${_D.fmt(o['delivery_date'])}'),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _chip(Icons.monetization_on_rounded, 'کل: ₨${tot.toStringAsFixed(0)}'),
                    const SizedBox(width: 8),
                    _chip(Icons.payment_rounded, 'ادا: ₨${paid.toStringAsFixed(0)}'),
                  ]),
                  if (o['notes'] != null && o['notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.note_rounded, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(child: Text(o['notes'].toString(),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'NotoNastaliqUrdu'))),
                      ]),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey[700], fontFamily: 'NotoNastaliqUrdu'))),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════
//  SPEED DIAL FAB
// ═══════════════════════════════════════════════
class SpeedDialFAB extends StatefulWidget {
  final Animation<double> pulseAnimation;
  final VoidCallback onNewOrder;
  final VoidCallback onNewMeasure;

  const SpeedDialFAB({
    super.key,
    required this.pulseAnimation,
    required this.onNewOrder,
    required this.onNewMeasure,
  });

  @override
  State<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _ctrl;
  late Animation<double> _rotAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _rotAnim = Tween<double>(begin: 0, end: 0.125)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _option(Icons.straighten_rounded, 'نئی پیمائش', _cTeal,
              () { _toggle(); widget.onNewMeasure(); }),
      const SizedBox(height: 10),
      _option(Icons.add_shopping_cart_rounded, 'نیا آرڈر', _cGreen,
              () { _toggle(); widget.onNewOrder(); }),
      const SizedBox(height: 14),
      AnimatedBuilder(
        animation: widget.pulseAnimation,
        builder: (_, __) => Transform.scale(
          scale: widget.pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: _cAccent.withOpacity(0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                  spreadRadius: 2)],
            ),
            child: FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: _cAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: AnimatedBuilder(
                animation: _rotAnim,
                builder: (_, __) => Transform.rotate(
                  angle: _rotAnim.value * 3.14159 * 2,
                  child: Icon(
                    _isOpen ? Icons.close_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _option(IconData icon, String label, Color color, VoidCallback onTap) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isOpen ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        offset: _isOpen ? Offset.zero : const Offset(0, 0.4),
        child: _isOpen
            ? GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontFamily: 'NotoNastaliqUrdu', fontWeight: FontWeight.bold)),
            ]),
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}