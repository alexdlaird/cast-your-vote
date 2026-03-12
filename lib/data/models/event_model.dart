import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:theatre_121/data/models/participant_model.dart';

enum EventStatus { open, closed }

class EventModel extends Equatable {
  final String id;
  final String name;
  final List<ParticipantModel> participants;
  final EventStatus status;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.name,
    required this.participants,
    required this.status,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json, String id) {
    return EventModel(
      id: id,
      name: json['name'] as String,
      participants: (json['participants'] as List<dynamic>)
              .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>))
              .toList(),
      status: EventStatus.values.byName(json['status'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'participants': participants.map((p) => p.toJson()).toList(),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int get participantCount => participants.length;

  bool get isVotingOpen => status == EventStatus.open;

  EventModel copyWith({
    String? id,
    String? name,
    List<ParticipantModel>? participants,
    EventStatus? status,
    DateTime? createdAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, participants, status, createdAt];
}
