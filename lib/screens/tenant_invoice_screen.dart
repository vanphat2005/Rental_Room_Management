// ============================================================
// Author : Le Van Nguyen - CE181235
// Feature: Invoice Management (Actor: Tenant)
// UC ID  : UC-22 (View Invoice)
// ============================================================

import 'package:flutter/material.dart';

import '../database/invoice_database.dart';
import '../database/room_database.dart';
import '../models/invoice.dart';
import 'login_screen.dart';

/// Màn hình Xem hóa đơn dành cho Khách thuê (Tenant).
/// Cho phép người thuê tra cứu, lọc và xem chi tiết hóa đơn theo từng phòng thuê.
class TenantInvoiceScreen extends StatefulWidget {
  final String? roomNumber;
  final String? tenantName;

  const TenantInvoiceScreen({
    super.key,
    this.roomNumber,
    this.tenantName,
  });

  @override
  State<TenantInvoiceScreen> createState() => _TenantInvoiceScreenState();
}

class _TenantInvoiceScreenState extends State<TenantInvoiceScreen> {
  List<Invoice> _invoices = [];
  String _selectedRoom = '';
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'unpaid', 'paid'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// Chuẩn hóa chuỗi số phòng theo tiền tố 'Phòng ' để truy vấn đồng nhất.
  String _normalizeRoomNumber(String? roomNumber) {
    final raw = (roomNumber ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }

    return raw.toLowerCase().startsWith('phòng')
        ? raw
        : 'Phòng $raw';
  }

  /// Tự động tải hóa đơn cho phòng tương ứng của khách thuê.
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      _selectedRoom = _normalizeRoomNumber(widget.roomNumber);
      await _loadInvoicesForSelectedRoom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    }
  }

  /// Tải danh sách hóa đơn theo số phòng đang chọn từ IndexedDB.
  Future<void> _loadInvoicesForSelectedRoom() async {
    if (_selectedRoom == null || _selectedRoom!.isEmpty) {
      setState(() {
        _invoices = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final list =
          await InvoiceDatabase.instance.getInvoicesByRoom(_selectedRoom!);

      if (!mounted) return;
      setState(() {
        _invoices = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải hóa đơn: $e')),
      );
    }
  }

  /// Áp dụng bộ lọc trạng thái thanh toán và từ khóa tìm kiếm trên danh sách hóa đơn.
  List<Invoice> get _filteredInvoices {
    return _invoices.where((inv) {
      final matchesStatus =
          _filterStatus == 'all' || inv.status == _filterStatus;
      final matchesSearch = inv.monthYear
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          inv.roomNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  /// Tính tổng số tiền cần thanh toán của các kỳ hóa đơn chưa trả.
  double get _totalUnpaidAmount {
    return _invoices
        .where((inv) => inv.status == 'unpaid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  /// Đếm số kỳ hóa đơn đã hoàn thành nghĩa vụ thanh toán.
  int get _paidCount => _invoices.where((inv) => inv.status == 'paid').length;

  /// Định dạng giá trị số sang tiền tệ VNĐ (ví dụ: 1.500.000 đ).
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hóa đơn của tôi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (widget.tenantName != null && widget.tenantName!.isNotEmpty)
              Text(
                'Khách thuê: ${widget.tenantName}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoicesForSelectedRoom,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thông tin phòng đang thuê của khách
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.indigo.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.door_front_door, color: Colors.indigo),
                      const SizedBox(width: 8),
                      const Text(
                        'Phòng của bạn:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedRoom.isNotEmpty
                              ? _selectedRoom
                              : 'Chưa được phân phòng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _selectedRoom.isNotEmpty
                                ? Colors.indigo.shade900
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Card thống kê nhanh tình trạng nợ và số lượng hóa đơn
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Tổng số hóa đơn
                      Column(
                        children: [
                          const Text(
                            'Tổng hóa đơn',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_invoices.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 35,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      // Số tiền cần thanh toán
                      Column(
                        children: [
                          const Text(
                            'Cần thanh toán',
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
                      Container(
                        height: 35,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      // Số kỳ đã thanh toán
                      Column(
                        children: [
                          const Text(
                            'Đã trả',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_paidCount kỳ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Thanh tìm kiếm và bộ lọc trạng thái hóa đơn
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tháng (VD: Tháng 10)...',
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
                                child: Text('Chưa trả'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Đã trả'),
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

                // Danh sách hóa đơn của khách thuê (chế độ chỉ xem)
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Không có hóa đơn nào cho phòng này',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredList.length,
                          padding: const EdgeInsets.only(bottom: 24),
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
                                        : Icons.error_outline,
                                    color: isPaid ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  invoice.monthYear,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Tổng tiền: ${_formatMoney(invoice.totalAmount)}',
                                    style: TextStyle(
                                      color: Colors.indigo.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                trailing: Chip(
                                  label: Text(
                                    isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TenantInvoiceDetailScreen(
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

/// Màn hình Chi tiết Hóa đơn dành cho Khách thuê (Chỉ xem).
class TenantInvoiceDetailScreen extends StatelessWidget {
  final Invoice invoice;

  const TenantInvoiceDetailScreen({
    super.key,
    required this.invoice,
  });

  /// Định dạng số tiền sang chuẩn VNĐ.
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

  /// Dòng hiển thị thành phần chi phí trong bảng kê.
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
              color: isTotal ? Colors.indigo.shade900 : Colors.black87,
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
          'Chi tiết ${invoice.monthYear}',
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
            // Thẻ tóm tắt thông tin kỳ hóa đơn và trạng thái
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

            // Bảng kê chi tiết các hạng mục thanh toán
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
                      'TỔNG CỘNG',
                      invoice.totalAmount,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // Lời nhắn đính kèm từ ban quản lý / chủ trọ
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
                        Icons.message_outlined,
                        size: 20,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lời nhắn: ${invoice.note}',
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

            const SizedBox(height: 16),

            // Thông báo hướng dẫn thanh toán dành cho người thuê
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPaid
                          ? 'Hóa đơn này đã được thanh toán đầy đủ. Cảm ơn bạn!'
                          : 'Vui lòng chuyển khoản hoặc liên hệ trực tiếp chủ trọ để hoàn tất thanh toán trước ngày đến hạn.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
