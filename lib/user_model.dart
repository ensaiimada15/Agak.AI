class UserModel {
  final int id;
  final String name;
  final String address;
  final int age;
  final String gender;
  final String? userNotes;
  final String? seniorId;
  final DateTime createdAt;
  final String? email;
  final String? mobileNo;
  final String? birthday;

  UserModel({
    required this.id,
    required this.name,
    required this.address,
    required this.age,
    required this.gender,
    this.userNotes,
    this.seniorId,
    required this.createdAt,
    this.email,
    this.mobileNo,
    this.birthday,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      gender: map['gender'] as String? ?? '',
      userNotes: map['user_notes'] as String?,
      seniorId: map['senior_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      email: map['email'] as String?,
      mobileNo: map['mobileNo'] as String?,
      birthday: map['birthday'] as String?,
    );
  }
}