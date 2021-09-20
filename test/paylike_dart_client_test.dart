import 'package:paylike_dart_client/paylike_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('Essential tests', () {
    final client = PaylikeClient('e393f9ec-b2f7-4f81-b455-ce45b02d355d');

    test('Tokenization should work as expected', () async {
      var response =
          await client.tokenize(TokenizeTypes.PCN, '4100000000000000');
      expect(response.token, isNotNull);
    });

    test('Payment creation should work as expected', () async {
      String cardNumber;
      String cardCode;
      {
        var response =
            await client.tokenize(TokenizeTypes.PCN, '4100000000000000');
        cardNumber = response.token;
      }
      {
        var response = await client.tokenize(TokenizeTypes.PCSC, '111');
        cardCode = response.token;
      }
      var response = await client.paymenCreate({
        'test': {},
        'integration': {
          'key': client.clientId,
        },
        'amount': {
          'currency': 'EUR',
          'value': 1000,
          'exponent': 0,
        },
        'card': {
          'number': {
            'token': cardNumber,
          },
          'code': {
            'token': cardCode,
          },
          'expiry': {'month': 12, 'year': 2022},
        },
      }, [], null);
      expect(response.transaction.id, isNotNull);
    });
  });
}
