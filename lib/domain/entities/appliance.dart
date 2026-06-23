class Appliance {
  final String id;
  final String boxId;
  final String? boxUid;
  final String userId;
  final int relayIndex;
  final String name;
  final String? location;
  final bool isOn;
  final DateTime createdAt;

  const Appliance({
    required this.id,
    required this.boxId,
    this.boxUid,
    required this.userId,
    required this.relayIndex,
    required this.name,
    this.location,
    this.isOn = false,
    required this.createdAt,
  });

  Appliance copyWith({
    String? name, String? location, bool? isOn, String? boxUid,
  }) => Appliance(
    id: id, boxId: boxId, userId: userId,
    boxUid: boxUid ?? this.boxUid,
    relayIndex: relayIndex,
    name: name ?? this.name,
    location: location ?? this.location,
    isOn: isOn ?? this.isOn,
    createdAt: createdAt,
  );

  factory Appliance.fromJson(Map<String, dynamic> json) => Appliance(
    id: json['id'] as String,
    boxId: json['box_id'] as String,
    boxUid: json['box_uid'] as String?,
    userId: json['user_id'] as String,
    relayIndex: json['relay_index'] as int,
    name: json['name'] as String,
    location: json['location'] as String?,
    isOn: json['is_on'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'box_id': boxId, 'user_id': userId,
    if (boxUid != null) 'box_uid': boxUid,
    'relay_index': relayIndex, 'name': name,
    if (location != null) 'location': location,
    'is_on': isOn, 'created_at': createdAt.toIso8601String(),
  };
}
