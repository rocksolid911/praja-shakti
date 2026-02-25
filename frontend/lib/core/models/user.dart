class User {
  final int id;
  final String phone;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final int? panchayatId;
  final String? panchayatName;
  final int? ward;
  final String languagePreference;

  User({
    required this.id, required this.phone, required this.username,
    required this.firstName, required this.lastName, required this.role,
    this.panchayatId, this.panchayatName, this.ward,
    this.languagePreference = 'hi',
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isLeader => role == 'leader' || role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'], phone: json['phone'] ?? '', username: json['username'] ?? '',
    firstName: json['first_name'] ?? '', lastName: json['last_name'] ?? '',
    role: json['role'] ?? 'citizen', panchayatId: json['panchayat'],
    panchayatName: json['panchayat_name'], ward: json['ward'],
    languagePreference: json['language_preference'] ?? 'hi',
  );
}
