import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:theatre_121/core/google_auth_service.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/services/google_sheets_service.dart';

class GoogleSheetsServiceImpl implements GoogleSheetsService {
  final _authService = GoogleAuthService();

  @override
  Future<String> createResultsSpreadsheet({
    required EventModel event,
    required List<BallotModel> ballots,
  }) async {
    final client = await _authService.getAuthClient();
    final sheetsApi = sheets.SheetsApi(client);

    // Create the spreadsheet
    final eventDate = event.createdAt;
    final dateStr = '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';
    final shortCode = _generateShortCode(event.id);

    final spreadsheet = await sheetsApi.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: '${event.name} - $dateStr - $shortCode - Voting Results',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(title: 'Audience Votes'),
          ),
          sheets.Sheet(
            properties: sheets.SheetProperties(title: 'Judge Votes'),
          ),
          sheets.Sheet(
            properties: sheets.SheetProperties(title: 'Summary'),
          ),
        ],
      ),
    );

    final spreadsheetId = spreadsheet.spreadsheetId!;

    // Prepare audience votes data
    final audienceBallots = ballots.where((b) => b.isAudience && b.submitted).toList();
    final judgeBallots = ballots.where((b) => b.isJudge && b.submitted).toList();
    final participants = List<ParticipantModel>.from(event.participants)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Build audience votes sheet
    final audienceRows = <List<Object?>>[];
    audienceRows.add(['Ballot Code', ...participants.map((p) => p.displayName)]);
    for (final ballot in audienceBallots) {
      final row = <Object?>[ballot.code];
      for (final participant in participants) {
        row.add(ballot.audienceVotes[participant.id] ?? '');
      }
      audienceRows.add(row);
    }

    // Build judge votes sheet
    final judgeRows = <List<Object?>>[];
    judgeRows.add([
      'Judge',
      'Ballot Code',
      'Participant',
      'Singing',
      'Performance',
      'Audience Participation',
      'Total',
      'Comments',
    ]);
    for (final ballot in judgeBallots) {
      for (final participant in participants) {
        final vote = ballot.judgeVotes[participant.id];
        if (vote != null) {
          // Each judge category multiplied by 3 (max 15 per category)
          final singing = vote.singing * 3;
          final performance = vote.performance * 3;
          final audienceParticipation = vote.audienceParticipation * 3;
          final total = singing + performance + audienceParticipation;
          judgeRows.add([
            ballot.judgeName ?? ballot.code,
            ballot.code,
            participant.displayName,
            singing,
            performance,
            audienceParticipation,
            total,
            vote.comments,
          ]);
        }
      }
    }

    // Build summary sheet
    final summaryRows = <List<Object?>>[];
    summaryRows.add(['Participant', 'Audience Total', 'Judge Total', 'Bonus', 'Combined']);
    for (var i = 0; i < participants.length; i++) {
      final participant = participants[i];
      final col = _columnLetter(i + 2); // B, C, D, etc.
      final row = i + 2; // 2, 3, 4, etc.

      // Calculate bonus points (0.25 each for largest donation and most donations)
      var bonus = 0.0;
      if (event.largestDonationWinnerId == participant.id) bonus += 0.25;
      if (event.mostDonationsWinnerId == participant.id) bonus += 0.25;

      summaryRows.add([
        participant.displayName,
        "=SUM('Audience Votes'!${col}2:$col)",
        "=SUMIF('Judge Votes'!C:C,\"${participant.displayName}\",'Judge Votes'!G:G)",
        bonus,
        '=B$row+C$row+D$row',
      ]);
    }

    // Write data to sheets
    await sheetsApi.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: [
          sheets.ValueRange(
            range: 'Audience Votes!A1',
            values: audienceRows,
          ),
          sheets.ValueRange(
            range: 'Judge Votes!A1',
            values: judgeRows,
          ),
          sheets.ValueRange(
            range: 'Summary!A1',
            values: summaryRows,
          ),
        ],
      ),
      spreadsheetId,
    );

    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
  }

  String _columnLetter(int column) {
    String result = '';
    var col = column;
    while (col > 0) {
      col--;
      result = String.fromCharCode(65 + (col % 26)) + result;
      col ~/= 26;
    }
    return result;
  }

  /// Generates a deterministic 3-character alphanumeric code from an event ID.
  String _generateShortCode(String eventId) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes I, O, 0, 1 for clarity
    final hash = eventId.hashCode.abs();
    final c1 = chars[(hash >> 0) % chars.length];
    final c2 = chars[(hash >> 5) % chars.length];
    final c3 = chars[(hash >> 10) % chars.length];
    return '$c1$c2$c3';
  }

  @override
  Future<List<ParticipantResult>> fetchResultsFromSpreadsheet({
    required String spreadsheetUrl,
  }) async {
    final client = await _authService.getAuthClient();
    final sheetsApi = sheets.SheetsApi(client);

    // Extract spreadsheet ID from URL
    final uri = Uri.parse(spreadsheetUrl);
    final pathSegments = uri.pathSegments;
    final dIndex = pathSegments.indexOf('d');
    if (dIndex == -1 || dIndex + 1 >= pathSegments.length) {
      throw StateError('Invalid spreadsheet URL');
    }
    final spreadsheetId = pathSegments[dIndex + 1];

    // Read the Summary sheet (columns: Participant, Audience, Judge, Bonus, Combined)
    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      'Summary!A2:E100',
    );

    final values = response.values;
    if (values == null || values.isEmpty) {
      return [];
    }

    final results = <ParticipantResult>[];
    for (var i = 0; i < values.length; i++) {
      final row = values[i];
      if (row.isEmpty || row[0].toString().isEmpty) continue;

      results.add(ParticipantResult(
        id: 'p${i + 1}',
        name: row[0].toString(),
        audienceTotal: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
        judgeTotal: row.length > 2 ? int.tryParse(row[2].toString()) ?? 0 : 0,
        // Combined is in column E (index 4), may have decimals from bonus points
        combinedScore: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0 : 0,
      ));
    }

    results.sort((a, b) => a.combinedScore.compareTo(b.combinedScore));
    return results;
  }
}
