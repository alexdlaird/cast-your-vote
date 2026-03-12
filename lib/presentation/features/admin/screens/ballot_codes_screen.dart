import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:theatre_121/config/app_routes.dart';
import 'package:theatre_121/presentation/ui/theme/app_theme.dart';
import 'package:theatre_121/presentation/features/admin/bloc/admin_bloc.dart';
import 'package:theatre_121/data/models/models.dart';

String _buildBallotUrl(String code) {
  if (kIsWeb) {
    final base = Uri.base;
    return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}/vote?ballot=$code';
  }
  // Fallback for non-web (shouldn't happen for this app)
  return 'https://comeout.theatre121.org/vote?ballot=$code';
}

String _getBaseHost() {
  if (kIsWeb) {
    final base = Uri.base;
    return '${base.host}${base.hasPort ? ':${base.port}' : ''}/vote';
  }
  return 'comeout.theatre121.org/vote';
}

class BallotCodesScreen extends StatelessWidget {
  const BallotCodesScreen({super.key});

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
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => _showPrintPreview(
                    context,
                    audienceBallots,
                    judgeBallots,
                  ),
                  tooltip: 'Print Preview',
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

  void _showPrintPreview(
    BuildContext context,
    List<BallotModel> audienceBallots,
    List<BallotModel> judgeBallots,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PrintPreviewScreen(
          audienceBallots: audienceBallots,
          judgeBallots: judgeBallots,
        ),
      ),
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
                  Text(
                    ballot.code,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PrintPreviewScreen extends StatelessWidget {
  final List<BallotModel> audienceBallots;
  final List<BallotModel> judgeBallots;

  const _PrintPreviewScreen({
    required this.audienceBallots,
    required this.judgeBallots,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: null,
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text('Print Preview'),
        actions: [
          TextButton.icon(
            onPressed: () => _exportToGoogleDocs(context),
            icon: const Icon(Icons.file_upload),
            label: const Text('Export to Google Docs'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audience Ballots (${audienceBallots.length})',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildPrintableGrid(audienceBallots, isJudge: false),
            const SizedBox(height: 32),
            Text(
              'Judge Ballots (${judgeBallots.length})',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildPrintableGrid(judgeBallots, isJudge: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintableGrid(
    List<BallotModel> ballots, {
    required bool isJudge,
  }) {
    final baseHost = _getBaseHost();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: ballots.map((ballot) {
        final url = _buildBallotUrl(ballot.code);

        return Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              QrImageView(
                data: url,
                size: 120,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                ballot.code,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (isJudge)
                Text(
                  'JUDGE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                baseHost,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Exports ballot codes to a Google Doc for printing.
  void _exportToGoogleDocs(BuildContext context) {
    // TODO: Implement Google Docs export using googleapis package.
    // Create a new document with printable ballot cards containing:
    // - QR codes for each ballot
    // - Ballot codes in large text
    // - Judge/Audience labels
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Docs export coming soon')),
    );
  }
}
