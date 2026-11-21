import 'department.dart';

/// Membre du club tel que renvoyé par l'API.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.position,
    required this.positionLabel,
    required this.status,
    this.department,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;

  /// president | vice_president | responsable | membre
  final String position;
  final String positionLabel;
  final String status;
  final Department? department;

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  bool get isPresidency => position == 'president' || position == 'vice_president';

  /// Peut valider des inscriptions (présidence ou responsable).
  bool get canApprove => isPresidency || position == 'responsable';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String,
        position: json['position'] as String,
        positionLabel: json['position_label'] as String? ?? json['position'] as String,
        status: json['status'] as String? ?? 'active',
        department: json['department'] is Map<String, dynamic>
            ? Department.fromJson(json['department'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'position': position,
        'position_label': positionLabel,
        'status': status,
        'department': department?.toJson(),
      };
}
