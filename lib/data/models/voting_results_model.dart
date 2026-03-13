import 'package:equatable/equatable.dart';

class ParticipantResult extends Equatable {
  final String id;
  final String name;
  final int audiencePoints;
  final int judgeTotal;
  final int combinedScore;

  const ParticipantResult({
    required this.id,
    required this.name,
    required this.audiencePoints,
    required this.judgeTotal,
    required this.combinedScore,
  });

  factory ParticipantResult.fromJson(Map<String, dynamic> json) {
    return ParticipantResult(
      id: json['id'] as String,
      name: json['name'] as String,
      audiencePoints: json['audiencePoints'] as int,
      judgeTotal: json['judgeTotal'] as int,
      combinedScore: json['combinedScore'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'audiencePoints': audiencePoints,
      'judgeTotal': judgeTotal,
      'combinedScore': combinedScore,
    };
  }

  @override
  List<Object?> get props => [id, name, audiencePoints, judgeTotal, combinedScore];
}

class VotingResults extends Equatable {
  final List<ParticipantResult> rankings;
  final String? eliminatedParticipantId;
  final List<String> tiedParticipantIds;
  final String spreadsheetUrl;

  const VotingResults({
    required this.rankings,
    this.eliminatedParticipantId,
    this.tiedParticipantIds = const [],
    required this.spreadsheetUrl,
  });

  factory VotingResults.fromJson(Map<String, dynamic> json) {
    return VotingResults(
      rankings: (json['rankings'] as List<dynamic>)
          .map((r) => ParticipantResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      eliminatedParticipantId: json['eliminatedParticipantId'] as String?,
      tiedParticipantIds: (json['tiedParticipantIds'] as List<dynamic>?)
              ?.map((id) => id as String)
              .toList() ??
          const [],
      spreadsheetUrl: json['spreadsheetUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rankings': rankings.map((r) => r.toJson()).toList(),
      'eliminatedParticipantId': eliminatedParticipantId,
      'tiedParticipantIds': tiedParticipantIds,
      'spreadsheetUrl': spreadsheetUrl,
    };
  }

  bool get hasTie => tiedParticipantIds.isNotEmpty;

  ParticipantResult? get eliminatedParticipant {
    if (eliminatedParticipantId == null) return null;
    return rankings.where((r) => r.id == eliminatedParticipantId).firstOrNull;
  }

  List<ParticipantResult> get tiedParticipants {
    return rankings.where((r) => tiedParticipantIds.contains(r.id)).toList();
  }

  @override
  List<Object?> get props => [rankings, eliminatedParticipantId, tiedParticipantIds, spreadsheetUrl];
}
