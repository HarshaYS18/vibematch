typedef EpochMillisProvider = int Function();

class WatchPartyClock {
  WatchPartyClock({
    EpochMillisProvider? clientNowMs,
  }) : _clientNowMs =
           clientNowMs ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final EpochMillisProvider _clientNowMs;
  int _serverOffsetMs = 0;
  bool _hasServerSample = false;

  bool get hasServerSample => _hasServerSample;
  int get serverOffsetMs => _serverOffsetMs;

  void observeServerTime(
    int serverTimeMs, {
    int? clientReceiptTimeMs,
  }) {
    if (serverTimeMs <= 0) return;
    final localReceipt = clientReceiptTimeMs ?? _clientNowMs();
    _serverOffsetMs = serverTimeMs - localReceipt;
    _hasServerSample = true;
  }

  int get serverNowMs => _clientNowMs() + _serverOffsetMs;
}
