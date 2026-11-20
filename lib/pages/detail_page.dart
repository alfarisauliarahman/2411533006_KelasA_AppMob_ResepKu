import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/providers/favorite_provider.dart';
import 'package:resepku/services/recipe_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late int _servings; // state lokal: hanya halaman ini yang butuh

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings; // nilai awal dari data resep
  }

  void _addServing() {
    setState(() => _servings++);
  }

  void _removeServing() {
    if (_servings > 1) {
      setState(() => _servings--);
    }
  }

  bool _requesting = false;

  Future<void> _runAction(String action) async {
    final service = context.read<RecipeService>();
    final recipe = widget.recipe;
    if (action == 'rename') {
      var draftName = recipe.name;
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ubah nama resep'),
          content: TextFormField(
            initialValue: recipe.name,
            onChanged: (value) => draftName = value,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama resep'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final value = draftName.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (!mounted || name == null) return;
      setState(() => _requesting = true);
      try {
        final updated = await service.updateRecipe(recipe.id, name: name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nama dari server: ${updated.name}')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengubah resep: $error')));
      } finally {
        if (mounted) setState(() => _requesting = false);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus resep?'),
        content: Text('Hapus "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _requesting = true);
    try {
      final deleted = await service.deleteRecipe(recipe.id);
      if (!mounted) return;
      if (!deleted) {
        throw RecipeServiceException('Server belum mengonfirmasi penghapusan.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${recipe.name}" dihapus oleh server.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus resep: $error')));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final totalCalories = recipe.caloriesPerServing * _servings;
    final isFavorite = context.watch<FavoriteProvider>().isFavorite(recipe);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            title: Text(recipe.name),
            actions: [
              IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () =>
                    context.read<FavoriteProvider>().toggle(recipe),
              ),
              PopupMenuButton<String>(
                enabled: !_requesting,
                tooltip: 'Menu resep',
                onSelected: _runAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: recipe.image,
                fit: BoxFit.cover,
                placeholder: (context, url) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.restaurant_menu)),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/placeholder.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recipe.cuisine} • ${recipe.difficulty} • ${recipe.totalTimeMinutes} menit',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text('Porsi', style: textTheme.titleMedium),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: _servings > 1 ? _removeServing : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_servings',
                              style: textTheme.titleLarge,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _addServing,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total kalori: $totalCalories kkal',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Bahan', style: textTheme.titleLarge),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.builder(
              itemCount: recipe.ingredients.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(recipe.ingredients[index]),
              ),
            ),
          ),
          if (recipe.instructions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Text('Langkah', style: textTheme.titleLarge),
              ),
            ),
          SliverList.builder(
            itemCount: recipe.instructions.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${index + 1}')),
              title: Text(recipe.instructions[index]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
