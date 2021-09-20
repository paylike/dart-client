import 'dart:io';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:paylike_dart_client/paylike_dart_client.dart';
import 'package:paylike_dart_request/paylike_dart_request.dart';
import 'package:test/test.dart';

import 'paylike_dart_client_test.mocks.dart';

class Mocker {
  var response = MockPaylikeResponse();
  var requester = MockPaylikeRequester();
}

var E2E_TESTING_ENABLED = Platform.environment['E2E_TEST'] == 'true';
var E2E_CLIENT_KEY = Platform.environment['E2E_CLIENT_KEY'];

@GenerateMocks([PaylikeRequester, PaylikeResponse])
void main() {
  group('Essential tests', () {
    test('Tokenization should be able to provide back a token', () async {
      var mocker = Mocker();
      var client = PaylikeClient('CLIENT_ID').setRequester(mocker.requester);
      var opts = RequestOptions.fromClientId(client.clientId)
          .setData({
            'type': 'pcn',
            'value': '4100000000000000',
          })
          .setVersion(1)
          .setTimeout(client.timeout);

      when(mocker.requester.request(client.hosts.vault, opts))
          .thenAnswer((realInvocation) {
        return Future.value(mocker.response);
      });
    });
  });
  group('End to end tests', () {
    if (E2E_CLIENT_KEY == null || E2E_CLIENT_KEY!.isEmpty) {
      throw Exception('E2E_CLIENT_KEY is required for E2E tests');
    }
    final client = PaylikeClient(E2E_CLIENT_KEY as String);

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
  }, skip: !E2E_TESTING_ENABLED);
}
