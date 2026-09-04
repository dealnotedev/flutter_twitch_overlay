enum TwitchRedemptionStatus {
  unfulfilled('UNFULFILLED'),
  fulfilled('FULFILLED'),
  canceled('CANCELED');

  final String apiValue;

  const TwitchRedemptionStatus(this.apiValue);
}
