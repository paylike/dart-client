# Paylike Dart API client

_This is an ALPHA release_

Although the functionality included is production quality, the supported scope
of the API is merely a stub.

High-level client for the API documented at:
https://github.com/paylike/api-reference. It is using
[paylike/request](https://www.npmjs.com/package/@paylike/request) under the
hood.

## Examples

```sh
dart pub add paylike_dart_client
```

```dart
import 'package:paylike_dart_client/paylike_dart_client.dart';

void main() {
  var client = PaylikeClient('MY_CLIENT_ID');

  Future<TokenizedResponse> request = client.tokenize(TokenizeTypes.PCN, '1000000000000000');
  request.then((response) {
    print('Received token: ' + response.token);
  }).catchError((e) => print(e));
}

```

## Methods

```dart
// client.tokenize(TokenizeTypes.PCN, '...');
// client.tokenize(TokenizeTypes.PCSC, '...');
Future<TokenizedResponse> tokenize(TokenizeTypes type, String value)

// client.paymentCreate(payment, [], null);
Future<PaymentResponse> paymenCreate(
      Map<String, dynamic> payment,
      List<String> hints,
      String? challengePath
)
```

## Error handling

The methods may throw any error forwarded from the used PaylikeRequester implementation as
well as one of the below error classes.

- `RateLimitException`

  May have a `retryAfter` (Duration) property if sent by the server
  specifying the minimum delay.

- `TimeoutException`

  Comes from `dart:async` library https://api.dart.dev/be/169657/dart-async/TimeoutException-class.html

- `ServerErrorException`

  Has `status` and `headers` properties copied from the io.HttpClientResponse

- `PaylikeException`

  These errors correspond to
  [status codes](https://github.com/paylike/api-reference/blob/master/status-codes.md)
  from the API reference. They have at least a `code` and `message` property,
  but may also have other useful properties relevant to the specific error code,
  such as a minimum and maximum for amounts.

## Logging

Pass a log function of the format `void Function(dynamic d)` to catch internal (structured)
logging.

```dart
  var client = PaylikeClient('MY_CLIENT_ID').setLog((dynamic d) => print(d))
```

## Timeouts and retries

There is a default timeout for all HTTPS requests of 10 seconds and a retry
strategy of 10 retries with increasing delay (check the source for details). The
default maximum timeout (retries and timeouts accumulated) is 72,100
milliseconds.

Both of these parameters can be customized:

```js
const server = require('@paylike/client')({
  timeout: 10000,
  retryAfter: (err, attempts) => {
    // err = current error
    // attempts = total attempts so far
    return false // no more attempts (err will be returned to the client)
    // or
    return 1000 // retry after this many milliseconds
  },
})
```

Both options can be set on the factory or the individual method.
