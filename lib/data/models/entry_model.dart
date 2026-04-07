// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:equatable/equatable.dart';

class EntryModel extends Equatable {
  final String participantId;
  final String title;

  const EntryModel({
    required this.participantId,
    required this.title,
  });

  factory EntryModel.fromJson(Map<String, dynamic> json) {
    return EntryModel(
      participantId: json['participantId'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'title': title,
    };
  }

  EntryModel copyWith({String? participantId, String? title}) {
    return EntryModel(
      participantId: participantId ?? this.participantId,
      title: title ?? this.title,
    );
  }

  @override
  List<Object?> get props => [participantId, title];
}
