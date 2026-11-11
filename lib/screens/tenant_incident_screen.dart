// ============================================================
// File   : lib/screens/tenant_incident_screen.dart
// Author : Thọ
// Mô tả  : Màn hình theo dõi và báo cáo Sự cố / Bảo trì
//          dành riêng cho Người thuê (Tenant).
//          Chức năng:
//            - Xem danh sách sự cố thuộc phòng của mình
//            - Kiểm tra tiến độ: Đã xử lý hay chưa (pending/processing/resolved/closed)
//            - Xem chi tiết phản hồi và ghi chú xử lý từ chủ trọ
//            - Gửi báo cáo sự cố mới cho phòng của mình
// ============================================================

import 'package:flutter/material.dart';

import '../database/incident_database.dart';
import '../database/room_database.dart';
import '../models/incident.dart';
import 'login_screen.dart';
import 'tenant_invoice_screen.dart';

class TenantIncidentScreen extends StatefulWidget {
  final String? roomNumber;
  final String? tenantName;

  const TenantIncidentScreen({super.key, this.roomNumber, this.tenantName});

  @override
  State<TenantIncidentScreen> createState() => _TenantIncidentScreenState();
}

class _TenantIncidentScreenState extends State<TenantIncidentScreen> {
  List<Incident> _allRoomIncidents = [];
  List<String> _availableRooms = [];
  String? _selectedRoom;
  bool _isLoading = true;
  String _filterStatus =
      'all'; // 'all', 'pending', 'processing', 'resolved', 'closed'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  String _normalizeRoomNumber(String? roomNumber) {
    final raw = (roomNumber ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.toLowerCase().startsWith('phòng') ? raw : 'Phòng $raw';
  }

  bool _isSameRoom(String a, String b) {
    final normA = a.trim().toLowerCase().replaceFirst(
      RegExp(r'^phòng\s*', caseSensitive: false),
      '',
    );
    final normB = b.trim().toLowerCase().replaceFirst(
      RegExp(r'^phòng\s*', caseSensitive: false),
      '',
    );
    return normA == normB;
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final roomsFromDb = await RoomDatabase.instance.getAllRooms();
      final allIncidents = await IncidentDatabase.instance.getAllIncidents();

      final roomSet = <String>{};
      for (final r in roomsFromDb) {
        final normalized = _normalizeRoomNumber(r.roomNumber);
        if (normalized.isNotEmpty) roomSet.add(normalized);
      }
      for (final inc in allIncidents) {
        final normalized = _normalizeRoomNumber(inc.roomNumber);
        if (normalized.isNotEmpty) roomSet.add(normalized);
      }

      final roomList = roomSet.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      String? defaultRoom = _normalizeRoomNumber(widget.roomNumber);
      if (defaultRoom.isEmpty && roomList.isNotEmpty) {
        defaultRoom = roomList.first;
      }

      _availableRooms = roomList;
      _selectedRoom = defaultRoom;

      await _loadIncidentsForSelectedRoom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')));
    }
  }

  Future<void> _loadIncidentsForSelectedRoom() async {
    if (_selectedRoom == null || _selectedRoom!.isEmpty) {
      setState(() {
        _allRoomIncidents = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final all = await IncidentDatabase.instance.getAllIncidents();
      final filteredByRoom = all
          .where((inc) => _isSameRoom(inc.roomNumber, _selectedRoom!))
          .toList();

      if (!mounted) return;
      setState(() {
        _allRoomIncidents = filteredByRoom;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tải sự cố: $e')));
    }
  }

  List<Incident> get _filteredIncidents {
    return _allRoomIncidents.where((inc) {
      final matchesStatus =
          _filterStatus == 'all' || inc.status == _filterStatus;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          inc.title.toLowerCase().contains(q) ||
          inc.description.toLowerCase().contains(q);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get _pendingCount =>
      _allRoomIncidents.where((i) => i.status == IncidentStatus.pending).length;
  int get _processingCount => _allRoomIncidents
      .where((i) => i.status == IncidentStatus.processing)
      .length;
  int get _resolvedCount => _allRoomIncidents
      .where(
        (i) =>
            i.status == IncidentStatus.resolved ||
            i.status == IncidentStatus.closed,
      )
      .length;

  Color _getStatusColor(String status) {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.red;
      case IncidentStatus.processing:
        return Colors.orange;
      case IncidentStatus.resolved:
        return Colors.green;
      case IncidentStatus.closed:
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case IncidentStatus.pending:
        return Icons.pending_actions;
      case IncidentStatus.processing:
        return Icons.sync;
      case IncidentStatus.resolved:
        return Icons.check_circle;
      case IncidentStatus.closed:
        return Icons.lock_outline;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _openCreateIncidentDialog() async {
    if (_selectedRoom == null || _selectedRoom!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có thông tin phòng để báo cáo.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final now = DateTime.now();
    final todayFormatted =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report_problem_rounded, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Text(
              'Báo sự cố mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.room, color: Colors.teal, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Phòng báo cáo: $_selectedRoom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề sự cố *',
                      hintText:
                          'VD: Hỏng vòi nước, chập điện, hỏng máy lạnh...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tiêu đề sự cố'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết *',
                      hintText:
                          'Mô tả rõ tình trạng hỏng hóc để chủ trọ kịp thời xử lý...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập mô tả chi tiết'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: todayFormatted,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Ngày báo cáo',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final newIncident = Incident(
                roomNumber: _selectedRoom!,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                reportDate: todayFormatted,
                status: IncidentStatus.pending,
              );

              await IncidentDatabase.instance.insertIncident(newIncident);
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx, true);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );

    if (created == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã gửi báo cáo sự cố thành công! Chủ trọ sẽ sớm xử lý.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadIncidentsForSelectedRoom();
    }
  }

  void _showIncidentDetailDialog(Incident incident) {
    final statusColor = _getStatusColor(incident.status);
    final statusLabel = IncidentStatus.label(incident.status);
    final isResolved =
        incident.status == IncidentStatus.resolved ||
        incident.status == IncidentStatus.closed;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(
                _getStatusIcon(incident.status),
                size: 18,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Chi tiết sự cố & Tiến độ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thẻ thông báo trạng thái xử lý
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isResolved
                            ? Icons.check_circle_outline
                            : Icons.pending_actions_outlined,
                        color: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isResolved
                                  ? 'SỰ CỐ ĐÃ ĐƯỢC XỬ LÝ'
                                  : 'SỰ CỐ ĐANG TRONG TIẾN TRÌNH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'Trạng thái: $statusLabel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tiến trình từng bước (Status Stepper Indicator)
                _buildStatusProgressStepper(incident.status),
                const SizedBox(height: 16),

                // Thông tin sự cố
                _buildInfoTile(
                  'Phòng',
                  incident.roomNumber,
                  Icons.door_front_door,
                ),
                _buildInfoTile(
                  'Ngày báo cáo',
                  incident.reportDate,
                  Icons.calendar_today,
                ),
                _buildInfoTile('Tiêu đề', incident.title, Icons.title),
                const SizedBox(height: 6),
                const Text(
                  'Mô tả chi tiết:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    incident.description,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),

                // Phản hồi / Ghi chú từ chủ trọ (Quan trọng nhất cho Tenant)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: incident.resolutionNote.isNotEmpty
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: incident.resolutionNote.isNotEmpty
                          ? Colors.blue.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 18,
                            color: incident.resolutionNote.isNotEmpty
                                ? Colors.blue.shade800
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Phản hồi từ Chủ trọ / Thợ sửa:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: incident.resolutionNote.isNotEmpty
                                  ? Colors.blue.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        incident.resolutionNote.isNotEmpty
                            ? incident.resolutionNote
                            : 'Chủ trọ đã ghi nhận và đang sắp xếp lịch xử lý.',
                        style: TextStyle(
                          fontSize: 13,
                          color: incident.resolutionNote.isNotEmpty
                              ? Colors.black87
                              : Colors.grey.shade700,
                          fontStyle: incident.resolutionNote.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusProgressStepper(String currentStatus) {
    final steps = [
      {'key': IncidentStatus.pending, 'label': 'Đã gửi'},
      {'key': IncidentStatus.processing, 'label': 'Đang sửa'},
      {'key': IncidentStatus.resolved, 'label': 'Đã xử lý'},
      {'key': IncidentStatus.closed, 'label': 'Đã đóng'},
    ];

    int currentIndex = steps.indexWhere((s) => s['key'] == currentStatus);
    if (currentIndex < 0) currentIndex = 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepBefore = index ~/ 2;
            final isPassed = stepBefore < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isPassed ? Colors.teal : Colors.grey.shade300,
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex <= currentIndex;
          final isCurrent = stepIndex == currentIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.teal : Colors.white,
                  border: Border.all(
                    color: isCompleted ? Colors.teal : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex]['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Colors.teal.shade900
                      : Colors.grey.shade600,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredIncidents;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sự cố & Bảo trì',
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
            onPressed: _loadIncidentsForSelectedRoom,
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
        onPressed: _openCreateIncidentDialog,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Báo sự cố mới'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Đang ở Tab Sự cố & Bảo trì
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) {
          if (index == 0) {
            // Chuyển sang Tab Hóa đơn của tôi
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TenantInvoiceScreen(
                  roomNumber: _selectedRoom ?? widget.roomNumber,
                  tenantName: widget.tenantName,
                ),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Hóa đơn của tôi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle_outlined),
            activeIcon: Icon(Icons.build_circle),
            label: 'Sự cố & Báo hỏng',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Bộ chọn phòng ──
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
                                        room,
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
                                      _loadIncidentsForSelectedRoom();
                                    }
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Thẻ thống kê: Xem sự cố đã xử lý hay chưa ──
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
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
                      _buildStatColumn(
                        'Tổng sự cố',
                        _allRoomIncidents.length,
                        Colors.black87,
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      _buildStatColumn('Chưa xử lý', _pendingCount, Colors.red),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      _buildStatColumn(
                        'Đang xử lý',
                        _processingCount,
                        Colors.orange,
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      _buildStatColumn(
                        'Đã xử lý xong',
                        _resolvedCount,
                        Colors.green,
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
                            hintText: 'Tìm theo tiêu đề, mô tả...',
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
                                value: IncidentStatus.pending,
                                child: Text('Chưa xử lý'),
                              ),
                              DropdownMenuItem(
                                value: IncidentStatus.processing,
                                child: Text('Đang xử lý'),
                              ),
                              DropdownMenuItem(
                                value: IncidentStatus.resolved,
                                child: Text('Đã xử lý'),
                              ),
                              DropdownMenuItem(
                                value: IncidentStatus.closed,
                                child: Text('Đã đóng'),
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

                // ── Danh sách sự cố (ListView) ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadIncidentsForSelectedRoom,
                    child: filteredList.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 280,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 56,
                                        color: Colors.teal.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _allRoomIncidents.isEmpty
                                            ? 'Phòng $_selectedRoom chưa có sự cố nào được báo cáo'
                                            : 'Không tìm thấy sự cố phù hợp bộ lọc',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Nếu có hỏng hóc, hãy bấm "Báo sự cố mới" bên dưới.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: filteredList.length,
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 80,
                              top: 4,
                            ),
                            itemBuilder: (context, index) {
                              final incident = filteredList[index];
                              final statusColor = _getStatusColor(
                                incident.status,
                              );
                              final isResolved =
                                  incident.status == IncidentStatus.resolved ||
                                  incident.status == IncidentStatus.closed;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: statusColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      _showIncidentDetailDialog(incident),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header: Trạng thái & Ngày
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: statusColor
                                                  .withValues(alpha: 0.15),
                                              child: Icon(
                                                _getStatusIcon(incident.status),
                                                size: 16,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                IncidentStatus.label(
                                                  incident.status,
                                                ),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              incident.reportDate,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Tiêu đề sự cố
                                        Text(
                                          incident.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Mô tả tóm tắt
                                        Text(
                                          incident.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),

                                        // Ghi chú xử lý từ chủ trọ (nếu có)
                                        if (incident
                                            .resolutionNote
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: 15,
                                                  color: Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Chủ trọ phản hồi: ${incident.resolutionNote}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.blue.shade900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            isResolved
                                                ? '✓ Đã hoàn tất xử lý • Chạm để xem chi tiết'
                                                : '⏳ Đang chờ xử lý • Chạm để xem chi tiết',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isResolved
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
