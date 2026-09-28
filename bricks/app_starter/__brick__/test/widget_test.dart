import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name}}/core/enums/the_states.dart';

void main() {
  group('TheStates.showWidget', () {
    testWidgets('renders the builder matching the current state', (tester) async {
      const state = TheStates.loading;

      await tester.pumpWidget(
        MaterialApp(
          home: state.showWidget(
            loading: (_) => const Text('loading'),
            success: (_) => const Text('success'),
            error: (_) => const Text('error'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('success'), findsNothing);
    });

    testWidgets('falls back to orElse when no builder matches the state', (tester) async {
      const state = TheStates.initial;

      await tester.pumpWidget(
        MaterialApp(
          home: state.showWidget(
            success: (_) => const Text('success'),
            orElse: (_) => const Text('fallback'),
          ),
        ),
      );

      expect(find.text('fallback'), findsOneWidget);
    });
  });
}
