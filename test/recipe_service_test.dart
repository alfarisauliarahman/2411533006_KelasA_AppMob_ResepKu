import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resepku/models/recipe.dart';
import 'package:resepku/services/recipe_service.dart';

void main() {
  test('fromJson accepts integer rating and supplies optional defaults', () {
    final recipe = Recipe.fromJson({'id': 1, 'name': 'Pizza', 'rating': 5});
    expect(recipe.rating, 5.0);
    expect(recipe.rating, isA<double>());
    expect(recipe.cuisine, '-');
    expect(recipe.difficulty, '-');
    expect(recipe.prepTimeMinutes, 0);
    expect(recipe.cookTimeMinutes, 0);
    expect(recipe.servings, 1);
    expect(recipe.caloriesPerServing, 0);
    expect(recipe.image, '');
    expect(recipe.ingredients, isEmpty);
    expect(recipe.instructions, isEmpty);
  });

  test('fetchRecipes decodes the recipes array and sends limit', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/recipes');
        expect(request.url.queryParameters['limit'], '50');
        return http.Response(
          jsonEncode({
            'recipes': [
              {
                'id': 1,
                'name': 'Pizza',
                'rating': 4.6,
                'ingredients': ['Flour'],
                'instructions': ['Bake'],
              },
              {'id': 2, 'name': 'Pasta', 'rating': 5},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final recipes = await service.fetchRecipes();
    expect(recipes, isA<List<Recipe>>());
    expect(recipes.map((recipe) => recipe.name), ['Pizza', 'Pasta']);
    expect(recipes.first.instructions, ['Bake']);
  });

  test('fetchRecipes reports HTTP 404 as RecipeServiceException', () async {
    final service = RecipeService(
      client: MockClient((_) async => http.Response('Not found', 404)),
    );
    addTearDown(service.close);
    await expectLater(
      service.fetchRecipes(),
      throwsA(isA<RecipeServiceException>()),
    );
  });

  test('searchRecipes encodes spaces and special characters', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.url.path, '/recipes/search');
        expect(request.url.queryParameters['q'], 'rice & chicken');
        return http.Response('{"recipes":[]}', 200);
      }),
    );
    addTearDown(service.close);
    expect(await service.searchRecipes('rice & chicken'), isEmpty);
  });

  test('addRecipe sends JSON and reads partial response with new ID', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/recipes/add');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'name': 'Rendang',
          'cuisine': 'Indonesian',
          'cookTimeMinutes': 180,
        });
        return http.Response(jsonEncode({'id': 51, ...body}), 201);
      }),
    );
    addTearDown(service.close);
    final created = await service.addRecipe(
      name: 'Rendang',
      cuisine: 'Indonesian',
      cookTimeMinutes: 180,
    );
    expect(created.id, 51);
    expect(created.name, 'Rendang');
    expect(created.instructions, isEmpty);
  });

  test('updateRecipe sends PUT and returns server name', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/recipes/1');
        expect(jsonDecode(request.body), {'name': 'Pizza Baru'});
        return http.Response('{"id":1,"name":"Pizza Baru"}', 200);
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.updateRecipe(1, name: 'Pizza Baru')).name,
      'Pizza Baru',
    );
  });

  test('deleteRecipe checks server deletion confirmation', () async {
    final service = RecipeService(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/recipes/1');
        return http.Response('{"id":1,"isDeleted":true}', 200);
      }),
    );
    addTearDown(service.close);
    expect(await service.deleteRecipe(1), isTrue);
  });
}
