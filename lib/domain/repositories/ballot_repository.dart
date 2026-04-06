import 'package:cast_your_vote/data/models/models.dart';

abstract class BallotRepository {
  Future<BallotModel?> getBallot(String code);
  Future<void> createBallots({
    required String eventId,
    required int audienceCount,
    required List<JudgeModel> judges,
  });
  Future<List<BallotModel>> createBallotsAndReturn({
    required String eventId,
    required int audienceCount,
    required List<JudgeModel> judges,
  });
  Future<void> updateBallot(BallotModel ballot);
  Future<void> submitBallot(String code);
  Future<List<BallotModel>> getEventBallots(String eventId);
  Future<List<BallotModel>> getSubmittedBallots(String eventId);
  Future<void> deleteBallot(String code);
  Future<void> deleteEventBallots(String eventId);
  Future<void> clearParticipantVotes(
    String eventId,
    String participantId,
    List<String> roundIds,
  );
  Stream<BallotModel?> watchBallot(String code);
  Stream<List<BallotModel>> watchEventBallots(String eventId);
}
