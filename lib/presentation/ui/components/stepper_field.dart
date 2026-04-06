import 'package:flutter/material.dart';
import 'package:cast_your_vote/presentation/ui/theme/app_theme.dart';

class StepperField extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const StepperField({
    super.key,
    required this.value,
    this.min = 1,
    this.max = 5,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filled(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
          style: IconButton.styleFrom(
            backgroundColor: context.colorScheme.primaryContainer,
            foregroundColor: context.colorScheme.onPrimaryContainer,
            disabledBackgroundColor: context.colorScheme.surfaceContainerHighest,
          ),
        ),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value == 0 ? '-' : value.toString(),
            style: context.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton.filled(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            backgroundColor: context.colorScheme.primaryContainer,
            foregroundColor: context.colorScheme.onPrimaryContainer,
            disabledBackgroundColor: context.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
