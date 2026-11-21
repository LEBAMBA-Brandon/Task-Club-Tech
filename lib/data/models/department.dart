/// Département du club.
class Department {
  const Department({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory Department.fromJson(Map<String, dynamic> json) =>
      Department(id: json['id'] as int, name: json['name'] as String, slug: json['slug'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  @override
  bool operator ==(Object other) => other is Department && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
