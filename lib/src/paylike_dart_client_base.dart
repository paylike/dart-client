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

enum TokenizeTypes {
  PCN,
  PCSC,
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
  PaylikeTransaction.fromJSON(Map<String, dynamic> json) : id = json['id'];
}

// Describes a payment response
class PaymentResponse {
  PaylikeTransaction transaction;
  Map<String, dynamic> custom;
  PaymentResponse.fromJSON(Map<String, dynamic> json)
      : transaction = json['transaction'],
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
    var body = await response.getBody();
    return PaymentResponse.fromJSON(jsonDecode(body));
  }
}
