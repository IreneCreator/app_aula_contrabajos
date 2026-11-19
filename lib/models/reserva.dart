import 'package:cloud_firestore/cloud_firestore.dart';

class Reserva {
  final String id; // "2026-10-01_570"
  final String uid;
  final String fecha; // "2026-10-01"
  final int minuto; // minuto del día en que empieza (570 = 9:30)
  final bool deProfesor;
  final String descripcion; // opcional, en las franjas del profesor (p. ej. "Seccionales")
  final DateTime creada;

  const Reserva({
    required this.id,
    required this.uid,
    required this.fecha,
    required this.minuto,
    required this.deProfesor,
    this.descripcion = '',
    required this.creada,
  });

  factory Reserva.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Reserva(
      id: doc.id,
      uid: (d['uid'] as String?) ?? '',
      fecha: (d['fecha'] as String?) ?? '',
      minuto: (d['minuto'] as num?)?.toInt() ?? 0,
      deProfesor: d['deProfesor'] == true,
      descripcion: (d['descripcion'] as String?) ?? '',
      // Mientras el servidor confirma la hora, usamos la del dispositivo.
      creada: (d['creada'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
