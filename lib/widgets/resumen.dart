import 'package:flutter/material.dart';

import '../estilo.dart';
import '../logic/fechas.dart';

/// Tarjeta con las horas reservadas en un día.
/// [cuadrado]: versión para la esquina superior derecha en pantallas anchas.
class ResumenDia extends StatelessWidget {
  final String titulo;
  final List<int> minutos; // franjas propias, ordenadas
  final int franjasMax;
  final double horasMax;
  final bool esProfesor;
  final bool cuadrado;

  const ResumenDia({
    super.key,
    required this.titulo,
    required this.minutos,
    required this.franjasMax,
    required this.horasMax,
    this.esProfesor = false,
    this.cuadrado = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final pasada = !esProfesor && minutos.length > franjasMax;
    final vacio = s.esPixel ? '-- vacío --' : 'Sin reservas';

    final Widget barra;
    if (s.esPixel) {
      barra = Row(children: [
        for (var i = 0; i < franjasMax.clamp(1, 12); i++)
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < minutos.length ? (pasada ? s.resina : s.mia) : s.libre,
                border: Border.all(color: s.tinta, width: 1.5),
              ),
            ),
          ),
      ]);
    } else {
      barra = ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: franjasMax == 0 ? 0 : (minutos.length / franjasMax).clamp(0.0, 1.0),
          minHeight: 3,
          backgroundColor: s.borde,
          color: pasada ? s.resinaTexto : s.mia,
        ),
      );
    }

    final decoracion = s.caja(
      color: pasada ? Color.alphaBlend(s.resina.withValues(alpha: 0.3), s.tarjeta) : null,
      colorBorde: pasada && !s.esPixel ? s.resina : null,
    );
    final detalle = Text(
      minutos.isEmpty ? vacio : minutos.map(horaTexto).join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: s.texto(size: 11.5, color: s.suave),
    );
    final cifra = Text.rich(TextSpan(children: [
      TextSpan(text: '${horasDeFranjas(minutos.length)} h', style: s.titulo(size: cuadrado ? 24 : 16)),
      TextSpan(
        text: esProfesor ? ' bloqueadas' : ' / ${horasBonitas(horasMax)} h',
        style: s.texto(size: 12, color: s.suave),
      ),
    ]));

    if (cuadrado) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: decoracion,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo.toUpperCase(), style: s.etiqueta()),
          const SizedBox(height: 2),
          cifra,
          if (!esProfesor) ...[const SizedBox(height: 8), barra],
          const SizedBox(height: 6),
          detalle,
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: decoracion,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(titulo.toUpperCase(), style: s.etiqueta()),
          const SizedBox(width: 8),
          cifra,
          const SizedBox(width: 10),
          Expanded(child: esProfesor ? const SizedBox() : barra),
        ]),
        const SizedBox(height: 4),
        detalle,
      ]),
    );
  }
}
