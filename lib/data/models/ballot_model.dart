import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum BallotType { audience, judge }

class JudgeVote extends Equatable {
  final int singing;
  final int performance;
  final int audienceParticipation;

  const JudgeVote({
    required this.singing,
    required this.performance,
    required this.audienceParticipation,
  });

  factory JudgeVote.fromJson(Map<String, dynamic> json) {
    return JudgeVote(
      singing: json['singing'] as int? ?? 0,
      performance: json['performance'] as int? ?? 0,
      audienceParticipation: json['audienceParticipation'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'singing': singing,
      'performance': performance,
      'audienceParticipation': audienceParticipation,
    };
  }

  JudgeVote copyWith({
    int? singing,
    int? performance,
    int? audienceParticipation,
  }) {
    return JudgeVote(
      singing: singing ?? this.singing,
      performance: performance ?? this.performance,
      audienceParticipation:
          audienceParticipation ?? this.audienceParticipation,
    );
  }

  @override
  List<Object?> get props => [singing, performance, audienceParticipation];
}

class BallotModel extends Equatable {
  final String code;
  final BallotType type;
  final String eventId;
  final bool submitted;
  final Map<String, int> audienceVotes;
  final Map<String, JudgeVote> judgeVotes;
  final DateTime createdAt;
  final DateTime? submittedAt;

  const BallotModel({
    required this.code,
    required this.type,
    required this.eventId,
    required this.submitted,
    this.audienceVotes = const {},
    this.judgeVotes = const {},
    required this.createdAt,
    this.submittedAt,
  });

  factory BallotModel.fromJson(Map<String, dynamic> json, String code) {
    final type = BallotType.values.byName(json['type'] as String);
    return BallotModel(
      code: code,
      type: type,
      eventId: json['eventId'] as String,
      submitted: json['submitted'] as bool,
      audienceVotes: (json['audienceVotes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      judgeVotes: (json['judgeVotes'] as Map<String, dynamic>?)?.map((k, v) =>
              MapEntry(k, JudgeVote.fromJson(v as Map<String, dynamic>))) ??
          {},
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      submittedAt: json['submittedAt'] != null
          ? (json['submittedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'eventId': eventId,
      'submitted': submitted,
      'audienceVotes': audienceVotes,
      'judgeVotes': judgeVotes.map((k, v) => MapEntry(k, v.toJson())),
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
    };
  }

  bool get isAudience => type == BallotType.audience;
  bool get isJudge => type == BallotType.judge;

  BallotModel copyWith({
    String? code,
    BallotType? type,
    String? eventId,
    bool? submitted,
    Map<String, int>? audienceVotes,
    Map<String, JudgeVote>? judgeVotes,
    DateTime? createdAt,
    DateTime? submittedAt,
  }) {
    return BallotModel(
      code: code ?? this.code,
      type: type ?? this.type,
      eventId: eventId ?? this.eventId,
      submitted: submitted ?? this.submitted,
      audienceVotes: audienceVotes ?? this.audienceVotes,
      judgeVotes: judgeVotes ?? this.judgeVotes,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
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
        createdAt,
        submittedAt,
      ];
}
