import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaCripto extends StatefulWidget {
  const TelaCripto({super.key});

  @override
  State<TelaCripto> createState() => _TelaCriptoState();
}

class _TelaCriptoState extends State<TelaCripto> {
  List<String> moedasIds = ['bitcoin', 'ethereum', 'tether'];
  Map<String, dynamic> _precos = {};
  bool _carregando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregarListaSalva();
  }

  Future<void> _carregarListaSalva() async {
    final prefs = await SharedPreferences.getInstance();
    final listaSalva = prefs.getStringList('minhas_moedas');
    if (listaSalva != null && listaSalva.isNotEmpty) {
      setState(() => moedasIds = listaSalva);
    }
    _buscarPrecos();
  }

  Future<void> _salvarLista() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('minhas_moedas', moedasIds);
  }

  // --- NOVA FUNÇÃO PARA ABRIR O SITE ---
  Future<void> _abrirSiteAjuda() async {
    final Uri url = Uri.parse('https://www.coingecko.com/pt');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o navegador')),
        );
      }
    }
  }
  // -------------------------------------

  void _adicionarMoeda(String id) {
    String idFormatado = id.trim().toLowerCase();
    if (idFormatado.isNotEmpty && !moedasIds.contains(idFormatado)) {
      setState(() {
        moedasIds.add(idFormatado);
        _carregando = true;
      });
      _salvarLista();
      _buscarPrecos();
    }
  }

  void _removerMoeda(String id) {
    setState(() => moedasIds.remove(id));
    _salvarLista();
  }

  Future<void> _buscarPrecos() async {
    if (moedasIds.isEmpty) {
      setState(() => _carregando = false);
      return;
    }
    try {
      final String ids = moedasIds.join(',');
      final url = Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=brl&include_24hr_change=true');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _precos = jsonDecode(response.body);
          _carregando = false;
          _erro = false;
        });
      } else {
        throw Exception('Erro na API');
      }
    } catch (e) {
      setState(() {
        _erro = true;
        _carregando = false;
      });
    }
  }

  Color _gerarCor(String id) {
    if (id == 'bitcoin') return Colors.orange;
    if (id == 'ethereum') return Colors.purple;
    if (id == 'tether') return Colors.green;
    final int hash = id.codeUnits.fold(0, (prev, element) => prev + element);
    return Colors.primaries[hash % Colors.primaries.length];
  }

  String _formatarNome(String id) {
    // --- EXCEÇÃO MANUAL PARA O DÓLAR ---
    if (id == 'tether') {
      return 'Dólar (USDT)';
    }
    // -----------------------------------

    return id.split('-').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _mostrarDialogoAdicionar() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Adicionar Moeda",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Digite o ID da moeda (igual na URL do CoinGecko).",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ex: solana, cardano",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF64B5F6))),
              ),
            ),
            const SizedBox(height: 20),
            // --- LINK DE AJUDA ---
            InkWell(
              onTap: _abrirSiteAjuda,
              child: Row(
                children: const [
                  Icon(Icons.search, color: Color(0xFF64B5F6), size: 16),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Não sabe o ID? Toque aqui para procurar no site.",
                      style: TextStyle(
                        color: Color(0xFF64B5F6),
                        decoration: TextDecoration.underline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
            // ---------------------
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              _adicionarMoeda(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6)),
            child:
                const Text("Adicionar", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Criptos"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _buscarPrecos)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAdicionar,
        backgroundColor: const Color(0xFF64B5F6),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro
              ? Center(
                  child: TextButton.icon(
                      onPressed: _buscarPrecos,
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: const Text("Erro. Tentar de novo.",
                          style: TextStyle(color: Colors.red))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: moedasIds.length,
                  itemBuilder: (context, index) {
                    final id = moedasIds[index];
                    final dados = _precos[id];
                    final cor = _gerarCor(id);
                    final nome = _formatarNome(id);

                    if (dados == null) {
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          title: Text(id,
                              style: const TextStyle(color: Colors.grey)),
                          subtitle: const Text("ID não encontrado",
                              style:
                                  TextStyle(color: Colors.red, fontSize: 10)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removerMoeda(id),
                          ),
                        ),
                      );
                    }

                    final double preco = (dados['brl'] as num).toDouble();
                    final double variacao =
                        (dados['brl_24h_change'] as num).toDouble();
                    final bool subiu = variacao >= 0;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cor.withOpacity(0.2),
                          child: Icon(Icons.token, color: cor),
                        ),
                        title: Text(nome,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(id.toUpperCase(),
                            style: TextStyle(color: Colors.grey[500])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "R\$ ${preco.toStringAsFixed(preco < 1 ? 4 : 2).replaceAll('.', ',')}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${subiu ? '+' : ''}${variacao.toStringAsFixed(2)}%",
                                  style: TextStyle(
                                      color: subiu ? Colors.green : Colors.red,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.grey),
                              onPressed: () => _removerMoeda(id),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
