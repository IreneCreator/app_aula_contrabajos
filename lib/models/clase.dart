import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';

/// Clase del horario. Puede ser fija (se repite todas las semanas) o puntual
/// (solo un día concreto, por ejemplo cuando se mueve una clase fija).
class Clase {
  final String id;
  final int diaSemana; // 1 = lunes ... 7 = domingo
  final int inicio; // minuto del día
  final int fin; // minuto del día (no incluido)
  final String descripcion;
  final String abreviatura; // opcional, para cuando no cabe la descripción

  // Solo en clases puntuales:
  final String? fecha; // "2026-10-05": el único día en que hay clase
  final String? origenId; // clase fija de la que viene, si es un movimiento
  final String? origenFecha; // día en que estaba originalmente

  const Clase({
    this.id = '',
    required this.diaSemana,
    required this.inicio,
    required this.fin,
    required this.descripcion,
    this.abreviatura = '',
    this.fecha,
    this.origenId,
    this.origenFecha,
  });

  /// Es una clase de un solo día (por ejemplo, una clase movida).
  bool get esPuntual => fecha != null;

  /// Viene de mover una clase fija.
  bool get esMovida => esPuntual && origenId != null;

  /// Versión corta: la abreviatura o, si no hay, la primera letra de la descripción.
  String get corta {
    if (abreviatura.trim().isNotEmpty) return abreviatura.trim();
    final d = descripcion.trim();
    return d.isEmpty ? '?' : d[0].toUpperCase();
  }

  /// La franja que empieza en [minuto] coincide, aunque sea en parte, con la clase.
  /// Así, una clase de 10:15 a 11:45 bloquea las franjas de 10:00 a 11:30.
  bool contiene(int minuto) => minuto < fin && minuto + minutosFranja > inicio;

  /// La clase empieza dentro de esta franja.
  bool empiezaEn(int minuto) => inicio >= minuto && inicio < minuto + minutosFranja;

  /// La clase empieza o acaba a una hora que no es en punto ni y media.
  bool get horaRara => inicio % minutosFranja != 0 || fin % minutosFranja != 0;

  factory Clase.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Clase(
      id: doc.id,
      diaSemana: (d['diaSemana'] as num?)?.toInt() ?? 1,
      inicio: (d['inicio'] as num?)?.toInt() ?? 0,
      fin: (d['fin'] as num?)?.toInt() ?? 0,
      descripcion: (d['descripcion'] as String?) ?? 'Clase',
      abreviatura: (d['abreviatura'] as String?) ?? '',
      fecha: d['fecha'] as String?,
      origenId: d['origenId'] as String?,
      origenFecha: d['origenFecha'] as String?,
    );
  }

  Map<String, dynamic> toMapa() => {
        'diaSemana': diaSemana,
        'inicio': inicio,
        'fin': fin,
        'descripcion': descripcion,
        'abreviatura': abreviatura,
        if (fecha != null) 'fecha': fecha,
        if (origenId != null) 'origenId': origenId,
        if (origenFecha != null) 'origenFecha': origenFecha,
      };
}
