class Account {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String role;
  final String phone;
  final String email;
  final String status;

  const Account({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.email = '',
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'email': email,
      'status': status,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
    );
  }

  Account copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? role,
    String? phone,
    String? email,
    String? status,
  }) {
    return Account(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
    );
  }
}
