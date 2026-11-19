import 'package:flutter/material.dart';

import '../estilo.dart';
import '../logic/fechas.dart';
import '../models/clase.dart';
import '../services/datos_service.dart';
import 'dialogos.dart';

/// Acciones sobre una clase en un día concreto, compartidas por la rejilla
/// y por la pantalla "Clases de la semana".

Future<void> _ejecutar(BuildContext context, Future<void> Function() accion, String ok) async {
  try {
    await accion();
    if (context.mounted) avisar(context, ok);
  } catch (_) {
    if (context.mounted) avisar(context, 'No se ha podido guardar.');
  }
}

Future<void> liberarClaseDia(BuildContext context, Clase clase, DateTime dia) => _ejecutar(
      context,
      () => Datos.liberarClase(clase.id, fechaClave(dia)),
      '${clase.descripcion}: liberada el ${fechaCorta(dia)}.',
    );

/// Vuelve a poner una clase fija liberada. Si se había movido, deshace el movimiento.
Future<void> restaurarClaseDia(BuildContext context, Clase clase, DateTime dia, {Clase? movida}) => _ejecutar(
      context,
      () => movida != null ? Datos.deshacerMovimiento(movida) : Datos.restaurarClase(clase.id, fechaClave(dia)),
      '${clase.descripcion}: vuelve a su sitio.',
    );

Future<void> devolverClase(BuildContext context, Clase puntual) => _ejecutar(
      context,
      () => Datos.deshacerMovimiento(puntual),
      '${puntual.descripcion}: vuelve a su sitio.',
    );

Future<void> quitarClaseDia(BuildContext context, Clase puntual) => _ejecutar(
      context,
      () => Datos.quitarClasePuntual(puntual.id),
      '${puntual.descripcion}: quitada este día.',
    );

/// Cambia el día, la hora de inicio y/o la de fin de una clase solo para esa ocasión.
/// Sirve para moverla, acortarla o alargarla.
Future<void> moverClaseConDialogo(BuildContext context, Clase clase, DateTime diaOrigen) async {
  final hoy = soloDia(DateTime.now());
  var destino = diaOrigen;
  var inicio = clase.inicio;
  var fin = clase.fin;
  final horas = [for (var m = 7 * 60; m <= 24 * 60; m += 15) m];
  for (final m in [inicio, fin]) {
    if (!horas.contains(m)) horas.add(m);
  }
  horas.sort();

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, actualizar) {
        final s = Estilo.of(c);
        final duracion = fin - inicio;
        return AlertDialog(
          shape: formaDialogo(c),
          title: tituloDialogo(c, 'Cambiar ${clase.descripcion}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Ahora: ${fechaCorta(diaOrigen)}, ${horaTexto(clase.inicio)}–${horaTexto(clase.fin)}',
              style: s.texto(size: 13, color: s.suave),
            ),
            const SizedBox(height: 16),
            Text('Día', style: s.texto(size: 12, color: s.suave)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(capitalizar(fechaLarga(destino))),
              onPressed: () async {
                final elegido = await showDatePicker(
                  context: c,
                  initialDate: destino.isBefore(hoy) ? hoy : destino,
                  firstDate: hoy,
                  lastDate: hoy.add(const Duration(days: 365)),
                  helpText: 'Día de la clase',
                );
                if (elegido != null) actualizar(() => destino = soloDia(elegido));
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Empieza', style: s.texto(size: 12, color: s.suave)),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: inicio,
                    items: [
                      for (final m in horas.where((m) => m < 24 * 60))
                        DropdownMenuItem(value: m, child: Text(horaTexto(m))),
                    ],
                    onChanged: (v) => actualizar(() {
                      // Al cambiar el inicio, se mantiene la duración si cabe en el día.
                      final dur = fin - inicio;
                      inicio = v!;
                      fin = (inicio + dur).clamp(inicio + 15, 24 * 60);
                      if (!horas.contains(fin)) {
                        horas.add(fin);
                        horas.sort();
                      }
                    }),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Termina', style: s.texto(size: 12, color: s.suave)),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: fin,
                    items: [
                      for (final m in horas.where((m) => m > inicio))
                        DropdownMenuItem(value: m, child: Text(horaTexto(m))),
                    ],
                    onChanged: (v) => actualizar(() => fin = v!),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Duración: ${horasBonitas(duracion / 60)} h', style: s.texto(size: 13, color: s.suave)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;

  await _ejecutar(
    context,
    () => Datos.moverClase(
      clase: clase,
      fechaOrigen: clase.esPuntual ? (clase.origenFecha ?? clase.fecha!) : fechaClave(diaOrigen),
      fechaDestino: fechaClave(destino),
      diaSemanaDestino: destino.weekday,
      inicio: inicio,
      fin: fin,
    ),
    '${clase.descripcion}: ${fechaCorta(destino)}, ${horaTexto(inicio)}–${horaTexto(fin)}.',
  );
}
