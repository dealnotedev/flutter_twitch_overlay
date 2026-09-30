enum TwitchRedemptionStatus {
  unfulfilled('UNFULFILLED'),
  fulfilled('FULFILLED'),
  canceled('CANCELED');

  final String apiValue;

  const TwitchRedemptionStatus(this.apiValue);

  static TwitchRedemptionStatus? fromApi(String? value) {
    final normalized = value?.toUpperCase();
    for (final status in values) {
      if (status.apiValue == normalized) return status;
    }
    return null;
  }
}
