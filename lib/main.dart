// lib/main.dart
// App: Receitas & Avaliações (corrigido para padrão do professor)
// Telas: Home (/), Detalhe (/detalhe), Minhas Avaliações (/avaliacoes), Config (/config)
// Requisitos mantidos: Rotas nomeadas, arguments com ID, ListView.builder, FutureBuilder + http,
// shared_preferences (simples + JSON), formulário (TextField + Slider), ícones/botões/onPressed,
// bônus CRUD (JSONPlaceholder).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}


// --- UI E APP PRINCIPAL ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
     return MaterialApp(
      title: 'Receitas & Avaliações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.light,
      ),
      // Rotas nomeadas
      routes: {
        '/': (context) => const HomePage(),
        '/detalhe': (context) => const RecipeDetailPage(),
        '/avaliacao': (context) => const MyReviewsPage(),
        '/cofig': (context) => const SettingsPage(),
      },
      initialRoute: "/",
    );
  }
}


/// ======================= MODELOS / API / STORAGE ===========================

class Recipe {
  final int id;
  final String name;
  final String image;
  final String cuisine;
  final List<String> ingredients;
  final String instructions;
  final int prepMinutes;
  final int cookMinutes;
  final String difficulty;
  final int servings;

  Recipe({
    required this.id,
    required this.name,
    required this.image,
    required this.cuisine,
    required this.ingredients,
    required this.instructions,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.servings,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? 'Sem título').toString(),
        image: (j['image'] ?? '').toString(),
        cuisine: (j['cuisine'] ?? '').toString(),
        ingredients: (j['ingredients'] is List)
            ? (j['ingredients'] as List).map((e) => e.toString()).toList()
            : <String>[],
        instructions: (j['instructions'] ?? '').toString(),
        prepMinutes: (j['prepTimeMinutes'] ?? 0) is num
            ? (j['prepTimeMinutes'] as num).toInt()
            : int.tryParse(j['prepTimeMinutes'].toString()) ?? 0,
        cookMinutes: (j['cookTimeMinutes'] ?? 0) is num
            ? (j['cookTimeMinutes'] as num).toInt()
            : int.tryParse(j['cookTimeMinutes'].toString()) ?? 0,
        difficulty: (j['difficulty'] ?? '').toString(),
        servings: (j['servings'] ?? 0) is num
            ? (j['servings'] as num).toInt()
            : int.tryParse(j['servings'].toString()) ?? 0,
      );
}

class DummyRecipesApi {
  // API pública (sem chave)
  // Ex.: GET https://dummyjson.com/recipes?limit=50
  static Future<List<Recipe>> fetchRecipes({int limit = 60}) async {
    final uri = Uri.parse('https://dummyjson.com/recipes?limit=$limit');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Falha ao carregar receitas (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['recipes'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}

class Review {
  final int recipeId;
  final String title;
  final String image;
  final double rating; // 0..5
  final String comment;
  final String updatedAtIso;

  Review({
    required this.recipeId,
    required this.title,
    required this.image,
    required this.rating,
    required this.comment,
    required this.updatedAtIso,
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'title': title,
        'image': image,
        'rating': rating,
        'comment': comment,
        'updatedAtIso': updatedAtIso,
      };

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        recipeId: (j['recipeId'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        rating: (j['rating'] is int)
            ? (j['rating'] as int).toDouble()
            : (j['rating'] as num).toDouble(),
        comment: (j['comment'] ?? '').toString(),
        updatedAtIso: (j['updatedAtIso'] ?? '').toString(),
      );
}

class Storage {
  static const kUser = 'pref_user';
  static const kFavs = 'pref_favs'; // List<int> como JSON
  static const kReviews = 'pref_reviews'; // List<Review> como JSON

  static Future<String?> getUser() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(kUser);
  }

  static Future<void> setUser(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kUser, v);
  }

  static Future<List<int>> getFavs() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kFavs);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
  }

  static Future<void> setFavs(List<int> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kFavs, jsonEncode(ids));
  }

  static Future<List<Review>> getReviews() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kReviews);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> setReviews(List<Review> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kReviews,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }
}

/// ================================ TELA HOME ====================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Recipe>> _future;
  final _search = TextEditingController();
  List<int> _favs = [];

  @override
  void initState() {
    super.initState();
    _future = DummyRecipesApi.fetchRecipes(limit: 60);
    _loadFavs();
  }

  Future<void> _loadFavs() async {
    final favs = await Storage.getFavs();
    setState(() => _favs = favs);
  }

  void _toggleFav(int id) async {
    final favs = List<int>.from(_favs);
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    await Storage.setFavs(favs);
    setState(() => _favs = favs);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userFuture = Storage.getUser();
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: userFuture,
          builder: (_, s) {
            final name = s.data;
            return Text(name == null || name.isEmpty
                ? 'Receitas & Avaliações'
                : 'Olá, $name 👩‍🍳');
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Minhas avaliações',
            onPressed: () => Navigator.pushNamed(context, "/avaliacao"),
            icon: const Icon(Icons.reviews_outlined),
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => Navigator.pushNamed(context, "/config"),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Buscar por nome ou culinária...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Recipe>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); // Mostra um ícone de loading.
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar receitas.\n${snapshot.error}', // Mostra a mensagem de erro.
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                var recipes = snapshot.data ?? [];
                final q = _search.text.trim().toLowerCase();
                if (q.isNotEmpty) {
                  recipes = recipes.where((r) {
                    final inName = r.name.toLowerCase().contains(q);
                    final inCuisine = r.cuisine.toLowerCase().contains(q);
                    return inName || inCuisine;
                  }).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recipes.length,
                  itemBuilder: (_, i) {
                    final r = recipes[i];
                    final fav = _favs.contains(r.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          // Envia ID (e o objeto junto) via arguments
                          Navigator.pushNamed(
                            context,
                            "/detalhe",
                            arguments: {'id': r.id, 'recipe': r},
                          ).then((_) => _loadFavs());
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Thumb(url: r.image),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (r.cuisine.isNotEmpty)
                                          _InfoChip(
                                              icon: Icons.public,
                                              text: r.cuisine),
                                        _InfoChip(
                                            icon: Icons.timer_outlined,
                                            text:
                                                '${r.prepMinutes + r.cookMinutes} min'),
                                        if (r.difficulty.isNotEmpty)
                                          _InfoChip(
                                              icon: Icons.flag_outlined,
                                              text: r.difficulty),
                                        _InfoChip(
                                            icon: Icons.people_outline,
                                            text: '${r.servings} porções'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: fav
                                    ? 'Remover dos favoritos'
                                    : 'Favoritar',
                                onPressed: () => _toggleFav(r.id),
                                icon: Icon(
                                  fav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



/// ================================ TELA DE DETALHES ====================================
class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key});
  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late int recipeId;
  late Recipe recipe;
  double _rating = 0;
  final _comment = TextEditingController();
  bool _fav = false;

  // Para garantir leitura única dos arguments
  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      recipeId = (args['id'] as num).toInt();
      recipe = args['recipe'] as Recipe;
      _argsLoaded = true;
      _loadLocal();
    }
  }

  Future<void> _loadLocal() async {
    final favs = await Storage.getFavs();
    final reviews = await Storage.getReviews();
    final existing = reviews.where((e) => e.recipeId == recipeId).toList();
    setState(() {
      _fav = favs.contains(recipeId);
      if (existing.isNotEmpty) {
        _rating = existing.first.rating;
        _comment.text = existing.first.comment;
      }
    });
  }

  Future<void> _toggleFav() async {
    final favs = await Storage.getFavs();
    favs.contains(recipeId) ? favs.remove(recipeId) : favs.add(recipeId);
    await Storage.setFavs(favs);
    setState(() => _fav = favs.contains(recipeId));
  }

  Future<void> _saveReview() async {
    final list = await Storage.getReviews();
    final updated = List<Review>.from(list.where((e) => e.recipeId != recipeId));
    updated.add(Review(
      recipeId: recipeId,
      title: recipe.name,
      image: recipe.image,
      rating: _rating,
      comment: _comment.text.trim(),
      updatedAtIso: DateTime.now().toIso8601String(),
    ));
    await Storage.setReviews(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação salva!')),
      );
    }
  }


  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsLoaded) {
      // Primeira build pode ocorrer antes dos arguments estarem disponíveis
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final totalMin = recipe.prepMinutes + recipe.cookMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            tooltip: _fav ? 'Remover dos favoritos' : 'Favoritar',
            onPressed: _toggleFav,
            icon: Icon(_fav ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveReview,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar avaliação'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: recipe.image.isEmpty
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.restaurant_menu, size: 48),
                    ),
                  )
                : Image.network(
                    recipe.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (recipe.cuisine.isNotEmpty)
                  _InfoChip(icon: Icons.public, text: recipe.cuisine),
                _InfoChip(icon: Icons.timer_outlined, text: '$totalMin min'),
                if (recipe.difficulty.isNotEmpty)
                  _InfoChip(icon: Icons.flag_outlined, text: recipe.difficulty),
                _InfoChip(
                    icon: Icons.people_outline,
                    text: '${recipe.servings} porções'),
              ],
            ),
          ),
          if (recipe.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Ingredientes',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          if (recipe.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recipe.ingredients
                    .map((ing) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(ing)),
                          ],
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Modo de preparo',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              recipe.instructions.isEmpty
                  ? 'Sem instruções disponíveis.'
                  : recipe.instructions,
              textAlign: TextAlign.justify,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Sua avaliação', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.star_rate_outlined),
                Expanded(
                  child: Slider(
                    value: _rating.clamp(0, 5),
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _rating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                Text(_rating.toStringAsFixed(1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentário',
                hintText: 'O que achou da receita?',
                border: OutlineInputBorder(),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});
  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Storage.getReviews();
    setState(() => _reviews = list
      ..sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso)));
  }

  Future<void> _delete(int recipeId) async {
    final copy = List<Review>.from(_reviews)
      ..removeWhere((e) => e.recipeId == recipeId);
    await Storage.setReviews(copy);
    setState(() => _reviews = copy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Avaliações')),
      body: _reviews.isEmpty
          ? const Center(child: Text('Nenhuma avaliação salva.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = _reviews[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _Thumb(url: r.image, w: 84, h: 84),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              _StaticStars(value: r.rating),
                              const SizedBox(height: 8),
                              Text(
                                r.comment.isEmpty
                                    ? '(Sem comentário)'
                                    : r.comment,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Atualizado: ${r.updatedAtIso}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => _delete(r.recipeId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// ================================ TELA DE CONFIGURAÇÕES ====================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await Storage.getUser() ?? '';
    setState(() {
      _name.text = user;
    });
  }

  Future<void> _save() async {
    await Storage.setUser(_name.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas!')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Perfil', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Seu nome',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}


/// ========================== WIDGETS AUXILIARES =============================

class _Thumb extends StatelessWidget {
  final String url;
  final double w;
  final double h;
  const _Thumb({required this.url, this.w = 96, this.h = 72});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: w,
        height: h,
        color: bg,
        child: url.isEmpty
            ? const Icon(Icons.restaurant_menu)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
    );
  }
}

class _StaticStars extends StatelessWidget {
  final double value; // 0..5
  const _StaticStars({required this.value});

  @override
  Widget build(BuildContext context) {
    final sel = value.clamp(0, 5).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < sel ? Icons.star : Icons.star_border, size: 18),
      ),
    );
  }
}