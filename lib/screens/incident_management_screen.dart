import 'package:flutter/material.dart';

import '../database/incident_database.dart';
import '../models/incident.dart';

class IncidentManagementScreen extends StatefulWidget {
  const IncidentManagementScreen({super.key});

  @override
  State<IncidentManagementScreen> createState() =>
      _IncidentManagementScreenState();
}

class _IncidentManagementScreenState extends State<IncidentManagementScreen> {
  List<Incident> _incidents = [];
  bool _loading = true;

  String _keyword = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final list = await IncidentDatabase.instance.getAllIncidents();
      if (!mounted) return;
      setState(() {
        _incidents = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Không thể tải danh sách sự cố: $e');
    }
  }

  List<Incident> get _filteredIncidents {
    return _incidents.where((incident) {
      final matchesKeyword =
          incident.roomNumber.toLowerCase().contains(_keyword.toLowerCase()) ||
          incident.title.toLowerCase().contains(_keyword.toLowerCase()) ||
          incident.description.toLowerCase().contains(_keyword.toLowerCase());

      final matchesStatus =
          _filterStatus == 'all' || incident.status == _filterStatus;

      return matchesKeyword && matchesStatus;
    }).toList();
  }

  int get _pendingCount =>
      _incidents.where((i) => i.status == 'pending').length;
  int get _processingCount =>
      _incidents.where((i) => i.status == 'processing').length;
  int get _resolvedCount =>
      _incidents.where((i) => i.status == 'resolved').length;

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chưa xử lý';
      case 'processing':
        return 'Đang xử lý';
      case 'resolved':
        return 'Đã xử lý';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openIncidentForm({Incident? incident}) async {
    final result = await showDialog<Incident>(
      context: context,
      builder: (_) => IncidentFormDialog(incident: incident),
    );

    if (result == null || !mounted) return;

    try {
      if (incident == null) {
        await IncidentDatabase.instance.insertIncident(result);
        _showMessage('Gửi báo cáo sự cố thành công!');
      } else {
        await IncidentDatabase.instance.updateIncident(result);
        _showMessage('Cập nhật sự cố thành công!');
      }

      await _loadIncidents();
    } catch (e) {
      _showMessage('Không thể lưu sự cố: $e');
    }
  }

  Future<void> _openResolveDialog(Incident incident) async {
    final result = await showDialog<Incident>(
      context: context,
      builder: (_) => ResolveIncidentDialog(incident: incident),
    );

    if (result == null || !mounted) return;

    try {
      await IncidentDatabase.instance.updateIncident(result);
      _showMessage('Cập nhật trạng thái xử lý sự cố thành công!');
      await _loadIncidents();
    } catch (e) {
      _showMessage('Không thể cập nhật xử lý: $e');
    }
  }

  Future<void> _deleteIncident(Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa báo cáo sự cố'),
        content: Text(
          'Bạn có chắc muốn xóa sự cố "${incident.title}" của ${incident.roomNumber} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await IncidentDatabase.instance.deleteIncident(incident.id!);
      _showMessage('Đã xóa báo cáo sự cố');
      await _loadIncidents();
    } catch (e) {
      _showMessage('Không thể xóa sự cố: $e');
    }
  }

  Widget _buildStat(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidents = _filteredIncidents;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Sự cố & Bảo trì',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openIncidentForm(),
        icon: const Icon(Icons.add_alert),
        label: const Text('Báo cáo sự cố'),
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
                            'Tổng số',
                            _incidents.length,
                            Icons.report_problem,
                            Colors.indigo,
                          ),
                          _buildStat(
                            'Chưa xử lý',
                            _pendingCount,
                            Icons.pending_actions,
                            Colors.red,
                          ),
                          _buildStat(
                            'Đang xử lý',
                            _processingCount,
                            Icons.autorefresh,
                            Colors.orange,
                          ),
                          _buildStat(
                            'Đã xử lý',
                            _resolvedCount,
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm theo phòng, tiêu đề sự cố...',
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
                          labelText: 'Lọc trạng thái xử lý',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả sự cố'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Chưa xử lý'),
                          ),
                          DropdownMenuItem(
                            value: 'processing',
                            child: Text('Đang xử lý'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('Đã xử lý'),
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
                  child: incidents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _incidents.isEmpty
                                    ? 'Chưa có sự cố nào được báo cáo'
                                    : 'Không tìm thấy sự cố phù hợp',
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: incidents.length,
                          itemBuilder: (context, index) {
                            final item = incidents[index];
                            final color = _statusColor(item.status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: color.withValues(
                                                alpha: 0.15,
                                              ),
                                              child: Icon(
                                                Icons.build,
                                                size: 16,
                                                color: color,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              item.roomNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _statusLabel(item.status),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Báo cáo: ${item.reportDate}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.resolutionNote.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.blue.withValues(
                                                alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Ghi chú xử lý của Chủ trọ:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.resolutionNote,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _openResolveDialog(item),
                                          icon: const Icon(
                                              Icons.admin_panel_settings,
                                              size: 16),
                                          label: const Text(
                                              'Cập nhật xử lý (Chủ trọ)'),
                                        ),
                                        IconButton(
                                          tooltip: 'Sửa',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20),
                                          onPressed: () =>
                                              _openIncidentForm(incident: item),
                                        ),
                                        IconButton(
                                          tooltip: 'Xóa',
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteIncident(item),
                                        ),
                                      ],
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

// Dialog báo cáo sự cố mới
class IncidentFormDialog extends StatefulWidget {
  final Incident? incident;

  const IncidentFormDialog({super.key, this.incident});

  @override
  State<IncidentFormDialog> createState() => _IncidentFormDialogState();
}

class _IncidentFormDialogState extends State<IncidentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _roomController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _dateController;

  late String _status;

  @override
  void initState() {
    super.initState();
    final inc = widget.incident;
    _roomController = TextEditingController(text: inc?.roomNumber ?? 'P101');
    _titleController = TextEditingController(text: inc?.title ?? '');
    _descController = TextEditingController(text: inc?.description ?? '');
    _dateController = TextEditingController(
      text: inc?.reportDate ?? '14/10/2026',
    );
    _status = inc?.status ?? 'pending';
  }

  @override
  void dispose() {
    _roomController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final incident = Incident(
      id: widget.incident?.id,
      roomNumber: _roomController.text.trim(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      reportDate: _dateController.text.trim(),
      status: _status,
      resolutionNote: widget.incident?.resolutionNote ?? '',
    );

    Navigator.pop(context, incident);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.incident != null;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa báo cáo sự cố' : 'Báo cáo sự cố mới'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng *',
                    hintText: 'VD: P101',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề sự cố *',
                    hintText: 'VD: Hỏng vòi nước, chập điện...',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Chi tiết sự cố *',
                    hintText: 'Mô tả cụ thể tình trạng hỏng hóc...',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Ngày báo cáo *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
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
                      value: 'pending',
                      child: Text('Chưa xử lý'),
                    ),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('Đang xử lý'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Đã xử lý'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
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
          child: Text(isEditing ? 'Lưu' : 'Gửi báo cáo'),
        ),
      ],
    );
  }
}

// Dialog cập nhật trạng thái & ghi chú xử lý của Chủ trọ
class ResolveIncidentDialog extends StatefulWidget {
  final Incident incident;

  const ResolveIncidentDialog({super.key, required this.incident});

  @override
  State<ResolveIncidentDialog> createState() => _ResolveIncidentDialogState();
}

class _ResolveIncidentDialogState extends State<ResolveIncidentDialog> {
  late String _status;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _status = widget.incident.status;
    _noteController = TextEditingController(
      text: widget.incident.resolutionNote,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.incident.copyWith(
      status: _status,
      resolutionNote: _noteController.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cập nhật xử lý sự cố (${widget.incident.roomNumber})'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sự cố: ${widget.incident.title}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Chi tiết: ${widget.incident.description}'),
              const Divider(height: 20),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái xử lý *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Chưa xử lý (Pending)'),
                  ),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('Đang xử lý (Processing)'),
                  ),
                  DropdownMenuItem(
                    value: 'resolved',
                    child: Text('Đã xử lý (Resolved)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú / Kết quả xử lý của chủ trọ',
                  hintText: 'Ví dụ: Đã thay mới linh kiện lúc 14h ngày...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
          child: const Text('Lưu cập nhật'),
        ),
      ],
    );
  }
}
