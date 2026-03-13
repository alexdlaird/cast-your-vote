import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:theatre_121/domain/repositories/event_repository.dart';
import 'package:theatre_121/data/models/models.dart';

class EventRepositoryImpl implements EventRepository {
  final FirebaseFirestore _firestore;

  EventRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _firestore.collection('events');

  @override
  Future<EventModel?> getCurrentEvent() async {
    final snapshot = await _eventsCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return EventModel.fromJson(doc.data(), doc.id);
  }

  @override
  Future<EventModel> createEvent(EventModel event) async {
    final docRef = await _eventsCollection.add(event.toJson());
    return event.copyWith(id: docRef.id);
  }

  @override
  Future<void> updateEvent(EventModel event) async {
    await _eventsCollection.doc(event.id).update(event.toJson());
  }

  @override
  Future<void> updateDonationWinners(
    String eventId, {
    String? largestDonationWinnerId,
    String? mostDonationsWinnerId,
  }) async {
    final updates = <String, dynamic>{};
    if (largestDonationWinnerId != null) {
      updates['largestDonationWinnerId'] = largestDonationWinnerId.isEmpty ? null : largestDonationWinnerId;
    }
    if (mostDonationsWinnerId != null) {
      updates['mostDonationsWinnerId'] = mostDonationsWinnerId.isEmpty ? null : mostDonationsWinnerId;
    }
    if (updates.isNotEmpty) {
      await _eventsCollection.doc(eventId).update(updates);
    }
  }

  @override
  Future<void> closeVoting(String eventId) async {
    await _eventsCollection.doc(eventId).update({
      'status': EventStatus.closed.name,
    });
  }

  @override
  Future<void> updateSpreadsheetUrl(String eventId, String spreadsheetUrl) async {
    await _eventsCollection.doc(eventId).update({
      'spreadsheetUrl': spreadsheetUrl,
    });
  }

  @override
  Future<void> updateVotingResults(String eventId, VotingResults results) async {
    await _eventsCollection.doc(eventId).update({
      'votingResults': results.toJson(),
    });
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _eventsCollection.doc(eventId).delete();
  }

  @override
  Stream<EventModel?> watchCurrentEvent() {
    return _eventsCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return EventModel.fromJson(doc.data(), doc.id);
    });
  }
}
