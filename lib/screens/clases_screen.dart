import 'package:flutter/material.dart';

import '../estilo.dart';
import '../logic/fechas.dart';
import '../logic/reglas.dart';
import '../models/ajustes.dart';
import '../models/clase.dart';
import '../models/dia_cerrado.dart';
import '../models/usuario.dart';
import '../services/datos_service.dart';
import '../widgets/acciones_clase.dart';

/// Agenda de clases de los próximos 7 días, con su horario exacto.
/// Quien gestiona puede mover, liberar o restaurar cada clase desde aquí.
class ClasesScreen extends StatelessWidget {
  final Usuario yo;
  const ClasesScreen({super.key, required this.yo});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Clases de la semana')),
      body: StreamBuilder<List<Clase>>(
        stream: Datos.clases(),
        builder: (context, sc) {
          if (!sc.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<Clase>>(
            stream: Datos.clasesPuntuales(),
            builder: (context, sp) => StreamBuilder<Set<String>>(
            stream: Datos.liberaciones(),
            builder: (context, sl) => StreamBuilder<List<DiaCerrado>>(
              stream: Datos.diasCerrados(),
              builder: (context, sd) {
                final estado = EstadoAula(
                  ajustes: const Ajustes(),
                  reservas: const {},
                  clases: sc.data!,
                  puntuales: sp.data ?? [],
                  liberaciones: sl.data ?? {},
                  diasCerrados: {for (final d in sd.data ?? <DiaCerrado>[]) d.fecha: d},
                );
                final hoy = soloDia(DateTime.now());
                final dias = List.generate(7, (i) => hoy.add(Duration(days: i)));

                final filas = <Widget>[];
                for (var i = 0; i < dias.length; i++) {
                  final dia = dias[i];
                  final clases = estado.clasesDelDia(dia);
                  final festivo = estado.esFestivo(dia);
                  final marcado = estado.festivoMarcado(dia);
                  final sinClasesPorFestivo = estado.clasesLiberadasPorFestivo(dia);
                  if (clases.isEmpty && marcado == null && sinClasesPorFestivo.isEmpty) continue;

                  final titulo = i == 0
                      ? 'Hoy, ${fechaCorta(dia)}'
                      : i == 1
                          ? 'Mañana, ${fechaCorta(dia)}'
                          : capitalizar(fechaLarga(dia));
                  filas.add(Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(titulo, style: s.titulo(size: 18)),
                  ));

                  if (festivo && (marcado != null || sinClasesPorFestivo.isNotEmpty)) {
                    final motivo = marcado != null && marcado.motivo.isNotEmpty ? ' (${marcado.motivo})' : '';
                    filas.add(_aviso(
                      s,
                      'Festivo$motivo: horario de festivos'
                      '${sinClasesPorFestivo.isNotEmpty ? ' y sin clases fijas' : ''}.',
                    ));
                  }
                  for (final c in clases) {
                    final liberada = estado.liberada(c, dia);
                    String? nota;
                    if (liberada) {
                      final movida = estado.movidaDesde(c, dia);
                      nota = movida != null
                          ? 'movida al ${fechaCorta(deFechaClave(movida.fecha!))} a las ${horaTexto(movida.inicio)}'
                          : 'liberada';
                    } else if (c.esMovida) {
                      nota = 'movida desde el ${fechaCorta(deFechaClave(c.origenFecha!))}';
                    }
                    filas.add(_fila(context, s, estado, dia, c, liberada: liberada, nota: nota));
                  }
                }

                if (filas.isEmpty) {
                  return Center(
                    child: Text('No hay clases en los próximos días.', style: s.texto(size: 16, color: s.suave)),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 20, 24), children: filas),
                  ),
                );
              },
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _fila(
    BuildContext context,
    Estilo s,
    EstadoAula estado,
    DateTime dia,
    Clase c, {
    required bool liberada,
    String? nota,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 10, yo.gestiona ? 4 : 14, 10),
      decoration: s.caja(color: liberada ? null : Color.alphaBlend(s.clase.withValues(alpha: 0.35), s.tarjeta)),
      child: Row(children: [
        SizedBox(
          width: 104,
          child: Text(
            '${horaTexto(c.inicio)}–${horaTexto(c.fin)}',
            style: s.texto(size: 14, peso: FontWeight.w600, color: liberada ? s.suave : s.tinta),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              c.descripcion,
              style: s.texto(size: 15, color: liberada ? s.suave : s.tinta)
                  .copyWith(decoration: liberada ? TextDecoration.lineThrough : null),
            ),
            if (nota != null) Text(nota, style: s.texto(size: 12, color: s.suave)),
          ]),
        ),
        if (yo.gestiona) _menuClase(context, estado, dia, c, liberada: liberada),
      ]),
    );
  }

  /// Botón ⋮ con las acciones posibles para esa clase ese día.
  Widget _menuClase(BuildContext context, EstadoAula estado, DateTime dia, Clase c, {required bool liberada}) {
    final opciones = <String, String>{
      if (liberada) 'restaurar': 'Restaurar',
      if (!liberada) 'mover': 'Cambiar día u hora',
      if (!liberada && !c.esPuntual) 'liberar': 'Liberar este día',
      if (!liberada && c.esMovida) 'devolver': 'Devolver a su sitio',
      if (!liberada && c.esPuntual) 'quitar': 'Quitar este día',
    };
    return PopupMenuButton<String>(
      tooltip: 'Opciones de la clase',
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (_) => [
        for (final o in opciones.entries) PopupMenuItem(value: o.key, child: Text(o.value)),
      ],
      onSelected: (accion) {
        switch (accion) {
          case 'mover':
            moverClaseConDialogo(context, c, dia);
          case 'liberar':
            liberarClaseDia(context, c, dia);
          case 'restaurar':
            restaurarClaseDia(context, c, dia, movida: estado.movidaDesde(c, dia));
          case 'devolver':
            devolverClase(context, c);
          case 'quitar':
            quitarClaseDia(context, c);
        }
      },
    );
  }

  Widget _aviso(Estilo s, String texto) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: s.caja(color: s.cerrado),
        child: Text(texto, style: s.texto(size: 14, color: s.tinta)),
      );
}
