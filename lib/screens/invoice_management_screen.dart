
import 'package:flutter/material.dart';

import '../database/invoice_database.dart';
import '../models/invoice.dart';

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  State<InvoiceManagementScreen> createState() =>
      _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'unpaid', 'paid'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  // Tải danh sách hóa đơn từ Database
  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final list = await InvoiceDatabase.instance.getAllInvoices();

      if (!mounted) return;

      setState(() {
        _invoices = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải danh sách hóa đơn: $e')),
      );
    }
  }

  // Lọc danh sách theo trạng thái và tìm kiếm
  List<Invoice> get _filteredInvoices {
    return _invoices.where((inv) {
      final matchesStatus =
          _filterStatus == 'all' || inv.status == _filterStatus;
      final matchesSearch = inv.roomNumber
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          inv.monthYear.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  // Thống kê tổng tiền chưa thanh toán
  double get _totalUnpaidAmount {
    return _invoices
        .where((inv) => inv.status == 'unpaid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  // Định dạng số tiền VND: VD 2500000 -> "2.500.000 đ"
  String _formatMoney(double value) {
    final digits = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} đ';
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredInvoices;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Hóa đơn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thẻ tổng quan thống kê nhanh
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Tổng hóa đơn',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_invoices.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 35,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          const Text(
                            'Chưa thanh toán',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatMoney(_totalUnpaidAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ô tìm kiếm và bộ lọc trạng thái
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Tìm theo phòng hoặc tháng...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterStatus,
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Tất cả'),
                              ),
                              DropdownMenuItem(
                                value: 'unpaid',
                                child: Text('Chưa thu'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Đã thu'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filterStatus = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Danh sách hóa đơn (ListView)
                Expanded(
                  child: filteredList.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy hóa đơn nào',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredList.length,
                          padding: const EdgeInsets.only(bottom: 20),
                          itemBuilder: (context, index) {
                            final invoice = filteredList[index];
                            final isPaid = invoice.status == 'paid';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPaid
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  child: Icon(
                                    isPaid
                                        ? Icons.check_circle
                                        : Icons.receipt_long,
                                    color: isPaid ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  '${invoice.roomNumber} • ${invoice.monthYear}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Tổng tiền: ${_formatMoney(invoice.totalAmount)}',
                                    style: TextStyle(
                                      color: Colors.indigo.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                trailing: Chip(
                                  label: Text(
                                    isPaid ? 'Đã thu' : 'Chưa thu',
                                    style: TextStyle(
                                      color: isPaid
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: isPaid
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  side: BorderSide(
                                    color: isPaid
                                        ? Colors.green.shade300
                                        : Colors.red.shade300,
                                  ),
                                ),
                                onTap: () {
                                  // Điều hướng sang Màn hình Chi tiết ngay bên dưới
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailScreen(
                                        invoice: invoice,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class InvoiceDetailScreen extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
  });

  // Định dạng số tiền VND
  String _formatMoney(double value) {
    final digits = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} đ';
  }

  // Widget hiển thị từng hàng chi phí
  Widget _buildFeeRow(
    String title,
    double amount, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            _formatMoney(amount),
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.indigo.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chi tiết ${invoice.roomNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ thông tin kỳ hóa đơn & trạng thái
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      invoice.monthYear,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Phòng: ${invoice.roomNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaid ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        isPaid ? 'ĐÃ THANH TOÁN' : 'CHƯA THANH TOÁN',
                        style: TextStyle(
                          color: isPaid
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bảng kê chi tiết các khoản phí
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết các khoản phí',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildFeeRow('Tiền phòng', invoice.roomPrice),
                    _buildFeeRow('Tiền điện', invoice.electricityCost),
                    _buildFeeRow('Tiền nước', invoice.waterCost),
                    if (invoice.otherCost > 0)
                      _buildFeeRow('Phí dịch vụ khác', invoice.otherCost),
                    const Divider(thickness: 1.5, height: 24),
                    _buildFeeRow(
                      'TỔNG TIỀN',
                      invoice.totalAmount,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // Ghi chú (nếu có)
            if (invoice.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ghi chú: ${invoice.note}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
