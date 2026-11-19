import 'package:flutter/material.dart';

import '../estilo.dart';

void avisar(BuildContext context, String texto) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Forma y título comunes a todos los diálogos.
ShapeBorder formaDialogo(BuildContext context) => Estilo.of(context).forma(radioForma: 18);

Widget tituloDialogo(BuildContext context, String texto) =>
    Text(texto, style: Estilo.of(context).titulo(size: 20));

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String boton,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: formaDialogo(c),
      title: tituloDialogo(c, titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(boton)),
      ],
    ),
  );
  return ok == true;
}

/// Muestra varias opciones y devuelve la clave de la elegida (o null si se cancela).
Future<String?> elegir(
  BuildContext context, {
  required String titulo,
  required String texto,
  required Map<String, String> opciones,
}) {
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      shape: formaDialogo(c),
      title: tituloDialogo(c, titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        for (final o in opciones.entries)
          FilledButton(onPressed: () => Navigator.pop(c, o.key), child: Text(o.value)),
      ],
    ),
  );
}

/// Pide un texto. Devuelve null si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String inicial = '',
  int lineas = 1,
  String boton = 'Guardar',
  bool permitirVacio = false,
}) async {
  final ctrl = TextEditingController(text: inicial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) {
      final s = Estilo.of(c);
      return AlertDialog(
        shape: formaDialogo(c),
        title: tituloDialogo(c, titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: lineas,
          decoration: InputDecoration(
            labelText: etiqueta,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(s.radio)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(boton)),
        ],
      );
    },
  );
  if (r == null) return null;
  if (r.isEmpty && !permitirVacio) return null;
  return r;
}
