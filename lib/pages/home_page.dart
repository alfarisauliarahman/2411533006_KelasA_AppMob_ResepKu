import 'package:resepku/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/pages/add_recipe_page.dart';
import 'package:resepku/pages/search_page.dart';
import 'package:resepku/pages/settings_page.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/error_view.dart';
import 'package:resepku/widgets/favorite_badge_button.dart';
import 'package:resepku/widgets/recipe_grid_card.dart';
import 'package:resepku/widgets/recipe_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _cuisine;
  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    // Future dibuat SEKALI di initState, bukan di build()
    _recipesFuture = context.read<RecipeService>().fetchRecipes();
  }

  // Membuat Future baru, lalu setState agar FutureBuilder memakainya
  void _reload() {
    setState(() {
      _recipesFuture = context.read<RecipeService>().fetchRecipes();
    });
  }

  // Dipanggil RefreshIndicator saat daftar ditarik ke bawah
  Future<void> _refresh() async {
    _reload();
    try {
      await _recipesFuture;
    } catch (_) {
      // error sudah ditampilkan oleh FutureBuilder
    }
  }

  Future<void> _openAddPage() async {
    final created = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (context) => const AddRecipePage()),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${created.name}" diterima server dengan id ${created.id}. '
          'dummyjson hanya menyimulasikan penyimpanan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isGrid = settings.isGrid;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('ResepKu', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cari resep',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchPage()),
            ),
          ),
          IconButton(
            tooltip: isGrid ? 'Tampilan list' : 'Tampilan grid',
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () => settings.setGrid(!isGrid),
          ),
          const FavoriteBadgeButton(),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah resep',
        onPressed: _openAddPage,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          // 1. Loading state (data lama tetap tampil saat refresh)
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error state
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Gagal memuat resep.\n${snapshot.error}',
              onRetry: _reload,
            );
          }
          // 3. Data state
          final recipes = snapshot.data ?? [];
          if (recipes.isEmpty) {
            return const Center(child: Text('Belum ada resep.'));
          }
          final cuisines = recipes.map((recipe) => recipe.cuisine).toSet();
          final selectedCuisine = cuisines.contains(_cuisine) ? _cuisine : null;
          final filteredRecipes = recipes
              .where(
                (recipe) =>
                    selectedCuisine == null ||
                    recipe.cuisine == selectedCuisine,
              )
              .toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: selectedCuisine == null,
                        onSelected: (_) => setState(() => _cuisine = null),
                      ),
                    ),
                    for (final cuisine in cuisines)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cuisine),
                          selected: selectedCuisine == cuisine,
                          onSelected: (_) => setState(() => _cuisine = cuisine),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: isGrid
                      ? _buildGrid(filteredRecipes)
                      : _buildList(filteredRecipes),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Recipe> recipes) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: recipes.length,
      itemBuilder: (context, index) => RecipeTile(recipe: recipes[index]),
    );
  }

  Widget _buildGrid(List<Recipe> recipes) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4, // lebar : tinggi
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) => RecipeGridCard(recipe: recipes[index]),
    );
  }
}
