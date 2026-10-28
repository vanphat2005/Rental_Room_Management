import 'package:flutter/material.dart';

import '../database/room_database.dart';
import '../models/room.dart';
import 'invoice_management_screen.dart';

import 'account_management_screen.dart';
import 'incident_management_screen.dart';
import 'login_screen.dart';
import 'tenant_management_screen.dart'; // Long: điều hướng sang màn hình Người thuê

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
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
      final matchesKeyword = room.roomNumber.toLowerCase().contains(
        _keyword.toLowerCase(),
      );

      final matchesStatus =
          _filterStatus == 'all' || room.status == _filterStatus;

      return matchesKeyword && matchesStatus;
    }).toList();
  }

  int get _availableCount =>
      _rooms.where((r) => r.status == 'available').length;

  int get _rentedCount => _rooms.where((r) => r.status == 'rented').length;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openRoomForm({Room? room}) async {
    final result = room == null
        ? await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddRoomScreen()),
          )
        : await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => EditRoomScreen(room: room)),
          );

    if (result == true && mounted) {
      await _loadRooms();
    }
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text('Bạn có chắc muốn xóa phòng ${room.roomNumber} không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  Widget _buildStat(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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

          // Long: Nút điều hướng sang Quản lý người thuê
          IconButton(
            tooltip: 'Người thuê',
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TenantManagementScreen(),
                ),
              );
            },
          ),

          IconButton(
            tooltip: 'Sự cố & Bảo trì',
            icon: const Icon(Icons.report_problem),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncidentManagementScreen(),
                ),
              );
            },
          ),

          IconButton(
            tooltip: 'Quản lý tài khoản',
            icon: const Icon(Icons.manage_accounts),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountManagementScreen(),
                ),
              );
            },
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
                                const Text('Nhấn "Thêm phòng" để bắt đầu.'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            final color = _statusColor(room.status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(Icons.meeting_room, color: color),
                                ),
                                title: Text(
                                  'Phòng ${room.roomNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class EditRoomScreen extends StatefulWidget {
  final Room room;

  const EditRoomScreen({super.key, required this.room});

  @override
  State<EditRoomScreen> createState() => _EditRoomScreenState();
}

String? _validateRoomCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mã phòng';
  }
  return null;
}

String? _validateRentPrice(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || !parsed.isFinite) {
    return 'Vui lòng nhập giá thuê hợp lệ';
  }
  if (parsed < 2000000) {
    return 'Giá thuê tối thiểu là 2,000,000 VND';
  }
  return null;
}

String? _validateArea(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || !parsed.isFinite) {
    return 'Vui lòng nhập diện tích hợp lệ';
  }
  if (parsed < 15 || parsed > 25) {
    return 'Diện tích phải nằm trong khoảng 15 đến 25 m²';
  }
  return null;
}

Future<bool> _isDuplicateRoomCode(
  String roomCode, {
  int? excludeId,
}) async {
  final rooms = await RoomDatabase.instance.getAllRooms();
  final normalized = roomCode.trim().toLowerCase();

  return rooms.any(
    (room) =>
        room.id != excludeId &&
        room.roomNumber.trim().toLowerCase() == normalized,
  );
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'available';
  String? _errorMessage;

  @override
  void dispose() {
    _numberController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final roomNumber = _numberController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final area = double.tryParse(_areaController.text.trim());

    if (price == null || area == null) {
      setState(() => _errorMessage = 'Thông tin giá thuê hoặc diện tích không hợp lệ.');
      return;
    }

    if (await _isDuplicateRoomCode(roomNumber)) {
      setState(() => _errorMessage = 'Mã phòng đã tồn tại. Vui lòng chọn mã khác.');
      return;
    }

    try {
      await RoomDatabase.instance.insertRoom(
        Room(
          roomNumber: roomNumber,
          rentPrice: price,
          area: area,
          status: _status,
          description: _descriptionController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể lưu phòng: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm phòng mới'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng *',
                    hintText: 'Ví dụ: P101',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateRoomCode,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Giá thuê mỗi tháng (VNĐ) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateRentPrice,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Diện tích (m²) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateArea,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Phòng trống')),
                    DropdownMenuItem(value: 'rented', child: Text('Đang thuê')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu phòng'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _priceController;
  late final TextEditingController _areaController;
  late final TextEditingController _descriptionController;
  late String _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _numberController = TextEditingController(text: room.roomNumber);
    _priceController = TextEditingController(text: room.rentPrice.toString());
    _areaController = TextEditingController(text: room.area.toString());
    _descriptionController = TextEditingController(text: room.description);
    _status = room.status;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final roomNumber = _numberController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final area = double.tryParse(_areaController.text.trim());

    if (price == null || area == null) {
      setState(() => _errorMessage = 'Thông tin giá thuê hoặc diện tích không hợp lệ.');
      return;
    }

    if (await _isDuplicateRoomCode(roomNumber, excludeId: widget.room.id)) {
      setState(() => _errorMessage = 'Mã phòng đã tồn tại. Vui lòng chọn mã khác.');
      return;
    }

    try {
      await RoomDatabase.instance.updateRoom(
        Room(
          id: widget.room.id,
          roomNumber: roomNumber,
          rentPrice: price,
          area: area,
          status: _status,
          description: _descriptionController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể cập nhật phòng: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa phòng'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng *',
                    hintText: 'Ví dụ: P101',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateRoomCode,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Giá thuê mỗi tháng (VNĐ) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateRentPrice,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Diện tích (m²) *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateArea,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Phòng trống')),
                    DropdownMenuItem(value: 'rented', child: Text('Đang thuê')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Cập nhật phòng'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
