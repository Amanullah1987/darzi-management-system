import 'package:darzi_management_system/db/database_helper.dart';
import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const PaymentScreen({super.key, required this.customer});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  Map<String, dynamic> _customerSummary = {};

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'Cash';
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _customerSummary = await DatabaseHelper.instance
          .getCustomerFinancialSummary(widget.customer['id']);

      _orders = await DatabaseHelper.instance.getCustomerOrders(
        widget.customer['id'],
      );

      _payments = await DatabaseHelper.instance.getPaymentsByCustomer(
        widget.customer['id'],
      );

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isLoading = false);
      _showSnackBar('ڈیٹا لوڈ کرنے میں خرابی', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _addPayment() async {
    if (_selectedOrderId == null) {
      _showSnackBar('براہ کرم آرڈر منتخب کریں', Colors.orange);
      return;
    }

    int amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      _showSnackBar('درست رقم درج کریں', Colors.orange);
      return;
    }

    Map<String, dynamic> paymentData = {
      'customer_id': widget.customer['id'],
      'order_id': _selectedOrderId!,
      'payment_date': _paymentDate.toIso8601String(),
      'amount': amount,
      'payment_method': _paymentMethod,
      'notes': _notesCtrl.text,
    };

    try {
      await DatabaseHelper.instance.addPayment(paymentData);
      _showSnackBar('پیمنٹ کامیابی سے شامل ہو گئی ✅', Colors.green);

      _amountCtrl.clear();
      _notesCtrl.clear();
      _selectedOrderId = null;

      await _loadData();
    } catch (e) {
      _showSnackBar('پیمنٹ شامل کرنے میں خرابی', Colors.red);
    }
  }

  Future<void> _showPaymentDetails(Map<String, dynamic> payment) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'پیمنٹ کی تفصیل',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('رقم:', '₨ ${payment['amount']}'),
              _buildDetailRow(
                'تاریخ:',
                _formatDateString(payment['payment_date']),
              ),
              _buildDetailRow('طریقہ:', payment['payment_method']),
              if (payment['notes'] != null && payment['notes'].isNotEmpty)
                _buildDetailRow('نوٹس:', payment['notes']),
              _buildDetailRow('آرڈر آئی ڈی:', '${payment['order_id']}'),
              if (payment['created_at'] != null)
                _buildDetailRow(
                  'تاریخِ تخلیق:',
                  _formatDateString(payment['created_at']),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بند کریں'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePayment(payment['id']);
            },
            child: const Text(
              'ڈیلیٹ کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontFamily: 'NotoNastaliqUrdu')),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePayment(int paymentId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تصدیق',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        content: const Text(
          'کیا آپ واقعی اس پیمنٹ کو ڈیلیٹ کرنا چاہتے ہیں؟',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('منسوخ کریں'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePayment(paymentId);
            },
            child: const Text(
              'ڈیلیٹ کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(int paymentId) async {
    try {
      await DatabaseHelper.instance.deletePayment(paymentId);
      _showSnackBar('پیمنٹ ڈیلیٹ ہو گئی ✅', Colors.green);
      await _loadData();
    } catch (e) {
      _showSnackBar('ڈیلیٹ کرنے میں خرابی', Colors.red);
    }
  }

  String _formatDateString(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.customer['name']} کی پیمنٹس",
          style: const TextStyle(fontFamily: 'NotoNastaliqUrdu'),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          widget.customer['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoNastaliqUrdu',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'کل خریدیں',
                              '₨ ${(_customerSummary['total_purchases'] as num).toStringAsFixed(0)}',
                              Colors.blue,
                            ),
                            _buildSummaryItem(
                              'کل پیمنٹس',
                              '₨ ${(_customerSummary['total_payments'] as num).toStringAsFixed(0)}',
                              Colors.green,
                            ),
                            _buildSummaryItem(
                              'بقایا',
                              '₨ ${(_customerSummary['balance'] as num).toStringAsFixed(0)}',
                              (_customerSummary['balance'] as num) > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'نیا پیمنٹ شامل کریں',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoNastaliqUrdu',
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: "آرڈر منتخب کریں",
                            labelStyle: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                            ),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt),
                          ),
                          value: _selectedOrderId,
                          items: _orders
                              .where(
                                (order) => (order['remaining_amount'] ?? 0) > 0,
                              )
                              .map(
                                (order) => DropdownMenuItem<int>(
                                  value: order['id'] as int,
                                  child: Text(
                                    'آرڈر #${order['id']} - بقایا: ₨${order['remaining_amount'] ?? 0}',
                                    style: const TextStyle(
                                      fontFamily: 'NotoNastaliqUrdu',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedOrderId = val);
                          },
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "رقم",
                            labelStyle: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                            ),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "پیمنٹ کا طریقہ",
                            labelStyle: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                            ),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          value: _paymentMethod,
                          items:
                              ['Cash', 'Bank Transfer', 'JazzCash', 'EasyPaisa']
                                  .map(
                                    (method) => DropdownMenuItem<String>(
                                      value: method,
                                      child: Text(
                                        method,
                                        style: const TextStyle(
                                          fontFamily: 'NotoNastaliqUrdu',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            setState(() => _paymentMethod = val!);
                          },
                        ),

                        const SizedBox(height: 12),

                        ListTile(
                          title: Text(
                            _formatDateString(_paymentDate.toIso8601String()),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Text(
                            "پیمنٹ تاریخ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'NotoNastaliqUrdu',
                            ),
                          ),
                          leading: const Icon(
                            Icons.calendar_today,
                            color: Colors.blue,
                          ),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _paymentDate = d);
                          },
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "نوٹس (اختیاری)",
                            labelStyle: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                            ),
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: _addPayment,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "پیمنٹ شامل کریں",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'NotoNastaliqUrdu',
                                    fontWeight: FontWeight.bold,
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

                Expanded(
                  child: _payments.isEmpty
                      ? const Center(
                          child: Text(
                            'کوئی پیمنٹ ریکارڈ نہیں',
                            style: TextStyle(
                              fontFamily: 'NotoNastaliqUrdu',
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final payment = _payments[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.payment,
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  '₨ ${payment['amount']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatDateString(payment['payment_date']),
                                ),
                                trailing: Text(
                                  payment['payment_method'],
                                  style: const TextStyle(
                                    fontFamily: 'NotoNastaliqUrdu',
                                  ),
                                ),
                                onTap: () => _showPaymentDetails(payment),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: 'NotoNastaliqUrdu',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
