class Transacao {
  final int? id;
  final String descricao;
  final double valor;
  final String tipo; // 'entrada', 'conta', 'saida'
  final String categoria;
  final DateTime data;

  Transacao({
    this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.categoria,
    required this.data,
  });

  // Converte para salvar no SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'tipo': tipo,
      'categoria': categoria,
      'data': data.toIso8601String(), // SQLite guarda data como Texto
    };
  }

  // Converte do SQLite para o App
  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'],
      descricao: map['descricao'],
      valor: map['valor'],
      tipo: map['tipo'],
      categoria: map['categoria'],
      data: DateTime.parse(map['data']),
    );
  }
}