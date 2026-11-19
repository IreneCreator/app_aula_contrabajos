import 'package:cloud_firestore/cloud_firestore.dart';

class DiaCerrado {
  final String fecha; // "2026-12-08"
  final String motivo;

  const DiaCerrado({required this.fecha, this.motivo = ''});

  factory DiaCerrado.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DiaCerrado(fecha: doc.id, motivo: (d['motivo'] as String?) ?? '');
  }
}
