/// A child profile. No PII beyond a chosen display [name] and an [avatar] id
/// from a curated set (COPPA-safe — no photos, no real identifiers).
class Profile {
  const Profile({required this.id, required this.name, required this.avatar});

  final String id;
  final String name;
  final String avatar; // an avatar id (see features/profile/avatars.dart)

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'avatar': avatar};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
      );
}

/// The set of profiles plus which one is active. Per-profile *progress* lives
/// separately (keyed by profile id in the ProgressStore).
class ProfileData {
  const ProfileData({this.profiles = const [], this.activeId});

  final List<Profile> profiles;
  final String? activeId;

  Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  static const Object _keep = Object();

  /// Pass `activeId: null` to *clear* the active profile (switch screen);
  /// omitting it keeps the current one.
  ProfileData copyWith({List<Profile>? profiles, Object? activeId = _keep}) =>
      ProfileData(
        profiles: profiles ?? this.profiles,
        activeId:
            identical(activeId, _keep) ? this.activeId : activeId as String?,
      );

  Map<String, dynamic> toJson() => {
        'profiles': [for (final p in profiles) p.toJson()],
        'activeId': activeId,
      };

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        profiles: (json['profiles'] as List<dynamic>? ?? const [])
            .map((p) => Profile.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
        activeId: json['activeId'] as String?,
      );
}
