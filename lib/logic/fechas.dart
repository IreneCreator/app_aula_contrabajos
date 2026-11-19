import '../config.dart';

String _dos(int n) => n.toString().padLeft(2, '0');

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2026-10-01": se ordena bien como texto.
String fechaClave(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

DateTime deFechaClave(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String idReserva(String fecha, int minuto) => '${fecha}_$minuto';
String claveReserva(DateTime dia, int minuto) => idReserva(fechaClave(dia), minuto);

String horaTexto(int minuto) => '${minuto ~/ 60}:${_dos(minuto % 60)}';

/// "lunes 5"
String fechaCorta(DateTime d) => '${diasLargos[d.weekday - 1]} ${d.day}';

/// "lunes 5 de octubre"
String fechaLarga(DateTime d) => '${fechaCorta(d)} de ${meses[d.month - 1]}';

/// "Hoy", "Mañana" o "jue 8"
String nombreDia(DateTime d, int indice) {
  if (indice == 0) return 'Hoy';
  if (indice == 1) return 'Mañana';
  return '${diasCortos[d.weekday - 1]} ${d.day}';
}

/// 1.5 -> "1,5"; 2.0 -> "2"
String horasBonitas(double h) =>
    h == h.roundToDouble() ? h.toInt().toString() : h.toString().replaceAll('.', ',');

String horasDeFranjas(int franjas) => horasBonitas(franjas * minutosFranja / 60);

String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
