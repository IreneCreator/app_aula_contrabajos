import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TipoEstilo { concierto, tamagotchi }

/// Todo lo visual de la app: colores, tipografías, esquinas, bordes y sombras.
/// Para crear un estilo nuevo, añade otra constante como [concierto] o [tamagotchi].
class Estilo extends ThemeExtension<Estilo> {
  final TipoEstilo tipo;
  final String nombre;

  // Colores generales
  final Color fondo;
  final Color tinta; // texto principal
  final Color suave; // texto secundario
  final Color borde;
  final Color tarjeta;
  final Color acento;

  // Colores de las franjas
  final Color libre;
  final Color mia;
  final Color miaTexto;
  final Color otra;
  final Color otraTexto;
  final Color resina; // más horas del máximo: sin prioridad
  final Color resinaTexto;
  final Color clase;
  final Color claseTexto;
  final Color profe;
  final Color profeTexto;
  final Color cerrado;

  // Avisos
  final Color avisoFondo;
  final Color avisoTexto;

  // Solo Tamagotchi: pantalla LCD y motitas de la carcasa
  final Color lcd;
  final Color motas;

  // Formas
  final double radio; // franjas y botones
  final double radioTarjeta;
  final double grosorBorde;
  final Offset sombra; // Offset.zero = sin sombra

  // Tipografías (nombres de Google Fonts)
  final String fuenteTitulos;
  final String fuenteTexto;
  final double factorTexto;

  const Estilo({
    required this.tipo,
    required this.nombre,
    required this.fondo,
    required this.tinta,
    required this.suave,
    required this.borde,
    required this.tarjeta,
    required this.acento,
    required this.libre,
    required this.mia,
    required this.miaTexto,
    required this.otra,
    required this.otraTexto,
    required this.resina,
    required this.resinaTexto,
    required this.clase,
    required this.claseTexto,
    required this.profe,
    required this.profeTexto,
    required this.cerrado,
    required this.avisoFondo,
    required this.avisoTexto,
    required this.lcd,
    required this.motas,
    required this.radio,
    required this.radioTarjeta,
    required this.grosorBorde,
    required this.sombra,
    required this.fuenteTitulos,
    required this.fuenteTexto,
    required this.factorTexto,
  });

  // ───────────── Estilo "Concierto" ─────────────
  static const concierto = Estilo(
    tipo: TipoEstilo.concierto,
    nombre: 'Concierto',
    fondo: Color(0xFFF6F4F1),
    tinta: Color(0xFF1F1A2B),
    suave: Color(0xFF6E6878),
    borde: Color(0xFFE3DED8),
    tarjeta: Color(0xFFFFFFFF),
    acento: Color(0xFF7D2F3A),
    libre: Color(0xFFFFFFFF),
    mia: Color(0xFF2B2340),
    miaTexto: Color(0xFFF6F4F1),
    otra: Color(0xFFE4EAE3),
    otraTexto: Color(0xFF36513D),
    resina: Color(0xFFF2C76E),
    resinaTexto: Color(0xFF5E4108),
    clase: Color(0xFFEFDCDC),
    claseTexto: Color(0xFF7D2F3A),
    profe: Color(0xFF7D2F3A),
    profeTexto: Color(0xFFFFFFFF),
    cerrado: Color(0xFFEAE7E2),
    avisoFondo: Color(0xFFFFFFFF),
    avisoTexto: Color(0xFF1F1A2B),
    lcd: Color(0xFFF6F4F1),
    motas: Color(0xFFF6F4F1),
    radio: 8,
    radioTarjeta: 12,
    grosorBorde: 1,
    sombra: Offset.zero,
    fuenteTitulos: 'Fraunces',
    fuenteTexto: 'Manrope',
    factorTexto: 1,
  );

  // ───────────── Estilo "Tamagotchi" ─────────────
  static const tamagotchi = Estilo(
    tipo: TipoEstilo.tamagotchi,
    nombre: 'Tamagotchi',
    fondo: Color(0xFF7CC7BC), // carcasa turquesa
    tinta: Color(0xFF2E3326), // píxeles oscuros del LCD
    suave: Color(0xFF4A5240),
    borde: Color(0xFF2E3326),
    tarjeta: Color(0xFFFFF8EC), // papel de las pegatinas
    acento: Color(0xFF6EA3D8), // cinta adhesiva
    libre: Color(0xFFD7DCBC),
    mia: Color(0xFF2E3326),
    miaTexto: Color(0xFFD7DCBC),
    otra: Color(0xFF9FA77F),
    otraTexto: Color(0xFF2E3326),
    resina: Color(0xFFFF8A3D),
    resinaTexto: Color(0xFF2E3326),
    clase: Color(0xFF6EA3D8),
    claseTexto: Color(0xFF2E3326),
    profe: Color(0xFF7E5BB5),
    profeTexto: Color(0xFFFFF8EC),
    cerrado: Color(0xFFB5BC95),
    avisoFondo: Color(0xFFFFF8EC),
    avisoTexto: Color(0xFF2E3326),
    lcd: Color(0xFFC8CFA8),
    motas: Color(0xFF5EAFA3),
    radio: 4,
    radioTarjeta: 10,
    grosorBorde: 2,
    sombra: Offset(3, 3),
    fuenteTitulos: 'Pixelify Sans',
    fuenteTexto: 'DotGothic16',
    factorTexto: 1,
  );

  static const todos = [concierto, tamagotchi];

  /// Identificador que se guarda en la ficha del usuario: 'concierto' o 'tamagotchi'.
  String get id => tipo.name;

  static Estilo porId(String? id) {
    if (id == 'pixel') return tamagotchi; // quien eligió el antiguo estilo píxel pasa a Tamagotchi
    return todos.firstWhere((e) => e.id == id, orElse: () => concierto);
  }

  static Estilo of(BuildContext context) => Theme.of(context).extension<Estilo>() ?? concierto;

  bool get esTamagotchi => tipo == TipoEstilo.tamagotchi;

  /// Estilo retro de píxeles (ahora mismo, el Tamagotchi).
  bool get esPixel => esTamagotchi;

  // ───────────── Atajos de estilo ─────────────
  TextStyle titulo({double size = 20, Color? color, FontStyle? estiloFuente, FontWeight? peso}) =>
      GoogleFonts.getFont(
        fuenteTitulos,
        fontSize: size,
        color: color ?? tinta,
        fontStyle: estiloFuente,
        fontWeight: peso ?? (esPixel ? FontWeight.w600 : FontWeight.w500),
      );

  TextStyle texto({double size = 14, Color? color, FontWeight? peso, FontStyle? estiloFuente, double? espaciado}) =>
      GoogleFonts.getFont(
        fuenteTexto,
        fontSize: size * factorTexto,
        color: color ?? tinta,
        fontWeight: peso,
        fontStyle: estiloFuente,
        letterSpacing: espaciado,
      );

  /// Etiqueta pequeña en mayúsculas ("RESERVAS DEL AULA").
  TextStyle etiqueta({Color? color}) => esPixel
      ? titulo(size: 12, color: color ?? tinta)
      : texto(size: 11, color: color ?? suave, peso: FontWeight.w600, espaciado: 1);

  List<BoxShadow> get sombras =>
      sombra == Offset.zero ? const [] : [BoxShadow(color: tinta, offset: sombra)];

  /// Decoración de tarjetas (resúmenes, listas, ajustes).
  BoxDecoration caja({Color? color, Color? colorBorde, bool conSombra = true}) => BoxDecoration(
        color: color ?? tarjeta,
        borderRadius: BorderRadius.circular(radioTarjeta),
        border: Border.all(
          color: colorBorde ?? (esPixel ? tinta : borde),
          width: grosorBorde,
        ),
        boxShadow: conSombra ? sombras : const [],
      );

  /// Forma de diálogos, menús y botones.
  ShapeBorder forma({double? radioForma}) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioForma ?? radioTarjeta),
        side: esPixel ? BorderSide(color: tinta, width: grosorBorde) : BorderSide.none,
      );

  @override
  Estilo copyWith() => this;

  @override
  Estilo lerp(ThemeExtension<Estilo>? other, double t) => (other is Estilo && t >= 0.5) ? other : this;
}
