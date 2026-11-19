import 'package:flutter/material.dart';

import '../config.dart';
import '../estilo.dart';
import '../logic/fechas.dart';
import '../logic/reglas.dart';
import '../models/ajustes.dart';
import '../models/reserva.dart';
import '../models/usuario.dart';
import '../services/datos_service.dart';
import '../widgets/dialogos.dart';

class MisReservasScreen extends StatelessWidget {
  final Usuario yo;
  const MisReservasScreen({super.key, required this.yo});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: StreamBuilder<Ajustes>(
        stream: Datos.ajustes(),
        builder: (context, sa) {
          final ajustes = sa.data ?? const Ajustes();
          return StreamBuilder<List<Reserva>>(
            stream: Datos.reservasDesde(fechaClave(DateTime.now())),
            builder: (context, sr) {
              if (!sr.hasData) return const Center(child: CircularProgressIndicator());
              final todas = sr.data!;
              final estado = EstadoAula(ajustes: ajustes, reservas: {for (final r in todas) r.id: r});
              final ahora = DateTime.now();
              final mias = todas
                  .where((r) => r.uid == yo.uid && !franjaPasada(deFechaClave(r.fecha), r.minuto, ahora))
                  .toList()
                ..sort((a, b) => a.fecha != b.fecha ? a.fecha.compareTo(b.fecha) : a.minuto.compareTo(b.minuto));

              if (mias.isEmpty) {
                return Center(
                  child: Text(
                    s.esPixel ? '-- no hay reservas --' : 'Todavía no tienes reservas.',
                    style: s.texto(size: 16, color: s.suave),
                  ),
                );
              }

              final filas = <Widget>[];
              String? fechaActual;
              for (final r in mias) {
                if (r.fecha != fechaActual) {
                  fechaActual = r.fecha;
                  filas.add(Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(capitalizar(fechaLarga(deFechaClave(r.fecha))), style: s.titulo(size: 18)),
                  ));
                }
                filas.add(_fila(context, s, r, estado.tienePrioridad(r)));
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 20, 24), children: filas),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _fila(BuildContext context, Estilo s, Reserva r, bool prioridad) {
    final etiqueta = r.deProfesor
        ? (r.descripcion.isEmpty ? 'bloqueada' : r.descripcion)
        : (prioridad ? '' : 'sin prioridad');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      decoration: s.caja(
        color: prioridad ? null : Color.alphaBlend(s.resina.withValues(alpha: 0.3), s.tarjeta),
        colorBorde: prioridad || s.esPixel ? null : s.resina,
      ),
      child: Row(children: [
        Text(
          '${horaTexto(r.minuto)} – ${horaTexto(r.minuto + minutosFranja)}',
          style: s.texto(size: 15, peso: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        if (etiqueta.isNotEmpty) Text(etiqueta, style: s.texto(size: 12, color: prioridad ? s.suave : s.resinaTexto)),
        const Spacer(),
        IconButton(
          tooltip: 'Cancelar',
          icon: Icon(Icons.close_rounded, color: s.suave),
          onPressed: () async {
            final ok = await confirmar(
              context,
              titulo: 'Cancelar reserva',
              texto: '¿Cancelar la franja de las ${horaTexto(r.minuto)} del ${fechaLarga(deFechaClave(r.fecha))}?',
              boton: 'Cancelar reserva',
            );
            if (!ok) return;
            try {
              await Datos.cancelar(r.id);
              if (context.mounted) avisar(context, 'Reserva cancelada.');
            } catch (_) {
              if (context.mounted) avisar(context, 'No se ha podido cancelar.');
            }
          },
        ),
      ]),
    );
  }
}
