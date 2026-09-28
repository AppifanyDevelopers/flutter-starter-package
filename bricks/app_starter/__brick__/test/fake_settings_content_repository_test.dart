import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name}}/features/settings/data/repository/fake_settings_content_repository.dart';

void main() {
  group('FakeSettingsContentRepository.getFaqs', () {
    late FakeSettingsContentRepository repository;

    setUp(() => repository = FakeSettingsContentRepository());

    test('returns a full page when more items remain', () async {
      final result = await repository.getFaqs(page: 1, pageSize: 5);
      final items = result.fold((error) => null, (items) => items);

      expect(items, isNotNull);
      expect(items!.length, 5);
    });

    test('a page shorter than pageSize means there is no next page', () async {
      final result = await repository.getFaqs(page: 1, pageSize: 100);
      final items = result.fold((error) => null, (items) => items);

      expect(items, isNotNull);
      expect(items!.length, lessThan(100));
    });

    test('advances to a different set of items on the next page', () async {
      final firstPage = await repository.getFaqs(page: 1, pageSize: 5);
      final secondPage = await repository.getFaqs(page: 2, pageSize: 5);

      final firstQuestions = firstPage.fold((e) => <String>[], (items) => items.map((f) => f.question).toList());
      final secondQuestions = secondPage.fold((e) => <String>[], (items) => items.map((f) => f.question).toList());

      expect(firstQuestions, isNotEmpty);
      expect(secondQuestions, isNotEmpty);
      expect(firstQuestions.toSet().intersection(secondQuestions.toSet()), isEmpty);
    });

    test('filters by query against question and answer text', () async {
      final result = await repository.getFaqs(page: 1, pageSize: 50, query: 'password');
      final items = result.fold((error) => null, (items) => items);

      expect(items, isNotNull);
      expect(items, isNotEmpty);
      for (final faq in items!) {
        final matches = faq.question.toLowerCase().contains('password') ||
            faq.answer.toLowerCase().contains('password');
        expect(matches, isTrue);
      }
    });

    test('an unmatched query returns an empty page, not an error', () async {
      final result = await repository.getFaqs(page: 1, pageSize: 10, query: 'nonexistent-topic-xyz');
      final items = result.fold((error) => null, (items) => items);

      expect(items, isNotNull);
      expect(items, isEmpty);
    });
  });
}
