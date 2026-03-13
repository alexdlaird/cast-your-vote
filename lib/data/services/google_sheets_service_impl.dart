import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:theatre_121/config/google_sign_in_config.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/services/google_sheets_service.dart';

class GoogleSheetsServiceImpl implements GoogleSheetsService {

  static const _sheetsScope = 'https://www.googleapis.com/auth/drive.file';

  Future<AuthClient> _getAuthClient() async {
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    // If no account, sign in
    if (account == null) {
      account = await googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in required. Please try again.');
      }
    }

    // Request the drive.file scope explicitly - this triggers OAuth consent on web
    // and ensures we get an access token (not just an ID token from FedCM)
    final hasScope = await googleSignIn.requestScopes([_sheetsScope]);
    if (!hasScope) {
      throw StateError('Google Sheets access denied. Please grant permission to continue.');
    }

    // Now get the authentication with the proper access token
    final auth = await account.authentication;

    if (auth.accessToken == null) {
      throw StateError('Unable to get Google access token. Please sign out and sign back in.');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        auth.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      [_sheetsScope],
    );

    return authenticatedClient(http.Client(), credentials);
  }

  @override
  Future<String> createResultsSpreadsheet({
    required EventModel event,
    required List<BallotModel> ballots,
  }) async {
    final client = await _getAuthClient();

    try {
      final sheetsApi = sheets.SheetsApi(client);

      // Create the spreadsheet
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final spreadsheet = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(
            title: '${event.name} - Voting Results - $dateStr',
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
            final total = vote.singing + vote.performance + vote.audienceParticipation;
            judgeRows.add([
              ballot.judgeName ?? ballot.code,
              ballot.code,
              participant.displayName,
              vote.singing,
              vote.performance,
              vote.audienceParticipation,
              total,
              vote.comments,
            ]);
          }
        }
      }

      // Build summary sheet
      final summaryRows = <List<Object?>>[];
      summaryRows.add(['Participant', 'Audience Points', 'Judge Total', 'Combined']);
      for (var i = 0; i < participants.length; i++) {
        final participant = participants[i];
        final col = _columnLetter(i + 2); // B, C, D, etc.
        final row = i + 2; // 2, 3, 4, etc.
        summaryRows.add([
          participant.displayName,
          "=SUM('Audience Votes'!${col}2:$col)",
          "=SUMIF('Judge Votes'!C:C,\"${participant.displayName}\",'Judge Votes'!G:G)",
          '=B$row+C$row',
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
    } finally {
      client.close();
    }
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

  @override
  Future<List<ParticipantResult>> fetchResultsFromSpreadsheet({
    required String spreadsheetUrl,
  }) async {
    final client = await _getAuthClient();

    try {
      final sheetsApi = sheets.SheetsApi(client);

      // Extract spreadsheet ID from URL
      final uri = Uri.parse(spreadsheetUrl);
      final pathSegments = uri.pathSegments;
      final dIndex = pathSegments.indexOf('d');
      if (dIndex == -1 || dIndex + 1 >= pathSegments.length) {
        throw StateError('Invalid spreadsheet URL');
      }
      final spreadsheetId = pathSegments[dIndex + 1];

      // Read the Summary sheet
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'Summary!A2:D100',
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
          audiencePoints: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
          judgeTotal: row.length > 2 ? int.tryParse(row[2].toString()) ?? 0 : 0,
          combinedScore: row.length > 3 ? int.tryParse(row[3].toString()) ?? 0 : 0,
        ));
      }

      results.sort((a, b) => a.combinedScore.compareTo(b.combinedScore));
      return results;
    } finally {
      client.close();
    }
  }
}
