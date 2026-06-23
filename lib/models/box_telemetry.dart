class RelayState {
  final int index;
  final bool isOn;
  final double powerW;

  const RelayState({
    required this.index,
    required this.isOn,
    required this.powerW,
  });

  factory RelayState.fromJson(Map<String, dynamic> json) => RelayState(
    index: json['index'] as int,
    isOn: json['status'] == 'on',
    powerW: (json['power_w'] as num?)?.toDouble() ?? 0,
  );
}

class BoxTelemetry {
  final String? boxUid;
  final double temperature;
  final double humidity;
  final List<RelayState> relays;

  const BoxTelemetry({
    this.boxUid,
    required this.temperature,
    required this.humidity,
    required this.relays,
  });

  /// Parse le payload JSONB unique envoyé par le boîtier.
  /// Format attendu (défini par l'app, imposé au boîtier) :
  /// ```json
  /// {
  ///   "temperature": 22.5,
  ///   "humidity": 45,
  ///   "relays": [
  ///     { "index": 1, "status": "on", "power_w": 150 },
  ///     { "index": 2, "status": "off", "power_w": 0 },
  ///     { "index": 3, "status": "on", "power_w": 800 }
  ///   ]
  /// }
  /// ```
  factory BoxTelemetry.fromJson(Map<String, dynamic> json, {String? boxUid}) => BoxTelemetry(
    boxUid: boxUid,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    humidity: (json['humidity'] as num?)?.toDouble() ?? 0,
    relays: (json['relays'] as List<dynamic>?)
            ?.map((e) => RelayState.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'relays': relays
        .map((r) => {
          'index': r.index,
          'status': r.isOn ? 'on' : 'off',
          'power_w': r.powerW,
        })
        .toList(),
  };
}
