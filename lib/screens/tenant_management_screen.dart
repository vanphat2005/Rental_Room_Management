// ============================================================
// File   : lib/screens/tenant_management_screen.dart
// Author : Long
// Mô tả  : Màn hình Quản lý Người thuê phòng
//          - Xem danh sách người thuê (View Tenant List)
//          - Thêm người thuê mới (Add Tenant)
//          - Sửa / Xóa thông tin người thuê
// ============================================================

// BẮT ĐẦU CODE - Long

import 'package:flutter/material.dart';

import '../database/tenant_database.dart';
import '../models/tenant.dart';
import '../database/room_database.dart';
import '../models/room.dart';
import 'tenant_invoice_screen.dart';

// ─────────────────────────────────────────────────────────────
// Màn hình chính: danh sách người thuê
// ─────────────────────────────────────────────────────────────
class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  List<Tenant> _tenants = [];
  bool _isLoading = true;

  // Bộ lọc và tìm kiếm
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  // Tải danh sách người thuê từ Database
  Future<void> _loadTenants() async {
    setState(() => _isLoading = true);
    try {
      final list = await TenantDatabase.instance.getAllTenants();
      if (!mounted) return;
      setState(() {
        _tenants = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Lỗi tải danh sách người thuê: $e');
    }
  }

  // Lọc danh sách theo từ khóa và trạng thái
  List<Tenant> get _filteredTenants {
    return _tenants.where((t) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = t.fullName.toLowerCase().contains(query) ||
          t.username.toLowerCase().contains(query) ||
          t.cccd.contains(query) ||
          t.phone.contains(query) ||
          t.roomNumber.toLowerCase().contains(query);

      final matchesStatus =
          _filterStatus == 'all' || t.status == _filterStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // Thống kê nhanh
  int get _activeCount => _tenants.where((t) => t.status == 'active').length;
  int get _inactiveCount =>
      _tenants.where((t) => t.status == 'inactive').length;

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Mở form Thêm / Sửa người thuê
  Future<void> _openTenantForm({Tenant? tenant}) async {
    final result = await showDialog<Tenant>(
      context: context,
      builder: (_) => TenantFormDialog(tenant: tenant),
    );

    if (result == null || !mounted) return;

    try {
      if (tenant == null) {
        await TenantDatabase.instance.insertTenant(result);
        // Cập nhật trạng thái phòng sang 'rented'
        await _updateRoomStatus(result.roomNumber, 'rented');
        _showMessage('Thêm người thuê thành công!');
      } else {
        await TenantDatabase.instance.updateTenant(result);
        // Nếu đổi phòng thì giải phóng phòng cũ và chuyển phòng mới sang rented
        if (tenant.roomNumber != result.roomNumber) {
          await _updateRoomStatus(tenant.roomNumber, 'available');
          await _updateRoomStatus(result.roomNumber, 'rented');
        }
        _showMessage('Cập nhật thông tin thành công!');
      }
      await _loadTenants();
    } catch (e) {
      final error = e.toString().toLowerCase();
      if (error.contains('constraint') || error.contains('already exists')) {
        _showMessage('Tài khoản (username) đã được sử dụng!');
      } else {
        _showMessage('Không thể lưu thông tin: $e');
      }
    }
  }

  // Cập nhật trạng thái phòng trong RoomDatabase
  Future<void> _updateRoomStatus(String roomNumber, String newStatus) async {
    try {
      final rooms = await RoomDatabase.instance.getAllRooms();
      final cleanNum = roomNumber
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim();
      for (final r in rooms) {
        if (r.roomNumber == roomNumber ||
            r.roomNumber == cleanNum ||
            'Phòng ${r.roomNumber}' == roomNumber) {
          if (r.status != newStatus) {
            await RoomDatabase.instance.updateRoom(
              Room(
                id: r.id,
                roomNumber: r.roomNumber,
                rentPrice: r.rentPrice,
                area: r.area,
                status: newStatus,
                description: r.description,
              ),
            );
          }
          break;
        }
      }
    } catch (_) {}
  }

  // Xóa người thuê sau khi xác nhận
  Future<void> _deleteTenant(Tenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa người thuê'),
        content: Text(
          'Bạn có chắc muốn xóa người thuê "${tenant.fullName}" không?',
        ),
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
      await TenantDatabase.instance.deleteTenant(tenant.id!);
      // Trả lại trạng thái phòng là available khi xóa người thuê
      await _updateRoomStatus(tenant.roomNumber, 'available');
      if (!mounted) return;
      _showMessage('Đã xóa người thuê ${tenant.fullName}');
      await _loadTenants();
    } catch (e) {
      _showMessage('Không thể xóa: $e');
    }
  }

  // Xem chi tiết người thuê
  void _viewDetail(Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TenantDetailScreen(tenant: tenant),
      ),
    );
  }

  // Widget thẻ thống kê nhỏ
  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
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
    final list = _filteredTenants;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Người thuê',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTenants,
          ),
        ],
      ),

      // FAB Thêm người thuê mới
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTenantForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm người thuê'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Thống kê nhanh ──
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Tổng số',
                        _tenants.length,
                        Colors.indigo,
                        Icons.people,
                      ),
                      _buildStatCard(
                        'Đang thuê',
                        _activeCount,
                        Colors.green,
                        Icons.how_to_reg,
                      ),
                      _buildStatCard(
                        'Đã rời',
                        _inactiveCount,
                        Colors.grey,
                        Icons.person_off,
                      ),
                    ],
                  ),
                ),

                // ── Thanh tìm kiếm ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Tìm theo tên, username, CCCD, SĐT, phòng...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 8),

                      // ── Bộ lọc trạng thái ──
                      DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: const InputDecoration(
                          labelText: 'Lọc theo trạng thái',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Đang thuê'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Đã rời phòng'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _filterStatus = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Danh sách người thuê ──
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _tenants.isEmpty
                                    ? 'Chưa có người thuê nào'
                                    : 'Không tìm thấy kết quả phù hợp',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (_tenants.isEmpty) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Nhấn "Thêm người thuê" để bắt đầu.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: list.length,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemBuilder: (context, index) {
                            final tenant = list[index];
                            final isActive = tenant.status == 'active';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                // Avatar icon người thuê
                                leading: CircleAvatar(
                                  backgroundColor: isActive
                                      ? Colors.indigo.shade100
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person,
                                    color: isActive
                                        ? Colors.indigo
                                        : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  tenant.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Tên đăng nhập
                                      Text(
                                        '@${tenant.username}',
                                        style: TextStyle(
                                          color: Colors.indigo.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Số phòng và SĐT
                                      Text(
                                        '${tenant.roomNumber}  •  SĐT: ${tenant.phone}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      // CCCD
                                      Text(
                                        'CCCD: ${tenant.cccd}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      // Badge trạng thái
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.green.shade50
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isActive
                                                ? Colors.green.shade300
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        child: Text(
                                          isActive ? 'Đang thuê' : 'Đã rời phòng',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isActive
                                                ? Colors.green.shade700
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Menu hành động
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'detail') {
                                      _viewDetail(tenant);
                                    } else if (action == 'edit') {
                                      _openTenantForm(tenant: tenant);
                                    } else if (action == 'delete') {
                                      _deleteTenant(tenant);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'detail',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline),
                                          SizedBox(width: 8),
                                          Text('Xem chi tiết'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined),
                                          SizedBox(width: 8),
                                          Text('Sửa thông tin'),
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
                                          Text(
                                            'Xóa',
                                            style:
                                                TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Tap để xem chi tiết
                                onTap: () => _viewDetail(tenant),
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
// Dialog: Form Thêm / Sửa người thuê
// Sửa đổi bởi Long:
// - Chọn số phòng từ danh sách phòng trống (status == 'available')
// - Chọn Ngày bắt đầu thuê dạng lịch và phân chia Ngày / Tháng / Năm
// - Bỏ chọn Trạng thái phòng, thay bằng Ngày trả phòng cùng giao diện
// ─────────────────────────────────────────────────────────────
class TenantFormDialog extends StatefulWidget {
  final Tenant? tenant; // null = Thêm mới, có giá trị = Sửa

  const TenantFormDialog({super.key, this.tenant});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers cho từng trường nhập liệu
  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _cccdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _noteController;

  // Phòng trống để chọn (Long)
  List<Room> _availableRooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomNumber;

  // Ngày bắt đầu và Ngày trả phòng (Long)
  DateTime? _startDate;
  DateTime? _endDate;
  String? _startDateError;
  String? _endDateError;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;

    // Khởi tạo giá trị mặc định (nếu Sửa thì điền sẵn dữ liệu cũ)
    _usernameController = TextEditingController(text: t?.username ?? '');
    _fullNameController = TextEditingController(text: t?.fullName ?? '');
    _cccdController = TextEditingController(text: t?.cccd ?? '');
    _phoneController = TextEditingController(text: t?.phone ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
    _addressController = TextEditingController(text: t?.address ?? '');
    _emergencyContactController =
        TextEditingController(text: t?.emergencyContact ?? '');
    _emergencyPhoneController =
        TextEditingController(text: t?.emergencyPhone ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');

    // Parse ngày bắt đầu và ngày trả phòng (Long)
    _startDate = _parseDate(t?.startDate) ?? DateTime.now();
    _endDate = _parseDate(t?.endDate);

    // Tải danh sách phòng trống
    _loadAvailableRooms();
  }

  // Chuyển chuỗi dd/MM/yyyy thành DateTime (Long)
  DateTime? _parseDate(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    try {
      if (str.contains('/')) {
        final parts = str.split('/');
        if (parts.length == 3) {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      } else if (str.contains('-')) {
        return DateTime.parse(str);
      }
    } catch (_) {}
    return null;
  }

  // Định dạng DateTime thành dd/MM/yyyy (Long)
  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  // Tải các phòng có trạng thái trống từ RoomDatabase (Long)
  Future<void> _loadAvailableRooms() async {
    try {
      final allRooms = await RoomDatabase.instance.getAllRooms();
      final currentRoom = widget.tenant?.roomNumber.trim() ?? '';
      final cleanCurrent = currentRoom
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim();

      // Lọc các phòng có trạng thái 'available'
      final filtered = allRooms.where((r) {
        if (r.status == 'available') return true;
        // Nếu đang sửa thì giữ lại phòng hiện tại của khách
        if (cleanCurrent.isNotEmpty) {
          final cleanR = r.roomNumber
              .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
              .trim();
          if (cleanR == cleanCurrent || r.roomNumber == currentRoom) {
            return true;
          }
        }
        return false;
      }).toList();

      // Nếu đang sửa nhưng phòng không có trong database, thêm tạm để hiển thị
      if (cleanCurrent.isNotEmpty &&
          !filtered.any((r) =>
              r.roomNumber == currentRoom ||
              r.roomNumber.replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '').trim() == cleanCurrent)) {
        filtered.insert(
          0,
          Room(
            roomNumber: cleanCurrent.isEmpty ? currentRoom : cleanCurrent,
            rentPrice: 0,
            area: 0,
            status: 'rented',
            description: 'Phòng hiện tại',
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _availableRooms = filtered;
        _isLoadingRooms = false;

        // Chọn phòng ban đầu nếu đang sửa
        if (cleanCurrent.isNotEmpty) {
          for (final r in filtered) {
            final cleanR = r.roomNumber
                .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
                .trim();
            if (cleanR == cleanCurrent || r.roomNumber == currentRoom) {
              _selectedRoomNumber = r.roomNumber;
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
    _usernameController.dispose();
    _fullNameController.dispose();
    _cccdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Validator: bắt buộc nhập
  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin này';
    }
    return null;
  }

  // Validator: CCCD phải đủ 12 chữ số
  String? _validateCccd(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số CCCD';
    }
    if (!RegExp(r'^\d{12}$').hasMatch(value.trim())) {
      return 'CCCD phải gồm đúng 12 chữ số';
    }
    return null;
  }

  // Định dạng số tiền
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

  // Hiển thị tên phòng kèm thông tin giá trong dropdown (Long)
  String _formatRoomDisplay(Room room) {
    final prefix = room.roomNumber.toLowerCase().startsWith('phòng')
        ? room.roomNumber
        : 'Phòng ${room.roomNumber}';
    final priceStr = room.rentPrice > 0 ? ' - ${_money(room.rentPrice)}' : '';
    final isAvail = room.status == 'available';
    final statusStr = isAvail ? ' (Trống)' : ' (Hiện tại)';
    return '$prefix$priceStr$statusStr';
  }

  // Tính số ngày tối đa trong tháng (Long)
  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // Widget chọn ngày dạng lịch kết hợp phân Ngày / Tháng / Năm (Long)
  Widget _buildDateSelector({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDateChanged,
    required bool isRequired,
    String? errorText,
  }) {
    final now = DateTime.now();
    final year = selectedDate?.year ?? now.year;
    final month = selectedDate?.month ?? now.month;
    final maxDays = _daysInMonth(year, month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month,
              size: 16,
              color: Colors.indigo.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            if (selectedDate != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Text(
                  _formatDate(selectedDate),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                    fontSize: 12,
                  ),
                ),
              )
            else if (!isRequired)
              Text(
                '(Chưa chọn)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null
                  ? Colors.red.shade400
                  : Colors.grey.shade400,
            ),
          ),
          child: Row(
            children: [
              // 1. Phân chọn Ngày (Day dropdown)
              Expanded(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDate?.day,
                    hint: const Text('Ngày', style: TextStyle(fontSize: 13)),
                    items: List.generate(maxDays, (i) {
                      final day = i + 1;
                      return DropdownMenuItem(
                        value: day,
                        child: Text(
                          day.toString().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    onChanged: (newDay) {
                      if (newDay == null) return;
                      final base = selectedDate ?? DateTime.now();
                      final validDay =
                          newDay > _daysInMonth(base.year, base.month)
                              ? _daysInMonth(base.year, base.month)
                              : newDay;
                      onDateChanged(
                        DateTime(base.year, base.month, validDay),
                      );
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('/', style: TextStyle(color: Colors.grey)),
              ),

              // 2. Phân chọn Tháng (Month dropdown)
              Expanded(
                flex: 3,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDate?.month,
                    hint: const Text('Tháng', style: TextStyle(fontSize: 13)),
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          'Tháng ${m.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    onChanged: (newMonth) {
                      if (newMonth == null) return;
                      final base = selectedDate ?? DateTime.now();
                      final maxD = _daysInMonth(base.year, newMonth);
                      final validDay = base.day > maxD ? maxD : base.day;
                      onDateChanged(DateTime(base.year, newMonth, validDay));
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('/', style: TextStyle(color: Colors.grey)),
              ),

              // 3. Phân chọn Năm (Year dropdown)
              Expanded(
                flex: 3,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDate?.year,
                    hint: const Text('Năm', style: TextStyle(fontSize: 13)),
                    items: List.generate(21, (i) {
                      final y = 2020 + i;
                      return DropdownMenuItem(
                        value: y,
                        child: Text(
                          '$y',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    onChanged: (newYear) {
                      if (newYear == null) return;
                      final base = selectedDate ?? DateTime.now();
                      final maxD = _daysInMonth(newYear, base.month);
                      final validDay = base.day > maxD ? maxD : base.day;
                      onDateChanged(DateTime(newYear, base.month, validDay));
                    },
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 4. Nút chọn dạng lịch (showDatePicker)
              IconButton(
                tooltip: 'Chọn trực tiếp trên lịch',
                icon: const Icon(Icons.date_range, color: Colors.indigo),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    helpText: label,
                    confirmText: 'CHỌN',
                    cancelText: 'HỦY',
                  );
                  if (picked != null) {
                    onDateChanged(picked);
                  }
                },
              ),

              // Nút xóa ngày nếu không bắt buộc
              if (!isRequired && selectedDate != null)
                IconButton(
                  tooltip: 'Xóa ngày',
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => onDateChanged(null),
                ),
            ],
          ),
        ),

        // Hiển thị lỗi nếu có
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Lưu form và trả kết quả về màn hình cha (Long)
  void _save() {
    setState(() {
      _startDateError = _startDate == null
          ? 'Vui lòng chọn ngày bắt đầu thuê'
          : null;
      if (_startDate != null &&
          _endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        _endDateError = 'Ngày trả phòng không thể trước ngày bắt đầu thuê';
      } else {
        _endDateError = null;
      }
    });

    if (!_formKey.currentState!.validate()) return;
    if (_startDateError != null || _endDateError != null) return;

    if (_selectedRoomNumber == null || _selectedRoomNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn phòng trống cho người thuê!')),
      );
      return;
    }

    final rawRoom = _selectedRoomNumber!;
    final roomName = rawRoom.toLowerCase().startsWith('phòng')
        ? rawRoom
        : 'Phòng $rawRoom';

    // Xác định trạng thái người thuê
    String status = widget.tenant?.status ?? 'active';
    if (_endDate != null && _endDate!.isBefore(DateTime.now())) {
      status = 'inactive';
    }

    final result = Tenant(
      id: widget.tenant?.id,
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      cccd: _cccdController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim(),
      roomNumber: roomName,
      startDate: _formatDate(_startDate),
      endDate: _formatDate(_endDate),
      status: status,
      note: _noteController.text.trim(),
    );

    Navigator.pop(context, result);
  }

  // Widget tiêu đề phân nhóm trong form
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tenant != null;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa thông tin người thuê' : 'Thêm người thuê mới'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nhóm: Tài khoản ──
                _sectionHeader('Thông tin tài khoản', Icons.account_circle),

                TextFormField(
                  controller: _usernameController,
                  enabled: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập (username) *',
                    hintText: 'Ví dụ: tenant101',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _required,
                ),

                // ── Nhóm: Thông tin cá nhân ──
                _sectionHeader('Thông tin cá nhân', Icons.badge),

                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cccdController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Số CCCD / CMND *',
                    hintText: '12 chữ số',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                    counterText: '',
                  ),
                  validator: _validateCccd,
                ),

                // ── Nhóm: Thông tin liên hệ ──
                _sectionHeader('Thông tin liên hệ', Icons.contact_phone),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ thường trú',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  maxLines: 2,
                ),

                // ── Nhóm: Liên hệ khẩn cấp ──
                _sectionHeader('Liên hệ khẩn cấp', Icons.emergency),

                TextFormField(
                  controller: _emergencyContactController,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên người liên hệ khẩn cấp',
                    hintText: 'Ví dụ: Nguyễn Thị Lan (Mẹ)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_pin),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'SĐT người liên hệ khẩn cấp',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_in_talk),
                  ),
                ),

                // ── Nhóm: Thông tin thuê phòng (Long) ──
                _sectionHeader('Thông tin thuê phòng', Icons.meeting_room),

                // 1. Số phòng: Dropdown danh sách phòng trống (Long)
                if (_isLoadingRooms)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_availableRooms.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hiện không có phòng nào có trạng thái trống!',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedRoomNumber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Số phòng (chọn phòng trống) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.door_front_door_outlined),
                      helperText: 'Danh sách các phòng có trạng thái trống',
                    ),
                    items: _availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room.roomNumber,
                        child: Text(
                          _formatRoomDisplay(room),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: room.status == 'available'
                                ? Colors.green.shade800
                                : Colors.indigo.shade800,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedRoomNumber = val);
                    },
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Vui lòng chọn phòng trống';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),

                // 2. Ngày bắt đầu thuê (Dạng lịch & phân chia Ngày / Tháng / Năm) (Long)
                _buildDateSelector(
                  label: 'Ngày bắt đầu thuê *',
                  selectedDate: _startDate,
                  isRequired: true,
                  errorText: _startDateError,
                  onDateChanged: (dt) {
                    setState(() {
                      _startDate = dt;
                      _startDateError = null;
                      if (_endDate != null && dt != null && _endDate!.isBefore(dt)) {
                        _endDateError =
                            'Ngày trả phòng không thể trước ngày bắt đầu thuê';
                      } else {
                        _endDateError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // 3. Ngày trả phòng (Thay cho trạng thái phòng, cùng giao diện lịch & Ngày/Tháng/Năm) (Long)
                _buildDateSelector(
                  label: 'Ngày trả phòng',
                  selectedDate: _endDate,
                  isRequired: false,
                  errorText: _endDateError,
                  onDateChanged: (dt) {
                    setState(() {
                      _endDate = dt;
                      if (dt != null &&
                          _startDate != null &&
                          dt.isBefore(_startDate!)) {
                        _endDateError =
                            'Ngày trả phòng không thể trước ngày bắt đầu thuê';
                      } else {
                        _endDateError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // ── Nhóm: Ghi chú ──
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Ghi chú thêm về người thuê...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
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
          child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm người thuê'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Màn hình Chi tiết người thuê
// ─────────────────────────────────────────────────────────────
class TenantDetailScreen extends StatelessWidget {
  final Tenant tenant;

  const TenantDetailScreen({super.key, required this.tenant});

  // Widget hiển thị từng dòng thông tin
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.indigo.shade400),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget thẻ nhóm thông tin
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề nhóm
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = tenant.status == 'active';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tenant.fullName,
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
            // ── Thẻ tổng quan ──
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // Avatar lớn
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isActive
                          ? Colors.indigo.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: isActive ? Colors.indigo : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tenant.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${tenant.username}',
                      style: TextStyle(
                        color: Colors.indigo.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Badge trạng thái
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      child: Text(
                        isActive ? 'ĐANG THUÊ' : 'ĐÃ RỜI PHÒNG',
                        style: TextStyle(
                          color: isActive
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Thông tin cá nhân ──
            _buildSection(
              'Thông tin cá nhân',
              Icons.badge,
              [
                _buildInfoRow('Họ và tên', tenant.fullName, Icons.person),
                _buildInfoRow(
                    'CCCD / CMND', tenant.cccd, Icons.credit_card),
              ],
            ),
            const SizedBox(height: 10),

            // ── Thông tin liên hệ ──
            _buildSection(
              'Thông tin liên hệ',
              Icons.contact_phone,
              [
                _buildInfoRow('Số điện thoại', tenant.phone, Icons.phone),
                _buildInfoRow('Email', tenant.email, Icons.email_outlined),
                _buildInfoRow(
                    'Địa chỉ', tenant.address, Icons.home_outlined),
              ],
            ),
            const SizedBox(height: 10),

            // ── Liên hệ khẩn cấp ──
            _buildSection(
              'Liên hệ khẩn cấp',
              Icons.emergency,
              [
                _buildInfoRow(
                  'Người liên hệ',
                  tenant.emergencyContact,
                  Icons.person_pin,
                ),
                _buildInfoRow(
                  'SĐT khẩn cấp',
                  tenant.emergencyPhone,
                  Icons.phone_in_talk,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Thông tin thuê phòng ──
            _buildSection(
              'Thông tin thuê phòng',
              Icons.meeting_room,
              [
                _buildInfoRow(
                  'Phòng đang thuê',
                  tenant.roomNumber,
                  Icons.door_front_door_outlined,
                ),
                _buildInfoRow(
                  'Ngày bắt đầu',
                  tenant.startDate,
                  Icons.calendar_today,
                ),
                _buildInfoRow(
                  'Ngày trả phòng',
                  tenant.endDate.isEmpty ? 'Chưa trả phòng' : tenant.endDate,
                  Icons.event_busy,
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Xem hóa đơn phòng này (Tenant View)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade800,
                      side: BorderSide(color: Colors.teal.shade600),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TenantInvoiceScreen(
                            roomNumber: tenant.roomNumber,
                            tenantName: tenant.fullName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Ghi chú (nếu có) ──
            if (tenant.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                          'Ghi chú: ${tenant.note}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// KẾT THÚC CODE - Long
