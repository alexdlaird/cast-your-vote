import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:cast_your_vote/core/google_auth_service.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/domain/services/google_sheets_service.dart';

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
    // Scores are inverted (6 - score) so that higher raw score → lower contribution,
    // keeping the combined total aligned with audience ranking (higher total = worse).
    final judgeRows = <List<Object?>>[];
    judgeRows.add([
      'Judge',
      'Ballot Code',
      'Participant',
      'Singing',
      'Performance',
      'Song Fit',
      'Weight',
      'Total',
      'Singing Comments',
      'Performance Comments',
      'Song Fit Comments',
    ]);
    for (final ballot in judgeBallots) {
      for (final participant in participants) {
        final vote = ballot.judgeVotes[participant.id];
        if (vote != null) {
          // Invert scores: (6 - score) * 3 so that 5 (best) → 3, 1 (worst) → 15
          final singing = (6 - vote.singing) * 3;
          final performance = (6 - vote.performance) * 3;
          final songFit = (6 - vote.songFit) * 3;
          final weightRatio = ballot.judgeWeight / 5.0;
          final total = (singing + performance + songFit) * weightRatio;
          judgeRows.add([
            ballot.judgeName ?? ballot.code,
            ballot.code,
            participant.displayName,
            singing,
            performance,
            songFit,
            weightRatio,
            total,
            vote.singingComments,
            vote.performanceComments,
            vote.songFitComments,
          ]);
        }
      }
    }

    // Build summary sheet
    // Columns: Participant | Audience Total | Judge Total | Donation | Highest Donation | Most Donations | Combined
    // Donation: 1 if participant has hasDonation, else 0
    // Highest Donation: 1 for largestDonationWinnerId, else 0
    // Most Donations: 1 for mostDonationsWinnerId, else 0
    final summaryRows = <List<Object?>>[];
    summaryRows.add([
      'Participant',
      'Audience Total',
      'Judge Total',
      'Donation',
      'Highest Donation',
      'Most Donations',
      'Combined',
    ]);
    for (var i = 0; i < participants.length; i++) {
      final participant = participants[i];
      final col = _columnLetter(i + 2); // B, C, D, etc.
      final row = i + 2; // 2, 3, 4, etc.

      final donation = participant.hasDonation ? 1 : 0;
      final highestDonation = event.largestDonationWinnerId == participant.id ? 1 : 0;
      final mostDonations = event.mostDonationsWinnerId == participant.id ? 1 : 0;

      summaryRows.add([
        participant.displayName,
        "=SUM('Audience Votes'!${col}2:$col)",
        "=SUMIF('Judge Votes'!C:C,\"${participant.displayName}\",'Judge Votes'!H:H)",
        donation,
        highestDonation,
        mostDonations,
        '=B$row+C$row+D$row+E$row+F$row',
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

    // Read the Summary sheet (columns: Participant, Audience, Judge, Donation, Highest Donation, Most Donations, Combined)
    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      'Summary!A2:G100',
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
        // Combined is in column G (index 6)
        combinedScore: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0 : 0,
      ));
    }

    results.sort((a, b) => a.combinedScore.compareTo(b.combinedScore));
    return results;
  }
}
