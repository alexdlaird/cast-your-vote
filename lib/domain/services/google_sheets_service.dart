// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:cast_your_vote/data/models/models.dart';

/// Ranked results read back from a spreadsheet.
/// Scores are intentionally omitted — ranking order and tie detection
/// are computed from the spreadsheet formulas and discarded after use.
class FetchedRankings {
  /// Performer names in ranked order (best → worst).
  final List<String> rankedNames;

  /// Names of last-place performers if they tied; empty when there is a
  /// single clear last-place performer.
  final List<String> tiedNames;

  const FetchedRankings({
    required this.rankedNames,
    this.tiedNames = const [],
  });
}

abstract class GoogleSheetsService {
  /// Creates or overwrites a Google Sheet with voting results.
  /// If [existingSpreadsheetId] is provided, clears and rewrites that sheet
  /// instead of creating a new one. Returns the URL of the spreadsheet.
  Future<String> createResultsSpreadsheet({
    required EventModel event,
    required List<BallotModel> ballots,
    String? existingSpreadsheetId,
  });

  /// Fetches ranked results from the Summary sheet.
  /// Scores are used internally for ordering and tie detection, then discarded.
  Future<FetchedRankings> fetchResultsFromSpreadsheet({
    required String spreadsheetUrl,
  });
}
