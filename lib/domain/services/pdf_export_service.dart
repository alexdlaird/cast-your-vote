import 'dart:typed_data';

import 'package:cast_your_vote/data/models/models.dart';

abstract class PdfExportService {
  /// Generates a PDF with ballot codes and QR codes optimized for printing and cutting.
  Future<Uint8List> generateBallotCodesPdf({
    required List<BallotModel> audienceBallots,
    required List<BallotModel> judgeBallots,
    required String baseUrl,
  });
}
