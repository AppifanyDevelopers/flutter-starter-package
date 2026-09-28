import 'package:flutter/widgets.dart';

enum TheStates { initial, success, error, loading }

extension TheStatesX on TheStates {
  bool get isLoading => this == TheStates.loading;
  bool get isSuccess => this == TheStates.success;
  bool get isError => this == TheStates.error;
  bool get isInitial => this == TheStates.initial;

  /// Renders the widget matching this state, falling back to [orElse] (or an
  /// empty box) when a specific builder for the current state isn't given.
  Widget showWidget({
    WidgetBuilder? initial,
    WidgetBuilder? success,
    WidgetBuilder? error,
    WidgetBuilder? loading,
    WidgetBuilder? orElse,
  }) {
    final builder = switch (this) {
      TheStates.initial => initial ?? orElse,
      TheStates.success => success ?? orElse,
      TheStates.error => error ?? orElse,
      TheStates.loading => loading ?? orElse,
    };
    return Builder(builder: builder ?? (_) => const SizedBox.shrink());
  }
}
