import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:resepku/main.dart';
import 'package:resepku/models/favorite.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/pages/favorite_page.dart';
import 'package:resepku/pages/settings_page.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/providers/settings_provider.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/recipe_grid_card.dart';
import 'package:resepku/widgets/recipe_tile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fakes.dart';
import 'fixtures.dart';

Widget buildApp(
  http.Client client, {
  MemoryFavoriteStore? store,
  SettingsProvider? settings,
  Widget? page,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (context) => settings ?? SettingsProvider(),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            FavoriteProvider(store ?? MemoryFavoriteStore())..load(),
      ),
      Provider(
        create: (context) => RecipeService(client: client),
        dispose: (context, service) => service.close(),
      ),
    ],
    child: page == null ? const ResepKuApp() : MaterialApp(home: page),
  );
}

http.Client okClient() =>
    MockClient((_) async => http.Response(recipesJson, 200));
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'Pilihan grid dibaca dari SharedPreferences saat aplikasi dibuka',
    (tester) async {
      usePhoneSize(tester);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            SettingsProvider.keyGrid: true,
          });
      final settings = SettingsProvider();
      await settings.load();
      await tester.pumpWidget(buildApp(okClient(), settings: settings));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeGridCard), findsWidgets);
      expect(find.byType(RecipeTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Favorit dan catatan yang tersimpan tampil saat aplikasi dibuka',
    (tester) async {
      usePhoneSize(tester);
      final store = MemoryFavoriteStore([sampleFavorite(note: 'Tambah keju')]);
      await tester.pumpWidget(buildApp(okClient(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Favorit saya'));
      await tester.pumpAndSettle();
      expect(find.text('Classic Margherita Pizza'), findsOneWidget);
      expect(find.textContaining('Tambah keju'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Catatan dan jumlah dimasak ditulis ke store, detail lokal tetap lengkap',
    (tester) async {
      usePhoneSize(tester);
      final store = MemoryFavoriteStore([sampleFavorite()]);
      await tester.pumpWidget(
        buildApp(okClient(), store: store, page: const FavoritePage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Catatan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Kurangi garam  ');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect((await store.getAll()).single.note, 'Kurangi garam');
      await tester.tap(find.byTooltip('Sudah dimasak'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dimasak 1 kali'), findsOneWidget);
      expect((await store.getAll()).single.cookedCount, 1);
      await tester.tap(find.text('Classic Margherita Pizza'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flour'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Make dough.'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Make dough.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Urutan Nama A–Z memakai salinan list dan tersimpan', (
    tester,
  ) async {
    usePhoneSize(tester);
    final a = sampleFavorite();
    final z = Favorite(
      recipe: Recipe.fromJson({'id': 2, 'name': 'Zuppa'}),
      savedAt: DateTime(2026, 11, 1),
    );
    final store = MemoryFavoriteStore([a, z]);
    await tester.pumpWidget(
      buildApp(okClient(), store: store, page: const FavoritePage()),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Zuppa')).dy,
      lessThan(tester.getTopLeft(find.text(a.recipe.name)).dy),
    );
    await tester.tap(find.byTooltip('Urutan favorit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nama A–Z'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text(a.recipe.name)).dy,
      lessThan(tester.getTopLeft(find.text('Zuppa')).dy),
    );
    final reopened = SettingsProvider();
    await reopened.load();
    expect(reopened.favoriteSort, FavoriteSort.name);
    expect((await store.getAll()).first.recipe.name, 'Zuppa');
  });

  testWidgets(
    'Hapus semua di Pengaturan perlu konfirmasi dan mengosongkan store',
    (tester) async {
      usePhoneSize(tester);
      final store = MemoryFavoriteStore([sampleFavorite()]);
      await tester.pumpWidget(
        buildApp(okClient(), store: store, page: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 favorit tersimpan'), findsOneWidget);
      await tester.tap(find.text('Hapus semua favorit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await store.getAll(), hasLength(1));
      await tester.tap(find.text('Hapus semua favorit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(await store.getAll(), isEmpty);
      expect(find.text('0 favorit tersimpan'), findsOneWidget);
      expect(find.text('Semua favorit telah dihapus.'), findsOneWidget);
    },
  );
}
