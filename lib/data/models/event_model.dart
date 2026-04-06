import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:cast_your_vote/data/models/judge_model.dart';
import 'package:cast_your_vote/data/models/participant_model.dart';
import 'package:cast_your_vote/data/models/round_model.dart';
import 'package:cast_your_vote/data/models/voting_results_model.dart';

enum EventStatus { open, closed }

class EventModel extends Equatable {
  final String id;
  final String name;
  final List<ParticipantModel> participants;
  final List<JudgeModel> judges;
  final EventStatus status;
  final DateTime createdAt;
  final String? largestDonationWinnerId;
  final String? mostDonationsWinnerId;
  final String? spreadsheetUrl;
  final String? logoUrl;
  final VotingResults? votingResults;
  final List<RoundModel> rounds;

  const EventModel({
    required this.id,
    required this.name,
    required this.participants,
    this.judges = const <JudgeModel>[],
    required this.status,
    required this.createdAt,
    this.largestDonationWinnerId,
    this.mostDonationsWinnerId,
    this.spreadsheetUrl,
    this.logoUrl,
    this.votingResults,
    this.rounds = const <RoundModel>[],
  });

  factory EventModel.fromJson(Map<String, dynamic> json, String id) {
    final votingResultsJson = json['votingResults'] as Map<String, dynamic>?;

    return EventModel(
      id: id,
      name: json['name'] as String,
      participants: (json['participants'] as List<dynamic>)
              .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>))
              .toList(),
      judges: (json['judges'] as List<dynamic>?)
              ?.map((j) => JudgeModel.fromJson(j as Map<String, dynamic>))
              .toList() ?? const <JudgeModel>[],
      status: EventStatus.values.byName(json['status'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      largestDonationWinnerId: json['largestDonationWinnerId'] as String?,
      mostDonationsWinnerId: json['mostDonationsWinnerId'] as String?,
      spreadsheetUrl: json['spreadsheetUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
      votingResults: votingResultsJson != null
          ? VotingResults.fromJson(votingResultsJson)
          : null,
      rounds: [
        for (final r in (json['rounds'] as List<dynamic>?) ?? [])
          RoundModel.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'participants': participants.map((p) => p.toJson()).toList(),
      'judges': judges.map((j) => j.toJson()).toList(),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'largestDonationWinnerId': largestDonationWinnerId,
      'mostDonationsWinnerId': mostDonationsWinnerId,
      'spreadsheetUrl': spreadsheetUrl,
      'logoUrl': logoUrl,
      'votingResults': votingResults?.toJson(),
      'rounds': rounds.map((r) => r.toJson()).toList(),
    };
  }

  int get participantCount => participants.length;

  bool get isVotingOpen => status == EventStatus.open;

  bool get isMultiRound => rounds.length > 1;

  EventModel copyWith({
    String? id,
    String? name,
    List<ParticipantModel>? participants,
    List<JudgeModel>? judges,
    EventStatus? status,
    DateTime? createdAt,
    String? largestDonationWinnerId,
    String? mostDonationsWinnerId,
    String? spreadsheetUrl,
    String? logoUrl,
    VotingResults? votingResults,
    List<RoundModel>? rounds,
    bool clearLargestDonationWinner = false,
    bool clearMostDonationsWinner = false,
    bool clearVotingResults = false,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      judges: judges ?? this.judges,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      largestDonationWinnerId: clearLargestDonationWinner
          ? null
          : (largestDonationWinnerId ?? this.largestDonationWinnerId),
      mostDonationsWinnerId: clearMostDonationsWinner
          ? null
          : (mostDonationsWinnerId ?? this.mostDonationsWinnerId),
      spreadsheetUrl: spreadsheetUrl ?? this.spreadsheetUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      votingResults: clearVotingResults
          ? null
          : (votingResults ?? this.votingResults),
      rounds: rounds ?? this.rounds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        participants,
        judges,
        status,
        createdAt,
        largestDonationWinnerId,
        mostDonationsWinnerId,
        spreadsheetUrl,
        logoUrl,
        votingResults,
        rounds,
      ];
}
