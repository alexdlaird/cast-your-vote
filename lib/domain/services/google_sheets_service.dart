import 'package:cast_your_vote/data/models/models.dart';

abstract class GoogleSheetsService {
  /// Creates a new Google Sheet with voting results.
  /// Returns the URL of the created spreadsheet.
  Future<String> createResultsSpreadsheet({
    required EventModel event,
    required List<BallotModel> ballots,
  });

  /// Fetches voting results from an existing spreadsheet.
  Future<List<ParticipantResult>> fetchResultsFromSpreadsheet({
    required String spreadsheetUrl,
  });
}
