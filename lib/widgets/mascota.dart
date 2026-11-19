import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../estilo.dart';

enum Humor { dormido, contento, agobiado }

/// Reacciones breves a lo que hace el usuario.
enum Reaccion { reservar, ocupar, cancelar }

enum _Cara { contento, dormido, agobiado, triste, euforia }

/// La mascota del estilo Tamagotchi: un contrabajito con cara que salta, parpadea
/// y reacciona. Provisional hasta tener los dibujos de Procreate.
class Mascota extends StatefulWidget {
  final Humor humor;
  final double alto;

  /// Última reacción y su número. Cada vez que [idReaccion] cambia, la mascota reacciona.
  final Reaccion? reaccion;
  final int idReaccion;

  const Mascota({
    super.key,
    this.humor = Humor.contento,
    this.alto = 80,
    this.reaccion,
    this.idReaccion = 0,
  });

  @override
  State<Mascota> createState() => _MascotaState();
}

class _MascotaState extends State<Mascota> {
  static const _duracionReaccion = Duration(milliseconds: 2200);
  static const _vidaParticula = 1600; // ms

  final _azar = Random();
  int _tic = 0;
  Timer? _reloj; // ritmo normal: saltitos y parpadeo
  Timer? _animador; // ritmo rápido: partículas y saltos de reacción
  Timer? _finReaccion;
  Reaccion? _activa;
  final List<_Particula> _particulas = [];

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      _tic++;
      final s = Estilo.tamagotchi;
      if (_activa == null) {
        // Dormida: de vez en cuando suelta una "z".
        if (widget.humor == Humor.dormido && _tic % 4 == 0) {
          _soltar(_Sprite.zeta, [s.tinta], 1);
        }
        // Estresada: suda y suelta "!!".
        if (widget.humor == Humor.agobiado) {
          if (_tic.isEven) _soltarGotas();
          if (_tic % 5 == 0) _soltarExclamacion();
        }
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant Mascota old) {
    super.didUpdateWidget(old);
    if (widget.idReaccion != old.idReaccion && widget.reaccion != null) _reaccionar(widget.reaccion!);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _animador?.cancel();
    _finReaccion?.cancel();
    _animador = null;
    _finReaccion = null;
    super.dispose();
  }

  void _reaccionar(Reaccion r) {
    final s = Estilo.tamagotchi;
    _activa = r;
    _finReaccion?.cancel();
    _finReaccion = Timer(_duracionReaccion, () {
      if (mounted) setState(() => _activa = null);
    });
    switch (r) {
      case Reaccion.reservar:
        _soltar(_Sprite.nota, [s.tinta, s.profe], 5);
      case Reaccion.ocupar:
        _soltar(_Sprite.cuadro, [s.resina, s.clase, s.profe, s.tarjeta], 10);
      case Reaccion.cancelar:
        break;
    }
    _arrancarAnimador();
  }

  void _soltar(List<String> sprite, List<Color> colores, int cuantas) {
    final ahora = DateTime.now();
    for (var i = 0; i < cuantas; i++) {
      _particulas.add(_Particula(
        sprite: sprite,
        color: colores[i % colores.length],
        inicio: ahora.add(Duration(milliseconds: i * 120)),
        x: widget.alto * (0.15 + _azar.nextDouble() * 0.5),
        y: widget.alto * (0.05 + _azar.nextDouble() * 0.25),
        dx: (_azar.nextDouble() - 0.5) * widget.alto * 0.7,
        subida: 0.7,
      ));
    }
    _arrancarAnimador();
  }

  /// Dos gotas de sudor que salen disparadas hacia los lados y caen.
  void _soltarGotas() {
    final ahora = DateTime.now();
    final color = Estilo.tamagotchi.clase;
    for (final lado in [-1, 1]) {
      _particulas.add(_Particula(
        sprite: _Sprite.gota,
        color: color,
        inicio: ahora,
        x: widget.alto * (lado < 0 ? 0.05 : 0.48),
        y: widget.alto * 0.5,
        dx: lado * widget.alto * (0.25 + _azar.nextDouble() * 0.15),
        subida: -0.3, // negativo: cae
      ));
    }
    _arrancarAnimador();
  }

  /// Un "!!" que sale de la cabeza.
  void _soltarExclamacion() {
    _particulas.add(_Particula(
      sprite: _Sprite.exclamacion,
      color: Estilo.tamagotchi.resina,
      inicio: DateTime.now(),
      x: widget.alto * 0.42,
      y: widget.alto * 0.02,
      dx: widget.alto * 0.1,
      subida: 0.35,
    ));
    _arrancarAnimador();
  }

  void _arrancarAnimador() {
    if (!mounted) return;
    _animador ??= Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted) {
        _animador?.cancel();
        _animador = null;
        return;
      }
      final ahora = DateTime.now();
      _particulas.removeWhere((p) => ahora.difference(p.inicio).inMilliseconds > _vidaParticula);
      if (_particulas.isEmpty && _activa == null) {
        _animador?.cancel();
        _animador = null;
      }
      setState(() {});
    });
  }

  _Cara get _cara => switch (_activa) {
        Reaccion.reservar => _Cara.contento,
        Reaccion.ocupar => _Cara.euforia,
        Reaccion.cancelar => _Cara.triste,
        null => switch (widget.humor) {
            Humor.dormido => _Cara.dormido,
            Humor.contento => _Cara.contento,
            Humor.agobiado => _Cara.agobiado,
          },
      };

  @override
  Widget build(BuildContext context) {
    final pixel = widget.alto / 18;
    final ahora = DateTime.now();

    // Arriba o abajo en este momento
    final bool arriba;
    if (_activa == Reaccion.reservar || _activa == Reaccion.ocupar) {
      arriba = (ahora.millisecondsSinceEpoch ~/ 150).isEven; // saltos rápidos de alegría
    } else if (_activa == Reaccion.cancelar) {
      arriba = false; // triste: quieta y agachada
    } else {
      arriba = switch (widget.humor) {
        Humor.dormido => false,
        Humor.contento => _tic.isOdd,
        Humor.agobiado => _tic.isEven,
      };
    }
    final parpadea = _activa == null && _tic % 7 == 0;

    final tamPart = pixel * 0.8;
    return SizedBox(
      width: widget.alto * 11 / 18,
      height: widget.alto + pixel * 2,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, arriba ? 0 : pixel * 2),
            child: CustomPaint(painter: _PintorMascota(_cara, parpadea)),
          ),
        ),
        for (final p in _particulas)
          if (!ahora.isBefore(p.inicio))
            Builder(builder: (_) {
              // Avance en 8 pasos, para que se mueva "a saltos" como en una pantalla LCD.
              final t = (ahora.difference(p.inicio).inMilliseconds / _vidaParticula).clamp(0.0, 1.0);
              final paso = (t * 8).floor() / 8;
              return Positioned(
                left: p.x + p.dx * paso,
                top: p.y - widget.alto * p.subida * paso,
                child: Opacity(
                  opacity: 1 - paso,
                  child: SpritePixel(mapa: p.sprite, color: p.color, pixel: tamPart),
                ),
              );
            }),
      ]),
    );
  }
}

class _Particula {
  final List<String> sprite;
  final Color color;
  final DateTime inicio;
  final double x, y, dx;
  final double subida; // cuánto sube (en proporción al alto); negativo = cae
  _Particula({
    required this.sprite,
    required this.color,
    required this.inicio,
    required this.x,
    required this.y,
    required this.dx,
    required this.subida,
  });
}

/// Pequeños dibujos de píxeles para partículas y pegatinas.
class _Sprite {
  static const nota = [
    '...##',
    '...#.',
    '...#.',
    '.###.',
    '####.',
    '.##..',
  ];
  static const zeta = [
    '####',
    '..#.',
    '.#..',
    '####',
  ];
  static const cuadro = ['##', '##'];
  static const gota = [
    '.#.',
    '###',
    '###',
    '.#.',
  ];
  static const exclamacion = [
    '#.#',
    '#.#',
    '#.#',
    '...',
    '#.#',
  ];
}

/// Mapa público de la nota, para usarla en pegatinas.
const spriteNota = _Sprite.nota;

/// Dibuja un mapa de píxeles ('#' = píxel pintado).
class SpritePixel extends StatelessWidget {
  final List<String> mapa;
  final Color color;
  final double pixel;

  const SpritePixel({super.key, required this.mapa, required this.color, this.pixel = 3});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(mapa.first.length * pixel, mapa.length * pixel),
      painter: _PintorSprite(mapa, color),
    );
  }
}

class _PintorSprite extends CustomPainter {
  final List<String> mapa;
  final Color color;
  _PintorSprite(this.mapa, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / mapa.first.length;
    final p = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < mapa.length; y++) {
      for (var x = 0; x < mapa[y].length; x++) {
        if (mapa[y][x] == '#') canvas.drawRect(Rect.fromLTWH(x * px, y * px, px + 0.5, px + 0.5), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PintorSprite old) => old.color != color || old.mapa != mapa;
}

class _PintorMascota extends CustomPainter {
  final _Cara cara;
  final bool parpadea;

  _PintorMascota(this.cara, this.parpadea);

  // s = voluta, n = mástil, b = cuerpo, p = pica. La cara se dibuja aparte.
  static const _cuerpo = [
    '.....s.....',
    '....ss.....',
    '.....n.....',
    '.....n.....',
    '.....n.....',
    '....bnb....',
    '...bbbbb...',
    '...bbbbb...',
    '....bbb....',
    '..bbbbbbb..',
    '.bbbbbbbbb.',
    '.bbbbbbbbb.',
    '.bbbbbbbbb.',
    '.bbbbbbbbb.',
    '.bbbbbbbbb.',
    '..bbbbbbb..',
    '...bbbbb...',
    '.....p.....',
  ];

  static const _tinta = Color(0xFF2E3326);
  static const _madera = Color(0xFFC77B3B);
  static const _gota = Color(0xFF6EA3D8);

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 11;

    void punto(int x, int y, Color c) => canvas.drawRect(
          Rect.fromLTWH(x * px, y * px, px + 0.5, px + 0.5),
          Paint()
            ..color = c
            ..isAntiAlias = false,
        );

    for (var y = 0; y < _cuerpo.length; y++) {
      for (var x = 0; x < _cuerpo[y].length; x++) {
        final c = _cuerpo[y][x];
        if (c == '.') continue;
        punto(x, y, c == 'b' ? _madera : _tinta);
      }
    }

    // Ojos
    if (cara == _Cara.euforia) {
      // ojos en forma de ^ ^
      for (final (x, y) in [(2, 11), (3, 10), (4, 11), (6, 11), (7, 10), (8, 11)]) {
        punto(x, y, _tinta);
      }
    } else if (cara == _Cara.agobiado && !parpadea) {
      // ojos muy abiertos
      for (final x in [3, 7]) {
        punto(x, 10, _tinta);
        punto(x, 11, _tinta);
      }
    } else if (cara == _Cara.dormido || parpadea) {
      for (final x in [2, 3, 7, 8]) {
        punto(x, 11, _tinta);
      }
    } else {
      punto(3, 11, _tinta);
      punto(7, 11, _tinta);
    }

    // Boca
    switch (cara) {
      case _Cara.dormido:
        punto(5, 13, _tinta);
      case _Cara.contento:
        punto(3, 12, _tinta);
        punto(7, 12, _tinta);
        for (final x in [4, 5, 6]) {
          punto(x, 13, _tinta);
        }
      case _Cara.euforia:
        punto(3, 12, _tinta);
        punto(7, 12, _tinta);
        for (final x in [4, 5, 6]) {
          punto(x, 13, _tinta);
        }
        punto(5, 14, _tinta);
      case _Cara.triste:
        for (final x in [4, 5, 6]) {
          punto(x, 13, _tinta);
        }
        punto(3, 14, _tinta);
        punto(7, 14, _tinta);
      case _Cara.agobiado:
        for (final x in [4, 5, 6]) {
          punto(x, 13, _tinta);
          punto(x, 14, _tinta);
        }
        punto(9, 8, _gota); // gota de sudor
        punto(9, 9, _gota);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMascota old) => old.cara != cara || old.parpadea != parpadea;
}
