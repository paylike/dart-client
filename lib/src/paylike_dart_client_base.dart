import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:paylike_dart_request/paylike_dart_request.dart';

import 'dto.dart';
import 'request.dart';

/// Describes endpoints used.
class PaylikeHosts {
  String api = 'https://b.paylike.io';
  String vault = 'https://vault.paylike.io';
  String applePayAPI = 'https://applepay.paylike.io/token';
  PaylikeHosts();

  /// Creates a new PaylikeHosts from two given URLs.
  PaylikeHosts.from(this.api, this.vault);
}

/// TokenizeTypes describe the options for tokenizing card number and code
enum TokenizeTypes {
  /// For card number
  PCN,

  /// For CVC codes
  PCSC,
}

/// Handles high level requests towards the paylike ecosystem
class PaylikeClient {
  /// Generates a new client ID
  static String _generateClientID() {
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    var _rnd = Random();
    String getRandomString(int length) =>
        String.fromCharCodes(Iterable.generate(
            length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
    return 'dart-1-${getRandomString(6)}';
  }

  /// SDK Client ID used while making requests
  ///
  /// Note: This is not the merchant's client ID
  String clientId = _generateClientID();

  /// For testing purposes
  PaylikeClient.withSpecificClientId(this.clientId);
  PaylikeClient();

  /// Logger function
  Function log = (dynamic o) => print('''
  ${jsonEncode(o)}
  ''');

  /// Underlying implementation to do requests
  PaylikeRequester requester = PaylikeRequester();

  /// Timeout to use while making requests
  Duration timeout = Duration(seconds: 20);

  /// Host APIs
  PaylikeHosts hosts = PaylikeHosts();

  /// Overrides the used requester.
  PaylikeClient setRequester(PaylikeRequester requester) {
    this.requester = requester;
    return this;
  }

  /// Overrides the used logger.
  PaylikeClient setLog(void Function(dynamic d) log) {
    this.log = log;
    return this;
  }

  /// Overrides the timeout settings.
  PaylikeClient setTimeout(Duration timeout) {
    this.timeout = timeout;
    return this;
  }

  /// Overrides hosts.
  PaylikeClient setHosts(PaylikeHosts hosts) {
    this.hosts = hosts;
    return this;
  }

  /// Tokenize is used to acquire tokens from the vault
  /// with retry mechanism used.
  PaylikeRequestBuilder<TokenizedResponse> tokenize(
      TokenizeTypes type, String value) {
    return PaylikeRequestBuilder(() => _tokenize(type, value));
  }

  /// Used for the tokenization of a token acquired during apple payment flow
  PaylikeRequestBuilder<TokenizedResponse> tokenizeApple(String value) {
    return PaylikeRequestBuilder(() => _tokenizeApple(value));
  }

  /// Used to acquire tokens from the vault.
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

  /// Used to acquire tokens for apple pay
  Future<TokenizedResponse> _tokenizeApple(String value) async {
    var opts = RequestOptions.fromClientId(clientId)
        .setData({
          'token': value,
        })
        .setVersion(1)
        .setTimeout(timeout);
    var response = await requester.request(hosts.applePayAPI, opts);
    var body = await response.getBody();
    return TokenizedResponse.fromJSON(jsonDecode(body));
  }

  /// Payment create calls the capture API
  /// with retry mechanism used
  PaylikeRequestBuilder<PaylikeClientResponse> paymentCreate({
    required Map<String, dynamic> payment,
    List<String> hints = const [],
  }) {
    return PaylikeRequestBuilder(() => _paymentCreate(payment, hints, null));
  }

  /// Payment create calls the payment API
  Future<PaylikeClientResponse> _paymentCreate(Map<String, dynamic> payment,
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
    log({
      't': 'response-body',
      'data': body,
    });
    if (body['challenges'] != null &&
        (body['challenges'] as List<dynamic>).isNotEmpty) {
      var remainingChallenges = (body['challenges'] as List<dynamic>)
          .map((e) => PaymentChallenge.fromJSON(e));
      var fetchChallenges = remainingChallenges.where((c) => c.type == 'fetch');
      if (fetchChallenges.isNotEmpty) {
        return _paymentCreate(payment, hints, fetchChallenges.first.path);
      }
      var tdsChallenges = remainingChallenges.where(
          (c) => c.type == 'background-iframe' && c.name == 'tds-fingerprint');
      if (tdsChallenges.isNotEmpty) {
        return _paymentCreate(payment, hints, tdsChallenges.first.path);
      }
      return _paymentCreate(payment, hints, remainingChallenges.first.path);
    }
    // IFRAME
    if (body['action'] != null && body['fields'] != null) {
      var refreshedHints = hints;
      if (body['hints'] != null) {
        refreshedHints =
            <String>{...hints, ...HintsResponse.fromJSON(body).hints}.toList();
      }
      var formResp = await requester.request(
          Uri.parse(body['action']).toString(),
          RequestOptions(
              form: true,
              formFields: (body['fields'] as Map<String, dynamic>)
                  .map((key, value) => MapEntry(key, value.toString()))));
      return PaylikeClientResponse(
          isHTML: true,
          HTMLBody: await formResp.getBody(),
          hints: refreshedHints);
    }
    if (body['hints'] != null && (body['hints'] as List<dynamic>).isNotEmpty) {
      var hintsResp = HintsResponse.fromJSON(body);
      return _paymentCreate(
          payment, <String>{...hints, ...hintsResp.hints}.toList(), null);
    }
    return PaylikeClientResponse(
        isHTML: false, paymentResponse: PaymentResponse.fromJSON(body));
  }
}
