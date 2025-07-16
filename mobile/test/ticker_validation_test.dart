import 'package:flutter_test/flutter_test.dart';
import 'package:letagentsdyor_app/ticker_utils.dart';

void main() {
  group('isValidTicker', () {
    test('rejects lowercase and special chars', () {
      expect(isValidTicker('tesla'), isFalse);
      expect(isValidTicker('TSLA!'), isFalse);
    });

    test('accepts uppercase alphanumerics', () {
      expect(isValidTicker('TSLA'), isTrue);
      expect(isValidTicker('BRK.A'), isTrue);
    });
  });
}
