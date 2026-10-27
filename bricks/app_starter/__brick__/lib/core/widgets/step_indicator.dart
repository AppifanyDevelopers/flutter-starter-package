import 'package:flutter/material.dart';

/// "Step X of N" header with a segmented progress bar -- deliberately not a
/// package, to keep the signup wizard's dependency footprint small.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.step, required this.totalSteps, this.label});

  final int step;
  final int totalSteps;

  /// What this step is, e.g. "Basic details".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label == null ? 'Step $step of $totalSteps' : 'Step $step of $totalSteps: $label',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= totalSteps; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < totalSteps) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}
