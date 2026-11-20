import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:resepku/widgets/error_view.dart';
import 'package:resepku/widgets/recipe_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Future<List<Recipe>>? _recipesFuture;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _recipesFuture = query.isEmpty
          ? null
          : context.read<RecipeService>().searchRecipes(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari resep...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: _recipesFuture == null
          ? const Center(child: Text('Ketik kata kunci lalu tekan Enter.'))
          : FutureBuilder<List<Recipe>>(
              future: _recipesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Gagal mencari resep.\n${snapshot.error}',
                    onRetry: () => _search(_query),
                  );
                }
                final recipes = snapshot.data ?? [];
                if (recipes.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada resep yang cocok.'),
                  );
                }
                return ListView.builder(
                  itemCount: recipes.length,
                  itemBuilder: (context, index) =>
                      RecipeTile(recipe: recipes[index]),
                );
              },
            ),
    );
  }
}
