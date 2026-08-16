/// The logged-in senior's record, mirroring the `user` table in Supabase
/// plus a few convenience fields.
class Profile {
  const Profile({
    required this.name,
    required this.email,
    required this.seniorId,
    required this.mobileNo,
    required this.age,
    required this.birthday,
    required this.address,
    this.gender = '',
  });

  final String name;
  final String email;
  final String seniorId;
  final String mobileNo;
  final int age;
  final String birthday;
  final String address;

  /// 'Female' / 'Male' / free text — shown in the profile modal and sent to
  /// the LLM so AgakAI can address the senior correctly.
  final String gender;

  /// First name, used for greetings.
  String get firstName => name.trim().split(' ').first;

  factory Profile.fromJson(Map<String, dynamic> json) {
    Object? firstNonEmpty(Object? a, Object? b) =>
        a != null && a.toString().trim().isNotEmpty ? a : b;

    final rawSeniorId =
        firstNonEmpty(json['senior_id'], json['seniorId'])?.toString() ?? '';
    final rawMobile = firstNonEmpty(
          json['mobileNo'],
          firstNonEmpty(json['mobile_no'], json['mobile']),
        )?.toString() ??
        '';

    return Profile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      seniorId: rawSeniorId,
      mobileNo: rawMobile,
      age: (json['age'] as num?)?.toInt() ?? 0,
      birthday: json['birthday'] as String? ?? '',
      address: json['address'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
    );
  }
}
