// Copyright (c) 2024 Cast Your Vote. MIT License.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum BallotType { audience, judge }

class JudgeVote extends Equatable {
  final int singing;
  final int performance;
  final int songFit;
  final String singingComments;
  final String performanceComments;
  final String songFitComments;

  const JudgeVote({
    required this.singing,
    required this.performance,
    required this.songFit,
    this.singingComments = '',
    this.performanceComments = '',
    this.songFitComments = '',
  });

  factory JudgeVote.fromJson(Map<String, dynamic> json) {
    return JudgeVote(
      singing: json['singing'] as int,
      performance: json['performance'] as int,
      songFit: json['songFit'] as int,
      singingComments: json['singingComments'] as String? ?? '',
      performanceComments: json['performanceComments'] as String? ?? '',
      songFitComments: json['songFitComments'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'singing': singing,
      'performance': performance,
      'songFit': songFit,
      'singingComments': singingComments,
      'performanceComments': performanceComments,
      'songFitComments': songFitComments,
    };
  }

  JudgeVote copyWith({
    int? singing,
    int? performance,
    int? songFit,
    String? singingComments,
    String? performanceComments,
    String? songFitComments,
  }) {
    return JudgeVote(
      singing: singing ?? this.singing,
      performance: performance ?? this.performance,
      songFit: songFit ?? this.songFit,
      singingComments: singingComments ?? this.singingComments,
      performanceComments: performanceComments ?? this.performanceComments,
      songFitComments: songFitComments ?? this.songFitComments,
    );
  }

  @override
  List<Object?> get props => [
        singing,
        performance,
        songFit,
        singingComments,
        performanceComments,
        songFitComments,
      ];
}

/// Votes are keyed by round ID then participant ID.
/// e.g. audienceVotes['r1']['p1'] = 2
class BallotModel extends Equatable {
  final String code;
  final BallotType type;
  final String eventId;
  final bool submitted;
  final Map<String, Map<String, int>> audienceVotes;
  final Map<String, Map<String, JudgeVote>> judgeVotes;
  final int currentRoundIndex;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? judgeId;
  final String? judgeName;
  final int judgeWeight;

  const BallotModel({
    required this.code,
    required this.type,
    required this.eventId,
    required this.submitted,
    this.audienceVotes = const {},
    this.judgeVotes = const {},
    this.currentRoundIndex = 0,
    required this.createdAt,
    this.submittedAt,
    this.judgeId,
    this.judgeName,
    this.judgeWeight = 1,
  });

  factory BallotModel.fromJson(Map<String, dynamic> json, String code) {
    final type = BallotType.values.byName(json['type'] as String);
    return BallotModel(
      code: code,
      type: type,
      eventId: json['eventId'] as String,
      submitted: json['submitted'] as bool,
      audienceVotes: (json['audienceVotes'] as Map<String, dynamic>).map(
        (roundId, votes) => MapEntry(
          roundId,
          (votes as Map<String, dynamic>).map(
            (participantId, rank) => MapEntry(participantId, rank as int),
          ),
        ),
      ),
      judgeVotes: (json['judgeVotes'] as Map<String, dynamic>).map(
        (roundId, votes) => MapEntry(
          roundId,
          (votes as Map<String, dynamic>).map(
            (participantId, vote) => MapEntry(
              participantId,
              JudgeVote.fromJson(vote as Map<String, dynamic>),
            ),
          ),
        ),
      ),
      currentRoundIndex: (json['currentRoundIndex'] as int?) ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      submittedAt: json['submittedAt'] != null
          ? (json['submittedAt'] as Timestamp).toDate()
          : null,
      judgeId: json['judgeId'] as String?,
      judgeName: json['judgeName'] as String?,
      judgeWeight: (json['judgeWeight'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'eventId': eventId,
      'submitted': submitted,
      'audienceVotes': audienceVotes.map(
        (roundId, votes) => MapEntry(roundId, votes),
      ),
      'judgeVotes': judgeVotes.map(
        (roundId, votes) => MapEntry(
          roundId,
          votes.map((participantId, vote) => MapEntry(participantId, vote.toJson())),
        ),
      ),
      'currentRoundIndex': currentRoundIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'judgeId': judgeId,
      'judgeName': judgeName,
      'judgeWeight': judgeWeight,
    };
  }

  Map<String, int> audienceVotesForRound(String roundId) {
    return audienceVotes[roundId] ?? {};
  }

  Map<String, JudgeVote> judgeVotesForRound(String roundId) {
    return judgeVotes[roundId] ?? {};
  }

  bool isRoundLocked(int roundIndex) => roundIndex < currentRoundIndex;

  bool get isAudience => type == BallotType.audience;
  bool get isJudge => type == BallotType.judge;

  BallotModel copyWith({
    String? code,
    BallotType? type,
    String? eventId,
    bool? submitted,
    Map<String, Map<String, int>>? audienceVotes,
    Map<String, Map<String, JudgeVote>>? judgeVotes,
    int? currentRoundIndex,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? judgeId,
    String? judgeName,
    int? judgeWeight,
  }) {
    return BallotModel(
      code: code ?? this.code,
      type: type ?? this.type,
      eventId: eventId ?? this.eventId,
      submitted: submitted ?? this.submitted,
      audienceVotes: audienceVotes ?? this.audienceVotes,
      judgeVotes: judgeVotes ?? this.judgeVotes,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      judgeId: judgeId ?? this.judgeId,
      judgeName: judgeName ?? this.judgeName,
      judgeWeight: judgeWeight ?? this.judgeWeight,
    );
  }

  @override
  List<Object?> get props => [
        code,
        type,
        eventId,
        submitted,
        audienceVotes,
        judgeVotes,
        currentRoundIndex,
        createdAt,
        submittedAt,
        judgeId,
        judgeName,
        judgeWeight,
      ];
}
