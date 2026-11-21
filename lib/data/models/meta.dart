import 'department.dart';

/// Option d'une liste déroulante (poste, urgence).
class Option {
  const Option(this.value, this.label);
  final String value;
  final String label;

  factory Option.fromJson(Map<String, dynamic> json) => Option(json['value'] as String, json['label'] as String);
}

/// Référentiel renvoyé par GET /meta.
class Meta {
  const Meta({required this.departments, required this.positions, required this.urgencies});

  final List<Department> departments;

  /// Postes autorisés par identifiant de département.
  final Map<int, List<Option>> positions;
  final List<Option> urgencies;

  factory Meta.fromJson(Map<String, dynamic> json) {
    final rawPositions = (json['positions'] as Map?) ?? {};
    return Meta(
      departments: (json['departments'] as List)
          .map((e) => Department.fromJson(e as Map<String, dynamic>))
          .toList(),
      positions: rawPositions.map((key, value) => MapEntry(
            int.parse(key.toString()),
            (value as List).map((e) => Option.fromJson(e as Map<String, dynamic>)).toList(),
          )),
      urgencies: (json['urgencies'] as List).map((e) => Option.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
