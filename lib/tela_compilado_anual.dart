import 'package:flutter/material.dart';
import 'main.dart'; // Importante para acessar o bancoDeDadosGlobal e modelos

class TelaCompiladoAnual extends StatelessWidget {
  final int ano;

  const TelaCompiladoAnual({super.key, required this.ano});

  double _calcularTotalAnual(TipoTransacao tipo) {
    return bancoDeDadosGlobal
        .where((t) => t.tipo == tipo && t.data.year == ano)
        .fold(0.0, (sum, item) => sum + item.valor);
  }

  @override
  Widget build(BuildContext context) {
    double totalEntradas = _calcularTotalAnual(TipoTransacao.entrada);
    double totalFixas = _calcularTotalAnual(TipoTransacao.contaFixa);
    double totalVariaveis = _calcularTotalAnual(TipoTransacao.gastoVariavel);
    double totalInvestido = _calcularTotalAnual(TipoTransacao.poupanca);

    // Resgates do cofre (Categoria 99)
    double totalResgates = bancoDeDadosGlobal
        .where((t) => t.categoria.id == '99' && t.data.year == ano)
        .fold(0.0, (sum, t) => sum + t.valor);

    double saldoFinal = totalEntradas -
        (totalFixas + totalVariaveis + totalInvestido) +
        totalResgates;
    Color corBalanco =
        saldoFinal >= 0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    return Scaffold(
      appBar: AppBar(
        title: Text('Compilado Anual $ano'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              // Filtra para ver se existe alguma transação no ano
              final temDados =
                  bancoDeDadosGlobal.any((t) => t.data.year == ano);

              if (!temDados) {
                // Aviso padrão igual ao mensal
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Sem registros para PDF."),
                    backgroundColor:
                        Colors.orange, // Cor laranja padrão que você usa
                  ),
                );
              } else {
                PdfService.gerarRelatorioAnual(
                    context, ano, bancoDeDadosGlobal);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // ... resto do seu código de layout
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Principal de Saldo do Ano
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: corBalanco.withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  const Text("Saldo Acumulado no Ano",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "R\$ ${saldoFinal.toStringAsFixed(2).replaceAll('.', ',')}",
                      style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: corBalanco),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text("Resumo de Movimentações",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _ItemResumoAnual(
              titulo: "Total de Entradas",
              valor: totalEntradas,
              cor: const Color(0xFF66BB6A),
              icone: Icons.trending_up,
            ),
            _ItemResumoAnual(
              titulo: "Contas Fixas Pagas",
              valor: totalFixas,
              cor: const Color(0xFFEF5350),
              icone: Icons.receipt_long,
            ),
            _ItemResumoAnual(
              titulo: "Gastos Variáveis",
              valor: totalVariaveis,
              cor: const Color(0xFFFFA726),
              icone: Icons.shopping_bag,
            ),
            _ItemResumoAnual(
              titulo: "Total Investido (Cofre)",
              valor: totalInvestido - totalResgates,
              cor: const Color(0xFF4DD0E1),
              icone: Icons.savings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemResumoAnual extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;

  const _ItemResumoAnual(
      {required this.titulo,
      required this.valor,
      required this.cor,
      required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 15),
          Text(titulo, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cor),
          ),
        ],
      ),
    );
  }
}
