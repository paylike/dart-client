/// RetryException is used for throwing an exception
/// when retry count is reached.
class RetryException implements Exception {
  late int attempts;
  String cause = 'Reached maximum attempts in retrying';

  /// Creates a new RetryException with the number of made attempts.
  RetryException.fromAttempt(this.attempts);
}
