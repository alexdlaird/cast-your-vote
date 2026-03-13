import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/ui/utils/snack_bar_helper.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/data/services/pdf_export_service_impl.dart';

String _buildBallotUrl(String code) {
  if (!kIsWeb) {
    throw UnsupportedError('This app only supports web');
  }
  final base = Uri.base;
  return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}/vote?ballot=$code';
}

String _getBaseVoteUrl() {
  if (!kIsWeb) {
    throw UnsupportedError('This app only supports web');
  }
  final base = Uri.base;
  return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}/vote';
}

class BallotCodesScreen extends StatefulWidget {
  const BallotCodesScreen({super.key});

  @override
  State<BallotCodesScreen> createState() => _BallotCodesScreenState();
}

class _BallotCodesScreenState extends State<BallotCodesScreen> {
  bool _isExporting = false;

  Future<void> _exportToPdf(
    List<BallotModel> audienceBallots,
    List<BallotModel> judgeBallots,
  ) async {
    setState(() => _isExporting = true);

    try {
      final pdfService = PdfExportServiceImpl();
      final pdfBytes = await pdfService.generateBallotCodesPdf(
        audienceBallots: audienceBallots,
        judgeBallots: judgeBallots,
        baseUrl: _getBaseVoteUrl(),
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'ballot-codes.pdf',
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, 'Export failed: $e', type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is! AdminLoaded || state.currentEvent == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ballot Codes')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final ballots = state.ballots;

        final audienceBallots = ballots.where((b) => b.isAudience).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final judgeBallots = ballots.where((b) => b.isJudge).toList()
          ..sort((a, b) => a.code.compareTo(b.code));

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: null,
                onPressed: () => context.go(AppRoutes.admin),
              ),
              titleSpacing: 0,
              title: const Text('Ballot Codes'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Audience'),
                  Tab(text: 'Judges'),
                ],
              ),
              actions: [
                _isExporting
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _exportToPdf(
                          audienceBallots,
                          judgeBallots,
                        ),
                        tooltip: 'Export ballots as PDF',
                      ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildBallotList(context, audienceBallots, isJudge: false),
                _buildBallotList(context, judgeBallots, isJudge: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBallotList(
    BuildContext context,
    List<BallotModel> ballots, {
    required bool isJudge,
  }) {
    if (ballots.isEmpty) {
      return Center(
        child: Text(
          'No ${isJudge ? 'judge' : 'audience'} ballots',
          style: context.textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ballots.length,
      itemBuilder: (context, index) {
        final ballot = ballots[index];
        return _BallotCodeCard(
          ballot: ballot,
          isJudge: isJudge,
        );
      },
    );
  }
}

class _BallotCodeCard extends StatelessWidget {
  final BallotModel ballot;
  final bool isJudge;

  const _BallotCodeCard({
    required this.ballot,
    required this.isJudge,
  });

  String get _url => _buildBallotUrl(ballot.code);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (ballot.submitted)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.how_to_vote,
                  size: 40,
                  color: Colors.green.shade600,
                ),
              )
            else
              QrImageView(
                data: _url,
                size: 80,
                backgroundColor: Colors.white,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ballot.code,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                      if (ballot.judgeName != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          ballot.judgeName!,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (ballot.submitted)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voted',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    SelectableText(
                      _url,
                      style: context.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (!ballot.submitted)
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ballot.code));
                  SnackBarHelper.show(context, 'Code copied to clipboard');
                },
              ),
          ],
        ),
      ),
    );
  }
}

