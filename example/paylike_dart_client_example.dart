import 'package:paylike_dart_client/paylike_dart_client.dart';

void main() {
  var client = PaylikeClient('MY_CLIENT_ID')
      .setHosts(
          PaylikeHosts.from('https://b.paylike.io', 'https://vault.paylike.io'))
      .setLog((dynamic a) => print(a))
      .setTimeout(Duration(seconds: 20));

  () async {
    String cardNumberToken;
    String cardCodeToken;
    {
      var request = client
          .tokenize(TokenizeTypes.PCN, '4100000000000000') // Card Number
          .withDefaultRetry();
      var response = await request.execute();
      cardNumberToken = response.token;
    }
    {
      var request = client
          .tokenize(TokenizeTypes.PCSC, '111') // Card Number
          .withDefaultRetry();
      var response = await request.execute(); // CVC
      cardCodeToken = response.token;
    }
    {
      var payment = {
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
            'token': cardNumberToken,
          },
          'code': {
            'token': cardCodeToken,
          },
          'expiry': {'month': 12, 'year': 2022},
        },
      };
      var request = client.paymentCreate(payment).withDefaultRetry();
      var response = await request.execute();
      print('Acquried transaction reference: ' + response.transaction.id);
      // ... Store transaction ID
    }
  }()
      .then((_) => print('payment created'))
      .catchError((e) => print(e));
}
