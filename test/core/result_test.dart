import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value and folds to the ok branch', () {
      const Result<int> result = Ok<int>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
      expect(
        result.fold<int>(
          ok: (int value) => value,
          err: (AppException error) => -1,
        ),
        42,
      );
    });

    test('Err exposes its error and folds to the err branch', () {
      const Result<int> result = Err<int>(NotFoundException('nope'));
      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, isA<NotFoundException>());
      expect(
        result.fold<int>(
          ok: (int value) => value,
          err: (AppException error) => -1,
        ),
        -1,
      );
    });
  });
}
