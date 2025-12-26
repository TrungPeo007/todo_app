class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String role;
  final String? parentId;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.role,
    this.parentId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      role: json['role'],
      parentId: json['parentId'],
    );
  }
}