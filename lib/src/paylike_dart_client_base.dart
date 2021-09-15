import 'dart:async';
import 'dart:convert';
import 'package:paylike_dart_request/paylike_dart_request.dart';

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

// Handles high level requests towards the paylike ecosystem
class PaylikeClient {
  String clientId = 'dart-c-1';
  PaylikeClient(this.clientId);
  Function log = (dynamic o) => print(o);
  PaylikeRequester requester = PaylikeRequester();
  Duration timeout = Duration(seconds: 20);
  PaylikeHosts hosts = PaylikeHosts();

  // Tokenize is used to acquire tokens from the vault
  // TODO: ADD OPTS
  Future<TokenizedResponse> tokenize(TokenizeTypes type, String value) async {
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
  // TODO: ADD OPTS
  Future<PaymentResponse> paymenCreate(Map<String, dynamic> payment,
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
    print(body);
    if (body['challenges'] != null &&
        (body['challenges'] as List<dynamic>).isNotEmpty) {
      var fetchChallenge = (body['challenges'] as List<dynamic>)
          .map((e) => PaymentChallenge.fromJSON(e))
          .where((c) => c.type == 'fetch')
          .first;
      return paymenCreate(payment, hints, fetchChallenge.path);
    }
    if (body['hints'] != null && (body['hints'] as List<dynamic>).isNotEmpty) {
      var hintsResp = HintsResponse.fromJSON(body);
      return paymenCreate(payment, [...hints, ...hintsResp.hints], null);
    }
    return PaymentResponse.fromJSON(body);
  }
}
