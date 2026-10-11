import 'package:flutter/material.dart';

import '../database/account_database.dart';
import '../models/account.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all'; // 'all', 'landlord', 'tenant'
  String _filterStatus = 'all'; // 'all', 'active', 'blocked'

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final list = await AccountDatabase.instance.getAllAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Lỗi tải danh sách tài khoản: $e');
    }
  }

  List<Account> get _filteredAccounts {
    return _accounts.where((acc) {
      final matchesSearch =
          acc.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          acc.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          acc.phone.contains(_searchQuery);
      final matchesRole = _filterRole == 'all' || acc.role == _filterRole;
      final matchesStatus =
          _filterStatus == 'all' || acc.status == _filterStatus;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openAccountForm({Account? account}) async {
    final result = await showDialog<Account>(
      context: context,
      builder: (_) => AccountFormDialog(account: account),
    );
    if (result == null || !mounted) return;

    try {
      if (account == null) {
        await AccountDatabase.instance.insertAccount(result);
        _showMessage('Thêm tài khoản thành công!');
      } else {
        await AccountDatabase.instance.updateAccount(result);
        _showMessage('Cập nhật tài khoản thành công!');
      }
      await _loadAccounts();
    } catch (e) {
      _showMessage('Lưu tài khoản thất bại: Username có thể đã tồn tại.');
    }
  }

  Future<void> _toggleStatus(Account account) async {
    final newStatus = account.status == 'active' ? 'blocked' : 'active';
    final updated = account.copyWith(status: newStatus);
    await AccountDatabase.instance.updateAccount(updated);
    _showMessage(
      newStatus == 'blocked'
          ? 'Đã khóa tài khoản ${account.username}'
          : 'Đã mở khóa tài khoản ${account.username}',
    );
    await _loadAccounts();
  }

  Future<void> _resetPassword(Account account) async {
    final newPass = await showDialog<String>(
      context: context,
      builder: (_) => ResetPasswordDialog(username: account.username),
    );

    if (newPass == null || newPass.isEmpty || !mounted) return;

    final updated = account.copyWith(password: newPass);
    await AccountDatabase.instance.updateAccount(updated);
    _showMessage('Đã đổi mật khẩu cho ${account.username}');
    await _loadAccounts();
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: Text(
          'Bạn có chắc muốn xóa tài khoản "${account.username}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AccountDatabase.instance.deleteAccount(account.id!);
    _showMessage('Đã xóa tài khoản thành công');
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredAccounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý tài khoản',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAccountForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm tài khoản'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thong ke nhanh
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Tổng số',
                        '${_accounts.length}',
                        Colors.indigo,
                      ),
                      _buildStatCard(
                        'Chủ trọ',
                        '${_accounts.where((a) => a.role == 'landlord').length}',
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Người thuê',
                        '${_accounts.where((a) => a.role == 'tenant').length}',
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Bị khóa',
                        '${_accounts.where((a) => a.status == 'blocked').length}',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
                // search & filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên, username, SĐT...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filterRole,
                              decoration: const InputDecoration(
                                labelText: 'Vai trò',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Tất cả'),
                                ),
                                DropdownMenuItem(
                                  value: 'landlord',
                                  child: Text('Chủ trọ'),
                                ),
                                DropdownMenuItem(
                                  value: 'tenant',
                                  child: Text('Người thuê'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _filterRole = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filterStatus,
                              decoration: const InputDecoration(
                                labelText: 'Trạng thái',
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
                                  child: Text('Hoạt động'),
                                ),
                                DropdownMenuItem(
                                  value: 'blocked',
                                  child: Text('Bị khóa'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _filterStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // list
                Expanded(
                  child: filteredList.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy tài khoản nào'),
                        )
                      : ListView.builder(
                          itemCount: filteredList.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemBuilder: (context, index) {
                            final acc = filteredList[index];
                            final isLandlord = acc.role == 'landlord';
                            final isBlocked = acc.status == 'blocked';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isBlocked
                                      ? Colors.red.shade100
                                      : (isLandlord
                                            ? Colors.indigo.shade100
                                            : Colors.green.shade100),
                                  child: Icon(
                                    isLandlord
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    color: isBlocked
                                        ? Colors.red
                                        : (isLandlord
                                              ? Colors.indigo
                                              : Colors.green),
                                  ),
                                ),
                                title: Text(
                                  '${acc.fullName} (@${acc.username})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (acc.phone.isNotEmpty)
                                      Text('SĐT: ${acc.phone}'),
                                    if (acc.email.isNotEmpty)
                                      Text('Email: ${acc.email}'),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          labelPadding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            isLandlord
                                                ? 'Chủ trọ'
                                                : 'Người thuê',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Chip(
                                          labelPadding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isBlocked
                                              ? Colors.red.shade50
                                              : Colors.green.shade50,
                                          label: Text(
                                            isBlocked ? 'Bị khóa' : 'Hoạt động',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isBlocked
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _openAccountForm(account: acc);
                                    } else if (action == 'password') {
                                      _resetPassword(acc);
                                    } else if (action == 'toggle') {
                                      _toggleStatus(acc);
                                    } else if (action == 'delete') {
                                      _deleteAccount(acc);
                                    }
                                  },
                                  itemBuilder: (_) => [
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
                                      value: 'password',
                                      child: Row(
                                        children: [
                                          Icon(Icons.lock_reset),
                                          SizedBox(width: 8),
                                          Text('Đổi mật khẩu'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isBlocked
                                                ? Icons.lock_open
                                                : Icons.block,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isBlocked
                                                ? 'Mở khóa'
                                                : 'Khóa tài khoản',
                                          ),
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
                                            style: TextStyle(color: Colors.red),
                                          ),
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

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog add / edit acc
class AccountFormDialog extends StatefulWidget {
  final Account? account;

  const AccountFormDialog({super.key, this.account});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late String _role;
  late String _status;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _usernameController = TextEditingController(text: acc?.username ?? '');
    _passwordController = TextEditingController(text: acc?.password ?? '');
    _fullNameController = TextEditingController(text: acc?.fullName ?? '');
    _phoneController = TextEditingController(text: acc?.phone ?? '');
    _emailController = TextEditingController(text: acc?.email ?? '');
    _role = acc?.role ?? 'tenant';
    _status = acc?.status ?? 'active';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final acc = Account(
      id: widget.account?.id,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _fullNameController.text.trim(),
      role: _role,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      status: _status,
    );

    Navigator.pop(context, acc);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa thông tin tài khoản' : 'Thêm tài khoản mới'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  enabled: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập username'
                      : null,
                ),
                const SizedBox(height: 12),
                if (!isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vui lòng nhập mật khẩu'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'landlord', child: Text('Chủ trọ')),
                    DropdownMenuItem(
                      value: 'tenant',
                      child: Text('Người thuê'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Hoạt động')),
                    DropdownMenuItem(value: 'blocked', child: Text('Bị khóa')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
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
          child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo tài khoản'),
        ),
      ],
    );
  }
}

// Dialog change pass
class ResetPasswordDialog extends StatefulWidget {
  final String username;

  const ResetPasswordDialog({super.key, required this.username});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Đổi mật khẩu (@${widget.username})'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _passController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu mới',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Không được để trống' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _passController.text.trim());
            }
          },
          child: const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}
