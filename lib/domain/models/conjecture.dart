/// Conjecture lifecycle state (plan section 4). The static balancing data
/// ([ConjectureDef]) will live in YAML config from phase 3 on; only this
/// dynamic state is persisted in the save file.
enum ConjectureStatus { available, active, proven, refuted }

extension ConjectureStatusKey on ConjectureStatus {
  String get key => name;
}

class ConjectureState {
  final String defId;
  ConjectureStatus status;
  double progress; // 0..100
  DateTime lastWorkAt;
  int attempts;
  DateTime? resolvedAt;

  ConjectureState({
    required this.defId,
    this.status = ConjectureStatus.available,
    this.progress = 0,
    DateTime? lastWorkAt,
    this.attempts = 0,
    this.resolvedAt,
  }) : lastWorkAt = lastWorkAt ?? DateTime.now();

  factory ConjectureState.fromJson(Map<String, dynamic> json) => ConjectureState(
        defId: json['def_id'] as String,
        status: ConjectureStatus.values.byName(json['status'] as String),
        progress: (json['progress'] as num).toDouble(),
        lastWorkAt: DateTime.fromMillisecondsSinceEpoch(json['last_work_at_ms'] as int),
        attempts: json['attempts'] as int,
        resolvedAt: json['resolved_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['resolved_at_ms'] as int),
      );

  Map<String, dynamic> toJson() => {
        'def_id': defId,
        'status': status.key,
        'progress': progress,
        'last_work_at_ms': lastWorkAt.millisecondsSinceEpoch,
        'attempts': attempts,
        'resolved_at_ms': resolvedAt?.millisecondsSinceEpoch,
      };
}
