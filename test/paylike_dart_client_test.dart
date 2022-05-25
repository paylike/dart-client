import 'dart:convert';
import 'dart:io';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:paylike_dart_client/paylike_dart_client.dart';
import 'package:paylike_dart_client/src/dto.dart';
import 'package:paylike_dart_client/src/request.dart';
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
      var client = PaylikeClient().setRequester(mocker.requester);
      when(mocker.requester.request(any, any))
          .thenAnswer((realInvocation) async => mocker.response);
      when(mocker.response.getBody())
          .thenAnswer((realInvocation) async => '{"token":"foo"}');
      var request = client
          .tokenize(TokenizeTypes.PCN, '4100000000000000')
          .withDefaultRetry();
      var resp = await request.execute();
      expect(resp.token, 'foo');
    });

    test('Payment creation should do challenges based on fetch type', () async {
      var mocker = Mocker();
      var counter = 0;
      var client = PaylikeClient().setRequester(mocker.requester);
      var challengeResolvedResponse = MockPaylikeResponse();
      var finalResolveResponse = MockPaylikeResponse();
      when(finalResolveResponse.getBody())
          .thenAnswer((realinvocation) async => '{"authorizationId": "foo"}');
      when(mocker.requester.request(client.hosts.api + '/payments', any))
          .thenAnswer((realInvocation) async {
        if (counter == 0) {
          counter++;
          return mocker.response;
        }
        var opts = realInvocation.positionalArguments[1] as RequestOptions;
        expect((opts.data as Map<String, dynamic>)['test'], {});
        expect((opts.data as Map<String, dynamic>)['hints'], ['hint1']);
        return finalResolveResponse;
      });
      when(mocker.response.getBody())
          .thenAnswer((realInvocation) async => jsonEncode({
                'challenges': [
                  {'name': 'challenge01', 'type': 'fetch', 'path': '/challenge'}
                ]
              }));
      when(mocker.requester.request(client.hosts.api + '/challenge', any))
          .thenAnswer((realInvocation) async => challengeResolvedResponse);
      when(challengeResolvedResponse.getBody())
          .thenAnswer((realInvocation) async => jsonEncode({
                'hints': ['hint1']
              }));
      var resp = await client
          .paymentCreate(payment: {'test': {}})
          .withDefaultRetry()
          .execute();
      expect(resp.paymentResponse, isNotNull);
      expect(resp.isHTML, false);
      expect(resp.paymentResponse?.transaction.id, 'foo');
    });

    test('Default retry mechanism should work as expected with tokenize',
        () async {
      var retryHandler = DefaultRetryHandler<TokenizedResponse>();
      try {
        await retryHandler.retry(() async {
          throw RateLimitException.withTime('200');
        });
        fail('Should not be able to reach this');
      } catch (e) {
        expect(retryHandler.attempts, 11);
        expect(e is RateLimitException, true);
      }
      retryHandler = DefaultRetryHandler<TokenizedResponse>();
      try {
        var count = 0;
        var resp = await retryHandler.retry(() async {
          count++;
          if (count == 11) {
            return TokenizedResponse.fromJSON({'token': 'foo'});
          }
          throw RateLimitException.withTime('200');
        });
        expect(retryHandler.attempts, 10);
        expect(resp.token, 'foo');
      } catch (e) {
        fail('Should not be able to reach this');
      }
    });
  });

  group('End to end tests', () {
    if (E2E_CLIENT_KEY == null || E2E_CLIENT_KEY!.isEmpty) {
      throw Exception('E2E_CLIENT_KEY is required for E2E tests');
    }
    final client = PaylikeClient();

    test('Tokenization should work as expected', () async {
      var request = client
          .tokenize(TokenizeTypes.PCN, '4100000000000000')
          .withDefaultRetry();
      var response = await request.execute();
      expect(response.token, isNotNull);
    });

    test('Payment creation should work as expected', () async {
      String cardNumber;
      String cardCode;
      {
        var request = client
            .tokenize(TokenizeTypes.PCN, '4100000000000000')
            .withDefaultRetry();
        var response = await request.execute();
        cardNumber = response.token;
      }
      {
        var request =
            client.tokenize(TokenizeTypes.PCSC, '111').withDefaultRetry();
        var response = await request.execute();
        cardCode = response.token;
      }
      var response = await client
          .paymentCreate(payment: {
            'test': {},
            'integration': {
              'key': E2E_CLIENT_KEY as String,
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
          })
          .withDefaultRetry()
          .execute();
      expect(response.isHTML, true);
      expect(response.HTMLBody, isNotNull);
      expect(response.hints, isNotEmpty);
      expect(response.paymentResponse, isNull);
    });
  }, skip: !E2E_TESTING_ENABLED);
}
