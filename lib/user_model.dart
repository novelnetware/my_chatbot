// lib/user_model.dart

class User {
  final String firstName;
  final String lastName;
  final String birthDate; // Format: "1370/05/15"

  User({
    required this.firstName,
    required this.lastName,
    required this.birthDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      birthDate: json['birth_date'] ?? '//',
    );
  }
}