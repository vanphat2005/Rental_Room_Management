
import 'package:flutter/material.dart';

import '../database/invoice_database.dart';
import '../database/room_database.dart';
import '../models/invoice.dart';
import '../models/room.dart';

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

  // Mở form Tạo hoặc Cập nhật hóa đơn
  Future<void> _openInvoiceForm({Invoice? invoice}) async {
    final result = await showDialog<Invoice>(
      context: context,
      builder: (_) => InvoiceFormDialog(invoice: invoice),
    );

    if (result == null || !mounted) return;

    try {
      if (invoice == null) {
        await InvoiceDatabase.instance.insertInvoice(result);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo hóa đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await InvoiceDatabase.instance.updateInvoice(result);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hóa đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadInvoices();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
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
                          padding: const EdgeInsets.only(bottom: 80),
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
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
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Sửa hóa đơn',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.indigo,
                                        size: 20,
                                      ),
                                      onPressed: () => _openInvoiceForm(
                                        invoice: invoice,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  // Điều hướng sang Màn hình Chi tiết ngay bên dưới
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailScreen(
                                        invoice: invoice,
                                      ),
                                    ),
                                  );
                                  await _loadInvoices();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openInvoiceForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo hóa đơn'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Invoice _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  // Mở form Chỉnh sửa hóa đơn ngay trên màn hình chi tiết
  Future<void> _editInvoice() async {
    final updated = await showDialog<Invoice>(
      context: context,
      builder: (_) => InvoiceFormDialog(invoice: _invoice),
    );

    if (updated == null || !mounted) return;

    try {
      await InvoiceDatabase.instance.updateInvoice(updated);
      if (!mounted) return;

      setState(() {
        _invoice = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hóa đơn thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật hóa đơn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    final isPaid = _invoice.status == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chi tiết ${_invoice.roomNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Chỉnh sửa hóa đơn',
            icon: const Icon(Icons.edit),
            onPressed: _editInvoice,
          ),
        ],
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
                      _invoice.monthYear,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Phòng: ${_invoice.roomNumber}',
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
                    _buildFeeRow('Tiền phòng', _invoice.roomPrice),
                    _buildFeeRow('Tiền điện', _invoice.electricityCost),
                    _buildFeeRow('Tiền nước', _invoice.waterCost),
                    if (_invoice.otherCost > 0)
                      _buildFeeRow('Phí dịch vụ khác', _invoice.otherCost),
                    const Divider(thickness: 1.5, height: 24),
                    _buildFeeRow(
                      'TỔNG TIỀN',
                      _invoice.totalAmount,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),

            // Ghi chú (nếu có)
            if (_invoice.note.isNotEmpty) ...[
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
                          'Ghi chú: ${_invoice.note}',
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

// ─────────────────────────────────────────────────────────────
// Dialog: Tạo mới hoặc Cập nhật hóa đơn
// ─────────────────────────────────────────────────────────────
class InvoiceFormDialog extends StatefulWidget {
  final Invoice? invoice; // null = Tạo mới, có giá trị = Cập nhật

  const InvoiceFormDialog({super.key, this.invoice});

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _roomNumberController;
  late final TextEditingController _monthYearController;
  late final TextEditingController _roomPriceController;
  late final TextEditingController _electricityCostController;
  late final TextEditingController _waterCostController;
  late final TextEditingController _otherCostController;
  late final TextEditingController _noteController;

  late String _status;
  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomValue;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      _roomNumberController = TextEditingController(text: inv.roomNumber);
      _monthYearController = TextEditingController(text: inv.monthYear);
      _roomPriceController = TextEditingController(
        text: inv.roomPrice > 0 ? inv.roomPrice.toInt().toString() : '',
      );
      _electricityCostController = TextEditingController(
        text: inv.electricityCost.toInt().toString(),
      );
      _waterCostController = TextEditingController(
        text: inv.waterCost.toInt().toString(),
      );
      _otherCostController = TextEditingController(
        text: inv.otherCost.toInt().toString(),
      );
      _noteController = TextEditingController(text: inv.note);
      _status = inv.status;
    } else {
      final now = DateTime.now();
      _roomNumberController = TextEditingController();
      _monthYearController =
          TextEditingController(text: 'Tháng ${now.month}/${now.year}');
      _roomPriceController = TextEditingController();
      _electricityCostController = TextEditingController(text: '0');
      _waterCostController = TextEditingController(text: '0');
      _otherCostController = TextEditingController(text: '0');
      _noteController = TextEditingController();
      _status = 'unpaid';
    }
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final list = await RoomDatabase.instance.getAllRooms();
      if (!mounted) return;
      setState(() {
        _rooms = list;
        _isLoadingRooms = false;

        // Nếu đang sửa và phòng khớp với danh sách phòng trong DB, chọn sẵn
        if (widget.invoice != null) {
          final cur = widget.invoice!.roomNumber;
          for (final r in list) {
            final formatted = r.roomNumber.startsWith('Phòng')
                ? r.roomNumber
                : 'Phòng ${r.roomNumber}';
            if (r.roomNumber == cur || formatted == cur) {
              _selectedRoomValue = r.roomNumber;
              break;
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRooms = false);
    }
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _monthYearController.dispose();
    _roomPriceController.dispose();
    _electricityCostController.dispose();
    _waterCostController.dispose();
    _otherCostController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parseNumber(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  double get _totalAmount {
    return _parseNumber(_roomPriceController.text) +
        _parseNumber(_electricityCostController.text) +
        _parseNumber(_waterCostController.text) +
        _parseNumber(_otherCostController.text);
  }

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

  void _onRoomSelected(String? roomVal) {
    if (roomVal == null) return;
    setState(() {
      _selectedRoomValue = roomVal;
      final room = _rooms.firstWhere((r) => r.roomNumber == roomVal);
      _roomNumberController.text =
          roomVal.startsWith('Phòng') ? roomVal : 'Phòng $roomVal';
      if (room.rentPrice > 0) {
        _roomPriceController.text = room.rentPrice.toInt().toString();
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final invoice = Invoice(
      id: widget.invoice?.id, // Giữ nguyên ID khi cập nhật
      roomNumber: _roomNumberController.text.trim(),
      monthYear: _monthYearController.text.trim(),
      roomPrice: _parseNumber(_roomPriceController.text),
      electricityCost: _parseNumber(_electricityCostController.text),
      waterCost: _parseNumber(_waterCostController.text),
      otherCost: _parseNumber(_otherCostController.text),
      status: _status,
      note: _noteController.text.trim(),
    );

    Navigator.pop(context, invoice);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoice != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_note : Icons.receipt_long,
            color: Colors.indigo,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing ? 'Cập nhật hóa đơn' : 'Tạo hóa đơn mới',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chọn nhanh phòng nếu có danh sách phòng từ hệ thống
                if (!_isLoadingRooms && _rooms.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoomValue,
                    decoration: const InputDecoration(
                      labelText: 'Chọn nhanh phòng trọ',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('Chọn phòng có sẵn trong hệ thống'),
                    items: _rooms.map((r) {
                      final title = r.roomNumber.startsWith('Phòng')
                          ? r.roomNumber
                          : 'Phòng ${r.roomNumber}';
                      return DropdownMenuItem(
                        value: r.roomNumber,
                        child: Text(title),
                      );
                    }).toList(),
                    onChanged: _onRoomSelected,
                  ),
                  const SizedBox(height: 12),
                ],

                // Số / tên phòng
                TextFormField(
                  controller: _roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Tên / Số phòng *',
                    hintText: 'Ví dụ: Phòng 101',
                    prefixIcon: Icon(Icons.door_front_door_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên/số phòng'
                      : null,
                ),
                const SizedBox(height: 12),

                // Kỳ hóa đơn
                TextFormField(
                  controller: _monthYearController,
                  decoration: const InputDecoration(
                    labelText: 'Kỳ hóa đơn *',
                    hintText: 'Ví dụ: Tháng 10/2026',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập kỳ hóa đơn'
                      : null,
                ),
                const SizedBox(height: 12),

                // Tiền phòng
                TextFormField(
                  controller: _roomPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tiền thuê phòng (VNĐ) *',
                    hintText: 'Ví dụ: 2500000',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tiền phòng';
                    }
                    if (_parseNumber(v) <= 0) {
                      return 'Tiền phòng phải lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Tiền điện và Tiền nước trên cùng 1 hàng
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _electricityCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiền điện (VNĐ) *',
                          prefixIcon: Icon(Icons.bolt, color: Colors.amber),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Bắt buộc nhập'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _waterCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiền nước (VNĐ) *',
                          prefixIcon:
                              Icon(Icons.water_drop, color: Colors.blue),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Bắt buộc nhập'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Phí khác
                TextFormField(
                  controller: _otherCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Phí dịch vụ khác (Wifi, rác...)',
                    hintText: '0',
                    prefixIcon:
                        Icon(Icons.miscellaneous_services_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Trạng thái thu tiền
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái thu tiền *',
                    prefixIcon: Icon(Icons.check_circle_outline),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'unpaid',
                      child: Text('Chưa thu (Chưa thanh toán)'),
                    ),
                    DropdownMenuItem(
                      value: 'paid',
                      child: Text('Đã thu (Đã thanh toán)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const SizedBox(height: 12),

                // Ghi chú
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    hintText: 'Ví dụ: Hạn đóng tiền trước ngày 15...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Thẻ tổng tiền tạm tính trực tiếp (Live Total Preview)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng hóa đơn:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      Text(
                        _formatMoney(_totalAmount),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: _submit,
          icon: Icon(isEditing ? Icons.save : Icons.add),
          label: Text(isEditing ? 'Lưu thay đổi' : 'Tạo hóa đơn'),
        ),
      ],
    );
  }
}


