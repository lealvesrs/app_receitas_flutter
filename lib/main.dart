// lib/main.dart
// App: Receitas & Avaliações (corrigido para padrão do professor)
// Telas: Home (/), Detalhe (/detalhe), Minhas Avaliações (/avaliacoes), Config (/config)
// Requisitos mantidos: Rotas nomeadas, arguments com ID, ListView.builder, FutureBuilder + http,
// shared_preferences (simples + JSON), formulário (TextField + Slider), ícones/botões/onPressed,
// bônus CRUD (JSONPlaceholder).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
        '/detalhe': (context) => const DetalheReceitaPage(),
        '/avaliacao': (context) => const MinhasAvaliacoesPage(),
        '/config': (context) => const ConfiguracoesPage(),
      },
      initialRoute: "/",
    );
  }
}

/// ======================= MODELOS / API / STORAGE ===========================

class Receita {
  final int id;
  final String nome; // "receita"
  final String ingredientesTexto; // texto grande "ingredientes"
  final String modoPreparo; // "modo_preparo"
  final String linkImagem;
  final String tipo;
  final String? criadoEm;
  final List<String> ingredientesBase; // nomesIngrediente[]

  Receita({
    required this.id,
    required this.nome,
    required this.ingredientesTexto,
    required this.modoPreparo,
    required this.linkImagem,
    required this.tipo,
    required this.criadoEm,
    required this.ingredientesBase,
  });

  factory Receita.fromJson(Map<String, dynamic> j) {
    // Pega lista dentro de IngredientesBase[0].nomesIngrediente
    List<String> listaBase = [];
    if (j["IngredientesBase"] is List && j["IngredientesBase"].isNotEmpty) {
      final item = j["IngredientesBase"][0];
      if (item["nomesIngrediente"] is List) {
        listaBase = (item["nomesIngrediente"] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    String? dataFormatada;
    if (j["created_at"] != null) {
      final parsed = DateTime.tryParse(j["created_at"]);
      if (parsed != null) {
        dataFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(parsed);
      }
    }

    return Receita(
      id: (j["id"] as num).toInt(),
      nome: (j["receita"] ?? "Sem nome").toString(),
      ingredientesTexto: (j["ingredientes"] ?? "").toString(),
      modoPreparo: (j["modo_preparo"] ?? "").toString(),
      linkImagem: (j["link_imagem"] ?? "").toString(),
      tipo: (j["tipo"] ?? "").toString().capitalizar(),
      criadoEm: dataFormatada,
      ingredientesBase: listaBase,
    );
  }
}

class ReceitasApi {
  static Future<List<Receita>> buscarReceitas() async {
    final uri = Uri.parse(
      'https://api-receitas-pi.vercel.app/receitas/todas?page=1&limit=60',
    );
    final resposta = await http.get(uri);

    if (resposta.statusCode != 200) {
      throw Exception(
        'Erro ao carregar receitas (código: ${resposta.statusCode}).',
      );
    }

    final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
    final lista = (dados['items'] as List)
        .map((item) => Receita.fromJson(item as Map<String, dynamic>))
        .toList();

    return lista;
  }
}

class Review {
  final int receitaId;
  final String titulo;
  final String image;
  final double avaliacao; // 0..5
  final String comentario;
  final String dataComentario;

  Review({
    required this.receitaId,
    required this.titulo,
    required this.image,
    required this.avaliacao,
    required this.comentario,
    required this.dataComentario,
  });

  Map<String, dynamic> toJson() => {
    'receitaId': receitaId,
    'titulo': titulo,
    'image': image,
    'avaliacao': avaliacao,
    'comentario': comentario,
    'dataComentario': dataComentario,
  };

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    receitaId: (j['receitaId'] as num).toInt(),
    titulo: (j['titulo'] ?? '').toString(),
    image: (j['image'] ?? '').toString(),
    avaliacao: (j['avaliacao'] is int)
        ? (j['avaliacao'] as int).toDouble()
        : (j['avaliacao'] as num).toDouble(),
    comentario: (j['comentario'] ?? '').toString(),
    dataComentario: (j['dataComentario'] ?? '').toString(),
  );
}

class Storage {
  static const keyUsuario = 'pref_user'; //String
  static const keyFavs = 'pref_favs'; // List<int> como JSON
  static const keyAvaliacoes = 'pref_avaliacoes'; // List<Review> como JSON

  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUsuario);
  }

  static Future<void> setUser(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUsuario, name);
  }

  static Future<List<int>> getFavs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFavs);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList(); //vai retornar um array de ids
  }

  static Future<void> setFavs(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFavs, jsonEncode(ids));
  }

  static Future<List<Review>> getReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyAvaliacoes);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> setReviews(List<Review> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyAvaliacoes,
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
  late Future<List<Receita>> _future;
  final _pesquisar = TextEditingController();
  List<int> _favs = [];

  @override
  void initState() {
    super.initState();
    _future = ReceitasApi.buscarReceitas();
    _carregarFavs();
  }

  Future<void> _carregarFavs() async {
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
    _pesquisar.dispose();
    super.dispose();
  }
  Future<String?> get _userFuture => Storage.getUser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: _userFuture,
          builder: (_, s) {
            final nomeUsuario = s.data;
            return Text(
              nomeUsuario == null || nomeUsuario.isEmpty
                  ? 'Receitas & Avaliações'
                  : 'Olá, $nomeUsuario 👩‍🍳',
            );
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
            onPressed: () =>
              Navigator.pushNamed(context, "/config")
              .then((_) => setState(() {})),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _pesquisar,
              decoration: InputDecoration(
                labelText: 'Buscar por nome ou tipo de receita',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}), //reconstroi dnv a tela
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Receita>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  ); // Mostra um ícone de loading.
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar receitas.\n${snapshot.error}', // Mostra a mensagem de erro.
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                var receitas = snapshot.data ?? [];
                final pesquisar = _pesquisar.text.trim().toLowerCase(); //se tiver valor na barra de pesquisa, filtra a lista
                if (pesquisar.isNotEmpty) {
                  receitas = receitas.where((receita) {
                    final contemNome = receita.nome.toLowerCase().contains(pesquisar);
                    final contemTipo = receita.tipo.toLowerCase().contains(pesquisar);
                    return contemNome || contemTipo;
                  }).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: receitas.length,
                  itemBuilder: (_, i) {
                    final receita = receitas[i];
                    final fav = _favs.contains(receita.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell( //anima o hover do card e deixa clicável
                      onTap: () {
                          // Envia ID (e o objeto junto) via arguments
                          Navigator.pushNamed(
                            context,
                            "/detalhe",
                            arguments: {'id': receita.id, 'receita': receita},
                          ).then((_) => _carregarFavs());
                        },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MiniImagem(url: receita.linkImagem),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    receita.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (receita.tipo.isNotEmpty)
                                        _InfoChip(
                                          icon: receita.tipo == 'Doce'? Icons.cake : Icons.restaurant,
                                          text: receita.tipo,
                                        ),
                                      _InfoChip(
                                        icon: Icons.numbers,
                                        text:
                                            '${receita.ingredientesBase.length} ingredientes',
                                      ),
                                      _InfoChip(
                                        icon: Icons.calendar_month,
                                        text:
                                            'Criada em: ${receita.criadoEm}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: fav
                                  ? 'Remover dos favoritos'
                                  : 'Favoritar',
                              onPressed: () => _toggleFav(receita.id),
                              icon: Icon(
                                fav ? Icons.favorite : Icons.favorite_border,
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
class DetalheReceitaPage extends StatefulWidget {
  const DetalheReceitaPage({super.key});
  @override
  State<DetalheReceitaPage> createState() => _DetalheReceitaPageState();
}

class _DetalheReceitaPageState extends State<DetalheReceitaPage> {
  late int receitaId;
  late Receita receita;
  double _avaliacao = 0;
  final _comentario = TextEditingController();
  bool _fav = false;

  // Para garantir leitura única dos arguments da rota
  bool _carregando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_carregando) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>; //pega argumento passado pela rota
      receitaId = (args['id'] as num).toInt();
      receita = args['receita'] as Receita;
      _carregando = true;
      _carregarLocal();
    }
  }

  Future<void> _carregarLocal() async {
    final favs = await Storage.getFavs();
    final reviews = await Storage.getReviews();
    final existing = reviews.where((e) => e.receitaId == receitaId).toList();
    setState(() {
      _fav = favs.contains(receitaId);
      if (existing.isNotEmpty) {
        _avaliacao = existing.first.avaliacao;
        _comentario.text = existing.first.comentario;
      }
    });
  }

  Future<void> _toggleFav() async {
    final favs = await Storage.getFavs();
    favs.contains(receitaId) ? favs.remove(receitaId) : favs.add(receitaId);
    await Storage.setFavs(favs);
    setState(() => _fav = favs.contains(receitaId));
  }

  Future<void> _salvarReview() async {
    final list = await Storage.getReviews();
    final updated = List<Review>.from(
      list.where((e) => e.receitaId != receitaId), //remove review antiga da mesma receita se tiver
    );
    final agora = DateTime.now();
    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(agora);
    updated.add(
      Review(
        receitaId: receitaId,
        titulo: receita.nome,
        image: receita.linkImagem,
        avaliacao: _avaliacao,
        comentario: _comentario.text.trim(),
        dataComentario: dataFormatada,
      ),
    );
    await Storage.setReviews(updated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avaliação salva!')));
    }
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregando) {
      // Primeira build pode ocorrer antes dos arguments estarem disponíveis
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(receita.nome),
        actions: [
          IconButton(
            tooltip: _fav ? 'Remover dos favoritos' : 'Favoritar',
            onPressed: _toggleFav,
            icon: Icon(_fav ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _salvarReview,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar avaliação'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SizedBox(
            height: 500,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: receita.linkImagem.isEmpty
                  ? Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.restaurant_menu, size: 48),
                      ),
                    )
                  : Image.network(
                       'https://corsproxy.io/?${receita.linkImagem}',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
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
                if (receita.tipo.isNotEmpty)
                  _InfoChip(icon: Icons.public, text: receita.tipo),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  text: '${receita.ingredientesBase.length} ingredientes',
                ),
              ],
            ),
          ),
          if (receita.ingredientesBase.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Ingredientes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (receita.ingredientesBase.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: receita.ingredientesBase
                    .map(
                      (ing) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(ing.capitalizar())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Modo de preparo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              receita.modoPreparo.isEmpty
                  ? 'Sem instruções disponíveis.'
                  : receita.modoPreparo,
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
                    value: _avaliacao.clamp(0, 5),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: _avaliacao.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _avaliacao = v),
                  ),
                ),
                Text(_avaliacao.toStringAsFixed(1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _comentario,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentário',
                hintText: 'O que achou da receita?',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MinhasAvaliacoesPage extends StatefulWidget {
  const MinhasAvaliacoesPage({super.key});
  @override
  State<MinhasAvaliacoesPage> createState() => _MinhasAvaliacoesPageState();
}

class _MinhasAvaliacoesPageState extends State<MinhasAvaliacoesPage> {
  List<Review> _avaliacoes = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final list = await Storage.getReviews();
    list.sort((a, b) => b.dataComentario.compareTo(a.dataComentario)); //mais recentes primeiro
    
    setState(() {
      _avaliacoes = list;
    });
  }

  Future<void> _delete(int receitaId) async {
    final copy = List<Review>.from(_avaliacoes);
    copy.removeWhere((e) => e.receitaId == receitaId);

    await Storage.setReviews(copy);
    setState(() => _avaliacoes = copy);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Avaliações')),
      body: _avaliacoes.isEmpty
          ? const Center(child: Text('Nenhuma avaliação salva.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _avaliacoes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final receita = _avaliacoes[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _MiniImagem(url: receita.image),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receita.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _Estrelas(votacao: receita.avaliacao),
                              const SizedBox(height: 8),
                              Text(
                                receita.comentario.isEmpty
                                    ? '(Sem comentário)'
                                    : receita.comentario,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Atualizado: ${receita.dataComentario}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => _delete(receita.receitaId),
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
class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});
  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final _nomeUsuario = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final user = await Storage.getUser() ?? '';
    setState(() {
      _nomeUsuario.text = user;
    });
  }

  Future<void> _salvar() async {
    await Storage.setUser(_nomeUsuario.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
    }
  }

  @override
  void dispose() {
    _nomeUsuario.dispose();
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
            controller: _nomeUsuario,
            decoration: const InputDecoration(
              labelText: 'Seu nome',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// ========================== WIDGETS AUXILIARES =============================

class _MiniImagem extends StatelessWidget {
  final String url;
  final double largura;
  final double altura;
  const _MiniImagem({required this.url, this.largura = 84, this.altura = 84});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: largura,
        height: altura,
        child: url.isEmpty
            ? const Icon(Icons.restaurant_menu)
            : Image.network(
                 'https://corsproxy.io/?$url', //adicionado pois alguns links que a API retorna ficam bloqueado por CORS
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
    return Chip(avatar: Icon(icon, size: 16), label: Text(text));
  }
}

class _Estrelas extends StatelessWidget {
  final double votacao; // 0..5
  const _Estrelas({required this.votacao});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (icon) => Icon(icon < votacao ? Icons.star : Icons.star_border, size: 18),
      ),
    );
  }
}

extension CapitalizarExt on String {
  String capitalizar() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
