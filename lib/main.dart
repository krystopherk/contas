import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'tela_cripto.dart';
import 'tela_compilado_anual.dart';

// Variável Global para o estado de segurança
bool bloqueioAtivoGlobal = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await carregarDados(); // Carrega configs e transações antes de iniciar
  }
  runApp(const AppContas());
}

// ================= GESTÃO DE PERSISTÊNCIA =================

Future<String> _getDiretorioDocuments() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> _getArquivoTransacoes() async {
  final path = await _getDiretorioDocuments();
  return File('$path/dados_financeiros_offline.json');
}

Future<File> _getArquivoCategorias() async {
  final path = await _getDiretorioDocuments();
  return File('$path/categorias_customizadas_offline.json');
}

Future<void> salvarDados() async {
  if (kIsWeb) return;
  try {
    final arquivoTr = await _getArquivoTransacoes();
    final String jsonTr = jsonEncode(bancoDeDadosGlobal.map((t) => t.toMap()).toList());
    await arquivoTr.writeAsString(jsonTr);

    final arquivoCat = await _getArquivoCategorias();
    Map<String, dynamic> mapaConfig = {
      'bloqueioAtivo': bloqueioAtivoGlobal,
      'entradas': categoriasEntradaGlobal.map((c) => c.toMap()).toList(),
      'despesas': categoriasDespesaGlobal.map((c) => c.toMap()).toList(),
    };
    await arquivoCat.writeAsString(jsonEncode(mapaConfig));
  } catch (e) {
    debugPrint("Erro ao salvar: $e");
  }
}

Future<void> carregarDados() async {
  try {
    final arquivoCat = await _getArquivoCategorias();
    if (await arquivoCat.exists()) {
      final String jsonCat = await arquivoCat.readAsString();
      if (jsonCat.isNotEmpty) {
        Map<String, dynamic> mapa = jsonDecode(jsonCat);
        bloqueioAtivoGlobal = mapa['bloqueioAtivo'] ?? false;
        if (mapa['entradas'] != null) {
          categoriasEntradaGlobal = (mapa['entradas'] as List)
              .map((x) => CategoriaModel.fromMap(x))
              .toList();
        }
        if (mapa['despesas'] != null) {
          categoriasDespesaGlobal = (mapa['despesas'] as List)
              .map((x) => CategoriaModel.fromMap(x))
              .toList();
        }
      }
    }

    final arquivoTr = await _getArquivoTransacoes();
    if (await arquivoTr.exists()) {
      final String jsonTr = await arquivoTr.readAsString();
      if (jsonTr.isNotEmpty) {
        List<dynamic> lista = jsonDecode(jsonTr);
        bancoDeDadosGlobal = lista.map((item) => TransacaoModel.fromMap(item)).toList();
      }
    }
  } catch (e) {
    debugPrint("Erro ao carregar: $e");
  }
}

// ================= SERVIÇO DE BIOMETRIA =================
class AuthService {
  static final LocalAuthentication auth = LocalAuthentication();
  static Future<bool> autenticar() async {
    try {
      bool podeVerificar = await auth.canCheckBiometrics;
      bool ehDispositivoSuportado = await auth.isDeviceSupported();
      if (!podeVerificar || !ehDispositivoSuportado) return true;
      return await auth.authenticate(
        localizedReason: 'Toque no sensor para acessar suas finanças',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      return true;
    }
  }
}

// ================= SERVIÇO DE PDF =================
class PdfService {
  static Future<void> gerarRelatorioMensal(BuildContext context, int mes,
      int ano, List<TransacaoModel> transacoes) async {
    final pdf = pw.Document();
    final mesNome = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'][mes - 1];

    final entradas = transacoes.where((t) => t.tipo == TipoTransacao.entrada && t.categoria.id != '99').toList();
    final fixas = transacoes.where((t) => t.tipo == TipoTransacao.contaFixa).toList();
    final variaveis = transacoes.where((t) => t.tipo == TipoTransacao.gastoVariavel).toList();
    final depositosCofre = transacoes.where((t) => t.tipo == TipoTransacao.poupanca).toList();
    final resgatesCofre = transacoes.where((t) => t.categoria.id == '99').toList();

    double somaEntradas = entradas.fold(0, (sum, t) => sum + t.valor);
    double somaFixas = fixas.fold(0, (sum, t) => sum + t.valor);
    double somaVariaveis = variaveis.fold(0, (sum, t) => sum + t.valor);
    double somaDepositos = depositosCofre.fold(0, (sum, t) => sum + t.valor);
    double somaResgates = resgatesCofre.fold(0, (sum, t) => sum + t.valor);
    double despesasTotais = somaFixas + somaVariaveis;
    double saldoFinal = (somaEntradas + somaResgates) - (despesasTotais + somaDepositos);
    double saldoLiquidoCofre = somaDepositos - somaResgates;

    List<List<String>> agruparDados(List<TransacaoModel> lista, double totalGrupo) {
      Map<String, double> mapa = {};
      for (var t in lista) {
        mapa[t.categoria.nome] = (mapa[t.categoria.nome] ?? 0) + t.valor;
      }
      var ordenado = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return ordenado.map((e) {
        final percent = totalGrupo > 0 ? (e.value / totalGrupo * 100).toStringAsFixed(1) : "0.0";
        return [e.key, "R\$ ${e.value.toStringAsFixed(2)}", "$percent%"];
      }).toList();
    }

    final dadosFixas = agruparDados(fixas, somaFixas);
    final dadosVariaveis = agruparDados(variaveis, somaVariaveis);
    final dadosEntradas = agruparDados(entradas, somaEntradas);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Column(children: [
              pw.Text("RELATÓRIO FINANCEIRO", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text("$mesNome $ano".toUpperCase(), style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Divider(),
            ])),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _buildMiniCard("ENTRADAS", somaEntradas, PdfColors.green700),
                _buildMiniCard("DESPESAS", despesasTotais, PdfColors.red700),
                _buildMiniCard("INVESTIDO", somaDepositos, PdfColors.blue700),
                _buildMiniCard("SALDO FINAL", saldoFinal, PdfColors.grey800),
              ])
            ),
            pw.SizedBox(height: 20),
            _buildSectionHeader("DETALHAMENTO FIXAS", PdfColors.blueGrey800),
            pw.Table.fromTextArray(headers: ['CATEGORIA', 'VALOR', '%'], data: dadosFixas),
            pw.SizedBox(height: 20),
            _buildSectionHeader("DETALHAMENTO VARIÁVEIS", PdfColors.blueGrey800),
            pw.Table.fromTextArray(headers: ['CATEGORIA', 'VALOR', '%'], data: dadosVariaveis),
          ];
        },
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Relatorio_$mesNome.pdf');
  }

  static Future<void> gerarRelatorioAnual(BuildContext context, int ano, List<TransacaoModel> transacoes) async {
    final pdf = pw.Document();

    // Filtra transações apenas do ano solicitado
    final transacoesDoAno = transacoes.where((t) => t.data.year == ano).toList();

    final entradas = transacoesDoAno.where((t) => t.tipo == TipoTransacao.entrada && t.categoria.id != '99').toList();
    final fixas = transacoesDoAno.where((t) => t.tipo == TipoTransacao.contaFixa).toList();
    final variaveis = transacoesDoAno.where((t) => t.tipo == TipoTransacao.gastoVariavel).toList();
    final investimento = transacoesDoAno.where((t) => t.tipo == TipoTransacao.poupanca).toList();

    double somaEntradas = entradas.fold(0.0, (sum, t) => sum + t.valor);
    double somaFixas = fixas.fold(0.0, (sum, t) => sum + t.valor);
    double somaVariaveis = variaveis.fold(0.0, (sum, t) => sum + t.valor);
    double somaInvestido = investimento.fold(0.0, (sum, t) => sum + t.valor);
    double saldoAnual = somaEntradas - (somaFixas + somaVariaveis + somaInvestido);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text("FECHAMENTO ANUAL $ano", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            context: context,
            data: <List<String>>[
              ['CATEGORIA', 'VALOR ACUMULADO'],
              ['ENTRADAS TOTAIS', 'R\$ ${somaEntradas.toStringAsFixed(2)}'],
              ['CONTAS FIXAS', 'R\$ ${somaFixas.toStringAsFixed(2)}'],
              ['GASTOS VARIÁVEIS', 'R\$ ${somaVariaveis.toStringAsFixed(2)}'],
              ['INVESTIMENTOS', 'R\$ ${somaInvestido.toStringAsFixed(2)}'],
              ['SALDO LÍQUIDO', 'R\$ ${saldoAnual.toStringAsFixed(2)}'],
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Text("Relatorio gerado em ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"),
          )
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Relatorio_Anual_$ano.pdf');
  }

  static pw.Widget _buildMiniCard(String titulo, double valor, PdfColor cor) {
    return pw.Column(children: [
      pw.Text(titulo, style: const pw.TextStyle(fontSize: 8)),
      pw.Text("R\$ ${valor.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: cor)),
    ]);
  }

  static pw.Widget _buildSectionHeader(String titulo, PdfColor corFundo) {
    return pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(4), color: corFundo, child: pw.Text(titulo, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)));
  }
}

// ================= ESTRUTURA DE DADOS =================

enum TipoTransacao { entrada, contaFixa, gastoVariavel, poupanca }

class TransacaoModel {
  final String id;
  final String descricao;
  final double valor;
  final DateTime data;
  final CategoriaModel categoria;
  final TipoTransacao tipo;
  bool pago;
  final String? recorrenciaId;

  TransacaoModel({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.categoria,
    required this.tipo,
    this.pago = false,
    this.recorrenciaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'data': data.toIso8601String(),
      'categoriaId': categoria.id,
      'tipo': tipo.index,
      'pago': pago,
      'recorrenciaId': recorrenciaId,
    };
  }

  factory TransacaoModel.fromMap(Map<String, dynamic> map) {
    CategoriaModel catEncontrada;
    try {
      final todasCategorias = [...categoriasEntradaGlobal, ...categoriasDespesaGlobal];
      catEncontrada = todasCategorias.firstWhere((c) => c.id == map['categoriaId']);
    } catch (e) {
      catEncontrada = categoriasDespesaGlobal.last;
    }

    return TransacaoModel(
      id: map['id'],
      descricao: map['descricao'],
      valor: (map['valor'] as num).toDouble(),
      data: DateTime.parse(map['data']),
      categoria: catEncontrada,
      tipo: TipoTransacao.values[map['tipo']],
      pago: map['pago'] ?? false,
      recorrenciaId: map['recorrenciaId'],
    );
  }
}

class CategoriaModel {
  final String id;
  String nome;
  IconData icone;
  final TipoTransacao tipoPadrao;

  CategoriaModel({
    required this.id,
    required this.nome,
    required this.icone,
    required this.tipoPadrao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'codePoint': icone.codePoint,
      'fontFamily': icone.fontFamily,
      'tipoPadrao': tipoPadrao.index,
    };
  }

  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'],
      nome: map['nome'],
      icone: IconData(map['codePoint'], fontFamily: map['fontFamily']),
      tipoPadrao: TipoTransacao.values[map['tipoPadrao']],
    );
  }
}

// --- DADOS GLOBAIS ---
List<TransacaoModel> bancoDeDadosGlobal = [];

List<CategoriaModel> categoriasEntradaGlobal = [
  CategoriaModel(id: '1', nome: 'Salário', icone: Icons.attach_money, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '2', nome: 'Freelance', icone: Icons.work, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '3', nome: 'Investimentos', icone: Icons.trending_up, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '99', nome: 'Resgate Cofre', icone: Icons.savings_outlined, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '5', nome: 'Outros', icone: Icons.more_horiz, tipoPadrao: TipoTransacao.entrada),
];

List<CategoriaModel> categoriasDespesaGlobal = [
  CategoriaModel(id: '10', nome: 'Alimentação', icone: Icons.restaurant, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '11', nome: 'Moradia', icone: Icons.home, tipoPadrao: TipoTransacao.contaFixa),
  CategoriaModel(id: '12', nome: 'Transporte', icone: Icons.directions_car, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '13', nome: 'Lazer', icone: Icons.movie, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '15', nome: 'Educação', icone: Icons.school, tipoPadrao: TipoTransacao.contaFixa),
  CategoriaModel(id: '98', nome: 'Guardar no Cofre', icone: Icons.savings, tipoPadrao: TipoTransacao.poupanca),
  CategoriaModel(id: '16', nome: 'Outros', icone: Icons.more_horiz, tipoPadrao: TipoTransacao.gastoVariavel),
];

final List<IconData> iconesDisponiveis = [Icons.home, Icons.restaurant, Icons.directions_car, Icons.shopping_cart, Icons.local_hospital, Icons.school, Icons.work, Icons.fitness_center, Icons.attach_money, Icons.savings, Icons.card_giftcard, Icons.gamepad, Icons.wifi, Icons.phone_android];

final List<Color> coresGrafico = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown];

// ================= APP CONFIG =================
class AppContas extends StatelessWidget {
  const AppContas({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finanças',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF64B5F6), secondary: Color(0xFF4DD0E1), surface: Color(0xFF1E1E1E)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), elevation: 0, titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      home: bloqueioAtivoGlobal ? const TelaAutenticacao() : const TelaInicial(),
    );
  }
}

// ================= TELA 0: AUTENTICAÇÃO =================
class TelaAutenticacao extends StatefulWidget {
  const TelaAutenticacao({super.key});
  @override State<TelaAutenticacao> createState() => _TelaAutenticacaoState();
}
class _TelaAutenticacaoState extends State<TelaAutenticacao> {
  bool _tentando = false;
  @override void initState() { super.initState(); _verificarBiometria(); }
  Future<void> _verificarBiometria() async {
    setState(() => _tentando = true);
    bool sucesso = await AuthService.autenticar();
    if (mounted && sucesso) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaInicial()));
    }
    if (mounted) setState(() => _tentando = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.lock, size: 80, color: Color(0xFF64B5F6)), const SizedBox(height: 20), const Text("Finanças Protegidas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 40), if (!_tentando) ElevatedButton.icon(onPressed: _verificarBiometria, icon: const Icon(Icons.fingerprint), label: const Text("TENTAR NOVAMENTE")), if (_tentando) const CircularProgressIndicator()])));
}

// ================= TELA 1: INICIAL (COM MENU HAMBURGER) =================
class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});
  @override State<TelaInicial> createState() => _TelaInicialState();
}
class _TelaInicialState extends State<TelaInicial> {
  List<int> anosExibidos = [DateTime.now().year, DateTime.now().year + 1];
  bool _carregando = false;

  Future<void> _exportarBackup() async {
    try {
      final dadosBackup = {'transacoes': bancoDeDadosGlobal.map((e) => e.toMap()).toList(), 'categorias': {'entradas': categoriasEntradaGlobal.map((e) => e.toMap()).toList(), 'despesas': categoriasDespesaGlobal.map((e) => e.toMap()).toList()}};
      await FileSaver.instance.saveFile(name: 'backup_financas.json', bytes: Uint8List.fromList(utf8.encode(jsonEncode(dadosBackup))), mimeType: MimeType.json);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup salvo na pasta Downloads!"), backgroundColor: Colors.green));
    } catch (e) { debugPrint("Erro ao exportar: $e"); }
  }

  Future<void> _importarBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        Map<String, dynamic> dados = jsonDecode(await file.readAsString());
        setState(() {
          if (dados['transacoes'] != null) bancoDeDadosGlobal = (dados['transacoes'] as List).map((item) => TransacaoModel.fromMap(item)).toList();
        });
        await salvarDados();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados restaurados!"), backgroundColor: Colors.green));
      }
    } catch (e) { debugPrint("Erro: $e"); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Finanças'), centerTitle: true, bottom: _linhaSeparadora(), actions: [IconButton(icon: const Icon(Icons.currency_bitcoin, color: Colors.orange), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCripto())))]),
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(
          child: Column(children: [
            DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1E1E1E)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.account_balance_wallet, size: 50, color: Color(0xFF64B5F6)), const SizedBox(height: 10), const Text("Menu", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]))),
            SwitchListTile(secondary: Icon(bloqueioAtivoGlobal ? Icons.lock : Icons.lock_open, color: bloqueioAtivoGlobal ? Colors.green : Colors.grey), title: const Text("Bloqueio Biométrico"), value: bloqueioAtivoGlobal, activeColor: const Color(0xFF64B5F6), onChanged: (bool valor) async { if (!valor) { if (await AuthService.autenticar()) { setState(() => bloqueioAtivoGlobal = false); await salvarDados(); } } else { setState(() => bloqueioAtivoGlobal = true); await salvarDados(); } }),
            const Divider(color: Colors.white10),
            ListTile(leading: const Icon(Icons.settings, color: Colors.blueGrey), title: const Text("Gerenciar Categorias"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaGerenciarCategorias())).then((_) => setState(() {})); }),
            ListTile(leading: const Icon(Icons.download_rounded, color: Colors.green), title: const Text("Exportar Backup"), onTap: () { Navigator.pop(context); _exportarBackup(); }),
            ListTile(leading: const Icon(Icons.upload_file, color: Colors.blue), title: const Text("Importar Backup"), onTap: () { Navigator.pop(context); _importarBackup(); }),
            const Spacer(),
            ListTile(leading: const Icon(Icons.exit_to_app, color: Colors.redAccent), title: const Text("Sair / Bloquear"), onTap: () { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaAutenticacao())); }),
          ]),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaPoupancaGlobal())), icon: const Icon(Icons.savings), label: const Text("Meu Cofre"), backgroundColor: const Color(0xFF26A69A), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16.0), child: ListView.builder(itemCount: anosExibidos.length, itemBuilder: (context, index) => Card(margin: const EdgeInsets.symmetric(vertical: 10), child: ListTile(leading: const Icon(Icons.calendar_today, color: Color(0xFF64B5F6)), title: Text("${anosExibidos[index]}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaMeses(anoSelecionado: anosExibidos[index]))))))),
    );
  }
}

// ================= TELA 2: MESES =================
class TelaMeses extends StatelessWidget {
  final int anoSelecionado;
  const TelaMeses({super.key, required this.anoSelecionado});

  @override
  Widget build(BuildContext context) {
    final List<String> meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Meses de $anoSelecionado'),
        centerTitle: true,
        bottom: _linhaSeparadora(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- NOVO BOTÃO DE COMPILADO ANUAL ---
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TelaCompiladoAnual(ano: anoSelecionado),
                  ),
                ),
                icon: const Icon(Icons.bar_chart, color: Colors.black, size: 28),
                label: Text(
                  "COMPILADO $anoSelecionado",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF64B5F6), // Azul que você pediu
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white10)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("SELECIONE O MÊS", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ),
                Expanded(child: Divider(color: Colors.white10)),
              ],
            ),
            const SizedBox(height: 20),

            // --- GRID DE MESES ---
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final ehMesAtual = (anoSelecionado == DateTime.now().year) &&
                      (index == DateTime.now().month - 1);
                  return Card(
                    color: ehMesAtual ? const Color(0xFF1E2832) : const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: ehMesAtual
                          ? const BorderSide(color: Color(0xFF64B5F6), width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TelaDetalhesMes(
                            mesNome: meses[index],
                            mesIndex: index + 1,
                            ano: anoSelecionado,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            meses[index].substring(0, 3).toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ehMesAtual ? const Color(0xFF64B5F6) : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meses[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: ehMesAtual ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TELA 3: DASHBOARD RESPONSIVO =================
class TelaDetalhesMes extends StatefulWidget {
  final String mesNome; final int mesIndex; final int ano;
  const TelaDetalhesMes({super.key, required this.mesNome, required this.mesIndex, required this.ano});
  @override State<TelaDetalhesMes> createState() => _TelaDetalhesMesState();
}

class _TelaDetalhesMesState extends State<TelaDetalhesMes> {
  double _calcularTotal(TipoTransacao tipo) {
    return bancoDeDadosGlobal.where((t) => t.tipo == tipo && t.data.year == widget.ano && t.data.month == widget.mesIndex).fold(0, (sum, item) => sum + item.valor);
  }

  void _gerarPdf() {
    final transacoesDoMes = bancoDeDadosGlobal.where((t) => t.data.year == widget.ano && t.data.month == widget.mesIndex).toList();
    transacoesDoMes.sort((a, b) => a.data.compareTo(b.data));
    if (transacoesDoMes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sem registros para PDF."), backgroundColor: Colors.orange));
      return;
    }
    PdfService.gerarRelatorioMensal(context, widget.mesIndex, widget.ano, transacoesDoMes);
  }

  @override
  Widget build(BuildContext context) {
    double totalEntradas = _calcularTotal(TipoTransacao.entrada);
    double totalFixas = _calcularTotal(TipoTransacao.contaFixa);
    double totalVariaveis = _calcularTotal(TipoTransacao.gastoVariavel);
    double totalDepositosMes = _calcularTotal(TipoTransacao.poupanca);
    
    double totalResgatesMes = bancoDeDadosGlobal.where((t) => t.categoria.id == '99' && t.data.year == widget.ano && t.data.month == widget.mesIndex).fold(0, (sum, t) => sum + t.valor);
    double economiaLiquidaMes = totalDepositosMes - totalResgatesMes;
    double balancoFinal = totalEntradas - (totalFixas + totalVariaveis + totalDepositosMes);
    Color corBalanco = balancoFinal >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.mesNome} ${widget.ano}'), centerTitle: true, actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _gerarPdf)]),
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: corBalanco.withOpacity(0.3), width: 1.5)),
                    child: Column(children: [
                      const Text("Balanço Disponível", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 5),
                      FittedBox(fit: BoxFit.scaleDown, child: Text("R\$ ${balancoFinal.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: corBalanco))),
                      Text(balancoFinal >= 0 ? "Saldo Positivo" : "Saldo Negativo", style: TextStyle(color: corBalanco, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  const Text("Distribuição de Saídas", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  GraficoGastos(ano: widget.ano, mesIndex: widget.mesIndex),
                  const SizedBox(height: 25),
                  _CardResumo(titulo: "Investimento do Mês", valor: "R\$ ${economiaLiquidaMes.toStringAsFixed(2)}", corValor: const Color(0xFF4DD0E1), icone: Icons.savings, onTap: () => _navegar(TipoTransacao.poupanca)),
                  const SizedBox(height: 20),
                  const Text("Detalhamento", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  _CardResumo(titulo: "Entradas Reais", valor: "R\$ ${totalEntradas.toStringAsFixed(2)}", corValor: const Color(0xFF66BB6A), icone: Icons.arrow_upward, onTap: () => _navegar(TipoTransacao.entrada)),
                  const SizedBox(height: 10),
                  _CardResumo(titulo: "Contas Fixas", valor: "R\$ ${totalFixas.toStringAsFixed(2)}", corValor: const Color(0xFFEF5350), icone: Icons.push_pin, onTap: () => _navegar(TipoTransacao.contaFixa)),
                  const SizedBox(height: 10),
                  _CardResumo(titulo: "Gastos Variáveis", valor: "R\$ ${totalVariaveis.toStringAsFixed(2)}", corValor: const Color(0xFFFFA726), icone: Icons.shopping_cart, onTap: () => _navegar(TipoTransacao.gastoVariavel)),
                  const Spacer(),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }
  void _navegar(TipoTransacao t) => Navigator.push(context, MaterialPageRoute(builder: (c) => TelaListaTransacoes(mesNome: widget.mesNome, mesIndex: widget.mesIndex, ano: widget.ano, tipoFiltro: t))).then((_) => setState(() {}));
}

// ================= COMPONENTE CARD RESUMO =================
class _CardResumo extends StatelessWidget {
  final String titulo; final String valor; final Color corValor; final IconData icone; final VoidCallback onTap;
  const _CardResumo({required this.titulo, required this.valor, required this.corValor, required this.icone, required this.onTap});
  @override Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Icon(icone, color: corValor.withOpacity(0.7), size: 24),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 12)), FittedBox(fit: BoxFit.scaleDown, child: Text(valor.replaceAll('.', ','), style: TextStyle(color: corValor, fontSize: 18, fontWeight: FontWeight.bold)))])) ,
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
        ]),
      ),
    );
  }
}

// ================= GRÁFICO GASTOS (PIE CHART REAL) =================
class GraficoGastos extends StatelessWidget {
  final int ano; final int mesIndex;
  const GraficoGastos({super.key, required this.ano, required this.mesIndex});

  @override
  Widget build(BuildContext context) {
    Map<String, double> dados = {}; double total = 0;
    for (var t in bancoDeDadosGlobal) {
      if (t.data.year == ano && t.data.month == mesIndex && t.tipo != TipoTransacao.entrada) {
        if (t.categoria.id != '99') {
          dados[t.categoria.nome] = (dados[t.categoria.nome] ?? 0) + t.valor;
          total += t.valor;
        }
      }
    }
    if (total == 0) return const Center(child: Text("Sem gastos para exibir gráfico", style: TextStyle(color: Colors.grey, fontSize: 12)));
    var lista = dados.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        SizedBox(width: 80, height: 80, child: CustomPaint(painter: PieChartPainter(dados: lista, total: total, cores: coresGrafico))),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(lista.length > 4 ? 4 : lista.length, (i) => Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: coresGrafico[i % coresGrafico.length], shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(lista[i].key, style: const TextStyle(fontSize: 10, overflow: TextOverflow.ellipsis)))])))),
      ]),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> dados; final double total; final List<Color> cores;
  PieChartPainter({required this.dados, required this.total, required this.cores});
  @override
  void paint(Canvas canvas, Size size) {
    double start = -pi / 2;
    for (int i = 0; i < dados.length; i++) {
      final sweep = (dados[i].value / total) * 2 * pi;
      canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), start, sweep, false, Paint()..color = cores[i % cores.length]..style = PaintingStyle.stroke..strokeWidth = 12);
      start += sweep;
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================= TELA 4: LISTA TRANSAÇÕES (COMPLETA) =================
class TelaListaTransacoes extends StatefulWidget {
  final String mesNome; final int mesIndex; final int ano; final TipoTransacao tipoFiltro;
  const TelaListaTransacoes({super.key, required this.mesNome, required this.mesIndex, required this.ano, required this.tipoFiltro});
  @override State<TelaListaTransacoes> createState() => _TelaListaTransacoesState();
}

class _TelaListaTransacoesState extends State<TelaListaTransacoes> {
  final _search = TextEditingController();
  
  void _excluir(TransacaoModel t) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Excluir?"),
      content: Text("Deseja remover '${t.descricao}'?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Não")),
        if (t.recorrenciaId != null) TextButton(onPressed: () { setState(() => bancoDeDadosGlobal.removeWhere((x) => x.recorrenciaId == t.recorrenciaId && x.data.isAfter(t.data.subtract(const Duration(days: 1))))); salvarDados(); Navigator.pop(ctx); }, child: const Text("Esta e Futuras", style: TextStyle(color: Colors.orange))),
        TextButton(onPressed: () { setState(() => bancoDeDadosGlobal.remove(t)); salvarDados(); Navigator.pop(ctx); }, child: const Text("Sim", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lista = bancoDeDadosGlobal.where((t) => (widget.tipoFiltro == TipoTransacao.poupanca ? (t.tipo == TipoTransacao.poupanca || t.categoria.id == '99') : t.tipo == widget.tipoFiltro) && t.data.year == widget.ano && t.data.month == widget.mesIndex).toList();
    double total = lista.fold(0.0, (s, i) => i.categoria.id == '99' ? s - i.valor : s + i.valor);

    return Scaffold(
      appBar: AppBar(title: Text(widget.mesNome)),
      floatingActionButton: Padding(padding: const EdgeInsets.only(bottom: 60), child: FloatingActionButton(backgroundColor: const Color(0xFF64B5F6), child: const Icon(Icons.add, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TelaCadastro(tipo: widget.tipoFiltro, ano: widget.ano, mesIndex: widget.mesIndex, mesNome: widget.mesNome))).then((v) => setState(() {})))),
      bottomSheet: Container(color: const Color(0xFF2C2C2C), child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL DO MÊS", style: TextStyle(fontSize: 12, color: Colors.grey)), Text("R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF64B5F6)))])))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, decoration: const InputDecoration(hintText: "Buscar...", prefixIcon: Icon(Icons.search)), onChanged: (v)=> setState((){}))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: lista.length, itemBuilder: (context, i) {
          if (_search.text.isNotEmpty && !lista[i].descricao.toLowerCase().contains(_search.text.toLowerCase())) return const SizedBox.shrink();
          return CardTransacaoItem(item: lista[i], ehResgate: lista[i].categoria.id == '99', corTipo: const Color(0xFF64B5F6), tipoFiltro: widget.tipoFiltro, onPagar: (t){ setState(()=> t.pago = true); salvarDados(); }, onEditar: (t){}, onExcluir: _excluir);
        }))
      ]),
    );
  }
}

// ================= TELA 5: CADASTRO (LÓGICA COMPLETA) =================
class TelaCadastro extends StatefulWidget {
  final TipoTransacao tipo; final int ano; final int mesIndex; final String mesNome;
  const TelaCadastro({super.key, required this.tipo, required this.ano, required this.mesIndex, required this.mesNome});
  @override State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _desc = TextEditingController(); final _val = TextEditingController(); final _parc = TextEditingController(text: "1");
  CategoriaModel? _cat; bool _rep = false; DateTime _data = DateTime.now();

  @override void initState() { 
    super.initState(); 
    _cat = (widget.tipo == TipoTransacao.entrada ? categoriasEntradaGlobal : categoriasDespesaGlobal).first; 
    _data = DateTime(widget.ano, widget.mesIndex, min(DateTime.now().day, 28));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Novo Lançamento")),
    body: SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(children: [
      TextField(controller: _desc, decoration: const InputDecoration(labelText: "Descrição", prefixIcon: Icon(Icons.edit))),
      const SizedBox(height: 20),
      TextField(controller: _val, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Valor (R\$)", prefixIcon: Icon(Icons.attach_money))),
      const SizedBox(height: 20),
      ListTile(title: Text("Data: ${_data.day}/${_data.month}/${_data.year}"), leading: const Icon(Icons.calendar_today), onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _data, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if(d != null) setState(()=> _data = d);
      }),
      DropdownButtonFormField<CategoriaModel>(value: _cat, items: (widget.tipo == TipoTransacao.entrada ? categoriasEntradaGlobal : categoriasDespesaGlobal).map((c)=> DropdownMenuItem(value: c, child: Text(c.nome))).toList(), onChanged: (v)=> setState(()=> _cat = v), decoration: const InputDecoration(labelText: "Categoria")),
      SwitchListTile(title: const Text("Repetir por meses?"), value: _rep, onChanged: (v)=> setState(()=> _rep = v)),
      if(_rep) TextField(controller: _parc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantidade de parcelas")),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async {
        int p = _rep ? (int.tryParse(_parc.text) ?? 1) : 1;
        String rid = DateTime.now().millisecondsSinceEpoch.toString();
        for(int i=0; i<p; i++){
          bancoDeDadosGlobal.add(TransacaoModel(id: "$rid-$i", descricao: _desc.text + (p>1?" ${i+1}/$p":""), valor: double.tryParse(_val.text.replaceAll(',', '.')) ?? 0, data: DateTime(_data.year, _data.month + i, _data.day), categoria: _cat!, tipo: widget.tipo, recorrenciaId: p > 1 ? rid : null));
        }
        await salvarDados(); Navigator.pop(context);
      }, child: const Text("SALVAR FINANCEIRO")))
    ])),
  );
}

// ================= TELAS DE APOIO (CATEGORIAS E COFRE) =================
class TelaGerenciarCategorias extends StatefulWidget {
  const TelaGerenciarCategorias({super.key});
  @override State<TelaGerenciarCategorias> createState() => _TelaGerenciarCategoriasState();
}
class _TelaGerenciarCategoriasState extends State<TelaGerenciarCategorias> {
  @override Widget build(BuildContext context) => DefaultTabController(length: 2, child: Scaffold(
    appBar: AppBar(title: const Text("Categorias"), bottom: const TabBar(tabs: [Tab(text: "Entradas"), Tab(text: "Despesas")])),
    body: TabBarView(children: [_list(categoriasEntradaGlobal), _list(categoriasDespesaGlobal)]),
  ));
  Widget _list(List<CategoriaModel> l) => ListView.builder(itemCount: l.length, itemBuilder: (c, i) => ListTile(leading: Icon(l[i].icone, color: const Color(0xFF64B5F6)), title: Text(l[i].nome), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: (){ setState(()=> l.removeAt(i)); salvarDados(); })));
}

class TelaPoupancaGlobal extends StatefulWidget {
  const TelaPoupancaGlobal({super.key});
  @override State<TelaPoupancaGlobal> createState() => _TelaPoupancaGlobalState();
}
class _TelaPoupancaGlobalState extends State<TelaPoupancaGlobal> {
  @override Widget build(BuildContext context) {
    double total = bancoDeDadosGlobal
        .where((t) => t.tipo == TipoTransacao.poupanca)
        .fold(0.0, (s, i) => s + i.valor) -
        bancoDeDadosGlobal
            .where((t) => t.categoria.id == '99')
            .fold(0.0, (s, i) => s + i.valor);
    return Scaffold(
      appBar: AppBar(title: const Text("Meu Cofre")),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(30), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF80CBC4)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Icon(Icons.savings, size: 50, color: Colors.white), const Text("Total Guardado"), Text("R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.white))])),
        const Expanded(child: Center(child: Text("Use os botões de entrada/saída para movimentar o cofre.")))
      ]),
    );
  }
}

// ================= COMPONENTE CARD ACORDEÃO =================
class CardTransacaoItem extends StatefulWidget {
  final TransacaoModel item; final bool ehResgate; final Color corTipo; final TipoTransacao tipoFiltro;
  final Function(TransacaoModel) onPagar; final Function(TransacaoModel) onEditar; final Function(TransacaoModel) onExcluir;
  const CardTransacaoItem({super.key, required this.item, required this.ehResgate, required this.corTipo, required this.tipoFiltro, required this.onPagar, required this.onEditar, required this.onExcluir});
  @override State<CardTransacaoItem> createState() => _CardTransacaoItemState();
}
class _CardTransacaoItemState extends State<CardTransacaoItem> {
  bool _exp = false;
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: InkWell(onTap: ()=> setState(()=> _exp = !_exp), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
    Row(children: [
      CircleAvatar(backgroundColor: widget.corTipo.withOpacity(0.1), child: Icon(widget.item.categoria.icone, color: widget.corTipo)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.item.descricao, style: const TextStyle(fontWeight: FontWeight.bold)), Text("${widget.item.data.day}/${widget.item.data.month} - ${widget.item.categoria.nome}", style: const TextStyle(fontSize: 12, color: Colors.grey))])),
      Text("R\$ ${widget.item.valor.toStringAsFixed(2)}", style: TextStyle(color: widget.ehResgate ? Colors.orange : widget.corTipo, fontWeight: FontWeight.bold)),
    ]),
    if(_exp) ...[const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      TextButton.icon(onPressed: ()=> widget.onExcluir(widget.item), icon: const Icon(Icons.delete, color: Colors.red), label: const Text("Excluir", style: TextStyle(color: Colors.red))),
      if(widget.tipoFiltro == TipoTransacao.contaFixa && !widget.item.pago) TextButton.icon(onPressed: ()=> widget.onPagar(widget.item), icon: const Icon(Icons.check, color: Colors.green), label: const Text("Pagar", style: TextStyle(color: Colors.green))),
    ])]
  ]))));
}

PreferredSize _linhaSeparadora() => PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.white10));