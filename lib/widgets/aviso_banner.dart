import 'package:flutter/material.dart';

import '../estilo.dart';
import '../models/aviso.dart';

class AvisoBanner extends StatelessWidget {
  final Aviso aviso;
  final VoidCallback? onBorrar;

  const AvisoBanner({super.key, required this.aviso, this.onBorrar});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);

    final contenido = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(
                text: s.esTamagotchi ? '' : 'Aviso · ',
                style: s.texto(size: 13, peso: FontWeight.w700, color: s.acento),
              ),
              TextSpan(text: aviso.texto, style: s.texto(size: 13, color: s.avisoTexto)),
            ])),
            const SizedBox(height: 2),
            Text('— ${aviso.autor}', style: s.texto(size: 12, color: s.suave)),
          ]),
        ),
        if (onBorrar != null)
          IconButton(
            tooltip: 'Quitar aviso',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: s.suave),
            onPressed: onBorrar,
          ),
      ]),
    );

    if (s.esTamagotchi) {
      // Pegatina de papel sujeta con un trozo de cinta adhesiva.
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(width: double.infinity, decoration: s.caja(conSombra: false), child: contenido),
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.05,
                child: Container(width: 72, height: 18, color: s.acento.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ]),
      );
    }

    // Concierto: nota blanca con una línea lateral de color.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: s.avisoFondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.borde),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 3, color: s.acento),
          Expanded(child: contenido),
        ]),
      ),
    );
  }
}
