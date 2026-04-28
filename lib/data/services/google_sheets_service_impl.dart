// Copyright (c) 2026 Alex Laird. MIT License.

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

    final hasJudges = ballots.any((b) => b.isJudge && b.submitted);

    if (existingSpreadsheetId != null) {
      spreadsheetId = existingSpreadsheetId;

      // Fetch existing sheets so we can add missing ones and only clear present ones.
      final existing = await sheetsApi.spreadsheets.get(spreadsheetId);
      final existingTitles = {
        for (final s in existing.sheets ?? <sheets.Sheet>[])
          if (s.properties?.title != null) s.properties!.title!,
      };

      final needed = [
        'Audience Votes',
        if (hasJudges) 'Judge Votes',
        'Summary',
        'Variables',
      ];
      final addRequests = [
        for (final title in needed)
          if (!existingTitles.contains(title))
            sheets.Request(
              addSheet: sheets.AddSheetRequest(
                properties: sheets.SheetProperties(title: title),
              ),
            ),
      ];
      if (addRequests.isNotEmpty) {
        await sheetsApi.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(requests: addRequests),
          spreadsheetId,
        );
      }

      await sheetsApi.spreadsheets.values.batchClear(
        sheets.BatchClearValuesRequest(
          ranges: [
            for (final title in needed) '$title!A1:ZZ',
          ],
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
            if (hasJudges)
              sheets.Sheet(
                properties: sheets.SheetProperties(title: 'Judge Votes'),
              ),
            sheets.Sheet(
              properties: sheets.SheetProperties(title: 'Summary'),
            ),
            sheets.Sheet(
              properties: sheets.SheetProperties(title: 'Variables'),
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

    // ── Scoring config → Variables sheet cell references ─────────────────────
    final config = event.scoringConfig;
    final donationsEnabled = config.donationsEnabled;
    final maxJudgeWeight = hasJudges
        ? ballots.where((b) => b.isJudge).fold<int>(1, (m, b) => b.judgeWeight > m ? b.judgeWeight : m)
        : 1;

    int varRow = 2;
    String? vDonationBonus;
    String? vHighestDonationBonus;
    String? vMostDonationsBonus;
    if (donationsEnabled) {
      vDonationBonus        = 'Variables!\$B\$${varRow++}';
      vHighestDonationBonus = 'Variables!\$B\$${varRow++}';
      vMostDonationsBonus   = 'Variables!\$B\$${varRow++}';
    }
    final vAudienceScoreMultiplier = 'Variables!\$B\$${varRow++}';
    final vJudgeScoreMultiplier   = 'Variables!\$B\$${varRow++}';
    final vMaxJudgeWeight         = 'Variables!\$B\$${varRow++}';

    // ── Audience Votes sheet ──────────────────────────────────────────────────
    // Scores are stored as higher=better (inverted at vote time).
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
    // Higher is better. Raw scores (1-5) are multiplied directly.
    // Layout: Judge | [Round] | Ballot Code | Contestant | Cat1..CatN | Weight | ScaledCat1..ScaledCatN | Weight Ratio | Total | Comments...
    final categories = List<JudgeCategoryModel>.from(event.judgeCategories)
      ..sort((a, b) => a.order.compareTo(b.order));
    final catCount = categories.length;

    final judgeRows = <List<Object?>>[];
    {
      final header = <Object?>['Judge'];
      if (isMultiRound) header.add('Round');
      header.addAll(['Ballot Code', 'Contestant']);
      for (final c in categories) {
        header.add('${c.name} (1-5)');
      }
      header.add('Weight');
      for (final c in categories) {
        header.add('Scaled ${c.name}');
      }
      header.addAll(['Weight Ratio', 'Total']);
      for (final c in categories) {
        header.add('${c.name} Comments');
      }
      judgeRows.add(header);
    }

    final rawScoreStart = isMultiRound ? 4 : 3;

    for (final ballot in judgeBallots) {
      final roundsToProcess = isMultiRound
          ? rounds
          : [if (rounds.isNotEmpty) rounds.first];
      for (final round in roundsToProcess) {
        final votes = ballot.judgeVotesForRound(round.id);
        for (final p in participants) {
          final vote = votes[p.id];
          if (vote != null) {
            final r = judgeRows.length + 1;
            final row = <Object?>[ballot.judgeName ?? ballot.code];
            if (isMultiRound) row.add('R${round.order}');
            row.addAll([ballot.code, p.displayName]);
            for (final c in categories) {
              row.add(vote.score(c.id));
            }
            row.add(ballot.judgeWeight);
            // Scaled scores: rawScore * multiplier
            for (var ci = 0; ci < catCount; ci++) {
              final rawCol = _columnLetter(rawScoreStart + ci + 1);
              row.add('=$rawCol$r*$vJudgeScoreMultiplier');
            }
            // Weight ratio: weight / maxJudgeWeight
            final weightCol = _columnLetter(rawScoreStart + catCount + 1);
            row.add('=$weightCol$r/$vMaxJudgeWeight');
            // Total = sum of scaled scores * weight ratio
            final scaledStart = rawScoreStart + catCount + 2;
            final scaledCols = List.generate(
              catCount,
              (ci) => '${_columnLetter(scaledStart + ci)}$r',
            );
            final weightRatioCol = _columnLetter(scaledStart + catCount);
            row.add('=(${scaledCols.join('+')})*$weightRatioCol$r');
            // Comments
            for (final c in categories) {
              row.add(vote.comment(c.id));
            }
            judgeRows.add(row);
          }
        }
      }
    }

    final totalColIdx = rawScoreStart + catCount + 1 + catCount + 2;

    // ── Summary sheet ─────────────────────────────────────────────────────────
    // Contestant column in Judge Votes sheet (for SUMIF/SUMPRODUCT)
    final jvContestantCol = _columnLetter(isMultiRound ? 4 : 3);
    final jvRoundCol = isMultiRound ? 'B' : null;
    final jvTotalCol = _columnLetter(totalColIdx);

    final summaryRows = <List<Object?>>[];
    if (isMultiRound) {
      final header = <Object?>['Contestant'];
      for (final r in rounds) {
        header.add('Audience R${r.order}');
      }
      header.add('Audience Total');
      if (hasJudges) {
        for (final r in rounds) {
          header.add('Judge R${r.order}');
        }
        header.add('Judge Total');
      }
      if (donationsEnabled) {
        header.addAll(['Donation', 'Highest Donation', 'Most Donations']);
      }
      header.add('Combined');
      summaryRows.add(header);

      final n = rounds.length;
      var nextCol = hasJudges ? 4 + 2 * n : 3 + n;
      final audTotalCol = _columnLetter(2 + n);
      final jdgTotalCol = hasJudges ? _columnLetter(3 + 2 * n) : null;
      String? donationCol, highDonCol, mostDonCol;
      if (donationsEnabled) {
        donationCol = _columnLetter(nextCol++);
        highDonCol  = _columnLetter(nextCol++);
        mostDonCol  = _columnLetter(nextCol++);
      }

      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        final row = i + 2;
        final rowData = <Object?>[p.displayName];

        for (var ri = 0; ri < rounds.length; ri++) {
          final startCol = _columnLetter(2 + ri * participants.length + i);
          rowData.add("=SUM('Audience Votes'!${startCol}2:$startCol)");
        }

        final audStartCol = _columnLetter(2);
        final audEndCol = _columnLetter(1 + n);
        rowData.add('=SUM($audStartCol$row:$audEndCol$row)');

        if (hasJudges) {
          for (final round in rounds) {
            rowData.add(
              "=SUMPRODUCT(('Judge Votes'!${jvContestantCol}2:$jvContestantCol=\"${p.displayName}\")*('Judge Votes'!${jvRoundCol}2:$jvRoundCol=\"R${round.order}\")*'Judge Votes'!${jvTotalCol}2:$jvTotalCol)",
            );
          }
          final jdgStartCol = _columnLetter(3 + n);
          final jdgEndCol   = _columnLetter(2 + 2 * n);
          rowData.add('=SUM($jdgStartCol$row:$jdgEndCol$row)');
        }

        if (donationsEnabled) {
          rowData.addAll([
            p.hasDonation ? 1 : 0,
            event.largestDonationWinnerId == p.id ? 1 : 0,
            event.mostDonationsWinnerId == p.id ? 1 : 0,
          ]);
        }
        final judgePart = hasJudges ? '+$jdgTotalCol$row' : '';
        final donationPart = donationsEnabled
            ? '+$donationCol$row*$vDonationBonus'
              '+$highDonCol$row*$vHighestDonationBonus'
              '+$mostDonCol$row*$vMostDonationsBonus'
            : '';
        rowData.add('=$audTotalCol$row*$vAudienceScoreMultiplier$judgePart$donationPart');
        summaryRows.add(rowData);
      }
    } else {
      summaryRows.add([
        'Contestant',
        'Audience Total',
        if (hasJudges) 'Judge Total',
        if (donationsEnabled) ...['Donation', 'Highest Donation', 'Most Donations'],
        'Combined',
      ]);
      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        final col = _columnLetter(i + 2);
        final row = i + 2;
        var nextSrCol = hasJudges ? 4 : 3;
        String? srDonCol, srHighCol, srMostCol;
        if (donationsEnabled) {
          srDonCol  = _columnLetter(nextSrCol++);
          srHighCol = _columnLetter(nextSrCol++);
          srMostCol = _columnLetter(nextSrCol++);
        }
        final audJudgePart = hasJudges
            ? '=B$row*$vAudienceScoreMultiplier+C$row'
            : '=B$row*$vAudienceScoreMultiplier';
        final srDonationPart = donationsEnabled
            ? '+$srDonCol$row*$vDonationBonus'
              '+$srHighCol$row*$vHighestDonationBonus'
              '+$srMostCol$row*$vMostDonationsBonus'
            : '';
        summaryRows.add([
          p.displayName,
          "=SUM('Audience Votes'!${col}2:$col)",
          if (hasJudges)
            "=SUMIF('Judge Votes'!${jvContestantCol}2:$jvContestantCol,\"${p.displayName}\",'Judge Votes'!${jvTotalCol}2:$jvTotalCol)",
          if (donationsEnabled) ...[
            p.hasDonation ? 1 : 0,
            event.largestDonationWinnerId == p.id ? 1 : 0,
            event.mostDonationsWinnerId == p.id ? 1 : 0,
          ],
          '$audJudgePart$srDonationPart',
        ]);
      }
    }

    // ── Variables sheet ───────────────────────────────────────────────────────
    final variablesRows = [
      ['Variable', 'Value', 'Description'],
      if (donationsEnabled) ...[
        ['Donation Points',                  config.donationBonus,        'Points added when a contestant has any donation'],
        ['Largest Donation Bonus',    config.highestDonationBonus, 'One-time bonus for the contestant with the largest single donation'],
        ['Most Donations Bonus',  config.mostDonationsBonus,   'One-time bonus for the contestant with the most individual donations'],
      ],
      ['Audience Score Multiplier', config.audienceScoreMultiplier, 'Multiplier applied to each audience vote score'],
      ['Judge Score Multiplier',   config.judgeScoreMultiplier,   'Multiplier applied to each raw judge score category'],
      ['Max Judge Weight',         maxJudgeWeight,                'Highest judge weight; used to normalise the weight ratio'],
    ];

    await sheetsApi.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: [
          sheets.ValueRange(
            range: 'Audience Votes!A1',
            values: audienceRows,
          ),
          if (hasJudges)
            sheets.ValueRange(
              range: 'Judge Votes!A1',
              values: judgeRows,
            ),
          sheets.ValueRange(
            range: 'Summary!A1',
            values: summaryRows,
          ),
          sheets.ValueRange(
            range: 'Variables!A1',
            values: variablesRows,
          ),
        ],
      ),
      spreadsheetId,
    );

    // ── Bold formatting ───────────────────────────────────────────────────────
    final spreadsheetInfo = await sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetIdsByTitle = {
      for (final s in spreadsheetInfo.sheets ?? <sheets.Sheet>[])
        if (s.properties?.title != null)
          s.properties!.title!: s.properties!.sheetId ?? 0,
    };

    final boldRequests = <sheets.Request>[];
    for (final title in [
      'Audience Votes',
      if (hasJudges) 'Judge Votes',
      'Summary',
      'Variables',
    ]) {
      final sheetId = sheetIdsByTitle[title];
      if (sheetId == null) continue;
      final boldCell = sheets.CellData(
        userEnteredFormat: sheets.CellFormat(
          textFormat: sheets.TextFormat(bold: true),
        ),
      );
      const boldField = 'userEnteredFormat.textFormat.bold';
      // Row 1 (header)
      boldRequests.add(sheets.Request(
        repeatCell: sheets.RepeatCellRequest(
          range: sheets.GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: 1,
          ),
          cell: boldCell,
          fields: boldField,
        ),
      ));
      // Column A
      boldRequests.add(sheets.Request(
        repeatCell: sheets.RepeatCellRequest(
          range: sheets.GridRange(
            sheetId: sheetId,
            startColumnIndex: 0,
            endColumnIndex: 1,
          ),
          cell: boldCell,
          fields: boldField,
        ),
      ));
    }

    await sheetsApi.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: boldRequests),
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

    final scored = <({String name, double score})>[];
    for (var i = 1; i < values.length; i++) {
      final row = values[i];
      if (row.isEmpty || row[nameIdx].toString().isEmpty) continue;
      final score = combinedIdx < row.length
          ? double.tryParse(row[combinedIdx].toString()) ?? 0.0
          : 0.0;
      scored.add((name: row[nameIdx].toString(), score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

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
