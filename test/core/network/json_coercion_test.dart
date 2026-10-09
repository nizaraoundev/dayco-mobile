import 'package:dayco_mobile/core/network/json_coercion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonCoercion.asMap', () {
    test('passes through a JSON object', () {
      expect(JsonCoercion.asMap({'a': 1}), {'a': 1});
    });

    test('widens a Map with non-dynamic value type', () {
      final Map<dynamic, dynamic> raw = {'a': 1};
      expect(JsonCoercion.asMap(raw), {'a': 1});
    });

    test('treats an empty body as an empty object', () {
      // A 200/204 with no body is a legitimate response to a write. The previous
      // implementation threw here, which turned successful updates into errors.
      expect(JsonCoercion.asMap(null), isEmpty);
      expect(JsonCoercion.asMap(''), isEmpty);
      expect(JsonCoercion.asMap('   '), isEmpty);
    });

    test('rejects a non-object body', () {
      expect(() => JsonCoercion.asMap(42), throwsFormatException);
    });
  });

  group('JsonCoercion.asListOfMaps', () {
    test('reads a bare array', () {
      expect(JsonCoercion.asListOfMaps([
        {'id': '1'},
        {'id': '2'},
      ]), hasLength(2));
    });

    test('unwraps a Spring page', () {
      final result = JsonCoercion.asListOfMaps({
        'content': [
          {'id': '1'},
        ],
        'totalPages': 3,
      });
      expect(result, [
        {'id': '1'},
      ]);
    });

    test('unwraps a data envelope', () {
      expect(
        JsonCoercion.asListOfMaps({
          'data': [
            {'id': '9'},
          ],
        }),
        [
          {'id': '9'},
        ],
      );
    });

    test('an empty portfolio is an empty list, not an error', () {
      expect(JsonCoercion.asListOfMaps(null), isEmpty);
      expect(JsonCoercion.asListOfMaps(const []), isEmpty);
      expect(JsonCoercion.asListOfMaps(const <String, dynamic>{}), isEmpty);
    });

    test('skips non-object entries instead of failing the whole list', () {
      final result = JsonCoercion.asListOfMaps([
        {'id': '1'},
        'garbage',
        null,
        {'id': '2'},
      ]);
      expect(result, hasLength(2));
    });

    test('wraps a single object in a one-element list', () {
      expect(JsonCoercion.asListOfMaps({'id': '1'}), [
        {'id': '1'},
      ]);
    });
  });

  group('JsonCoercion.string', () {
    test('never returns null', () {
      expect(JsonCoercion.string(null), '');
      expect(JsonCoercion.string(''), '');
    });

    test('normalises the literal string "null" to empty', () {
      // The backend emits this for absent optional text fields; without this
      // the UI rendered the word "null" in client cards.
      expect(JsonCoercion.string('null'), '');
    });

    test('trims surrounding whitespace', () {
      expect(JsonCoercion.string('  DAYCO  '), 'DAYCO');
    });

    test('stringifies numbers', () {
      expect(JsonCoercion.string(12), '12');
    });
  });

  group('JsonCoercion.toDouble', () {
    test('reads num and numeric strings', () {
      expect(JsonCoercion.toDouble(36.8), 36.8);
      expect(JsonCoercion.toDouble(36), 36.0);
      expect(JsonCoercion.toDouble('10.1815'), 10.1815);
    });

    test('accepts a comma decimal separator', () {
      expect(JsonCoercion.toDouble('36,8065'), 36.8065);
    });

    test('returns null for unparseable or non-finite input', () {
      expect(JsonCoercion.toDouble(null), isNull);
      expect(JsonCoercion.toDouble(''), isNull);
      expect(JsonCoercion.toDouble('abc'), isNull);
      expect(JsonCoercion.toDouble(double.nan), isNull);
      expect(JsonCoercion.toDouble(double.infinity), isNull);
    });
  });

  group('JsonCoercion.toBool', () {
    test('reads the shapes the backend uses, including French', () {
      expect(JsonCoercion.toBool(true), isTrue);
      expect(JsonCoercion.toBool('true'), isTrue);
      expect(JsonCoercion.toBool('oui'), isTrue);
      expect(JsonCoercion.toBool(1), isTrue);
      expect(JsonCoercion.toBool('non'), isFalse);
      expect(JsonCoercion.toBool(0), isFalse);
    });

    test('falls back for unrecognised input', () {
      expect(JsonCoercion.toBool(null, fallback: true), isTrue);
      expect(JsonCoercion.toBool('peut-être'), isFalse);
    });
  });

  group('JsonCoercion.firstString', () {
    test('returns the first present non-empty key', () {
      // A client's display name arrives under a different key per entity type.
      final json = {'raisonSociale': '', 'nomAgence': 'Agence Tunis'};
      expect(
        JsonCoercion.firstString(json, ['raisonSociale', 'nomAgence', 'nom']),
        'Agence Tunis',
      );
    });

    test('returns empty when no key matches', () {
      expect(JsonCoercion.firstString({}, ['a', 'b']), '');
    });
  });

  group('JsonCoercion.stringList', () {
    test('reads roles and drops blanks', () {
      expect(JsonCoercion.stringList(['COMMERCIAL', '', null, 'ADMIN']), [
        'COMMERCIAL',
        'ADMIN',
      ]);
    });

    test('returns empty for a non-list', () {
      expect(JsonCoercion.stringList('COMMERCIAL'), isEmpty);
    });
  });
}
