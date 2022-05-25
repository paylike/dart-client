/// PaymentChallenge describes a challenge after a payment creation
/// is initiated
class PaymentChallenge {
  late String name;
  late String type;
  late String path;
  PaymentChallenge.fromJSON(Map<String, dynamic> json)
      : name = json['name'],
        type = json['type'],
        path = json['path'];
}

/// Describes the hints array received after executing a challenge successfully.
class HintsResponse {
  late List<String> hints;
  HintsResponse.fromJSON(Map<String, dynamic> json)
      : hints = (json['hints'] as List<dynamic>).cast<String>();
}

/// Describes a response from tokenize.
class TokenizedResponse {
  String token;
  TokenizedResponse.fromJSON(Map<String, dynamic> json) : token = json['token'];
}

/// Describes a paylike transaction.
class PaylikeTransaction {
  String id;
  PaylikeTransaction(this.id);
  PaylikeTransaction.fromJSON(Map<String, dynamic> json)
      : id = json['authorizationId'] ?? json['transactionId'];
}

/// Describes a payment response.
class PaymentResponse {
  PaylikeTransaction transaction;
  Map<String, dynamic>? custom;
  PaymentResponse.fromJSON(Map<String, dynamic> json)
      : transaction = PaylikeTransaction.fromJSON(json),
        custom = json['custom'];
}

/// Describes the client response from the Paylike capture API
class PaylikeClientResponse {
  final bool isHTML;
  PaymentResponse? paymentResponse;
  List<String> hints;
  String? HTMLBody;
  PaylikeClientResponse({
    required this.isHTML,
    this.paymentResponse,
    this.HTMLBody,
    this.hints = const [],
  });

  /// Returns the payment response if not null
  /// otherwise throws an exception
  PaymentResponse getPaymentResponse() {
    if (paymentResponse == null) {
      throw Exception('Payment response is null, cannot be acquired');
    }
    return paymentResponse as PaymentResponse;
  }

  /// Returns HTML body if not null
  /// otherwise throws an exception
  String getHTMLBody() {
    if (HTMLBody == null) {
      throw Exception('HTMLBody is null, cannot be acquired');
    }
    return HTMLBody as String;
  }
}
