class Profile {
  const Profile({
    required this.name,
    required this.email,
    required this.seniorId,
    required this.mobileNo,
    required this.age,
    required this.birthday,
    required this.address,
  });

  final String name;
  final String email;
  final String seniorId;
  final String mobileNo;
  final int age;
  final String birthday;
  final String address;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      seniorId: (json['senior_id'] ?? json['seniorId']) as String? ?? '',
      mobileNo: (json['mobile_no'] ?? json['mobileNo']) as String? ?? '',
      age: json['age'] as int? ?? 0,
      birthday: json['birthday'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}