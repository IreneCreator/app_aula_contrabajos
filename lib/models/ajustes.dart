import '../config.dart';

/// Ajustes generales, editables desde la app por un administrador.
class Ajustes {
  final int diasAntelacion; // 1 = hoy y mañana
  final double horasMaxDia; // horas con prioridad por persona y día
  final int horaInicio; // días normales
  final int horaFin;
  final int horaInicioFestivo; // festivos, sábados y domingos
  final int horaFinFestivo;
  final int diasVista;

  const Ajustes({
    this.diasAntelacion = 1,
    this.horasMaxDia = 2,
    this.horaInicio = 9,
    this.horaFin = 24,
    this.horaInicioFestivo = 10,
    this.horaFinFestivo = 20,
    this.diasVista = 3,
  });

  int get franjasConPrioridad => (horasMaxDia * 60 / minutosFranja).round();

  factory Ajustes.desdeMapa(Map<String, dynamic>? d) {
    if (d == null) return const Ajustes();
    return Ajustes(
      diasAntelacion: (d['diasAntelacion'] as num?)?.toInt() ?? 1,
      horasMaxDia: (d['horasMaxDia'] as num?)?.toDouble() ?? 2,
      horaInicio: (d['horaInicio'] as num?)?.toInt() ?? 9,
      horaFin: (d['horaFin'] as num?)?.toInt() ?? 24,
      horaInicioFestivo: (d['horaInicioFestivo'] as num?)?.toInt() ?? 10,
      horaFinFestivo: (d['horaFinFestivo'] as num?)?.toInt() ?? 20,
      diasVista: (d['diasVista'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toMapa() => {
        'diasAntelacion': diasAntelacion,
        'horasMaxDia': horasMaxDia,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'horaInicioFestivo': horaInicioFestivo,
        'horaFinFestivo': horaFinFestivo,
        'diasVista': diasVista,
      };

  Ajustes copyWith({
    int? diasAntelacion,
    double? horasMaxDia,
    int? horaInicio,
    int? horaFin,
    int? horaInicioFestivo,
    int? horaFinFestivo,
    int? diasVista,
  }) =>
      Ajustes(
        diasAntelacion: diasAntelacion ?? this.diasAntelacion,
        horasMaxDia: horasMaxDia ?? this.horasMaxDia,
        horaInicio: horaInicio ?? this.horaInicio,
        horaFin: horaFin ?? this.horaFin,
        horaInicioFestivo: horaInicioFestivo ?? this.horaInicioFestivo,
        horaFinFestivo: horaFinFestivo ?? this.horaFinFestivo,
        diasVista: diasVista ?? this.diasVista,
      );
}
