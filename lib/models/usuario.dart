import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String uid;
  final String nombre;
  final String email;
  final String estilo; // 'concierto' o 'tamagotchi'
  final int diasVista; // días que quiere ver; 0 = automático
  final bool admin; // gestiona ajustes y permisos
  final bool profesor; // bloquea horas sin límite
  final bool gestorClases; // gestiona clases, avisos y días cerrados

  const Usuario({
    required this.uid,
    required this.nombre,
    this.email = '',
    this.estilo = 'concierto',
    this.diasVista = 0,
    this.admin = false,
    this.profesor = false,
    this.gestorClases = false,
  });

  /// Puede gestionar clases, avisos y días cerrados.
  bool get gestiona => admin || profesor || gestorClases;

  factory Usuario.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Usuario(
      uid: doc.id,
      nombre: (d['nombre'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      estilo: (d['estilo'] as String?) ?? 'concierto',
      diasVista: (d['diasVista'] as num?)?.toInt() ?? 0,
      admin: d['admin'] == true,
      profesor: d['profesor'] == true,
      gestorClases: d['gestorClases'] == true,
    );
  }
}
