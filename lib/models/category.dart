class Category {
  final int id;
  final String name;
  final int position;

  const Category({required this.id, required this.name, required this.position});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        position: (json['position'] as num?)?.toInt() ?? 0,
      );

  Category copyWith({String? name, int? position}) => Category(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
      );

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.name == name && other.position == position;

  @override
  int get hashCode => Object.hash(id, name, position);

  @override
  String toString() => 'Category($id, $name, $position)';
}
