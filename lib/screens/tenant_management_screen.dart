// ============================================================
// File   : lib/screens/tenant_management_screen.dart
// Author : Long (Đã tối ưu: Tính thời hạn thuê tự động, bắt lỗi chuẩn từng trường)
// Mô tả  : Màn hình Quản lý Người thuê phòng
//          - Xem danh sách người thuê (View Tenant List)
//          - Thêm người thuê mới (Add Tenant - Tự động tạo Account)
//          - Sửa / Xóa người thuê (Delete Tenant - Đồng bộ trạng thái an toàn)
//          - Đổi trạng thái thuê (Update Tenant Status - 1 chạm)
// ============================================================

// BẮT ĐẦU CODE - Long

import 'package:flutter/material.dart';

import '../database/account_database.dart';
import '../database/invoice_database.dart';
import '../database/room_database.dart';
import '../database/tenant_database.dart';
import '../models/account.dart';
import '../models/room.dart';
import '../models/tenant.dart';

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

  // Chuẩn hóa và đồng bộ trạng thái phòng an toàn:
  // Nếu phòng vẫn còn ít nhất 1 người thuê đang 'active' thì giữ 'rented'.
  // Chỉ khi không còn ai thuê mới chuyển về 'available'.
  Future<void> _syncRoomStatus(String roomNumber) async {
    try {
      final allTenants = await TenantDatabase.instance.getAllTenants();
      final cleanTarget = roomNumber
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim()
          .toLowerCase();

      final hasActiveTenant = allTenants.any((t) {
        if (t.status != 'active') return false;
        final cleanRoom = t.roomNumber
            .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
            .trim()
            .toLowerCase();
        return cleanRoom == cleanTarget ||
            t.roomNumber.trim().toLowerCase() == roomNumber.trim().toLowerCase();
      });

      final newStatus = hasActiveTenant ? 'rented' : 'available';
      await RoomDatabase.instance.updateStatusByRoomNumber(roomNumber, newStatus);
    } catch (_) {}
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
        // [Add Tenant] Thêm người thuê mới
        await TenantDatabase.instance.insertTenant(result);

        // Tự động tạo tài khoản đăng nhập tương ứng trong AccountDatabase nếu chưa có
        try {
          final accounts = await AccountDatabase.instance.getAllAccounts();
          final exists = accounts.any(
            (a) => a.username.toLowerCase() == result.username.toLowerCase(),
          );
          if (!exists) {
            await AccountDatabase.instance.insertAccount(
              Account(
                username: result.username,
                password: '123', // Mật khẩu khởi tạo mặc định
                fullName: result.fullName,
                role: 'tenant',
                phone: result.phone,
                email: result.email,
                status: 'active',
              ),
            );
          }
        } catch (_) {}

        // Đồng bộ trạng thái phòng mới sang 'rented'
        await _syncRoomStatus(result.roomNumber);
        _showMessage('Thêm người thuê thành công! (Mật khẩu đăng nhập mặc định: 123)');
      } else {
        // [Update Tenant] Cập nhật thông tin
        await TenantDatabase.instance.updateTenant(result);

        // Nếu có chuyển phòng, đồng bộ trạng thái cả phòng cũ lẫn phòng mới
        if (tenant.roomNumber != result.roomNumber) {
          await _syncRoomStatus(tenant.roomNumber);
        }
        await _syncRoomStatus(result.roomNumber);

        _showMessage('Cập nhật thông tin người thuê thành công!');
      }

      await _loadTenants();
    } catch (e) {
      final error = e.toString().toLowerCase();
      if (error.contains('constraint') || error.contains('already exists')) {
        _showMessage('Tên đăng nhập (username) đã được sử dụng!');
      } else {
        _showMessage('Không thể lưu thông tin: $e');
      }
    }
  }

  // [Update Tenant Status] Chức năng đổi nhanh trạng thái người thuê (Active <-> Inactive)
  Future<void> _toggleTenantStatus(Tenant tenant) async {
    final isCurrentlyActive = tenant.status == 'active';
    final newStatus = isCurrentlyActive ? 'inactive' : 'active';
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final updated = tenant.copyWith(
      status: newStatus,
      endDate: isCurrentlyActive ? todayStr : tenant.endDate,
    );

    try {
      await TenantDatabase.instance.updateTenant(updated);
      await _syncRoomStatus(tenant.roomNumber);

      if (!mounted) return;
      _showMessage(newStatus == 'inactive'
          ? 'Đã ghi nhận trả phòng cho "${tenant.fullName}"'
          : 'Đã kích hoạt lại trạng thái thuê cho "${tenant.fullName}"');

      await _loadTenants();
    } catch (e) {
      _showMessage('Không thể đổi trạng thái: $e');
    }
  }

  // [Delete Tenant] Xóa người thuê kèm cảnh báo công nợ và kiểm tra an toàn
  Future<void> _deleteTenant(Tenant tenant) async {
    bool hasUnpaidInvoices = false;
    try {
      final invoices =
          await InvoiceDatabase.instance.getInvoicesByRoom(tenant.roomNumber);
      hasUnpaidInvoices = invoices.any((inv) => inv.status == 'unpaid');
    } catch (_) {}

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa người thuê'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc muốn xóa người thuê "${tenant.fullName}" khỏi hệ thống?',
            ),
            if (hasUnpaidInvoices) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cảnh báo: ${tenant.roomNumber} đang có hóa đơn chưa thanh toán!',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
      await _syncRoomStatus(tenant.roomNumber);

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
        builder: (_) => TenantDetailScreen(
          tenant: tenant,
          onStatusToggle: () => _toggleTenantStatus(tenant),
        ),
      ),
    ).then((_) => _loadTenants());
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

                // ── [View Tenant List] Danh sách người thuê ──
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
                                      Text(
                                        '@${tenant.username}',
                                        style: TextStyle(
                                          color: Colors.indigo.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tenant.roomNumber}  •  SĐT: ${tenant.phone}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      // Hiển thị thời hạn thuê rõ ràng
                                      Text(
                                        'Bắt đầu: ${tenant.startDate}  •  ${tenant.isLongTerm ? "Thuê dài hạn (Chưa có ngày trả)" : "Hạn trả: ${tenant.endDate}"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
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
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'detail') {
                                      _viewDetail(tenant);
                                    } else if (action == 'toggle_status') {
                                      _toggleTenantStatus(tenant);
                                    } else if (action == 'edit') {
                                      _openTenantForm(tenant: tenant);
                                    } else if (action == 'delete') {
                                      _deleteTenant(tenant);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
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
                                      value: 'toggle_status',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isActive
                                                ? Icons.person_off_outlined
                                                : Icons.how_to_reg_outlined,
                                            color: isActive
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isActive
                                                ? 'Xác nhận trả phòng'
                                                : 'Kích hoạt lại thuê',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined),
                                          SizedBox(width: 8),
                                          Text('Sửa thông tin'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
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
// Tối ưu hóa:
// - Chọn số tháng thuê (1, 2, 3, 6, 9, 12, 24 hoặc Dài hạn)
// - Tự động tính ngày trả phòng dựa trên ngày bắt đầu và số tháng thuê
// - Bắt lỗi chi tiết chuẩn từng trường (Full name không số, SĐT 10 số bắt đầu bằng 0...)
// ─────────────────────────────────────────────────────────────
class TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;

  const TenantFormDialog({super.key, this.tenant});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _cccdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _noteController;

  List<Room> _availableRooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomNumber;

  DateTime _startDate = DateTime.now();

  // Số tháng thuê (0 = Thuê dài hạn / Không thời hạn)
  int _rentalMonths = 12;

  late String _status;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;

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
    _status = t?.status ?? 'active';

    _startDate = _parseDate(t?.startDate) ?? DateTime.now();

    // Khởi tạo số tháng thuê nếu đang chỉnh sửa
    if (t != null) {
      if (t.isLongTerm) {
        _rentalMonths = 0; // Thuê dài hạn
      } else {
        final parsedEnd = _parseDate(t.endDate);
        if (parsedEnd != null) {
          final diffMonths = (parsedEnd.year - _startDate.year) * 12 +
              (parsedEnd.month - _startDate.month);
          _rentalMonths = diffMonths > 0 ? diffMonths : 12;
        } else {
          _rentalMonths = 12;
        }
      }
    }

    _loadAvailableRooms();
  }

  // Thuật toán cộng N tháng chính xác, xử lý ngày cuối tháng (VD: 31/01 + 1 tháng = 28/02)
  DateTime _addMonths(DateTime date, int months) {
    final newYear = date.year + ((date.month + months - 1) ~/ 12);
    final newMonth = ((date.month + months - 1) % 12) + 1;
    final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
    return DateTime(newYear, newMonth, newDay);
  }

  // Ngày trả phòng dự kiến được tính tự động
  DateTime? get _calculatedEndDate {
    if (_rentalMonths <= 0) return null; // 0 = Dài hạn
    return _addMonths(_startDate, _rentalMonths);
  }

  DateTime? _parseDate(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    try {
      if (str.contains('/')) {
        final parts = str.split('/');
        if (parts.length == 3) {
          final d = int.parse(parts[0].trim());
          final m = int.parse(parts[1].trim());
          final y = int.parse(parts[2].trim());
          return DateTime(y, m, d);
        }
      } else if (str.contains('-')) {
        return DateTime.parse(str);
      }
    } catch (_) {}
    return null;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _loadAvailableRooms() async {
    try {
      final allRooms = await RoomDatabase.instance.getAllRooms();
      final currentRoom = widget.tenant?.roomNumber.trim() ?? '';
      final cleanCurrent = currentRoom
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim();

      if (!mounted) return;

      setState(() {
        _availableRooms = allRooms;
        _isLoadingRooms = false;

        if (cleanCurrent.isNotEmpty) {
          for (final r in allRooms) {
            final cleanR = r.roomNumber
                .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
                .trim();
            if (cleanR == cleanCurrent || r.roomNumber == currentRoom) {
              _selectedRoomNumber = r.roomNumber;
              break;
            }
          }
          _selectedRoomNumber ??= currentRoom;
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

  // ═══════════════════════════════════════════════════════════
  // CÁC HÀM VALIDATOR BẮT LỖI CHUẨN XÁC & CHI TIẾT
  // ═══════════════════════════════════════════════════════════

  // 1. Validator: Tên đăng nhập
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập tên đăng nhập';
    }
    final clean = value.trim();
    if (clean.contains(' ')) {
      return 'Tên đăng nhập không được chứa khoảng trắng';
    }
    if (clean.length < 3) {
      return 'Tên đăng nhập phải có ít nhất 3 ký tự';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      return 'Tên đăng nhập chỉ gồm chữ cái không dấu, số và dấu gạch dưới (_)';
    }
    return null;
  }

  // 2. Validator: Họ và tên (KHÔNG ĐƯỢC CÓ SỐ, chỉ chấp nhận chữ cái)
  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    final clean = value.trim();
    if (RegExp(r'\d').hasMatch(clean)) {
      return 'Họ và tên không được chứa chữ số';
    }
    // Regex hỗ trợ chữ cái tiếng Việt có dấu và không dấu
    final vietnameseLetterRegex = RegExp(
      r'^[a-zA-ZÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚĂĐĨŨƠàáâãèéêìíòóôõùúăđĩũơƯĂẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼỀỀỂưăạảấầẩẫậắằẳẵặẹẻẽềềểỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪễệỉịọỏốồổỗộớờởỡợụủứừỬỮỰỲỴÝỶỸửữựỳỵýỷỹ\s]+$',
    );
    if (!vietnameseLetterRegex.hasMatch(clean)) {
      return 'Họ và tên chỉ được chứa chữ cái và khoảng trắng';
    }
    if (clean.length < 3) {
      return 'Họ và tên phải có tối thiểu 3 ký tự';
    }
    return null;
  }

  // 3. Validator: Số điện thoại (ĐÚNG 10 SỐ, BẮT ĐẦU BẰNG 0, KHÔNG CHỨA CHỮ)
  String? _validatePhone(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Vui lòng nhập số điện thoại' : null;
    }
    final clean = value.trim();
    if (RegExp(r'[a-zA-Z]').hasMatch(clean)) {
      return 'Số điện thoại không được chứa chữ cái';
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Số điện thoại chỉ được chứa các ký tự chữ số';
    }
    if (!clean.startsWith('0')) {
      return 'Số điện thoại phải bắt đầu bằng số 0';
    }
    if (clean.length != 10) {
      return 'Số điện thoại phải gồm đúng 10 chữ số (hiện có ${clean.length} số)';
    }
    return null;
  }

  // 4. Validator: Số CCCD / CMND (ĐÚNG 12 SỐ, CHỈ CHỨA SỐ)
  String? _validateCccd(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số CCCD / CMND';
    }
    final clean = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Số CCCD chỉ được chứa chữ số';
    }
    if (clean.length != 12) {
      return 'Số CCCD phải gồm đúng 12 chữ số (hiện có ${clean.length} số)';
    }
    return null;
  }

  // 5. Validator: Email (Tùy chọn, nhưng nếu nhập thì phải chuẩn)
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final clean = value.trim();
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,7}$');
    if (!emailRegex.hasMatch(clean)) {
      return 'Email không hợp lệ (Ví dụ: tenant101@gmail.com)';
    }
    return null;
  }

  // 6. Validator: Người liên hệ khẩn cấp (Không được có số)
  String? _validateEmergencyContact(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final clean = value.trim();
    if (RegExp(r'\d').hasMatch(clean)) {
      return 'Tên người liên hệ không được chứa chữ số';
    }
    return null;
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

  String _formatRoomDisplay(Room room) {
    final prefix = room.roomNumber.toLowerCase().startsWith('phòng')
        ? room.roomNumber
        : 'Phòng ${room.roomNumber}';
    final priceStr = room.rentPrice > 0 ? ' - ${_money(room.rentPrice)}' : '';
    String statusStr;
    switch (room.status) {
      case 'available':
        statusStr = ' (Trống)';
        break;
      case 'rented':
        statusStr = ' (Đang thuê - Ở ghép)';
        break;
      case 'maintenance':
        statusStr = ' (Bảo trì)';
        break;
      default:
        statusStr = ' (${room.status})';
    }
    return '$prefix$priceStr$statusStr';
  }

  void _save() {
    setState(() => _autoValidate = true);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoomNumber == null || _selectedRoomNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn phòng cho người thuê!')),
      );
      return;
    }

    final rawRoom = _selectedRoomNumber!;
    final roomName = rawRoom.toLowerCase().startsWith('phòng')
        ? rawRoom
        : 'Phòng $rawRoom';

    // Tính ngày kết thúc: Nếu là dài hạn (months == 0) -> lưu rỗng ''; ngược lại lưu dd/MM/yyyy
    final calculatedEnd = _calculatedEndDate;
    final endDateString = calculatedEnd != null ? _formatDate(calculatedEnd) : '';

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
      endDate: endDateString,
      status: _status,
      note: _noteController.text.trim(),
    );

    Navigator.pop(context, result);
  }

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

    // Danh sách các lựa chọn thời hạn thuê
    final durationOptions = <int, String>{
      1: '1 tháng',
      2: '2 tháng',
      3: '3 tháng',
      6: '6 tháng (Nửa năm)',
      9: '9 tháng',
      12: '12 tháng (1 năm)',
      24: '24 tháng (2 năm)',
      0: 'Thuê dài hạn (Không thời hạn)',
    };

    // Đảm bảo nếu đang sửa và có số tháng lạ (VD: 5 tháng) thì vẫn hiển thị đúng
    if (!durationOptions.containsKey(_rentalMonths) && _rentalMonths > 0) {
      durationOptions[_rentalMonths] = '$_rentalMonths tháng';
    }

    return AlertDialog(
      title: Text(isEditing ? 'Sửa thông tin người thuê' : 'Thêm người thuê mới'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
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
                    helperText: 'Chữ cái thường, số, dấu gạch dưới (VD: tenant101)',
                  ),
                  validator: _validateUsername,
                ),

                // ── Nhóm: Thông tin cá nhân ──
                _sectionHeader('Thông tin cá nhân', Icons.badge),

                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    hintText: 'Ví dụ: Nguyễn Văn Phát',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                    helperText: 'Không được chứa chữ số hoặc ký tự đặc biệt',
                  ),
                  validator: _validateFullName,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cccdController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Số CCCD / CMND *',
                    hintText: 'Đúng 12 chữ số',
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
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    hintText: 'Ví dụ: 0987654321 (10 số, bắt đầu bằng 0)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: '',
                  ),
                  validator: (val) => _validatePhone(val, isRequired: true),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Ví dụ: nguyenphat@gmail.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ thường trú',
                    hintText: 'Số nhà, tên đường, quận/huyện, tỉnh/TP',
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
                  validator: _validateEmergencyContact,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'SĐT người liên hệ khẩn cấp',
                    hintText: 'Ví dụ: 0901234567',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_in_talk),
                    counterText: '',
                  ),
                  validator: (val) => _validatePhone(val, isRequired: false),
                ),

                // ── Nhóm: Thông tin thuê phòng & Thời hạn ──
                _sectionHeader('Thông tin thuê phòng', Icons.meeting_room),

                // 1. Chọn phòng
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
                        const Expanded(
                          child: Text(
                            'Chưa có phòng nào trong hệ thống! Vui lòng tạo phòng trước.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                      labelText: 'Chọn phòng trọ *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.door_front_door_outlined),
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
                        return 'Vui lòng chọn phòng thuê';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),

                // 2. Ngày bắt đầu thuê
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      helpText: 'Chọn ngày bắt đầu thuê',
                      confirmText: 'CHỌN',
                      cancelText: 'HỦY',
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày bắt đầu thuê *',
                      prefixIcon: Icon(Icons.calendar_month, color: Colors.indigo),
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _formatDate(_startDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Thời hạn thuê (Bỏ chọn ngày trả phòng, thay bằng số tháng thuê / dài hạn)
                DropdownButtonFormField<int>(
                  value: _rentalMonths,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Thời hạn thuê (Hợp đồng) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time_filled, color: Colors.indigo),
                  ),
                  items: durationOptions.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: entry.key == 0 ? FontWeight.bold : FontWeight.normal,
                          color: entry.key == 0 ? Colors.amber.shade900 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _rentalMonths = val);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Hộp hiển thị tự động Ngày trả phòng dự kiến
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _rentalMonths == 0 ? Colors.amber.shade50 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _rentalMonths == 0 ? Colors.amber.shade300 : Colors.indigo.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _rentalMonths == 0 ? Icons.all_inclusive : Icons.event_available,
                        color: _rentalMonths == 0 ? Colors.amber.shade800 : Colors.indigo.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày trả phòng dự kiến:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _rentalMonths == 0
                                  ? 'Chưa có (Thuê dài hạn / Chưa xác định)'
                                  : '${_formatDate(_calculatedEndDate)} (Hết hạn sau $_rentalMonths tháng)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _rentalMonths == 0
                                    ? Colors.amber.shade900
                                    : Colors.indigo.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Trạng thái người thuê
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái thuê *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.toggle_on_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('Đang thuê (Active)'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Đã rời phòng (Inactive)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
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
  final VoidCallback? onStatusToggle;

  const TenantDetailScreen({
    super.key,
    required this.tenant,
    this.onStatusToggle,
  });

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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            // Thẻ tổng quan
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
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
                    if (onStatusToggle != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          onStatusToggle!();
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          isActive ? Icons.person_off : Icons.how_to_reg,
                          size: 18,
                        ),
                        label: Text(
                          isActive ? 'Đánh dấu đã trả phòng' : 'Kích hoạt lại thuê',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thông tin cá nhân
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

            // Thông tin liên hệ
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

            // Liên hệ khẩn cấp
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

            // Thông tin thuê phòng
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
                  tenant.isLongTerm
                      ? 'Chưa có (Thuê dài hạn)'
                      : tenant.endDate,
                  Icons.event_busy,
                ),
              ],
            ),

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
