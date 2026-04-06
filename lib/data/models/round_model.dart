// Copyright (c) 2024 Cast Your Vote. MIT License.

import 'package:equatable/equatable.dart';
import 'package:cast_your_vote/data/models/entry_model.dart';

class RoundModel extends Equatable {
  final String id;
  final int order;
  final List<EntryModel> entries;

  const RoundModel({
    required this.id,
    required this.order,
    required this.entries,
  });

  factory RoundModel.fromJson(Map<String, dynamic> json) {
    return RoundModel(
      id: json['id'] as String,
      order: json['order'] as int,
      entries: (json['entries'] as List<dynamic>)
          .map((e) => EntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  EntryModel? entryForParticipant(String participantId) {
    return entries.cast<EntryModel?>().firstWhere(
          (e) => e?.participantId == participantId,
          orElse: () => null,
        );
  }

  RoundModel copyWith({
    String? id,
    int? order,
    List<EntryModel>? entries,
  }) {
    return RoundModel(
      id: id ?? this.id,
      order: order ?? this.order,
      entries: entries ?? this.entries,
    );
  }

  @override
  List<Object?> get props => [id, order, entries];
}
