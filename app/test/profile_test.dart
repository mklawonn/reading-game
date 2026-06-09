import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reading_game/features/profile/create_profile_screen.dart';
import 'package:reading_game/profile/local_profile_store.dart';
import 'package:reading_game/profile/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocalProfileStore round-trips the profile list + active id', () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalProfileStore();
    expect((await store.load()).profiles, isEmpty);

    await store.save(const ProfileData(
      profiles: [Profile(id: '1', name: 'Pip', avatar: 'fox')],
      activeId: '1',
    ));

    final loaded = await store.load();
    expect(loaded.profiles.single.name, 'Pip');
    expect(loaded.active?.avatar, 'fox');
  });

  test('ProfileData.active resolves the active profile (or null)', () {
    const data = ProfileData(profiles: [
      Profile(id: 'a', name: 'A', avatar: 'cat'),
      Profile(id: 'b', name: 'B', avatar: 'dog'),
    ], activeId: 'b');
    expect(data.active?.name, 'B');
    expect(data.copyWith(activeId: null).active, isNull);
  });

  testWidgets('CreateProfileScreen yields a profile with typed name + avatar',
      (tester) async {
    Profile? created;
    await tester.pumpWidget(MaterialApp(
      home: CreateProfileScreen(onCreate: (p) => created = p),
    ));

    // "Start" is disabled until a name is entered.
    final startBtn = tester.widget<FilledButton>(find.byKey(const Key('profile-start')));
    expect(startBtn.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('profile-name')), 'Pip');
    await tester.tap(find.byKey(const Key('avatar-owl')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-start')));

    expect(created, isNotNull);
    expect(created!.name, 'Pip');
    expect(created!.avatar, 'owl');
  });
}
