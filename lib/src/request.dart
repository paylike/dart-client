import 'dart:async';

import 'package:paylike_dart_request/paylike_dart_request.dart';

/// RetryHandler describes the interfaces of a retry handler.
abstract class RetryHandler<T> {
  /// Retry is the function that should be implemented by every retry handler.
  Future<T> retry(Future<T> Function() executor);
}

/// DefaultRetryHandler is used as the default retry backoff
/// mechanism for handling RateLimitExceptions.
class DefaultRetryHandler<T> implements RetryHandler<T> {
  /// Counts the number of attempts made so far
  int attempts = 0;

  /// Gives back the duration suggested by the API
  /// or a Duration based on the number of attempts if no
  /// retry headers were provided.
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

  /// Implementation of the retry mechanism.
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
      return retry(executor);
    } on TimeoutException catch (_) {
      attempts++;
      if (attempts > 2) {
        rethrow;
      }
      return retry(executor);
    } catch (e) {
      rethrow;
    }
  }
}

/// PaylikeRequestBuilder provides a flexible way to add
/// custom retry mechanism into the flow.
class PaylikeRequestBuilder<T> {
  /// Async function to execute
  late Future<T> Function() fn;

  /// Handler to do retry
  RetryHandler<T> retryHandler = DefaultRetryHandler<T>();

  /// Indicates if retry is enabled
  bool retryEnabled = false;
  PaylikeRequestBuilder(this.fn);

  /// Receives a custom retry implementation and enables retry mechanism.
  PaylikeRequestBuilder<T> withRetry(RetryHandler<T> retryHandler) {
    this.retryHandler = retryHandler;
    retryEnabled = true;
    return this;
  }

  /// Enables default retry - backoff mechanism.
  PaylikeRequestBuilder<T> withDefaultRetry() {
    retryEnabled = true;
    return this;
  }

  /// Executes the request.
  Future<T> execute() {
    return retryEnabled ? retryHandler.retry(fn) : fn();
  }
}
