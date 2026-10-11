
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/room_database.dart';
import '../models/room.dart';
import 'invoice_management_screen.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() =>
      _RoomManagementScreenState();
}

class _RoomManagementScreenState
    extends State<RoomManagementScreen> {
  List<Room> _rooms = [];
  bool _loading = true;

  String _keyword = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await RoomDatabase.instance.getAllRooms();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Không thể tải danh sách phòng: $e');
    }
  }

  List<Room> get _filteredRooms {
    return _rooms.where((room) {
      final matchesKeyword = room.roomNumber
          .toLowerCase()
          .contains(_keyword.toLowerCase());

      final matchesStatus = _filterStatus == 'all' ||
          room.status == _filterStatus;

      return matchesKeyword && matchesStatus;
    }).toList();
  }

  int get _availableCount =>
      _rooms.where((r) => r.status == 'available').length;

  int get _rentedCount =>
      _rooms.where((r) => r.status == 'rented').length;

  int get _maintenanceCount =>
      _rooms.where((r) => r.status == 'maintenance').length;

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Phòng trống';
      case 'rented':
        return 'Đang thuê';
      case 'maintenance':
        return 'Bảo trì';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _money(double value) {
    final digits = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} đ/tháng';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


Future<void> _openRoomForm({Room? room}) async {
  final result = await showDialog<Room>(
    context: context,
    builder: (_) => RoomFormDialog(room: room),
  );

  if (result == null || !mounted) return;

  try {
    if (room == null) {
      await RoomDatabase.instance.insertRoom(result);
    } else {
      await RoomDatabase.instance.updateRoom(result);
    }

    if (!mounted) return;

    _showMessage(
      room == null
          ? 'Thêm phòng thành công!'
          : 'Cập nhật phòng thành công!',
    );

    await _loadRooms();
  } catch (e) {
    if (!mounted) return;

    final error = e.toString().toLowerCase();

    if (error.contains('constraint') ||
        error.contains('already exists')) {
      _showMessage('Mã phòng đã tồn tại!');
    } else {
      _showMessage('Không thể lưu phòng: $e');
    }
  }
}

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text(
          'Bạn có chắc muốn xóa phòng ${room.roomNumber} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await RoomDatabase.instance.deleteRoom(room.id!);

      if (!mounted) return;

      _showMessage('Đã xóa phòng ${room.roomNumber}');
      await _loadRooms();
    } catch (e) {
      _showMessage('Không thể xóa phòng: $e');
    }
  }

  Widget _buildStat(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý phòng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Hóa đơn',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvoiceManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadRooms,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRoomForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm phòng'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStat(
                            'Tổng phòng',
                            _rooms.length,
                            Icons.meeting_room,
                            Colors.indigo,
                          ),
                          _buildStat(
                            'Phòng trống',
                            _availableCount,
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                          _buildStat(
                            'Đang thuê',
                            _rentedCount,
                            Icons.people_outline,
                            Colors.blue,
                          ),
                          _buildStat(
                            'Bảo trì',
                            _maintenanceCount,
                            Icons.build_outlined,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã phòng...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _keyword = value.trim());
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: const InputDecoration(
                          labelText: 'Lọc theo trạng thái',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả phòng'),
                          ),
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Phòng trống'),
                          ),
                          DropdownMenuItem(
                            value: 'rented',
                            child: Text('Đang thuê'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Bảo trì'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _filterStatus = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.meeting_room_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _rooms.isEmpty
                                    ? 'Chưa có phòng nào'
                                    : 'Không tìm thấy phòng phù hợp',
                              ),
                              const SizedBox(height: 8),
                              if (_rooms.isEmpty)
                                const Text(
                                  'Nhấn "Thêm phòng" để bắt đầu.',
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            12, 0, 12, 90,
                          ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            final color = _statusColor(room.status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      color.withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.meeting_room,
                                    color: color,
                                  ),
                                ),
                                title: Text(
                                  'Phòng ${room.roomNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_money(room.rentPrice)),
                                      Text('Diện tích: ${room.area} m²'),
                                      if (room.description.isNotEmpty)
                                        Text(room.description),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _statusLabel(room.status),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _openRoomForm(room: room);
                                    } else if (action == 'delete') {
                                      _deleteRoom(room);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined),
                                          SizedBox(width: 8),
                                          Text('Sửa'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Xóa'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

class RoomFormDialog extends StatefulWidget {
  final Room? room;

  const RoomFormDialog({super.key, this.room});

  @override
  State<RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numberController;
  late final TextEditingController _priceController;
  late final TextEditingController _areaController;
  late final TextEditingController _descriptionController;

  late String _status;

  @override
  void initState() {
    super.initState();

    final room = widget.room;

    _numberController = TextEditingController(
      text: room?.roomNumber ?? '',
    );
    _priceController = TextEditingController(
      text: room?.rentPrice.toString() ?? '',
    );
    _areaController = TextEditingController(
      text: room?.area.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: room?.description ?? '',
    );

    _status = room?.status ?? 'available';
  }

  @override
  void dispose() {
    _numberController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin';
    }
    return null;
  }

  String? _positiveNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');

    if (number == null || !number.isFinite || number <= 0) {
      return 'Vui lòng nhập số lớn hơn 0';
    }

    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final room = Room(
      id: widget.room?.id,
      roomNumber: _numberController.text.trim(),
      rentPrice: double.parse(_priceController.text.trim()),
      area: double.parse(_areaController.text.trim()),
      status: _status,
      description: _descriptionController.text.trim(),
    );

    Navigator.pop(context, room);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.room != null;

    return AlertDialog(
      title: Text(isEditing ? 'Cập nhật phòng' : 'Thêm phòng mới'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng *',
                    hintText: 'Ví dụ: P101',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Giá thuê mỗi tháng (VNĐ) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _positiveNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Diện tích (m²) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _positiveNumber,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Phòng trống'),
                    ),
                    DropdownMenuItem(
                      value: 'rented',
                      child: Text('Đang thuê'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Bảo trì'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    hintText: 'Nội thất, vị trí, ghi chú...',
                    border: OutlineInputBorder(),
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
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm phòng'),
        ),
      ],
    );
  }
}