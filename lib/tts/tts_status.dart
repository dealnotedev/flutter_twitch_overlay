enum TtsIssue {
  canceled,
  invalidUrl,
  loadFailed,
  disabled,
  noReward,
  twitchUnavailable,
  audioUnavailable,
  queueFull,
  rewardUnavailable,
  noAgentsAvailable,
  serviceUnavailable,
  timeout,
  invalidText,
  generationFailed,
  invalidAudio,
  settlementFailed,
  operationFailed,
}

enum TtsPhase { idle, generating, playing }

enum TtsCancellationReason {
  disabled,
  stopped,
  settledOnTwitch,
  timeout,
  shutdown,
}
