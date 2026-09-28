import 'package:flutter/material.dart';

/// A plain "Step X of N" label -- deliberately not an animated progress
/// bar/dots package, to keep the signup wizard's dependency footprint small.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Step $step of $totalSteps',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
