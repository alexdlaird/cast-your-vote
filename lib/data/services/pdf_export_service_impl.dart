import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/domain/services/pdf_export_service.dart';

class PdfExportServiceImpl implements PdfExportService {
  static const int _columnsPerPage = 3;
  static const int _rowsPerPage = 4;
  static const int _cardsPerPage = _columnsPerPage * _rowsPerPage;

  @override
  Future<Uint8List> generateBallotCodesPdf({
    required List<BallotModel> audienceBallots,
    required List<BallotModel> judgeBallots,
    required String baseUrl,
  }) async {
    final pdf = pw.Document();
    final displayHost = _extractDisplayHost(baseUrl);

    // Generate audience ballot pages
    if (audienceBallots.isNotEmpty) {
      _addBallotPages(
        pdf: pdf,
        ballots: audienceBallots,
        baseUrl: baseUrl,
        displayHost: displayHost,
      );
    }

    // Generate judge ballot pages
    if (judgeBallots.isNotEmpty) {
      _addBallotPages(
        pdf: pdf,
        ballots: judgeBallots,
        baseUrl: baseUrl,
        displayHost: displayHost,
      );
    }

    return pdf.save();
  }

  String _extractDisplayHost(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return '${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
  }

  void _addBallotPages({
    required pw.Document pdf,
    required List<BallotModel> ballots,
    required String baseUrl,
    required String displayHost,
  }) {
    for (var i = 0; i < ballots.length; i += _cardsPerPage) {
      final pageBallots = ballots.skip(i).take(_cardsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(12),
          build: (context) {
            return _buildBallotGrid(pageBallots, baseUrl, displayHost);
          },
        ),
      );
    }
  }

  pw.Widget _buildBallotGrid(
    List<BallotModel> ballots,
    String baseUrl,
    String displayHost,
  ) {
    final rows = <pw.TableRow>[];

    for (var i = 0; i < ballots.length; i += _columnsPerPage) {
      final rowBallots = ballots.skip(i).take(_columnsPerPage).toList();

      rows.add(
        pw.TableRow(
          children: [
            for (var j = 0; j < _columnsPerPage; j++)
              j < rowBallots.length
                  ? _buildBallotCard(rowBallots[j], baseUrl, displayHost)
                  : pw.Container(),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
        style: pw.BorderStyle.dashed,
      ),
      children: rows,
    );
  }

  pw.Widget _buildBallotCard(
    BallotModel ballot,
    String baseUrl,
    String displayHost,
  ) {
    final url = '$baseUrl?ballot=${ballot.code}';

    return pw.Container(
      width: 190,
      height: 190,
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            data: url,
            barcode: pw.Barcode.qrCode(),
            width: 100,
            height: 100,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            ballot.code,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          if (ballot.judgeName != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              ballot.judgeName!,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            displayHost,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
