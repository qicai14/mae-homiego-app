// This enum must match your 'user_role' type in Supabase
enum UserRole { tenant, homeowner, admin }

class Profile {
  final String id;
  final UserRole role;
  final String? fullName; // Nullable, we check this in AuthGate
  final String? contactNo;
  final String? gender;
  final String? avatarUrl;
  final String? shortBio;
  final String? location;
  final bool isVerified;

  Profile({
    required this.id,
    required this.role,
    this.fullName,
    this.contactNo,
    this.gender,
    this.avatarUrl,
    this.shortBio,
    this.location,
    required this.isVerified,
  });

  // Factory constructor to create a Profile from a Supabase (JSON) map
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      // Convert the string 'tenant' into UserRole.tenant
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.tenant, // Default fallback
      ),
      fullName: map['full_name'],
      contactNo: map['contact_no'],
      gender: map['gender'],
      avatarUrl: map['avatar_url'],
      shortBio: map['short_bio'],
      location: map['location'],
      isVerified: map['is_verified'] ?? false,
    );
  }

  // Helper to check if profile is "complete"
  bool get isProfileComplete {
    // We define "complete" as having a full name.
    // You can make this check more strict later (e.g., check contact_no)
    return fullName != null && fullName!.isNotEmpty;
  }
}

