// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:equatable/equatable.dart';

class JudgeCategoryModel extends Equatable {
  final String id;
  final String name;
  final int order;

  const JudgeCategoryModel({
    required this.id,
    required this.name,
    required this.order,
  });

  factory JudgeCategoryModel.fromJson(Map<String, dynamic> json) {
    return JudgeCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  JudgeCategoryModel copyWith({String? id, String? name, int? order}) {
    return JudgeCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [id, name, order];
}
