import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'estilo.dart';

ThemeData crearTema(Estilo s) {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: s.mia,
    scaffoldBackgroundColor: s.fondo,
  );
  final formaBoton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(s.radio),
    side: s.esPixel ? BorderSide(color: s.tinta, width: s.grosorBorde) : BorderSide.none,
  );

  return base.copyWith(
    extensions: [s],
    textTheme: GoogleFonts.getTextTheme(s.fuenteTexto, base.textTheme).apply(
      bodyColor: s.tinta,
      displayColor: s.tinta,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.fondo,
      foregroundColor: s.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s.titulo(size: 20),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.tinta,
      contentTextStyle: s.texto(color: s.fondo),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.radio)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.mia,
        foregroundColor: s.miaTexto,
        shape: formaBoton,
        textStyle: s.texto(size: 15, peso: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: s.tinta,
        textStyle: s.texto(size: 15, peso: FontWeight.w600),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s.tarjeta,
      shape: s.forma(),
      textStyle: s.texto(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: s.mia),
  );
}
