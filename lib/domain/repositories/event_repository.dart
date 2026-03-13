import 'package:theatre_121/data/models/models.dart';

abstract class EventRepository {
  Future<EventModel?> getCurrentEvent();
  Future<EventModel> createEvent(EventModel event);
  Future<void> updateEvent(EventModel event);
  Future<void> updateDonationWinners(String eventId, {String? largestDonationWinnerId, String? mostDonationsWinnerId});
  Future<void> closeVoting(String eventId);
  Future<void> updateSpreadsheetUrl(String eventId, String spreadsheetUrl);
  Future<void> updateVotingResults(String eventId, VotingResults results);
  Future<void> deleteEvent(String eventId);
  Stream<EventModel?> watchCurrentEvent();
}
