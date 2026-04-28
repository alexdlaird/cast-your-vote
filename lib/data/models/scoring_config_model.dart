// Copyright (c) 2026 Alex Laird. MIT License.

import 'package:equatable/equatable.dart';

class ScoringConfigModel extends Equatable {
  final bool donationsEnabled;
  final double donationBonus;
  final double highestDonationBonus;
  final double mostDonationsBonus;
  final int audienceScoreMultiplier;
  final int judgeScoreMultiplier;

  const ScoringConfigModel({
    this.donationsEnabled = true,
    this.donationBonus = 1,
    this.highestDonationBonus = 3.0,
    this.mostDonationsBonus = 3.0,
    this.audienceScoreMultiplier = 1,
    this.judgeScoreMultiplier = 3,
  });

  factory ScoringConfigModel.fromJson(Map<String, dynamic> json) {
    return ScoringConfigModel(
      donationsEnabled: (json['donationsEnabled'] as bool?) ?? true,
      donationBonus: (json['donationBonus'] as num?)?.toDouble() ?? 1,
      highestDonationBonus:
          (json['highestDonationBonus'] as num?)?.toDouble() ?? 3.0,
      mostDonationsBonus:
          (json['mostDonationsBonus'] as num?)?.toDouble() ?? 3.0,
      audienceScoreMultiplier: (json['audienceScoreMultiplier'] as int?) ?? 1,
      judgeScoreMultiplier: (json['judgeScoreMultiplier'] as int?) ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'donationsEnabled': donationsEnabled,
      'donationBonus': donationBonus,
      'highestDonationBonus': highestDonationBonus,
      'mostDonationsBonus': mostDonationsBonus,
      'audienceScoreMultiplier': audienceScoreMultiplier,
      'judgeScoreMultiplier': judgeScoreMultiplier,
    };
  }

  ScoringConfigModel copyWith({
    bool? donationsEnabled,
    double? donationBonus,
    double? highestDonationBonus,
    double? mostDonationsBonus,
    int? audienceScoreMultiplier,
    int? judgeScoreMultiplier,
  }) {
    return ScoringConfigModel(
      donationsEnabled: donationsEnabled ?? this.donationsEnabled,
      donationBonus: donationBonus ?? this.donationBonus,
      highestDonationBonus:
          highestDonationBonus ?? this.highestDonationBonus,
      mostDonationsBonus: mostDonationsBonus ?? this.mostDonationsBonus,
      audienceScoreMultiplier:
          audienceScoreMultiplier ?? this.audienceScoreMultiplier,
      judgeScoreMultiplier:
          judgeScoreMultiplier ?? this.judgeScoreMultiplier,
    );
  }

  @override
  List<Object?> get props => [
        donationsEnabled,
        donationBonus,
        highestDonationBonus,
        mostDonationsBonus,
        audienceScoreMultiplier,
        judgeScoreMultiplier,
      ];
}
