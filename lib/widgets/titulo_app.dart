import 'package:flutter/material.dart';

import '../estilo.dart';

/// "Aula de contrabajo" en una línea, con el aspecto de cada estilo.
/// Si no cabe, se encoge en lugar de saltar de línea.
class TituloApp extends StatelessWidget {
  final double size;
  const TituloApp({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final Widget texto = s.esTamagotchi
        ? Text('Aula de contrabajo', maxLines: 1, style: s.titulo(size: size))
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Aula de ', style: s.titulo(size: size)),
              TextSpan(
                text: 'contrabajo',
                style: s.titulo(size: size, estiloFuente: FontStyle.italic, peso: FontWeight.w400),
              ),
            ]),
            maxLines: 1,
          );
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: texto);
  }
}
