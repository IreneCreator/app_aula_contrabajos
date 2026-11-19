import 'dart:math';

import 'package:flutter/material.dart';

import '../estilo.dart';
import 'mascota.dart';

/// Fondo de plástico moteado (solo en el estilo Tamagotchi).
class Carcasa extends StatelessWidget {
  final Widget child;
  const Carcasa({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    if (!s.esTamagotchi) return child;
    final ancho = MediaQuery.sizeOf(context).width >= 680;
    return Stack(children: [
        // Las motas van en su propia capa: se dibujan una vez y no se repintan
        // cada vez que la mascota se mueve.
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _Motas(s.motas), isComplex: true, willChange: false),
          ),
        ),
        Positioned.fill(child: child),
        // Tornillos en las esquinas (solo en pantallas anchas, para no tapar nada en el móvil)
        if (ancho) ...const [
          Positioned(left: 16, top: 16, child: _Tornillo()),
          Positioned(right: 16, top: 16, child: _Tornillo()),
          Positioned(left: 16, bottom: 16, child: _Tornillo()),
          Positioned(right: 16, bottom: 16, child: _Tornillo()),
        ],
      ]);
  }
}

class _Tornillo extends StatelessWidget {
  const _Tornillo();

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: s.motas,
        shape: BoxShape.circle,
        border: Border.all(color: s.tinta, width: 3),
      ),
      child: Center(
        child: Transform.rotate(angle: 0.6, child: Container(width: 14, height: 3, color: s.tinta)),
      ),
    );
  }
}

/// Columna decorativa a cada lado de la pantalla LCD (solo pantallas anchas).
/// Las pegatinas son provisionales: aquí irán tus dibujos de Procreate.
class LateralCarcasa extends StatelessWidget {
  final bool izquierdo;
  const LateralCarcasa({super.key, required this.izquierdo});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final hijos = izquierdo
        ? <Widget>[
            const SizedBox(height: 28),
            const _RejillaAltavoz(),
            const Spacer(),
            Pegatina(
              color: s.clase,
              angulo: -0.18,
              child: Text('COSCyL', style: s.titulo(size: 11)),
            ),
            const SizedBox(height: 40),
          ]
        : <Widget>[
            const SizedBox(height: 36),
            Pegatina(
              color: s.tarjeta,
              angulo: 0.14,
              child: Text('4/4', style: s.titulo(size: 14)),
            ),
            const SizedBox(height: 30),
            Pegatina(
              color: s.resina,
              angulo: -0.1,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SpritePixel(mapa: spriteNota, color: s.tinta, pixel: 2.5),
                const SizedBox(width: 3),
                SpritePixel(mapa: spriteNota, color: s.tinta, pixel: 2.5),
              ]),
            ),
            const Spacer(),
          ];
    // Las pegatinas se alinean hacia fuera, lejos de la pantalla central.
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: izquierdo ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: hijos,
      ),
    );
  }
}

/// Pegatina de papel ligeramente torcida.
class Pegatina extends StatelessWidget {
  final Widget child;
  final Color color;
  final double angulo;

  const Pegatina({super.key, required this.child, required this.color, this.angulo = 0});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Transform.rotate(
      angle: angulo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: s.tinta, width: 2),
          boxShadow: [BoxShadow(color: s.tinta, offset: const Offset(2, 2))],
        ),
        child: child,
      ),
    );
  }
}

/// Agujeros de altavoz, como en los aparatos de verdad.
class _RejillaAltavoz extends StatelessWidget {
  const _RejillaAltavoz();

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    Widget agujero() => Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(color: s.tinta.withValues(alpha: 0.75), shape: BoxShape.circle),
        );
    return Column(children: [
      for (var f = 0; f < 5; f++) Row(mainAxisSize: MainAxisSize.min, children: [for (var c = 0; c < 3; c++) agujero()]),
    ]);
  }
}

class _Motas extends CustomPainter {
  final Color color;
  _Motas(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final azar = Random(7); // misma semilla: las motas no cambian de sitio
    final oscura = Paint()..color = color;
    final clara = Paint()..color = Colors.white.withValues(alpha: 0.5);
    const paso = 15.0;
    for (var y = 0.0; y < size.height; y += paso) {
      for (var x = 0.0; x < size.width; x += paso) {
        if (azar.nextDouble() < 0.6) {
          canvas.drawCircle(Offset(x + azar.nextDouble() * paso, y + azar.nextDouble() * paso), 1.4, oscura);
        }
        if (azar.nextDouble() < 0.25) {
          canvas.drawCircle(Offset(x + azar.nextDouble() * paso, y + azar.nextDouble() * paso), 1.0, clara);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Motas old) => old.color != color;
}

/// Pantalla LCD con trama de píxeles donde vive la rejilla.
class PantallaLcd extends StatelessWidget {
  final Widget child;
  const PantallaLcd({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: s.lcd,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.tinta, width: 4),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // La trama de píxeles también va en su propia capa.
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _Trama(s.tinta.withValues(alpha: 0.05)), isComplex: true, willChange: false),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4), child: child),
      ]),
    );
  }
}

class _Trama extends CustomPainter {
  final Color color;
  _Trama(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Trama old) => old.color != color;
}

/// Botón redondo del aparato, con su etiqueta debajo.
class BotonAparato extends StatelessWidget {
  final Color color;
  final String etiqueta;
  final VoidCallback? onTap; // null si lo gestiona otro widget (p. ej. un menú)

  const BotonAparato({super.key, required this.color, required this.etiqueta, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final boton = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: s.tinta, width: 3),
          // Brillo arriba a la izquierda y sombra abajo, como un botón de plástico.
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.9,
            colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.18)!],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [BoxShadow(color: s.tinta, offset: const Offset(2, 3))],
        ),
      ),
      const SizedBox(height: 4),
      Text(etiqueta, style: s.texto(size: 12)),
    ]);
    if (onTap == null) return boton;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: boton);
  }
}
