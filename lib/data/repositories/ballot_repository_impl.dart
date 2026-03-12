import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:theatre_121/domain/repositories/ballot_repository.dart';
import 'package:theatre_121/data/models/models.dart';

class BallotRepositoryImpl implements BallotRepository {
  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  BallotRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ballotsCollection =>
      _firestore.collection('ballots');

  static const _alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  String _generateCode() {
    return List.generate(
      6,
      (_) => _alphanumeric[_random.nextInt(_alphanumeric.length)],
    ).join();
  }

  /// Generate multiple unique codes in parallel.
  /// Uses batch reads and local deduplication for efficiency.
  Future<List<String>> _generateUniqueCodes(int count) async {
    final uniqueCodes = <String>{};

    while (uniqueCodes.length < count) {
      final needed = count - uniqueCodes.length;
      // Generate more candidates than needed to account for potential collisions
      final candidates = <String>{};
      while (candidates.length < needed + 10) {
        candidates.add(_generateCode());
      }

      // Remove any that are already in our set
      candidates.removeAll(uniqueCodes);

      // Check existence in parallel
      final checkFutures = candidates.map((code) async {
        final results = await Future.wait([
          _ballotsCollection.doc(code).get(),
          _ballotsCollection.doc('J-$code').get(),
        ]);
        final exists = results[0].exists || results[1].exists;
        return exists ? null : code;
      });

      final results = await Future.wait(checkFutures);
      for (final code in results) {
        if (code != null && uniqueCodes.length < count) {
          uniqueCodes.add(code);
        }
      }
    }

    return uniqueCodes.toList();
  }

  @override
  Future<BallotModel?> getBallot(String code) async {
    final doc = await _ballotsCollection.doc(code).get();
    if (!doc.exists) return null;
    return BallotModel.fromJson(doc.data()!, code);
  }

  @override
  Future<void> createBallots({
    required String eventId,
    required int audienceCount,
    required int judgeCount,
  }) async {
    await createBallotsAndReturn(
      eventId: eventId,
      audienceCount: audienceCount,
      judgeCount: judgeCount,
    );
  }

  @override
  Future<List<BallotModel>> createBallotsAndReturn({
    required String eventId,
    required int audienceCount,
    required int judgeCount,
  }) async {
    final now = DateTime.now();

    // Generate all codes in parallel
    final allCodes = await _generateUniqueCodes(audienceCount + judgeCount);
    final audienceCodes = allCodes.sublist(0, audienceCount);
    final judgeCodes = allCodes.sublist(audienceCount);

    // Create ballot models
    final allBallots = <BallotModel>[];

    for (final code in audienceCodes) {
      allBallots.add(BallotModel(
        code: code,
        type: BallotType.audience,
        eventId: eventId,
        submitted: false,
        createdAt: now,
      ));
    }

    for (final baseCode in judgeCodes) {
      final code = 'J-$baseCode';
      allBallots.add(BallotModel(
        code: code,
        type: BallotType.judge,
        eventId: eventId,
        submitted: false,
        createdAt: now,
      ));
    }

    // Batch writes so we don't go over Firestore's limits
    for (var i = 0; i < allBallots.length; i += 500) {
      final batch = _firestore.batch();
      final end = (i + 500 < allBallots.length) ? i + 500 : allBallots.length;
      for (var j = i; j < end; j++) {
        final ballot = allBallots[j];
        batch.set(_ballotsCollection.doc(ballot.code), ballot.toJson());
      }
      await batch.commit();
    }

    return allBallots;
  }

  @override
  Future<void> updateBallot(BallotModel ballot) async {
    await _ballotsCollection.doc(ballot.code).update(ballot.toJson());
  }

  @override
  Future<void> submitBallot(String code) async {
    await _ballotsCollection.doc(code).update({
      'submitted': true,
      'submittedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<List<BallotModel>> getEventBallots(String eventId) async {
    final snapshot = await _ballotsCollection
        .where('eventId', isEqualTo: eventId)
        .get();

    return snapshot.docs
        .map((doc) => BallotModel.fromJson(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  @override
  Future<List<BallotModel>> getSubmittedBallots(String eventId) async {
    final snapshot = await _ballotsCollection
        .where('eventId', isEqualTo: eventId)
        .where('submitted', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => BallotModel.fromJson(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  @override
  Future<void> deleteEventBallots(String eventId) async {
    final snapshot = await _ballotsCollection
        .where('eventId', isEqualTo: eventId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<BallotModel?> watchBallot(String code) {
    return _ballotsCollection.doc(code).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BallotModel.fromJson(doc.data()!, code);
    });
  }

  @override
  Stream<List<BallotModel>> watchEventBallots(String eventId) {
    return _ballotsCollection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      final ballots = snapshot.docs
          .map((doc) => BallotModel.fromJson(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      return ballots;
    });
  }
}
