// Copyright (c) 2024 Cast Your Vote. MIT License.

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
    String? existingSpreadsheetId,
  }) async {
    final client = await _authService.getAuthClient();
    final sheetsApi = sheets.SheetsApi(client);

    final String spreadsheetId;

    if (existingSpreadsheetId != null) {
      spreadsheetId = existingSpreadsheetId;
      await sheetsApi.spreadsheets.values.batchClear(
        sheets.BatchClearValuesRequest(
          ranges: ['Audience Votes!A1:ZZ', 'Judge Votes!A1:ZZ', 'Summary!A1:ZZ'],
        ),
        spreadsheetId,
      );
    } else {
      final eventDate = event.createdAt;
      final dateStr =
          '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';
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
      spreadsheetId = spreadsheet.spreadsheetId!;
    }

    final audienceBallots =
        ballots.where((b) => b.isAudience && b.submitted).toList();
    final judgeBallots =
        ballots.where((b) => b.isJudge && b.submitted).toList();
    final participants = List<ParticipantModel>.from(event.participants)
      ..sort((a, b) => a.order.compareTo(b.order));

    final rounds = event.rounds;
    final isMultiRound = rounds.length > 1;

    // ── Audience Votes sheet ──────────────────────────────────────────────────
    // Single round:  Ballot Code | P1 | P2 | …
    // Multi-round:   Ballot Code | P1 R1 | P2 R1 | … | P1 R2 | P2 R2 | …
    final audienceRows = <List<Object?>>[];
    if (isMultiRound) {
      final header = <Object?>['Ballot Code'];
      for (final round in rounds) {
        for (final p in participants) {
          header.add('${p.displayName} R${round.order}');
        }
      }
      audienceRows.add(header);
      for (final ballot in audienceBallots) {
        final row = <Object?>[ballot.code];
        for (final round in rounds) {
          final votes = ballot.audienceVotesForRound(round.id);
          for (final p in participants) {
            row.add(votes[p.id] ?? '');
          }
        }
        audienceRows.add(row);
      }
    } else {
      audienceRows.add([
        'Ballot Code',
        ...participants.map((p) => p.displayName),
      ]);
      final roundId = rounds.isNotEmpty ? rounds.first.id : 'r1';
      for (final ballot in audienceBallots) {
        final votes = ballot.audienceVotesForRound(roundId);
        final row = <Object?>[ballot.code];
        for (final p in participants) {
          row.add(votes[p.id] ?? '');
        }
        audienceRows.add(row);
      }
    }

    // ── Judge Votes sheet ─────────────────────────────────────────────────────
    // Raw scores (1–5) are written as data so admins can audit them as
    // necessary. Adjusted scores, weight ratio, and total are spreadsheet
    // formulas so they recalculate automatically when overrides are made.
    //
    // Single round column layout:
    //   A: Judge | B: Ballot Code | C: Participant
    //   D: Singing (1-5) | E: Performance (1-5) | F: Song Fit (1-5)
    //   G: Weight (1-5)
    //   H: Adj Singing =(6-D)*3 | I: Adj Performance | J: Adj Song Fit
    //   K: Weight Ratio =G/5 | L: Total =(H+I+J)*K
    //   M: Singing Comments | N: Performance Comments | O: Song Fit Comments
    //
    // Multi-round inserts a Round column at B, shifting scores to E–H,
    // formulas to I–M, comments to N–P.
    final judgeRows = <List<Object?>>[];
    if (isMultiRound) {
      judgeRows.add([
        'Judge', 'Round', 'Ballot Code', 'Performer',
        'Singing (1-5)', 'Performance (1-5)', 'Song Fit (1-5)', 'Weight (1-5)',
        'Adj Singing', 'Adj Performance', 'Adj Song Fit',
        'Weight Ratio', 'Total',
        'Singing Comments', 'Performance Comments', 'Song Fit Comments',
      ]);
    } else {
      judgeRows.add([
        'Judge', 'Ballot Code', 'Performer',
        'Singing (1-5)', 'Performance (1-5)', 'Song Fit (1-5)', 'Weight (1-5)',
        'Adj Singing', 'Adj Performance', 'Adj Song Fit',
        'Weight Ratio', 'Total',
        'Singing Comments', 'Performance Comments', 'Song Fit Comments',
      ]);
    }

    for (final ballot in judgeBallots) {
      if (isMultiRound) {
        for (final round in rounds) {
          final votes = ballot.judgeVotesForRound(round.id);
          for (final p in participants) {
            final vote = votes[p.id];
            if (vote != null) {
              final r = judgeRows.length + 1;
              judgeRows.add([
                ballot.judgeName ?? ballot.code,
                'R${round.order}',
                ballot.code,
                p.displayName,
                vote.singing,
                vote.performance,
                vote.songFit,
                ballot.judgeWeight,
                '=(6-E$r)*3',
                '=(6-F$r)*3',
                '=(6-G$r)*3',
                '=H$r/5',
                '=(I$r+J$r+K$r)*L$r',
                vote.singingComments,
                vote.performanceComments,
                vote.songFitComments,
              ]);
            }
          }
        }
      } else {
        final roundId = rounds.isNotEmpty ? rounds.first.id : 'r1';
        final votes = ballot.judgeVotesForRound(roundId);
        for (final p in participants) {
          final vote = votes[p.id];
          if (vote != null) {
            final r = judgeRows.length + 1;
            judgeRows.add([
              ballot.judgeName ?? ballot.code,
              ballot.code,
              p.displayName,
              vote.singing,
              vote.performance,
              vote.songFit,
              ballot.judgeWeight,
              '=(6-D$r)*3',
              '=(6-E$r)*3',
              '=(6-F$r)*3',
              '=G$r/5',
              '=(H$r+I$r+J$r)*K$r',
              vote.singingComments,
              vote.performanceComments,
              vote.songFitComments,
            ]);
          }
        }
      }
    }

    // ── Summary sheet ─────────────────────────────────────────────────────────
    // Single round:  Participant | Audience Total | Judge Total | … | Combined
    // Multi-round:   Participant | Aud R1 | Aud R2 | … | Audience Total |
    //                             Jdg R1 | Jdg R2 | … | Judge Total | … | Combined
    final summaryRows = <List<Object?>>[];
    if (isMultiRound) {
      final header = <Object?>['Performer'];
      for (final r in rounds) {
        header.add('Audience R${r.order}');
      }
      header.add('Audience Total');
      for (final r in rounds) {
        header.add('Judge R${r.order}');
      }
      header.add('Judge Total');
      header.addAll(['Donation', 'Highest Donation', 'Most Donations', 'Combined']);
      summaryRows.add(header);

      // Column layout (1-indexed):
      // 1: Participant
      // 2..(1+rounds.length): Aud R1..RN
      // (2+rounds.length): Audience Total
      // (3+rounds.length)..(2+2*rounds.length): Jdg R1..RN
      // (3+2*rounds.length): Judge Total
      // (4+2*rounds.length): Donation
      // (5+2*rounds.length): Highest Donation
      // (6+2*rounds.length): Most Donations
      // (7+2*rounds.length): Combined
      final n = rounds.length;
      final audTotalCol = _columnLetter(2 + n);
      final jdgTotalCol = _columnLetter(3 + 2 * n);
      final donationCol = _columnLetter(4 + 2 * n);
      final highDonCol  = _columnLetter(5 + 2 * n);
      final mostDonCol  = _columnLetter(6 + 2 * n);

      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        final row = i + 2;
        final donation = p.hasDonation ? 1 : 0;
        final highestDonation = event.largestDonationWinnerId == p.id ? 1 : 0;
        final mostDonations = event.mostDonationsWinnerId == p.id ? 1 : 0;

        final rowData = <Object?>[p.displayName];

        // Audience per-round: SUMIF on round's column range in Audience Votes
        for (var ri = 0; ri < rounds.length; ri++) {
          // Audience Votes columns for this round: cols 2+ri*participants.length
          // through 1+(ri+1)*participants.length (1-indexed)
          final startCol = _columnLetter(2 + ri * participants.length + i);
          rowData.add("=SUM('Audience Votes'!${startCol}2:$startCol)");
        }

        // Audience Total = sum of Aud R1..RN columns for this row
        final audStartCol = _columnLetter(2);
        final audEndCol = _columnLetter(1 + n);
        rowData.add('=SUM($audStartCol$row:$audEndCol$row)');

        // Judge per-round: SUMIF where Participant=name AND Round=Rn
        // Total is column M in multi-round layout (D=Participant, B=Round).
        // Start ranges from row 2 to exclude the header row.
        for (final round in rounds) {
          rowData.add(
            "=SUMPRODUCT(('Judge Votes'!D2:D=\"${p.displayName}\")*('Judge Votes'!B2:B=\"R${round.order}\")*'Judge Votes'!M2:M)",
          );
        }

        // Judge Total
        final jdgStartCol = _columnLetter(3 + n);
        final jdgEndCol   = _columnLetter(2 + 2 * n);
        rowData.add('=SUM($jdgStartCol$row:$jdgEndCol$row)');

        rowData.addAll([donation, highestDonation, mostDonations]);
        rowData.add(
          '=$audTotalCol$row+$jdgTotalCol$row+$donationCol$row+$highDonCol$row+$mostDonCol$row',
        );
        summaryRows.add(rowData);
      }
    } else {
      summaryRows.add([
        'Performer',
        'Audience Total',
        'Judge Total',
        'Donation',
        'Highest Donation',
        'Most Donations',
        'Combined',
      ]);
      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        final col = _columnLetter(i + 2);
        final row = i + 2;
        final donation = p.hasDonation ? 1 : 0;
        final highestDonation = event.largestDonationWinnerId == p.id ? 1 : 0;
        final mostDonations = event.mostDonationsWinnerId == p.id ? 1 : 0;
        summaryRows.add([
          p.displayName,
          "=SUM('Audience Votes'!${col}2:$col)",
          // Total is column L in single-round layout (C=Participant).
          // Start ranges from row 2 to exclude the header row.
          "=SUMIF('Judge Votes'!C2:C,\"${p.displayName}\",'Judge Votes'!L2:L)",
          donation,
          highestDonation,
          mostDonations,
          '=B$row+C$row+D$row+E$row+F$row',
        ]);
      }
    }

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

  String _generateShortCode(String eventId) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hash = eventId.hashCode.abs();
    final c1 = chars[(hash >> 0) % chars.length];
    final c2 = chars[(hash >> 5) % chars.length];
    final c3 = chars[(hash >> 10) % chars.length];
    return '$c1$c2$c3';
  }

  @override
  Future<FetchedRankings> fetchResultsFromSpreadsheet({
    required String spreadsheetUrl,
  }) async {
    final client = await _authService.getAuthClient();
    final sheetsApi = sheets.SheetsApi(client);

    final uri = Uri.parse(spreadsheetUrl);
    final pathSegments = uri.pathSegments;
    final dIndex = pathSegments.indexOf('d');
    if (dIndex == -1 || dIndex + 1 >= pathSegments.length) {
      throw StateError('Invalid spreadsheet URL');
    }
    final spreadsheetId = pathSegments[dIndex + 1];

    final response = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      'Summary!A1:ZZ200',
    );

    final values = response.values;
    if (values == null || values.length < 2) return const FetchedRankings(rankedNames: []);

    final header = values[0].map((h) => h.toString()).toList();
    const nameIdx = 0;
    final combinedIdx = header.indexOf('Combined');

    if (combinedIdx == -1) return const FetchedRankings(rankedNames: []);

    // Use scores only for sorting and tie detection; discard afterwards.
    final scored = <({String name, double score})>[];
    for (var i = 1; i < values.length; i++) {
      final row = values[i];
      if (row.isEmpty || row[nameIdx].toString().isEmpty) continue;
      final score = combinedIdx < row.length
          ? double.tryParse(row[combinedIdx].toString()) ?? 0.0
          : 0.0;
      scored.add((name: row[nameIdx].toString(), score: score));
    }

    scored.sort((a, b) => a.score.compareTo(b.score));

    final rankedNames = scored.map((r) => r.name).toList();
    if (rankedNames.isEmpty) return const FetchedRankings(rankedNames: []);

    final lowestScore = scored.last.score;
    final tiedNames = scored
        .where((r) => r.score == lowestScore)
        .map((r) => r.name)
        .toList();

    return FetchedRankings(
      rankedNames: rankedNames,
      tiedNames: tiedNames.length > 1 ? tiedNames : [],
    );
  }
}
