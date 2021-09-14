import 'package:paylike_dart_client/paylike_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('Essential tests', () {
    final client = PaylikeClient('e393f9ec-b2f7-4f81-b455-ce45b02d355d');

    setUp(() {
      // Additional setup goes here.
    });

    test('Tokenization should work as expected', () async {
      var response =
          await client.tokenize(TokenizeTypes.PCN, '1234123412341234');
      expect(response.token, isNotNull);
    });
  });
}
