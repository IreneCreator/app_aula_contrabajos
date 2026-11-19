import 'package:flutter/material.dart';

import '../estilo.dart';

enum TipoCelda { libre, mia, otra, sinPrioridad, clase, profesor, cerrado, bloqueada, claseLiberada }

/// Una franja de media hora en la rejilla. El aspecto lo decide el estilo activo.
class Celda extends StatelessWidget {
  final TipoCelda tipo;
  final String etiqueta;

  /// Versiones cada vez más cortas, por si [etiqueta] no cabe.
  /// Ej.: ["Natalia", "NG"] para "Natalia García". Se usa la primera que quepa.
  final List<String> alternativas;
  final bool atenuada;
  final VoidCallback? onTap;

  const Celda({
    super.key,
    required this.tipo,
    this.etiqueta = '',
    this.alternativas = const [],
    this.atenuada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);

    var (fondo, texto, borde) = switch (tipo) {
      TipoCelda.libre => (s.libre, s.tinta, s.borde),
      TipoCelda.mia => (s.mia, s.miaTexto, s.mia),
      TipoCelda.otra => (s.otra, s.otraTexto, s.otra),
      TipoCelda.sinPrioridad => (s.resina, s.resinaTexto, s.resina),
      TipoCelda.clase => (s.clase, s.claseTexto, s.clase),
      TipoCelda.profesor => (s.profe, s.profeTexto, s.profe),
      TipoCelda.cerrado => (s.cerrado, s.suave, s.cerrado),
      TipoCelda.bloqueada => (Colors.transparent, s.suave, s.borde.withValues(alpha: 0.6)),
      TipoCelda.claseLiberada => (s.libre, s.claseTexto.withValues(alpha: 0.7), s.clase),
    };
    if (s.esPixel && tipo != TipoCelda.bloqueada) borde = s.tinta;

    final rayas = s.esPixel && (tipo == TipoCelda.cerrado || tipo == TipoCelda.bloqueada);
    final cursiva = !s.esPixel && (tipo == TipoCelda.clase || tipo == TipoCelda.claseLiberada);

    // Las clases se distinguen sin depender del color (pensado también para personas daltónicas):
    // una barra oscura en el lateral izquierdo.
    final esClase = tipo == TipoCelda.clase;
    final barra = esClase || tipo == TipoCelda.claseLiberada;
    final colorBarra = s.esPixel ? s.tinta : Color.lerp(s.claseTexto, Colors.black, 0.35)!;
    final anchoBarra = barra ? 5.0 : 0.0;

    return Opacity(
      opacity: atenuada ? 0.3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: fondo,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.radio),
            side: BorderSide(color: borde, width: s.grosorBorde),
          ),
          child: InkWell(
            onTap: onTap,
            child: CustomPaint(
              painter: rayas ? _Rayas(s.suave.withValues(alpha: 0.35)) : null,
              child: SizedBox(
                height: 30,
                child: LayoutBuilder(builder: (context, medidas) {
                  final estiloTexto = s.texto(
                    size: 12.5,
                    color: texto,
                    peso: FontWeight.w600,
                    estiloFuente: cursiva ? FontStyle.italic : null,
                  );
                  // Se prueba el texto completo y luego cada alternativa, y se usa la primera que quepa.
                  // Si ninguna cabe, la última (la más corta) con puntos suspensivos.
                  final disponible = medidas.maxWidth - 16 - anchoBarra;
                  var mostrar = etiqueta;
                  if (etiqueta.isNotEmpty && alternativas.isNotEmpty) {
                    bool cabe(String t) {
                      final medida = TextPainter(
                        text: TextSpan(text: t, style: estiloTexto),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();
                      return medida.width <= disponible;
                    }

                    final candidatos = [etiqueta, ...alternativas];
                    mostrar = candidatos.firstWhere(cabe, orElse: () => candidatos.last);
                  }
                  final textoCelda = Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 8 + anchoBarra, right: 8),
                      child: Text(mostrar, maxLines: 1, overflow: TextOverflow.ellipsis, style: estiloTexto),
                    ),
                  );
                  if (!barra) return textoCelda;
                  return Stack(children: [
                    Positioned.fill(child: textoCelda),
                    // Barra lateral: llena en las clases, más suave en las clases liberadas.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: anchoBarra,
                        color: esClase ? colorBarra : colorBarra.withValues(alpha: 0.35),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rayas diagonales para días cerrados o no disponibles en el estilo píxel.
class _Rayas extends CustomPainter {
  final Color color;
  _Rayas(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..isAntiAlias = false;
    for (var x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Rayas old) => old.color != color;
}
