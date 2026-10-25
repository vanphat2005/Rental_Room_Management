
import 'package:flutter/material.dart';

import '../database/invoice_database.dart';
import '../database/room_database.dart';
import '../models/invoice.dart';

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
  List<String> _availableRooms = [];
  String? _selectedRoom;
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'unpaid', 'paid'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Khởi tạo danh sách phòng và tải hóa đơn
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      // Tải danh sách phòng từ RoomDatabase & InvoiceDatabase để làm danh sách lựa chọn
      final roomsFromDb = await RoomDatabase.instance.getAllRooms();
      final allInvoices = await InvoiceDatabase.instance.getAllInvoices();

      final roomSet = <String>{};
      for (final r in roomsFromDb) {
        roomSet.add(r.roomNumber);
      }
      for (final inv in allInvoices) {
        roomSet.add(inv.roomNumber);
      }

      final roomList = roomSet.toList()..sort();

      // Xác định phòng mặc định được chọn
      String? defaultRoom = widget.roomNumber;
      if (defaultRoom == null || defaultRoom.trim().isEmpty) {
        if (roomList.isNotEmpty) {
          defaultRoom = roomList.first;
        }
      }

      _availableRooms = roomList;
      _selectedRoom = defaultRoom;

      // Tải hóa đơn của phòng đã chọn
      await _loadInvoicesForSelectedRoom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    }
  }

  // Tải danh sách hóa đơn của phòng đang chọn
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

  // Lọc danh sách theo trạng thái và tìm kiếm
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

  // Thống kê tiền chưa thanh toán của phòng này
  double get _totalUnpaidAmount {
    return _invoices
        .where((inv) => inv.status == 'unpaid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  int get _paidCount => _invoices.where((inv) => inv.status == 'paid').length;

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
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoicesForSelectedRoom,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Bộ chọn phòng (cho phép chuyển đổi phòng để xem) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.teal.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.door_front_door, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Text(
                        'Phòng:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _availableRooms.isEmpty
                            ? const Text('Chưa có thông tin phòng')
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRoom,
                                  isExpanded: true,
                                  items: _availableRooms.map((room) {
                                    return DropdownMenuItem<String>(
                                      value: room,
                                      child: Text(
                                        room.startsWith('Phòng')
                                            ? room
                                            : 'Phòng $room',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newRoom) {
                                    if (newRoom != null &&
                                        newRoom != _selectedRoom) {
                                      setState(() => _selectedRoom = newRoom);
                                      _loadInvoicesForSelectedRoom();
                                    }
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Thẻ tổng quan thống kê cho Người thuê ──
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
                    border: Border.all(color: Colors.teal.shade100),
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
                              color: Colors.teal.shade800,
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
                      // Số hóa đơn đã thanh toán
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

                // ── Tìm kiếm & Lọc trạng thái ──
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

                // ── Danh sách hóa đơn (ListView) - Chỉ xem ──
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
                                      color: Colors.teal.shade900,
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
                                  // Điều hướng sang Màn hình Chi tiết hóa đơn dành cho Tenant (Chỉ xem)
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

// ─────────────────────────────────────────────────────────────
// Màn hình Chi tiết Hóa đơn dành cho Người thuê (Chỉ xem)
// ─────────────────────────────────────────────────────────────
class TenantInvoiceDetailScreen extends StatelessWidget {
  final Invoice invoice;

  const TenantInvoiceDetailScreen({
    super.key,
    required this.invoice,
  });

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
              color: isTotal ? Colors.teal.shade900 : Colors.black87,
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
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ trạng thái & thông tin kỳ hóa đơn
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
                      'TỔNG CỘNG',
                      invoice.totalAmount,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // Ghi chú từ chủ trọ (nếu có)
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
                        color: Colors.teal,
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

            // Hướng dẫn thanh toán thân thiện cho người thuê
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPaid
                          ? 'Hóa đơn này đã được thanh toán đầy đủ. Cảm ơn bạn!'
                          : 'Vui lòng chuyển khoản hoặc liên hệ trực tiếp chủ trọ để hoàn tất thanh toán trước ngày đến hạn.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal.shade900,
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
