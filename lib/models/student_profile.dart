/// Own-account data only. Construct from the server-validated /me endpoint.
/// No Student ID is ever accepted as a lookup parameter.
class StudentProfile {
  const StudentProfile({
    required this.studentName,
    required this.department,
    required this.role,
    required this.accountStatus,
    required this.verificationStatus,
    this.studentId,
    this.verifiedEmail,
    this.profileId,
    this.avatarVersion,
    this.verificationExpiresAt,
  });

  final String studentName;
  final String? studentId;
  final String? department;
  final String role;
  final String accountStatus;
  final String verificationStatus;
  final String? verifiedEmail;
  final String? profileId;
  final String? avatarVersion;
  final DateTime? verificationExpiresAt;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final name = json['student_name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid student profile.');
    }
    return StudentProfile(
      studentName: name,
      studentId: json['student_id'] is String ? json['student_id'] as String : null,
      department: json['department'] is String ? json['department'] as String : null,
      verifiedEmail: json['verified_email'] is String
          ? json['verified_email'] as String : null,
      profileId: json['profile_id'] is String ? json['profile_id'] as String : null,
      avatarVersion: json['avatar_version'] is String ? json['avatar_version'] as String : null,
      verificationExpiresAt: json['verification_expires_at'] is String
          ? DateTime.tryParse(json['verification_expires_at'] as String)?.toLocal()
          : null,
      role: json['role'] is String ? json['role'] as String : 'student',
      accountStatus: json['account_status'] is String
          ? json['account_status'] as String : 'unknown',
      verificationStatus: json['verification_status'] is String
          ? json['verification_status'] as String : 'unknown',
    );
  }
}
