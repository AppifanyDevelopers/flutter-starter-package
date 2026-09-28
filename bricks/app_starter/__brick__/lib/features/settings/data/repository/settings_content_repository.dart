import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/faq_item.dart';

abstract class SettingsContentRepository {
  /// Returns one page of FAQs, optionally filtered by [query] (case-insensitive
  /// substring match against question+answer). A page shorter than [pageSize]
  /// signals there's no next page -- no separate "hasMore"/total-count field,
  /// the same convention many real paginated APIs use.
  Future<Either<AppError, List<FaqItem>>> getFaqs({int page = 1, int pageSize = 10, String? query});

  Future<Either<AppError, String>> getTermsHtml();

  Future<Either<AppError, String>> getPrivacyPolicyHtml();

  Future<Either<AppError, Unit>> submitContactMessage({
    required String name,
    required String email,
    required String message,
  });
}
