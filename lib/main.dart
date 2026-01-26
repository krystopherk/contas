import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const AppContas());
}

// ================= GESTÃO DE PERSISTÊNCIA (ANDROID + WINDOWS) =================

Future<String> _getDiretorioDocuments() async {
  // Pega a pasta segura do aplicativo no Android ou Windows
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> _getArquivoTransacoes() async {
  final path = await _getDiretorioDocuments();
  // Usa a barra normal '/' que funciona em todos os sistemas
  return File('$path/dados_financeiros_offline.json');
}

Future<File> _getArquivoCategorias() async {
  final path = await _getDiretorioDocuments();
  return File('$path/categorias_customizadas_offline.json');
}

Future<void> salvarDados() async {
  try {
    // 1. Salvar Transações
    final arquivoTr = await _getArquivoTransacoes();
    final String jsonTr = jsonEncode(bancoDeDadosGlobal.map((t) => t.toMap()).toList());
    await arquivoTr.writeAsString(jsonTr);

    // 2. Salvar Categorias
    final arquivoCat = await _getArquivoCategorias();
    Map<String, dynamic> mapaCategorias = {
      'entradas': categoriasEntradaGlobal.map((c) => c.toMap()).toList(),
      'despesas': categoriasDespesaGlobal.map((c) => c.toMap()).toList(),
    };
    await arquivoCat.writeAsString(jsonEncode(mapaCategorias));
  } catch (e) {
    debugPrint("Erro ao salvar: $e");
  }
}

Future<void> carregarDados() async {
  try {
    // 1. Carregar Categorias
    final arquivoCat = await _getArquivoCategorias();
    if (await arquivoCat.exists()) {
      final String jsonCat = await arquivoCat.readAsString();
      if (jsonCat.isNotEmpty) {
        Map<String, dynamic> mapa = jsonDecode(jsonCat);
        if (mapa['entradas'] != null) {
          categoriasEntradaGlobal = (mapa['entradas'] as List).map((x) => CategoriaModel.fromMap(x)).toList();
        }
        if (mapa['despesas'] != null) {
          categoriasDespesaGlobal = (mapa['despesas'] as List).map((x) => CategoriaModel.fromMap(x)).toList();
        }
      }
    }

    // 2. Carregar Transações
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

  TransacaoModel({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.categoria,
    required this.tipo,
    this.pago = false,
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
  CategoriaModel(id: '4', nome: 'Presente', icone: Icons.card_giftcard, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '99', nome: 'Resgate Cofre', icone: Icons.savings_outlined, tipoPadrao: TipoTransacao.entrada),
  CategoriaModel(id: '5', nome: 'Outros', icone: Icons.more_horiz, tipoPadrao: TipoTransacao.entrada),
];

List<CategoriaModel> categoriasDespesaGlobal = [
  CategoriaModel(id: '10', nome: 'Alimentação', icone: Icons.restaurant, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '11', nome: 'Moradia', icone: Icons.home, tipoPadrao: TipoTransacao.contaFixa),
  CategoriaModel(id: '12', nome: 'Transporte', icone: Icons.directions_car, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '13', nome: 'Lazer', icone: Icons.movie, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '14', nome: 'Saúde', icone: Icons.local_hospital, tipoPadrao: TipoTransacao.gastoVariavel),
  CategoriaModel(id: '15', nome: 'Educação', icone: Icons.school, tipoPadrao: TipoTransacao.contaFixa),
  CategoriaModel(id: '98', nome: 'Guardar no Cofre', icone: Icons.savings, tipoPadrao: TipoTransacao.poupanca),
  CategoriaModel(id: '16', nome: 'Outros', icone: Icons.more_horiz, tipoPadrao: TipoTransacao.gastoVariavel),
];

final List<IconData> iconesDisponiveis = [
  Icons.home, Icons.restaurant, Icons.directions_car, Icons.shopping_cart,
  Icons.local_hospital, Icons.school, Icons.work, Icons.fitness_center,
  Icons.pets, Icons.child_friendly, Icons.local_cafe, Icons.flight,
  Icons.build, Icons.lightbulb, Icons.wifi, Icons.phone_android,
  Icons.attach_money, Icons.savings, Icons.card_giftcard, Icons.gamepad,
  Icons.fastfood, Icons.local_gas_station, Icons.shopping_bag, Icons.celebration,
  Icons.sports_soccer, Icons.music_note, Icons.brush, Icons.chair,
];

final List<Color> coresGrafico = [
  Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
  Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown
];

// ================= APP CONFIG =================
class AppContas extends StatelessWidget {
  const AppContas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerenciador de Contas',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64B5F6),
          secondary: Color(0xFF4DD0E1),
          onPrimary: Colors.black,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF64B5F6)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64B5F6),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF64B5F6),
          foregroundColor: Colors.black,
        ),
      ),
      home: const TelaInicial(),
    );
  }
}

// ================= TELA 1: ANOS =================
class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});
  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  List<int> anosExibidos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    int anoAtual = DateTime.now().year;
    anosExibidos = [anoAtual, anoAtual + 1];
    _iniciarApp();
  }

  Future<void> _iniciarApp() async {
    await carregarDados();
    if (mounted) {
      setState(() {
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Finanças'),
        centerTitle: true,
        bottom: _linhaSeparadora(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gerenciar Categorias',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaGerenciarCategorias())).then((_) => setState((){}));
            },
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaPoupancaGlobal()));
        },
        icon: const Icon(Icons.savings),
        label: const Text("Meu Cofre"),
        backgroundColor: const Color(0xFF26A69A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: anosExibidos.length,
            itemBuilder: (context, index) {
              final ano = anosExibidos[index];
              final eAnoAtual = ano == DateTime.now().year;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: eAnoAtual ? const Color(0xFF1E2832) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: eAnoAtual ? const BorderSide(color: Color(0xFF64B5F6), width: 2) : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaMeses(anoSelecionado: ano))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: eAnoAtual ? const Color(0xFF64B5F6) : Colors.grey, size: 28),
                        const SizedBox(width: 20),
                        Text(ano.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: eAnoAtual ? const Color(0xFF64B5F6) : Colors.white)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ================= TELA 2: MESES =================
class TelaMeses extends StatelessWidget {
  final int anoSelecionado;
  const TelaMeses({super.key, required this.anoSelecionado});
  @override
  Widget build(BuildContext context) {
    final List<String> meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    return Scaffold(
      appBar: AppBar(title: Text('Meses de $anoSelecionado'), centerTitle: true, bottom: _linhaSeparadora()),
      body: Padding(padding: const EdgeInsets.all(16.0), child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: 12, itemBuilder: (context, index) {
        final ehMesAtual = (anoSelecionado == DateTime.now().year) && (index == DateTime.now().month - 1);
        return Card(
            color: ehMesAtual ? const Color(0xFF1E2832) : const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: ehMesAtual ? const BorderSide(color: Color(0xFF64B5F6), width: 2) : BorderSide.none),
            child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaDetalhesMes(mesNome: meses[index], mesIndex: index + 1, ano: anoSelecionado))), borderRadius: BorderRadius.circular(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(meses[index].substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ehMesAtual ? const Color(0xFF64B5F6) : Colors.grey[400])), Text(meses[index], style: TextStyle(fontSize: 12, color: ehMesAtual ? Colors.white : Colors.grey[600]))]))
        );
      })),
    );
  }
}

// ================= TELA 3: DASHBOARD =================
class TelaDetalhesMes extends StatefulWidget {
  final String mesNome;
  final int mesIndex;
  final int ano;
  const TelaDetalhesMes({super.key, required this.mesNome, required this.mesIndex, required this.ano});
  @override
  State<TelaDetalhesMes> createState() => _TelaDetalhesMesState();
}

class _TelaDetalhesMesState extends State<TelaDetalhesMes> {
  double _calcularTotal(TipoTransacao tipo) {
    double total = 0.0;
    for (var t in bancoDeDadosGlobal) {
      if (t.tipo == tipo && t.data.year == widget.ano && t.data.month == widget.mesIndex) {
        total += t.valor;
      }
    }
    return total;
  }

  void _navegarParaLista(TipoTransacao tipo) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TelaListaTransacoes(mesNome: widget.mesNome, mesIndex: widget.mesIndex, ano: widget.ano, tipoFiltro: tipo))).then((_) => setState((){}));
  }

  @override
  Widget build(BuildContext context) {
    double totalEntradas = _calcularTotal(TipoTransacao.entrada);
    double totalFixas = _calcularTotal(TipoTransacao.contaFixa);
    double totalVariaveis = _calcularTotal(TipoTransacao.gastoVariavel);
    double totalDepositosMes = _calcularTotal(TipoTransacao.poupanca);

    double totalResgatesMes = 0.0;
    for (var t in bancoDeDadosGlobal) {
      if (t.categoria.id == '99' && t.data.year == widget.ano && t.data.month == widget.mesIndex) {
        totalResgatesMes += t.valor;
      }
    }

    double economiaLiquidaMes = totalDepositosMes - totalResgatesMes;
    double entradasReais = totalEntradas - totalResgatesMes;

    double totalSaidasFluxo = totalFixas + totalVariaveis + totalDepositosMes;
    double balancoFinal = totalEntradas - totalSaidasFluxo;

    Color corBalanco = balancoFinal >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.mesNome} ${widget.ano}'), centerTitle: true, bottom: _linhaSeparadora()),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Balanço Disponível", style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: corBalanco.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: corBalanco.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(children: [Text("R\$ ${balancoFinal.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: corBalanco)), const SizedBox(height: 5), Text(balancoFinal >= 0 ? "Saldo Positivo" : "Saldo Negativo", style: TextStyle(color: corBalanco, fontSize: 12))]),
              ),
              const SizedBox(height: 30),

              const Text("Distribuição de Saídas", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 10),
              GraficoGastos(ano: widget.ano, mesIndex: widget.mesIndex),
              const SizedBox(height: 30),

              const Text("Investimento do Mês", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 10),
              InkWell(onTap: () => _navegarParaLista(TipoTransacao.poupanca), borderRadius: BorderRadius.circular(12), child: _CardResumo(titulo: "Total Investido (Líquido)", valor: "R\$ ${economiaLiquidaMes.toStringAsFixed(2).replaceAll('.', ',')}", corValor: const Color(0xFF4DD0E1), icone: Icons.savings, temNavegacao: true)),

              const SizedBox(height: 20),
              const Text("Detalhamento", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 10),
              InkWell(onTap: () => _navegarParaLista(TipoTransacao.entrada), borderRadius: BorderRadius.circular(12), child: _CardResumo(titulo: "Entradas Reais", valor: "R\$ ${entradasReais.toStringAsFixed(2).replaceAll('.', ',')}", corValor: const Color(0xFF66BB6A), icone: Icons.arrow_upward, temNavegacao: true)),
              const SizedBox(height: 10),
              InkWell(onTap: () => _navegarParaLista(TipoTransacao.contaFixa), borderRadius: BorderRadius.circular(12), child: _CardResumo(titulo: "Contas Fixas", valor: "R\$ ${totalFixas.toStringAsFixed(2).replaceAll('.', ',')}", corValor: const Color(0xFFEF5350), icone: Icons.push_pin, temNavegacao: true)),
              const SizedBox(height: 10),
              InkWell(onTap: () => _navegarParaLista(TipoTransacao.gastoVariavel), borderRadius: BorderRadius.circular(12), child: _CardResumo(titulo: "Gastos Variáveis", valor: "R\$ ${totalVariaveis.toStringAsFixed(2).replaceAll('.', ',')}", corValor: const Color(0xFFFFA726), icone: Icons.shopping_cart, temNavegacao: true)),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= GRÁFICO GASTOS =================
class GraficoGastos extends StatelessWidget {
  final int ano;
  final int mesIndex;
  const GraficoGastos({super.key, required this.ano, required this.mesIndex});

  @override
  Widget build(BuildContext context) {
    Map<String, double> dadosAgrupados = {};
    double totalSaidas = 0.0;

    for (var t in bancoDeDadosGlobal) {
      if (t.data.year == ano && t.data.month == mesIndex) {
        if (t.tipo == TipoTransacao.contaFixa || t.tipo == TipoTransacao.gastoVariavel || t.tipo == TipoTransacao.poupanca) {
          if (t.categoria.id != '99') {
            dadosAgrupados[t.categoria.nome] = (dadosAgrupados[t.categoria.nome] ?? 0) + t.valor;
            totalSaidas += t.valor;
          }
        }
      }
    }

    final colorCard = Theme.of(context).cardColor;
    final colorText = Theme.of(context).colorScheme.onSurface;

    if (totalSaidas == 0) {
      return Container(height: 100, alignment: Alignment.center, decoration: BoxDecoration(color: colorCard, borderRadius: BorderRadius.circular(12)), child: const Text("Sem gastos registrados", style: TextStyle(color: Colors.grey)));
    }

    var listaOrdenada = dadosAgrupados.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorCard, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(width: 120, height: 120, child: CustomPaint(painter: PieChartPainter(dados: listaOrdenada, total: totalSaidas, cores: coresGrafico))),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(listaOrdenada.length, (index) {
            final entry = listaOrdenada[index];
            final porcentagem = (entry.value / totalSaidas * 100).toStringAsFixed(1);
            final cor = coresGrafico[index % coresGrafico.length];
            return Padding(padding: const EdgeInsets.only(bottom: 6.0), child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(entry.key, style: TextStyle(color: colorText.withOpacity(0.7), fontSize: 12), overflow: TextOverflow.ellipsis)), Text("$porcentagem%", style: TextStyle(color: colorText, fontWeight: FontWeight.bold, fontSize: 12))]));
          })))
        ],
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> dados;
  final double total;
  final List<Color> cores;
  PieChartPainter({required this.dados, required this.total, required this.cores});

  @override
  void paint(Canvas canvas, Size size) {
    double startAngle = -pi / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 20;
    for (int i = 0; i < dados.length; i++) {
      final sweepAngle = (dados[i].value / total) * 2 * pi;
      paint.color = cores[i % cores.length];
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================= TELA: MEU COFRE (PRINCIPAL) =================
class TelaPoupancaGlobal extends StatefulWidget {
  const TelaPoupancaGlobal({super.key});
  @override
  State<TelaPoupancaGlobal> createState() => _TelaPoupancaGlobalState();
}

class _TelaPoupancaGlobalState extends State<TelaPoupancaGlobal> {

  double _calcularSaldoCofre() {
    double total = 0.0;
    for (var t in bancoDeDadosGlobal) {
      if (t.tipo == TipoTransacao.poupanca) total += t.valor;
      else if (t.categoria.id == '99') total -= t.valor;
    }
    return total;
  }

  static void mostrarDialogoPoupanca(BuildContext context, {required bool ehDeposito, TransacaoModel? transacaoParaEditar, required Function aoSalvar, DateTime? minDate, DateTime? maxDate}) {
    final TextEditingController valorController = TextEditingController(text: transacaoParaEditar?.valor.toStringAsFixed(2) ?? '');
    DateTime initialDate = transacaoParaEditar?.data ?? DateTime.now();

    if (minDate != null && initialDate.isBefore(minDate)) initialDate = minDate;
    if (maxDate != null && initialDate.isAfter(maxDate)) initialDate = maxDate;

    DateTime dataSelecionada = initialDate;

    double saldoAtual = 0.0;
    for (var t in bancoDeDadosGlobal) {
      if (t.tipo == TipoTransacao.poupanca) saldoAtual += t.valor;
      else if (t.categoria.id == '99') saldoAtual -= t.valor;
    }
    if (transacaoParaEditar != null && transacaoParaEditar.categoria.id == '99') saldoAtual += transacaoParaEditar.valor;

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(ehDeposito ? 'Investir Dinheiro' : 'Retirar Dinheiro', style: TextStyle(color: ehDeposito ? Colors.green : Colors.orange)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: valorController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white, fontSize: 24), decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0,00', border: InputBorder.none), textAlign: TextAlign.center),
          const Divider(color: Colors.grey),
          InkWell(onTap: () async {
            final DateTime? data = await showDatePicker(context: context, initialDate: dataSelecionada, firstDate: minDate ?? DateTime(2000), lastDate: maxDate ?? DateTime(2100), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF64B5F6), onPrimary: Colors.black, onSurface: Colors.white)), child: child!));
            if (data != null) setStateDialog(() => dataSelecionada = data);
          }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 15.0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 8), Text("${dataSelecionada.day}/${dataSelecionada.month}/${dataSelecionada.year}", style: const TextStyle(color: Colors.white)), const Icon(Icons.arrow_drop_down, color: Colors.grey)]))),
          Text(ehDeposito ? "Desconta do saldo do mês." : "Soma ao saldo do mês.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: ehDeposito ? Colors.green : Colors.orange), onPressed: () async {
            if (valorController.text.isNotEmpty) {
              double valor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;

              if (!ehDeposito && valor > saldoAtual) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldo insuficiente no cofre!'), backgroundColor: Colors.red));
                return;
              }

              var catGuardar = categoriasDespesaGlobal.firstWhere((c) => c.id == '98', orElse: () => categoriasDespesaGlobal.first);
              var catResgatar = categoriasEntradaGlobal.firstWhere((c) => c.id == '99', orElse: () => categoriasEntradaGlobal.first);

              final novaTransacao = TransacaoModel(
                id: transacaoParaEditar?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                descricao: ehDeposito ? "Depósito no Cofre" : "Resgate do Cofre",
                valor: valor,
                data: dataSelecionada,
                categoria: ehDeposito ? catGuardar : catResgatar,
                tipo: ehDeposito ? TipoTransacao.poupanca : TipoTransacao.entrada,
              );

              if (transacaoParaEditar != null) {
                int index = bancoDeDadosGlobal.indexWhere((t) => t.id == transacaoParaEditar.id);
                if (index != -1) bancoDeDadosGlobal[index] = novaTransacao;
              } else {
                bancoDeDadosGlobal.add(novaTransacao);
              }
              await salvarDados();
              Navigator.pop(context);
              aoSalvar();
            }
          }, child: const Text('CONFIRMAR'))
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    double saldo = _calcularSaldoCofre();

    return Scaffold(
      appBar: AppBar(title: const Text('Total Investido'), centerTitle: true, bottom: _linhaSeparadora()),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(30), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF80CBC4)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]), child: Column(children: [const Icon(Icons.savings, size: 50, color: Colors.white), const SizedBox(height: 10), const Text("Total Guardado", style: TextStyle(color: Colors.white70, fontSize: 16)), const SizedBox(height: 5), Text("R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () => mostrarDialogoPoupanca(context, ehDeposito: true, aoSalvar: () => setState((){})), icon: const Icon(Icons.arrow_downward), label: const Text("GUARDAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A), padding: const EdgeInsets.symmetric(vertical: 15)))), const SizedBox(width: 15), Expanded(child: ElevatedButton.icon(onPressed: () => mostrarDialogoPoupanca(context, ehDeposito: false, aoSalvar: () => setState((){})), icon: const Icon(Icons.arrow_upward), label: const Text("RESGATAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB74D), padding: const EdgeInsets.symmetric(vertical: 15))))])),
        const Spacer(),
        Padding(padding: const EdgeInsets.all(20.0), child: SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaExtratoPoupanca())); }, icon: const Icon(Icons.list_alt), label: const Text("VER EXTRATO / TRANSAÇÕES"), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey))))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ================= TELA: EXTRATO COFRE =================
class TelaExtratoPoupanca extends StatefulWidget {
  const TelaExtratoPoupanca({super.key});
  @override
  State<TelaExtratoPoupanca> createState() => _TelaExtratoPoupancaState();
}

class _TelaExtratoPoupancaState extends State<TelaExtratoPoupanca> {
  DateTime _mesFiltro = DateTime.now();

  List<TransacaoModel> _filtrarDados() {
    return bancoDeDadosGlobal.where((t) => (t.tipo == TipoTransacao.poupanca || t.categoria.id == '99') && t.data.year == _mesFiltro.year && t.data.month == _mesFiltro.month).toList()..sort((a, b) => b.data.compareTo(a.data));
  }

  void _alterarMes(int meses) { setState(() { _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + meses, 1); }); }
  void _confirmarExclusao(TransacaoModel transacao) { showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: const Text('Excluir?', style: TextStyle(color: Colors.white)), content: const Text('Remover do histórico?', style: TextStyle(color: Colors.grey)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () async { setState(() { bancoDeDadosGlobal.removeWhere((t) => t.id == transacao.id); }); await salvarDados(); Navigator.pop(context); }, child: const Text('Excluir', style: TextStyle(color: Colors.red)))])); }
  void _abrirOpcoesAdicionar() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), builder: (context) => Container(padding: const EdgeInsets.all(20), height: 180, child: Column(children: [const Text("Adicionar Transação", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: true, aoSalvar: () => setState((){})); }, icon: const Icon(Icons.arrow_downward), label: const Text("GUARDAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)))), const SizedBox(width: 15), Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: false, aoSalvar: () => setState((){})); }, icon: const Icon(Icons.arrow_upward), label: const Text("RESGATAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB74D))))])])));
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrarDados();
    final List<String> nomesMeses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico do Cofre'), centerTitle: true, bottom: _linhaSeparadora()),
      floatingActionButton: FloatingActionButton(onPressed: _abrirOpcoesAdicionar, backgroundColor: const Color(0xFF26A69A), child: const Icon(Icons.add)),
      body: Column(children: [
        Container(padding: const EdgeInsets.symmetric(vertical: 10), color: const Color(0xFF1E1E1E), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(onPressed: () => _alterarMes(-1), icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.grey)), Text("${nomesMeses[_mesFiltro.month - 1]} ${_mesFiltro.year}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), IconButton(onPressed: () => _alterarMes(1), icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey))])),
        Expanded(child: lista.isEmpty ? Center(child: Text("Sem movimentações neste mês.", style: TextStyle(color: Colors.grey[600]))) : ListView.builder(itemCount: lista.length, itemBuilder: (context, index) { final item = lista[index]; bool ehDeposito = item.tipo == TipoTransacao.poupanca; return Card(color: const Color(0xFF1E1E1E), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: ListTile(leading: CircleAvatar(backgroundColor: ehDeposito ? Colors.teal.withOpacity(0.2) : Colors.orange.withOpacity(0.2), child: Icon(ehDeposito ? Icons.arrow_downward : Icons.arrow_upward, color: ehDeposito ? Colors.teal : Colors.orange)), title: Text(ehDeposito ? "Depósito" : "Resgate", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text("${item.data.day}/${item.data.month}/${item.data.year}", style: TextStyle(color: Colors.grey[600])), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("R\$ ${item.valor.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(color: ehDeposito ? Colors.teal : Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 10), InkWell(onTap: () => _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: ehDeposito, transacaoParaEditar: item, aoSalvar: () => setState((){})), child: const Icon(Icons.edit, size: 18, color: Colors.blue)), const SizedBox(width: 15), InkWell(onTap: () => _confirmarExclusao(item), child: const Icon(Icons.delete, size: 18, color: Colors.redAccent))]))); }))
      ]),
    );
  }
}

// ================= TELA: GERENCIAR CATEGORIAS (ATUALIZADA: ADD + DEL) =================
class TelaGerenciarCategorias extends StatefulWidget {
  const TelaGerenciarCategorias({super.key});
  @override
  State<TelaGerenciarCategorias> createState() => _TelaGerenciarCategoriasState();
}

class _TelaGerenciarCategoriasState extends State<TelaGerenciarCategorias> {
  // Função unificada para criar ou editar
  void _mostrarDialogoCategoria({required bool ehEntrada, CategoriaModel? categoriaAntiga}) {
    final TextEditingController controller = TextEditingController(text: categoriaAntiga?.nome ?? '');
    IconData iconeSelecionado = categoriaAntiga?.icone ?? (ehEntrada ? Icons.attach_money : Icons.shopping_bag);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(categoriaAntiga == null ? 'Nova Categoria' : 'Editar Categoria', style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Nome')),
                    const SizedBox(height: 20),
                    const Text("Ícone:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
                        itemCount: iconesDisponiveis.length,
                        itemBuilder: (context, index) {
                          final icone = iconesDisponiveis[index];
                          return InkWell(
                            onTap: () => setStateDialog(() => iconeSelecionado = icone),
                            child: Icon(icone, color: icone == iconeSelecionado ? const Color(0xFF64B5F6) : Colors.grey),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      setState(() {
                        List<CategoriaModel> lista = ehEntrada ? categoriasEntradaGlobal : categoriasDespesaGlobal;
                        if (categoriaAntiga == null) {
                          // ADICIONAR NOVA
                          lista.add(CategoriaModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            nome: controller.text,
                            icone: iconeSelecionado,
                            tipoPadrao: ehEntrada ? TipoTransacao.entrada : TipoTransacao.gastoVariavel,
                          ));
                        } else {
                          // EDITAR EXISTENTE
                          categoriaAntiga.nome = controller.text;
                          categoriaAntiga.icone = iconeSelecionado;
                        }
                      });
                      await salvarDados(); // SALVA AS NOVAS CATEGORIAS
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          }
      ),
    );
  }

  void _deletarCategoria(bool ehEntrada, CategoriaModel categoria) {
    // Impede deletar categorias do sistema
    if (categoria.id == '99' || categoria.id == '98') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Categoria do sistema não pode ser excluída."), backgroundColor: Colors.red));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Excluir?', style: TextStyle(color: Colors.white)),
        content: Text('Deseja excluir "${categoria.nome}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              setState(() {
                if (ehEntrada) {
                  categoriasEntradaGlobal.remove(categoria);
                } else {
                  categoriasDespesaGlobal.remove(categoria);
                }
              });
              await salvarDados(); // SALVA A REMOÇÃO
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(List<CategoriaModel> categorias, bool ehEntrada) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final cat = categorias[index];
        // Esconde as de sistema da lista para não poluir
        if (cat.id == '99' || cat.id == '98') return const SizedBox.shrink();

        return Card(
          color: const Color(0xFF2C2C2C),
          child: ListTile(
            leading: Icon(cat.icone, color: const Color(0xFF64B5F6)),
            title: Text(cat.nome, style: const TextStyle(color: Colors.white)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _mostrarDialogoCategoria(ehEntrada: ehEntrada, categoriaAntiga: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deletarCategoria(ehEntrada, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          bottom: const TabBar(tabs: [Tab(text: 'Entradas'), Tab(text: 'Despesas')]),
        ),
        body: TabBarView(
          children: [
            _buildLista(categoriasEntradaGlobal, true),
            _buildLista(categoriasDespesaGlobal, false),
          ],
        ),
        // BOTÃO FLUTUANTE PARA ADICIONAR (INTELIGENTE)
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            backgroundColor: const Color(0xFF64B5F6),
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              // Descobre qual aba está aberta (0 = Entradas, 1 = Despesas)
              final index = DefaultTabController.of(context).index;
              _mostrarDialogoCategoria(ehEntrada: index == 0, categoriaAntiga: null);
            },
          ),
        ),
      ),
    );
  }
}

// ================= TELA 4: LISTA GENÉRICA (ATUALIZADA ⚠️✅) =================
class TelaListaTransacoes extends StatefulWidget {
  final String mesNome;
  final int mesIndex;
  final int ano;
  final TipoTransacao tipoFiltro;
  const TelaListaTransacoes({super.key, required this.mesNome, required this.mesIndex, required this.ano, required this.tipoFiltro});
  @override
  State<TelaListaTransacoes> createState() => _TelaListaTransacoesState();
}

class _TelaListaTransacoesState extends State<TelaListaTransacoes> {
  final TextEditingController _searchController = TextEditingController();
  List<TransacaoModel> _listaFiltrada = [];
  bool _apenasPendentes = false; // NOVO FILTRO

  String get _tituloTela {
    switch (widget.tipoFiltro) {
      case TipoTransacao.entrada: return "Minhas Entradas";
      case TipoTransacao.contaFixa: return "Contas Fixas";
      case TipoTransacao.gastoVariavel: return "Gastos Variáveis";
      case TipoTransacao.poupanca: return "Investimento";
    }
  }

  Color get _corTipo {
    switch (widget.tipoFiltro) {
      case TipoTransacao.entrada: return const Color(0xFF66BB6A);
      case TipoTransacao.contaFixa: return const Color(0xFFEF5350);
      case TipoTransacao.gastoVariavel: return const Color(0xFFFFA726);
      case TipoTransacao.poupanca: return const Color(0xFF4DD0E1);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    setState(() {
      var query = bancoDeDadosGlobal.where((t) => t.data.year == widget.ano && t.data.month == widget.mesIndex);

      if (widget.tipoFiltro == TipoTransacao.poupanca) {
        _listaFiltrada = query.where((t) => (t.tipo == TipoTransacao.poupanca || t.categoria.id == '99')).toList();
      } else {
        query = query.where((t) => t.tipo == widget.tipoFiltro);

        // APLICANDO O FILTRO "APENAS PENDENTES" NAS CONTAS FIXAS
        if (widget.tipoFiltro == TipoTransacao.contaFixa && _apenasPendentes) {
          query = query.where((t) => !t.pago);
        }

        _listaFiltrada = query.toList();
      }
      _listaFiltrada.sort((a, b) => b.data.compareTo(a.data));
    });
  }

  void _filtrarBusca(String query) {
    if (query.isEmpty) { _carregarDados(); } else { setState(() { _listaFiltrada = _listaFiltrada.where((t) => t.descricao.toLowerCase().contains(query.toLowerCase())).toList(); }); }
  }

  // NOVA FUNÇÃO DE PAGAMENTO
  void _confirmarPagamento(TransacaoModel item) {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Confirmar Pagamento?", style: TextStyle(color: Colors.white)),
      content: Text("Marcar '${item.descricao}' como paga?", style: const TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () async {
          setState(() => item.pago = true);
          await salvarDados();
          _carregarDados();
          Navigator.pop(context);
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("SIM, PAGO")),
      ],
    ));
  }

  void _confirmarExclusao(TransacaoModel transacao) {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: const Text('Excluir?', style: TextStyle(color: Colors.white)), content: const Text('Deseja remover?', style: TextStyle(color: Colors.grey)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () async { setState(() { bancoDeDadosGlobal.removeWhere((t) => t.id == transacao.id); _carregarDados(); }); await salvarDados(); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removido!'), backgroundColor: Colors.red)); }, child: const Text('Excluir', style: TextStyle(color: Colors.red)))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_tituloTela - ${widget.mesNome}'), centerTitle: true, bottom: _linhaSeparadora()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.tipoFiltro == TipoTransacao.poupanca) {
            DateTime primeiroDia = DateTime(widget.ano, widget.mesIndex, 1);
            DateTime ultimoDia = DateTime(widget.ano, widget.mesIndex + 1, 0);
            showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), builder: (context) => Container(padding: const EdgeInsets.all(20), height: 180, child: Column(children: [Text("O que deseja fazer?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: true, minDate: primeiroDia, maxDate: ultimoDia, aoSalvar: () => _carregarDados()); }, icon: const Icon(Icons.arrow_downward), label: const Text("GUARDAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)))), const SizedBox(width: 15), Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: false, minDate: primeiroDia, maxDate: ultimoDia, aoSalvar: () => _carregarDados()); }, icon: const Icon(Icons.arrow_upward), label: const Text("RESGATAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB74D))))])])));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TelaCadastro(tipo: widget.tipoFiltro, ano: widget.ano, mesIndex: widget.mesIndex, mesNome: widget.mesNome))).then((_) => _carregarDados());
          }
        },
        label: const Text("Adicionar"), icon: const Icon(Icons.add), backgroundColor: _corTipo, foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: _searchController, onChanged: _filtrarBusca, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Pesquisar...', prefixIcon: Icon(Icons.search, color: Colors.grey)))),

          // --- SWITCH DO FILTRO DE PENDENTES ---
          if (widget.tipoFiltro == TipoTransacao.contaFixa)
            SwitchListTile(
              title: const Text("Mostrar apenas pendentes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              value: _apenasPendentes,
              activeColor: _corTipo,
              onChanged: (val) {
                setState(() {
                  _apenasPendentes = val;
                  _carregarDados();
                });
              },
            ),

          Expanded(child: _listaFiltrada.isEmpty ? Center(child: Text("Nada encontrado.", style: TextStyle(color: Colors.grey[600]))) : ListView.builder(itemCount: _listaFiltrada.length, padding: const EdgeInsets.only(bottom: 80, top: 10), itemBuilder: (context, index) {
            final item = _listaFiltrada[index];
            bool ehResgate = item.categoria.id == '99';
            bool contaPaga = item.tipo == TipoTransacao.contaFixa && item.pago; // Verifica se está paga

            String prefixo = "R\$ ";
            if (widget.tipoFiltro == TipoTransacao.poupanca) prefixo = ehResgate ? "- R\$ " : "+ R\$ ";
            else if (widget.tipoFiltro == TipoTransacao.entrada && ehResgate) prefixo = "R\$ ";

            return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                        leading: CircleAvatar(backgroundColor: ehResgate ? Colors.orange.withOpacity(0.2) : _corTipo.withOpacity(0.2), child: Icon(item.categoria.icone, color: ehResgate ? Colors.orange : _corTipo, size: 20)),

                        title: Row(children: [
                          Expanded(child: Text(item.descricao, style: TextStyle(fontWeight: FontWeight.bold, color: contaPaga ? Colors.green : Colors.white, fontSize: 16, decoration: contaPaga ? TextDecoration.lineThrough : null))),
                          // ÍCONE DE ALERTA (SE NÃO PAGO)
                          if (widget.tipoFiltro == TipoTransacao.contaFixa && !item.pago)
                            const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20))
                        ]),

                        subtitle: Text("${item.categoria.nome} • ${item.data.day}/${item.data.month}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),

                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text("$prefixo${item.valor.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(color: contaPaga ? Colors.grey : (ehResgate ? Colors.orange : _corTipo), fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),

                          // BOTÃO DE CHECK (SE NÃO PAGO)
                          if (widget.tipoFiltro == TipoTransacao.contaFixa && !item.pago)
                            IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.grey), onPressed: () => _confirmarPagamento(item)),

                          InkWell(onTap: () { if(widget.tipoFiltro == TipoTransacao.poupanca || item.tipo == TipoTransacao.poupanca || ehResgate) { DateTime primeiroDia = DateTime(widget.ano, widget.mesIndex, 1); DateTime ultimoDia = DateTime(widget.ano, widget.mesIndex + 1, 0); _TelaPoupancaGlobalState.mostrarDialogoPoupanca(context, ehDeposito: !ehResgate, transacaoParaEditar: item, minDate: primeiroDia, maxDate: ultimoDia, aoSalvar: () => _carregarDados()); } else { Navigator.push(context, MaterialPageRoute(builder: (context) => TelaCadastro(tipo: widget.tipoFiltro, ano: widget.ano, mesIndex: widget.mesIndex, mesNome: widget.mesNome, transacaoParaEditar: item))).then((_) => _carregarDados()); } }, child: const Icon(Icons.edit, size: 18, color: Colors.blue)),
                          const SizedBox(width: 12),
                          InkWell(onTap: () => _confirmarExclusao(item), child: const Icon(Icons.delete, size: 18, color: Colors.redAccent))
                        ])
                    )
                )
            );
          })),
        ],
      ),
    );
  }
}

// ================= TELA 5: CADASTRO =================
class TelaCadastro extends StatefulWidget {
  final TipoTransacao tipo;
  final int ano;
  final int mesIndex;
  final String mesNome;
  final TransacaoModel? transacaoParaEditar;
  final bool bloquearCategoria;
  const TelaCadastro({super.key, required this.tipo, required this.ano, required this.mesIndex, required this.mesNome, this.transacaoParaEditar, this.bloquearCategoria = false});
  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descricaoController;
  late TextEditingController _valorController;
  late DateTime _dataSelecionada;
  CategoriaModel? _categoriaSelecionada;
  bool _repetir = false;
  bool get ehEdicao => widget.transacaoParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (ehEdicao) {
      final t = widget.transacaoParaEditar!;
      _descricaoController = TextEditingController(text: t.descricao);
      _valorController = TextEditingController(text: t.valor.toStringAsFixed(2));
      _dataSelecionada = t.data;
      _categoriaSelecionada = t.categoria;
    } else {
      _descricaoController = TextEditingController();
      _valorController = TextEditingController();
      final hoje = DateTime.now();
      _dataSelecionada = (hoje.year == widget.ano && hoje.month == widget.mesIndex) ? hoje : DateTime(widget.ano, widget.mesIndex, 1);
      if (widget.tipo == TipoTransacao.poupanca) _categoriaSelecionada = categoriasDespesaGlobal.firstWhere((c) => c.id == '98', orElse: () => categoriasDespesaGlobal.first);
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final primeiroDia = DateTime(widget.ano, widget.mesIndex, 1);
    final ultimoDia = DateTime(widget.ano, widget.mesIndex + 1, 0);
    final DateTime? dataEscolhida = await showDatePicker(context: context, initialDate: _dataSelecionada, firstDate: primeiroDia, lastDate: ultimoDia, builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF64B5F6), onPrimary: Colors.black, onSurface: Colors.white)), child: child!));
    if (dataEscolhida != null) setState(() => _dataSelecionada = dataEscolhida);
  }

  void _tentarSalvar() { if (_formKey.currentState!.validate()) _salvarFinal(); }

  void _salvarFinal() async {
    int repeticoes = (_repetir && !ehEdicao) ? 12 : 1;

    for (int i = 0; i < repeticoes; i++) {
      DateTime dataFinal = DateTime(_dataSelecionada.year, _dataSelecionada.month + i, _dataSelecionada.day);
      final novaTransacao = TransacaoModel(
        id: (ehEdicao ? widget.transacaoParaEditar!.id : DateTime.now().millisecondsSinceEpoch.toString()) + "_$i",
        descricao: _descricaoController.text + (repeticoes > 1 ? " (${i+1}/12)" : ""),
        valor: double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0,
        data: dataFinal,
        categoria: _categoriaSelecionada!,
        tipo: widget.tipo,
        pago: false, // Ao criar, sempre começa como não pago
      );

      if (ehEdicao) {
        final index = bancoDeDadosGlobal.indexWhere((t) => t.id == widget.transacaoParaEditar!.id);
        if (index != -1) bancoDeDadosGlobal[index] = novaTransacao;
      } else {
        bancoDeDadosGlobal.add(novaTransacao);
      }
    }
    await salvarDados();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    List<CategoriaModel> categorias;
    if (widget.tipo == TipoTransacao.entrada) categorias = categoriasEntradaGlobal;
    else if (widget.tipo == TipoTransacao.poupanca) { var catPoupanca = categoriasDespesaGlobal.where((c) => c.id == '98'); categorias = catPoupanca.isNotEmpty ? catPoupanca.toList() : [categoriasDespesaGlobal.first]; }
    else categorias = categoriasDespesaGlobal.where((c) => c.id != '98').toList();
    String tituloAcao = ehEdicao ? "Editar" : "Novo Lançamento";

    return Scaffold(
      appBar: AppBar(title: Text(tituloAcao), centerTitle: true, bottom: _linhaSeparadora()),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: _descricaoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Descrição', prefixIcon: Icon(Icons.edit, color: Colors.grey)), validator: (value) => value!.isEmpty ? 'Obrigatório' : null),
        const SizedBox(height: 20),
        TextFormField(controller: _valorController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixIcon: Icon(Icons.attach_money, color: Colors.grey)), validator: (value) => value!.isEmpty ? 'Obrigatório' : null),
        const SizedBox(height: 20),
        GestureDetector(onTap: () => _selecionarData(context), child: AbsorbPointer(child: TextFormField(controller: TextEditingController(text: "${_dataSelecionada.day}/${_dataSelecionada.month}/${_dataSelecionada.year}"), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today, color: Colors.grey), suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey))))),
        const SizedBox(height: 20),
        IgnorePointer(ignoring: widget.bloquearCategoria, child: DropdownButtonFormField<CategoriaModel>(value: (categorias.contains(_categoriaSelecionada)) ? _categoriaSelecionada : (widget.bloquearCategoria && categorias.isNotEmpty ? categorias.first : null), dropdownColor: const Color(0xFF2C2C2C), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category, color: Colors.grey)), items: categorias.map((CategoriaModel cat) { return DropdownMenuItem<CategoriaModel>(value: cat, child: Row(children: [Icon(cat.icone, size: 18, color: const Color(0xFF64B5F6)), const SizedBox(width: 10), Text(cat.nome)])); }).toList(), onChanged: (novoValor) => setState(() => _categoriaSelecionada = novoValor), validator: (value) => value == null ? 'Selecione' : null)),

        if (!ehEdicao && widget.tipo != TipoTransacao.poupanca) ...[
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("Repetir por 12 meses?", style: TextStyle(color: Colors.white)),
            value: _repetir,
            activeColor: const Color(0xFF64B5F6),
            onChanged: (val) => setState(() => _repetir = val),
          )
        ],

        const SizedBox(height: 40),
        SizedBox(height: 50, child: ElevatedButton(onPressed: _tentarSalvar, child: Text(ehEdicao ? "ATUALIZAR" : "SALVAR", style: const TextStyle(fontSize: 18)))),
      ]))),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final String titulo; final String valor; final Color corValor; final IconData icone; final bool temNavegacao;
  const _CardResumo({required this.titulo, required this.valor, required this.corValor, required this.icone, this.temNavegacao = false});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.1))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 4), Text(valor, style: TextStyle(color: corValor, fontSize: 24, fontWeight: FontWeight.bold))]), Row(children: [Icon(icone, color: Colors.grey[700], size: 30), if (temNavegacao) ...[const SizedBox(width: 10), Icon(Icons.arrow_forward_ios, color: Colors.grey[800], size: 14)]])]));
  }
}

PreferredSize _linhaSeparadora() => PreferredSize(preferredSize: const Size.fromHeight(1.0), child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0));