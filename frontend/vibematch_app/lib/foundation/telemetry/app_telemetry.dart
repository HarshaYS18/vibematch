typedef TelemetrySink = void Function(
  String event,
  Map<String, Object?> attributes,
);

class AppTelemetry {
  const AppTelemetry({this.sink});

  final TelemetrySink? sink;

  void record(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    sink?.call(event, Map<String, Object?>.unmodifiable(attributes));
  }
}
