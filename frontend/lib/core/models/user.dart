class User {
  final int id;
  final String phone;
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final int? panchayatId;
  final String? panchayatName;
  final int? villageId;
  final String? villageName;
  final int? ward;
  final String languagePreference;
  final bool isAnonymousUser;

  User({
    required this.id, required this.phone, required this.username,
    required this.firstName, required this.lastName, required this.role,
    this.panchayatId, this.panchayatName, this.villageId, this.villageName,
    this.ward, this.languagePreference = 'hi', this.isAnonymousUser = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isCitizen => role == 'citizen';
  bool get isLeader => role == 'leader';
  bool get isGovernment => role == 'government' || role == 'admin';
  bool get hasFullAccess => isLeader || isGovernment;
  bool get isAnonymous => isAnonymousUser;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'], phone: json['phone'] ?? '', username: json['username'] ?? '',
    firstName: json['first_name'] ?? '', lastName: json['last_name'] ?? '',
    role: json['role'] ?? 'citizen', panchayatId: json['panchayat'],
    panchayatName: json['panchayat_name'],
    villageId: json['village_id'], villageName: json['village_name'],
    ward: json['ward'], languagePreference: json['language_preference'] ?? 'hi',
    isAnonymousUser: json['is_anonymous_user'] ?? false,
  );
}
