import 'package:flutter/material.dart';

import '../estilo.dart';

class Leyenda extends StatelessWidget {
  final String horasMax;
  const Leyenda({super.key, required this.horasMax});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);

    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(s.esPixel ? 0 : 3),
              border: Border.all(color: s.esPixel ? s.tinta : s.borde, width: s.esPixel ? 2 : 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(t, style: s.texto(size: 12, color: s.tinta.withValues(alpha: 0.85))),
        ]);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: s.esPixel ? s.tinta : s.borde, width: s.grosorBorde)),
      ),
      child: Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, children: [
        item(s.libre, 'Libre'),
        item(s.mia, 'Tuya'),
        item(s.otra, 'Ocupada'),
        item(s.resina, 'Más de $horasMax h'),
        _muestraClase(s),
        item(s.profe, 'Profesor'),
        item(s.cerrado, 'Fuera de horario'),
      ]),
    );
  }

  /// Muestra de "Clase" con su barra lateral, como en la rejilla.
  Widget _muestraClase(Estilo s) {
    final colorBarra = s.esPixel ? s.tinta : Color.lerp(s.claseTexto, Colors.black, 0.35)!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 16,
        height: 12,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: s.clase,
          borderRadius: BorderRadius.circular(s.esPixel ? 0 : 3),
          border: Border.all(color: s.esPixel ? s.tinta : s.borde, width: s.esPixel ? 2 : 1),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(width: 4, color: colorBarra),
        ),
      ),
      const SizedBox(width: 6),
      Text('Clase', style: s.texto(size: 12, color: s.tinta.withValues(alpha: 0.85))),
    ]);
  }
}
