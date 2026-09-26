import 'package:flutter/widgets.dart';

abstract interface class GameRuntime {
  Widget buildView({Key? key});

  Future<void> sendHostEvent(
    String event, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  });

  Future<void> reload();

  Future<void> dispose();
}
