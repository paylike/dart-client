# Paylike Dart API client

_This is an ALPHA release_

Although the functionality included is production quality, the supported scope
of the API is merely a stub.

High-level client for the API documented at:
https://github.com/paylike/api-reference. It is using
[paylike_dart_request](https://pub.dev/packages/paylike_dart_request) under the
hood.

## Examples

```sh
dart pub add paylike_dart_client
```

```dart
import 'package:paylike_dart_client/paylike_dart_client.dart';

void main() {
  var client = PaylikeClient('MY_CLIENT_ID');

  PaylikeRequestBuilder<TokenizedResponse> request = client.tokenize(TokenizeTypes.PCN, '1000000000000000');
  request.execute().then((response) {
    print('Received token: ' + response.token);
  }).catchError((e) => print(e));
}

```

## Methods

```dart
// client.tokenize(TokenizeTypes.PCN, '...');
// client.tokenize(TokenizeTypes.PCSC, '...');
PaylikeRequestBuilder<TokenizedResponse> tokenize(TokenizeTypes type, String value);

// client.paymentCreate(payment);
PaylikeRequestBuilder<PaymentResponse> paymenCreate({
  required Map<String, dynamic> payment,
  List<String> hints = const [],
});
```

[More information](https://github.com/paylike/api-reference/blob/main/payments/index.md) on payment data structure.

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
strategy of 10 retries with increasing delay. 
```dart
      switch (attempts) {
        case 0:
        case 1:
          usedDuration = Duration(milliseconds: 0);
          break;
        case 2:
          usedDuration = Duration(milliseconds: 100);
          break;
        case 3:
          usedDuration = Duration(seconds: 2);
          break;
        default:
          usedDuration = Duration(seconds: 10);
      }
```

Using the default retry handler is recommended which you can do by specifying on the `PaylikeRequestBuilder` you receive:
```dart
      var request = client
          .tokenize(TokenizeTypes.PCN, '4100000000000000')
          .withDefaultRetry();
      var response = await request.execute();
```
You can also create your own handler by implementing the RetryHandler abstract class:
```dart
class CustomRetryHandler<T> implements RetryHandler<T> {
  int attempts = 0;
  @override
  Future<T> retry(Future<T> Function() executor) async {
    try {
      var res = await executor();
      return res;
    } on RateLimitException catch (e) {
      attempts++;
      if (attempts > 10) {
        rethrow;
      }
      await Future.delayed(Duration(seconds: 5));
    } catch (e) {
      rethrow;
    }
    return retry(executor);
  }
}

// Then you can apply your own retry handler to the request builder:
var request = client
      .tokenize(TokenizeTypes.PCN, '4100000000000000')
      .withRetry(CustomRetryHandler<TokenizedResponse>());
var response = await request.execute();
```
