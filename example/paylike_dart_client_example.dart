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
      var response = await client.tokenize(
          TokenizeTypes.PCN, '4100000000000000'); // Card number
      cardNumberToken = response.token;
    }
    {
      var response = await client.tokenize(TokenizeTypes.PCSC, '111'); // CVC
      cardCodeToken = response.token;
    }
    {
      var response = await client.paymenCreate({
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
      }, [], null);
      print('Acquried transaction reference: ' + response.transaction.id);
      // ... Store transaction ID
    }
  }()
      .then((_) => print('payment created'))
      .catchError((e) => print(e));
}
