import 'package:cloud_firestore/cloud_firestore.dart';

class Aviso {
  final String id;
  final String texto;
  final String autor;
  final DateTime creado;

  const Aviso({required this.id, required this.texto, required this.autor, required this.creado});

  factory Aviso.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Aviso(
      id: doc.id,
      texto: (d['texto'] as String?) ?? '',
      autor: (d['autor'] as String?) ?? '',
      creado: (d['creado'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
