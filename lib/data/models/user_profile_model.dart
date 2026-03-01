class UserProfileModel {
  final String name;
  final String email;
  final String age;
  final String handle;
  final String avatarUrl;

  UserProfileModel({
    required this.name,
    required this.email,
    this.age = '',
    this.handle = '',
    this.avatarUrl = '',
  });

  UserProfileModel copyWith({
    String? name,
    String? email,
    String? age,
    String? handle,
    String? avatarUrl,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'handle': handle,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      name: map['name'] as String,
      email: map['email'] as String,
      age: (map['age'] as String?) ?? '',
      handle: (map['handle'] as String?) ?? '',
      avatarUrl: (map['avatarUrl'] as String?) ?? '',
    );
  }
}
