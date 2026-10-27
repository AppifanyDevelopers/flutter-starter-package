// Scaffolds a feature in this app's conventions: model, repository interface
// plus a fake implementation, GetX controller (loading/error/empty/refresh),
// screen, bindings, an AuthGuard-protected route, and a controller test.
//
//   dart run tool/new_feature.dart orders
//   dart run tool/new_feature.dart order_history --item Order
//
//   <feature>      lower_snake_case folder name under lib/features/
//   --item <Name>  model class name (default: <Feature>Item)
//   --no-route     do not touch core/routes/app_routes.dart
//
// Run it from the app's root. Works in a standalone app and in a monorepo app
// (it detects the shared `<base>_common` package and imports from it).
// No packages needed -- plain `dart`.

import 'dart:io';

Never _fail(String message) {
  stderr.writeln('new_feature: $message');
  exit(64);
}

String _pascal(String snake) => snake.split('_').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();

String _camel(String snake) {
  final p = _pascal(snake);
  return p[0].toLowerCase() + p.substring(1);
}

String _snakeOfPascal(String pascal) => pascal
    .replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => '_${m.group(1)}')
    .toLowerCase();

void main(List<String> args) {
  final positional = <String>[];
  String? item;
  var addRoute = true;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--item':
        if (i + 1 >= args.length) _fail('--item needs a class name.');
        item = args[++i];
      case '--no-route':
        addRoute = false;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.length != 1) {
    _fail('usage: dart run tool/new_feature.dart <feature_snake_case> [--item ClassName] [--no-route]');
  }

  final feature = positional.single;
  if (!RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$').hasMatch(feature)) {
    _fail('"$feature" must be lower_snake_case (e.g. order_history).');
  }
  final itemClass = item ?? '${_pascal(feature)}Item';
  if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(itemClass)) {
    _fail('--item "$itemClass" must be a PascalCase class name.');
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync() || !Directory('lib/features').existsSync()) {
    _fail('run this from the app root (pubspec.yaml and lib/features/ not found).');
  }
  final pubspecText = pubspec.readAsStringSync();
  final package = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspecText)!.group(1)!;
  final commonPackage = RegExp(r'^  (\w+_common):', multiLine: true).firstMatch(pubspecText)?.group(1);

  final featureDir = Directory('lib/features/$feature');
  if (featureDir.existsSync()) _fail('lib/features/$feature already exists; nothing was changed.');

  final itemFile = _snakeOfPascal(itemClass);
  final values = <String, String>{
    '__PACKAGE__': package,
    '__FEATURE__': feature,
    '__CLASS__': _pascal(feature),
    '__TITLE__': _pascal(feature).replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => ' ${m.group(1)}'),
    '__ITEM__': itemClass,
    '__ITEM_FILE__': itemFile,
    '__ROUTE_CONST__': _camel(feature),
    '__ROUTE_PATH__': '/${feature.replaceAll('_', '-')}',
    // Widgets live in the app's core/ for a standalone app, in <base>_common for a monorepo app.
    '__COMMON_IMPORTS__': commonPackage == null
        ? "import '../../../../core/widgets/app_error_widget.dart';\n"
            "import '../../../../core/widgets/app_scaffold.dart';\n"
            "import '../../../../core/widgets/app_shimmer.dart';"
        : "import 'package:$commonPackage/$commonPackage.dart';",
  };

  String render(String template) =>
      values.entries.fold(template, (text, e) => text.replaceAll(e.key, e.value));

  final files = <String, String>{
    'lib/features/$feature/data/model/$itemFile.dart': _model,
    'lib/features/$feature/data/repository/${feature}_repository.dart': _repository,
    'lib/features/$feature/data/repository/fake_${feature}_repository.dart': _fakeRepository,
    'lib/features/$feature/presentation/controllers/${feature}_controller.dart': _controller,
    'lib/features/$feature/presentation/screens/${feature}_screen.dart': _screen,
    'lib/features/$feature/presentation/bindings/${feature}_bindings.dart': _bindings,
    'test/${feature}_controller_test.dart': _test,
  };

  for (final entry in files.entries) {
    final file = File(entry.key)..createSync(recursive: true);
    file.writeAsStringSync(render(entry.value));
    stdout.writeln('created ${entry.key}');
  }

  if (addRoute) {
    final routes = File('lib/core/routes/app_routes.dart');
    final text = routes.existsSync() ? routes.readAsStringSync() : '';
    final updated = _addRoute(text, render, feature);
    if (updated == null) {
      stdout.writeln('\nCould not find the expected spots in lib/core/routes/app_routes.dart, so the route was '
          'not added. Add this yourself:\n${render(_routeSnippet)}');
    } else {
      routes.writeAsStringSync(updated);
      stdout.writeln('updated lib/core/routes/app_routes.dart (AppRoutes.${values['__ROUTE_CONST__']}, behind AuthGuard)');
    }
  }

  stdout.writeln('\nNext: dart analyze && flutter test test/${feature}_controller_test.dart');
  stdout.writeln('Then replace the Fake${values['__CLASS__']}Repository with a real one (see TODO(swap-backend)).');
}

String? _addRoute(String text, String Function(String) render, String feature) {
  const classAnchor = 'abstract class AppRoutes {\n  AppRoutes._();\n';
  const pagesAnchor = 'static final pages = <GetPage>[\n';
  const guardImport = "import 'auth_guard.dart';";
  if (!text.contains(classAnchor) || !text.contains(pagesAnchor) || !text.contains(guardImport)) return null;

  return text
      .replaceFirst(
        guardImport,
        render("import '../../features/__FEATURE__/presentation/bindings/__FEATURE___bindings.dart';\n"
            "import '../../features/__FEATURE__/presentation/screens/__FEATURE___screen.dart';\n") +
            guardImport,
      )
      .replaceFirst(classAnchor, '$classAnchor\n${render("  static const __ROUTE_CONST__ = '__ROUTE_PATH__';\n")}')
      .replaceFirst(
        pagesAnchor,
        '$pagesAnchor${render('''
    GetPage(
      name: __ROUTE_CONST__,
      page: __CLASS__Screen.new,
      binding: __CLASS__Bindings(),
      middlewares: [AuthGuard()],
    ),
''')}',
      );
}

const _routeSnippet = r'''
  static const __ROUTE_CONST__ = '__ROUTE_PATH__';

  GetPage(
    name: __ROUTE_CONST__,
    page: __CLASS__Screen.new,
    binding: __CLASS__Bindings(),
    middlewares: [AuthGuard()],
  ),
''';

const _model = r'''
/// One entry of the __TITLE__ list. Replace the fields with your API's, and
/// parse defensively: never `as String` on a value that can be null.
class __ITEM__ {
  const __ITEM__({required this.id, required this.title});

  factory __ITEM__.fromJson(Map<String, dynamic> json) => __ITEM__(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
      );

  final int id;
  final String title;
}
''';

const _repository = r'''
// `show`: dartz also exports an `Order`, which would clash with a model of that name.
import 'package:dartz/dartz.dart' show Either;

import '../../../../core/errors/app_error.dart';
import '../model/__ITEM_FILE__.dart';

abstract class __CLASS__Repository {
  Future<Either<AppError, List<__ITEM__>>> getAll();
}
''';

const _fakeRepository = r'''
import 'package:dartz/dartz.dart' show Either, right;

import '../../../../core/errors/app_error.dart';
import '../model/__ITEM_FILE__.dart';
import '__FEATURE___repository.dart';

/// Placeholder data so the screen works before the backend does.
/// TODO(swap-backend): replace with a Dio__CLASS__Repository.
class Fake__CLASS__Repository implements __CLASS__Repository {
  @override
  Future<Either<AppError, List<__ITEM__>>> getAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return right(const [
      __ITEM__(id: 1, title: 'First __TITLE__'),
      __ITEM__(id: 2, title: 'Second __TITLE__'),
      __ITEM__(id: 3, title: 'Third __TITLE__'),
    ]);
  }
}
''';

const _controller = r'''
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../data/model/__ITEM_FILE__.dart';
import '../../data/repository/__FEATURE___repository.dart';

class __CLASS__Controller extends GetxController {
  __CLASS__Controller(this._repository);

  final __CLASS__Repository _repository;

  final state = TheStates.loading.obs;
  final errorMessage = ''.obs;
  final items = <__ITEM__>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// First load and "Retry": shows the shimmer.
  Future<void> load() async {
    state.value = TheStates.loading;
    final result = await _repository.getAll();
    result.fold(
      (error) {
        errorMessage.value = error.message;
        state.value = TheStates.error;
      },
      (list) {
        items.assignAll(list);
        state.value = TheStates.success;
      },
    );
  }

  /// Pull-to-refresh: never switches to the shimmer (that would replace the
  /// list and cancel the refresh indicator) and keeps the old list on failure.
  Future<void> pullToRefresh() async {
    final result = await _repository.getAll();
    result.fold(
      (error) => Get.snackbar('Could not refresh', error.message),
      (list) {
        items.assignAll(list);
        state.value = TheStates.success;
      },
    );
  }
}
''';

const _screen = r'''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
__COMMON_IMPORTS__
import '../controllers/__FEATURE___controller.dart';

class __CLASS__Screen extends GetView<__CLASS__Controller> {
  const __CLASS__Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '__TITLE__',
      body: Obx(
        () => controller.state.value.showWidget(
          loading: (_) => const _Shimmer(),
          error: (_) => AppErrorWidget(message: controller.errorMessage.value, onRetry: controller.load),
          orElse: (_) => RefreshIndicator(
            onRefresh: controller.pullToRefresh,
            child: controller.items.isEmpty
                ? ListView(
                    // Scrollable, so pull-to-refresh also works on an empty list.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Nothing here yet.')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => ListTile(title: Text(controller.items[index].title)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppShimmer.box(height: 56),
    );
  }
}
''';

const _bindings = r'''
import 'package:get/get.dart';

import '../../data/repository/fake___FEATURE___repository.dart';
import '../../data/repository/__FEATURE___repository.dart';
import '../controllers/__FEATURE___controller.dart';

class __CLASS__Bindings extends Bindings {
  @override
  void dependencies() {
    Get
      // TODO(swap-backend): replace with a real Dio__CLASS__Repository(Get.find()).
      ..lazyPut<__CLASS__Repository>(Fake__CLASS__Repository.new)
      ..lazyPut(() => __CLASS__Controller(Get.find()));
  }
}
''';

const _test = r'''
import 'package:dartz/dartz.dart' show Either, left, right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:__PACKAGE__/core/enums/the_states.dart';
import 'package:__PACKAGE__/core/errors/app_error.dart';
import 'package:__PACKAGE__/features/__FEATURE__/data/model/__ITEM_FILE__.dart';
import 'package:__PACKAGE__/features/__FEATURE__/data/repository/__FEATURE___repository.dart';
import 'package:__PACKAGE__/features/__FEATURE__/presentation/controllers/__FEATURE___controller.dart';
import 'package:__PACKAGE__/features/__FEATURE__/presentation/screens/__FEATURE___screen.dart';

class _Repo implements __CLASS__Repository {
  _Repo(this.result);
  Either<AppError, List<__ITEM__>> result;

  @override
  Future<Either<AppError, List<__ITEM__>>> getAll() async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const one = __ITEM__(id: 1, title: 'One');
  const two = __ITEM__(id: 2, title: 'Two');

  test('load: success fills the list', () async {
    final controller = __CLASS__Controller(_Repo(right(const [one, two])));
    expect(controller.state.value, TheStates.loading);

    await controller.load();

    expect(controller.state.value, TheStates.success);
    expect(controller.items.map((i) => i.id), [1, 2]);
  });

  test('load: failure shows the error and its message', () async {
    final controller = __CLASS__Controller(_Repo(left(const InternalAppError(message: 'Boom'))));

    await controller.load();

    expect(controller.state.value, TheStates.error);
    expect(controller.errorMessage.value, 'Boom');
  });

  test('load: an empty result is success, not an error', () async {
    final controller = __CLASS__Controller(_Repo(right(const [])));

    await controller.load();

    expect(controller.state.value, TheStates.success);
    expect(controller.items, isEmpty);
  });

  test('pullToRefresh replaces the list without ever showing the shimmer', () async {
    final repo = _Repo(right(const [one]));
    final controller = __CLASS__Controller(repo);
    await controller.load();

    repo.result = right(const [one, two]);
    final states = <TheStates>[];
    final stop = controller.state.listen(states.add);
    await controller.pullToRefresh();
    stop.cancel();

    expect(controller.items.length, 2);
    expect(states, isNot(contains(TheStates.loading)));
  });

  testWidgets('pullToRefresh failure keeps the old list', (tester) async {
    // Get.snackbar needs an overlay, so mount a GetMaterialApp.
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final repo = _Repo(right(const [one]));
    final controller = __CLASS__Controller(repo);
    await controller.load();

    repo.result = left(const InternalAppError(message: 'Offline'));
    await controller.pullToRefresh();
    await tester.pump(const Duration(seconds: 5));

    expect(controller.items.map((i) => i.id), [1]);
    expect(controller.state.value, TheStates.success);
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester, _Repo repo) async {
      Get.testMode = true;
      Get.reset();
      Get.put(__CLASS__Controller(repo));
      await tester.pumpWidget(const GetMaterialApp(home: __CLASS__Screen()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the items', (tester) async {
      await pumpScreen(tester, _Repo(right(const [one, two])));
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
    });

    testWidgets('shows an empty message when there is nothing', (tester) async {
      await pumpScreen(tester, _Repo(right(const [])));
      expect(find.text('Nothing here yet.'), findsOneWidget);
    });

    testWidgets('shows the error with a Retry that loads again', (tester) async {
      final repo = _Repo(left(const InternalAppError(message: 'Offline')));
      await pumpScreen(tester, repo);
      expect(find.text('Offline'), findsOneWidget);

      repo.result = right(const [one]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
    });
  });
}
''';
