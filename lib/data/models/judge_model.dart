import 'package:equatable/equatable.dart';

class JudgeModel extends Equatable {
  final String name;
  final int weight;

  const JudgeModel({
    required this.name,
    this.weight = 1,
  });

  factory JudgeModel.fromJson(Map<String, dynamic> json) {
    return JudgeModel(
      name: json['name'] as String,
      weight: (json['weight'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
    };
  }

  JudgeModel copyWith({String? name, int? weight}) {
    return JudgeModel(
      name: name ?? this.name,
      weight: weight ?? this.weight,
    );
  }

  @override
  List<Object?> get props => [name, weight];
}
