import 'package:equatable/equatable.dart';

class ParticipantModel extends Equatable {
  final String id;
  final String name;
  final int order;
  final bool hasDonation;
  final bool droppedOut;

  const ParticipantModel({
    required this.id,
    required this.name,
    required this.order,
    this.hasDonation = false,
    this.droppedOut = false,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      order: json['order'] as int,
      hasDonation: (json['hasDonation'] as bool?) ?? false,
      droppedOut: (json['droppedOut'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'hasDonation': hasDonation,
      'droppedOut': droppedOut,
    };
  }

  String get displayName => name;

  ParticipantModel copyWith({
    String? id,
    String? name,
    int? order,
    bool? hasDonation,
    bool? droppedOut,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      hasDonation: hasDonation ?? this.hasDonation,
      droppedOut: droppedOut ?? this.droppedOut,
    );
  }

  @override
  List<Object?> get props => [id, name, order, hasDonation, droppedOut];
}
