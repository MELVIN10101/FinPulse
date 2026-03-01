class GoalModel {
  final String id;
  final String title;
  final String subtitle;
  final double current;
  final double target;
  final String deadline;
  final String imagePath;

  GoalModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.current = 0,
    required this.target,
    required this.deadline,
    this.imagePath = '',
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  GoalModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? current,
    double? target,
    String? deadline,
    String? imagePath,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      current: current ?? this.current,
      target: target ?? this.target,
      deadline: deadline ?? this.deadline,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'current': current,
      'target': target,
      'deadline': deadline,
      'imagePath': imagePath,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: (map['subtitle'] as String?) ?? '',
      current: (map['current'] as num).toDouble(),
      target: (map['target'] as num).toDouble(),
      deadline: map['deadline'] as String,
      imagePath: (map['imagePath'] as String?) ?? '',
    );
  }
}
