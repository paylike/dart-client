import 'package:paylike_dart_client/paylike_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final client = PaylikeClient();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(client.clientId, 'dart-c-1');
    });
  });
}
