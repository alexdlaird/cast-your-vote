import 'package:equatable/equatable.dart';

class JudgeModel extends Equatable {
  final String id;
  final String name;
  final int weight;

  const JudgeModel({
    this.id = '',
    required this.name,
    this.weight = 5,
  });

  factory JudgeModel.fromJson(Map<String, dynamic> json) {
    return JudgeModel(
      // Backwards compat: old records have no 'id', fall back to name as stable key.
      id: json['id'] as String? ?? json['name'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as int?) ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
    };
  }

  JudgeModel copyWith({String? id, String? name, int? weight}) {
    return JudgeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
    );
  }

  @override
  List<Object?> get props => [id, name, weight];
}
