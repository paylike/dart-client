import 'dart:async';
import 'dart:convert';
import 'package:paylike_dart_request/paylike_dart_request.dart';

// RetryException is used for throwing an exception
// when retry count is reached
class RetryException implements Exception {
  late int attempts;
  String cause = 'Reached maximum attempts in retrying';
  RetryException.fromAttempt(this.attempts);
}

// Describes endpoints used
class PaylikeHosts {
  String api = 'https://b.paylike.io';
  String vault = 'https://vault.paylike.io';
  PaylikeHosts();
  PaylikeHosts.from(this.api, this.vault);
}

// TokenizeTypes describe the options for tokenizing card number and code
// PCN -> Card Number
// PCSC -> Card Code
enum TokenizeTypes {
  PCN,
  PCSC,
}

// PaymentChallenge describes a challenge after a payment creation
// is initiated
class PaymentChallenge {
  late String name;
  late String type;
  late String path;
  PaymentChallenge.fromJSON(Map<String, dynamic> json)
      : name = json['name'],
        type = json['type'],
        path = json['path'];
}

// Describes the hints array received after executing a challenge successfully
class HintsResponse {
  late List<String> hints;
  HintsResponse.fromJSON(Map<String, dynamic> json)
      : hints = (json['hints'] as List<dynamic>).cast<String>();
}

// Describes a response from tokenize
class TokenizedResponse {
  String token;
  TokenizedResponse.fromJSON(Map<String, dynamic> json) : token = json['token'];
}

// Describes a paylike transaction
class PaylikeTransaction {
  String id;
  PaylikeTransaction(this.id);
  PaylikeTransaction.fromJSON(Map<String, dynamic> json)
      : id = json['authorizationId'] ?? json['transactionId'];
}

// Describes a payment response
class PaymentResponse {
  PaylikeTransaction transaction;
  Map<String, dynamic>? custom;
  PaymentResponse.fromJSON(Map<String, dynamic> json)
      : transaction = PaylikeTransaction.fromJSON(json),
        custom = json['custom'];
}

// RetryHandler describes the interfaces of a retry handler
abstract class RetryHandler<T> {
  Future<T> retry(Future<T> Function() executor);
}

// DefaultRetryHandler is used as the default retry backoff
// mechanism for handling RateLimitExceptions
class DefaultRetryHandler<T> implements RetryHandler<T> {
  int attempts = 0;
  Duration getRetryAfter(Duration? retryAfter) {
    var usedDuration = retryAfter ?? Duration(milliseconds: 0);
    if (retryAfter == null) {
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
    }
    return usedDuration;
  }

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
      await Future.delayed(getRetryAfter(e.retryAfter));
    } catch (e) {
      rethrow;
    }
    return retry(executor);
  }
}

// PaylikeRequestBuilder provides a flexible way to add
// custom retry mechanism into the flow
class PaylikeRequestBuilder<T> {
  late Future<T> Function() fn;
  RetryHandler<T> retryHandler = DefaultRetryHandler<T>();
  bool retryEnabled = false;
  PaylikeRequestBuilder(this.fn);
  // Receives a custom retry implementation and enables retry mechanism
  PaylikeRequestBuilder<T> withRetry(RetryHandler<T> retryHandler) {
    this.retryHandler = retryHandler;
    retryEnabled = true;
    return this;
  }

  // Enables default retry - backoff mechanism
  PaylikeRequestBuilder<T> withDefaultRetry() {
    retryEnabled = true;
    return this;
  }

  // Executes the request
  Future<T> execute() {
    return retryEnabled ? retryHandler.retry(fn) : fn();
  }
}

// Handles high level requests towards the paylike ecosystem
class PaylikeClient {
  String clientId = 'dart-c-1';
  PaylikeClient(this.clientId);
  Function log = (dynamic o) => print(o);
  PaylikeRequester requester = PaylikeRequester();
  Duration timeout = Duration(seconds: 20);
  PaylikeHosts hosts = PaylikeHosts();

  // Overrides the used requester
  PaylikeClient setRequester(PaylikeRequester requester) {
    this.requester = requester;
    return this;
  }

  // Overrides the used logger
  PaylikeClient setLog(void Function(dynamic d) log) {
    this.log = log;
    return this;
  }

  // Overrides the timeout settings
  PaylikeClient setTimeout(Duration timeout) {
    this.timeout = timeout;
    return this;
  }

  // Overrides hosts
  PaylikeClient setHosts(PaylikeHosts hosts) {
    this.hosts = hosts;
    return this;
  }

  // Tokenize is used to acquire tokens from the vault
  // with retry mechanism used
  PaylikeRequestBuilder<TokenizedResponse> tokenize(
      TokenizeTypes type, String value) {
    return PaylikeRequestBuilder<TokenizedResponse>(
        () => _tokenize(type, value));
  }

  // tokenizeRequest is used to acquire tokens from the vault
  Future<TokenizedResponse> _tokenize(TokenizeTypes type, String value) async {
    var opts = RequestOptions.fromClientId(clientId)
        .setData({
          'type': type == TokenizeTypes.PCN ? 'pcn' : 'pcsc',
          'value': value,
        })
        .setVersion(1)
        .setTimeout(timeout);
    var response = await requester.request(hosts.vault, opts);
    var body = await response.getBody();
    return TokenizedResponse.fromJSON(jsonDecode(body));
  }

  // Payment create calls the capture API
  PaylikeRequestBuilder<PaymentResponse> paymentCreate(
      Map<String, dynamic> payment) {
    return PaylikeRequestBuilder(() => _paymentCreate(payment, [], null));
  }

  Future<PaymentResponse> _paymentCreate(Map<String, dynamic> payment,
      List<String> hints, String? challengePath) async {
    var subPath = challengePath ?? '/payments';
    var url = hosts.api + subPath;
    var opts = RequestOptions.fromClientId(clientId)
        .setData({
          ...payment,
          'hints': hints,
        })
        .setVersion(1)
        .setTimeout(timeout);
    var response = await requester.request(url, opts);
    Map<String, dynamic> body = jsonDecode(await response.getBody());
    if (body['challenges'] != null &&
        (body['challenges'] as List<dynamic>).isNotEmpty) {
      var fetchChallenge = (body['challenges'] as List<dynamic>)
          .map((e) => PaymentChallenge.fromJSON(e))
          .where((c) => c.type == 'fetch')
          .first;
      return _paymentCreate(payment, hints, fetchChallenge.path);
    }
    if (body['hints'] != null && (body['hints'] as List<dynamic>).isNotEmpty) {
      var hintsResp = HintsResponse.fromJSON(body);
      return _paymentCreate(payment, [...hints, ...hintsResp.hints], null);
    }
    return PaymentResponse.fromJSON(body);
  }
}
