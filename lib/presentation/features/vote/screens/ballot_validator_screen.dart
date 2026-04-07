// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:cast_your_vote/config/app_routes.dart';
import 'package:cast_your_vote/data/models/models.dart';
import 'package:cast_your_vote/data/repositories/ballot_repository_impl.dart';
import 'package:cast_your_vote/presentation/features/vote/screens/audience_ballot_screen.dart';
import 'package:cast_your_vote/presentation/features/vote/screens/judge_ballot_screen.dart';

final _log = Logger('ballot_validator_screen');

class BallotValidatorScreen extends StatefulWidget {
  final String ballotCode;

  const BallotValidatorScreen({
    super.key,
    required this.ballotCode,
  });

  @override
  State<BallotValidatorScreen> createState() => _BallotValidatorScreenState();
}

class _BallotValidatorScreenState extends State<BallotValidatorScreen> {
  final _ballotRepository = BallotRepositoryImpl();
  bool _isLoading = true;
  BallotModel? _ballot;

  @override
  void initState() {
    super.initState();
    _validateBallot();
  }

  Future<void> _validateBallot() async {
    try {
      final ballot = await _ballotRepository.getBallot(widget.ballotCode);

      if (!mounted) return;

      if (ballot == null) {
        context.go('${AppRoutes.home}?error=Ballot not found');
        return;
      }

      setState(() {
        _ballot = ballot;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to validate ballot', e, stackTrace);
      if (!mounted) return;
      context.go('${AppRoutes.home}?error=Error validating ballot');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_ballot == null) {
      return const SizedBox();
    }

    if (_ballot!.isJudge) {
      return JudgeBallotScreen(ballotCode: widget.ballotCode);
    }

    return AudienceBallotScreen(ballotCode: widget.ballotCode);
  }
}
