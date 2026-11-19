import 'package:flutter/material.dart';

import '../config.dart';
import '../estilo.dart';
import '../logic/fechas.dart';
import '../models/aviso.dart';
import '../models/clase.dart';
import '../models/dia_cerrado.dart';
import '../models/usuario.dart';
import '../services/datos_service.dart';
import '../widgets/acciones_clase.dart';
import '../widgets/dialogos.dart';

/// Gestión de clases fijas, festivos y avisos.
class GestionScreen extends StatelessWidget {
  final Usuario yo;
  const GestionScreen({super.key, required this.yo});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión del aula'),
          bottom: TabBar(
            indicatorColor: s.mia,
            labelColor: s.tinta,
            unselectedLabelColor: s.suave,
            labelStyle: s.texto(size: 14, peso: FontWeight.w600),
            tabs: const [Tab(text: 'Clases'), Tab(text: 'Festivos'), Tab(text: 'Avisos')],
          ),
        ),
        body: TabBarView(children: [
          const _ClasesTab(),
          const _CerradosTab(),
          _AvisosTab(yo: yo),
        ]),
      ),
    );
  }
}

// ───────────── Piezas comunes ─────────────
Widget _marco(List<Widget> hijos) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 20, 24), children: hijos),
      ),
    );

Widget _boton(String texto, IconData icono, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(onPressed: onTap, icon: Icon(icono), label: Text(texto)),
      ),
    );

Widget _nota(Estilo s, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(texto, style: s.texto(size: 13, color: s.suave)),
    );

Widget _tarjeta(
  Estilo s, {
  required String titulo,
  String? subtitulo,
  VoidCallback? onTap,
  VoidCallback? onBorrar,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: s.caja(),
    child: ListTile(
      title: Text(titulo, style: s.texto(size: 15, peso: FontWeight.w600)),
      subtitle: (subtitulo == null || subtitulo.isEmpty) ? null : Text(subtitulo, style: s.texto(size: 13, color: s.suave)),
      onTap: onTap,
      trailing: onBorrar == null
          ? null
          : IconButton(icon: Icon(Icons.delete_outline_rounded, color: s.suave), onPressed: onBorrar),
    ),
  );
}

Future<void> _guardar(BuildContext context, Future<void> Function() accion, String ok) async {
  try {
    await accion();
    if (context.mounted) avisar(context, ok);
  } catch (_) {
    if (context.mounted) avisar(context, 'No se ha podido guardar.');
  }
}

// ───────────── Clases ─────────────
class _ClasesTab extends StatelessWidget {
  const _ClasesTab();

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return StreamBuilder<List<Clase>>(
      stream: Datos.clases(),
      builder: (context, sc) {
        final clases = sc.data ?? [];
        return _marco([
          _nota(s, 'Estas clases se repiten todas las semanas. Toca una para cambiar su horario fijo, '
              'o usa el botón ⋮ para cambiarla o liberarla solo un día concreto. En festivos no hay clases fijas.'),
          _boton('Añadir clase', Icons.add_rounded, () => _editarClase(context, null)),
          for (final c in clases) _tarjetaClase(context, s, c),
        ]);
      },
    );
  }
}

/// Tarjeta de una clase fija con su menú de opciones.
Widget _tarjetaClase(BuildContext context, Estilo s, Clase c) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: s.caja(),
    child: ListTile(
      title: Text(
        '${capitalizar(diasLargos[c.diaSemana - 1])} · ${horaTexto(c.inicio)}–${horaTexto(c.fin)}',
        style: s.texto(size: 15, peso: FontWeight.w600),
      ),
      subtitle: Text(
        c.abreviatura.isEmpty ? c.descripcion : '${c.descripcion} (${c.abreviatura})',
        style: s.texto(size: 13, color: s.suave),
      ),
      onTap: () => _editarClase(context, c),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones de la clase',
        icon: Icon(Icons.more_vert_rounded, color: s.suave),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'editar', child: Text('Editar horario fijo')),
          PopupMenuItem(value: 'mover', child: Text('Cambiar día u hora un día…')),
          PopupMenuItem(value: 'liberar', child: Text('Liberar un día…')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'borrar', child: Text('Borrar de todas las semanas')),
        ],
        onSelected: (accion) async {
          switch (accion) {
            case 'editar':
              await _editarClase(context, c);
            case 'mover':
              final dia = await _elegirDia(context, c, 'Cambiar ${c.descripcion}: ¿qué día?');
              if (dia != null && context.mounted) await moverClaseConDialogo(context, c, dia);
            case 'liberar':
              final dia = await _elegirDia(context, c, 'Liberar ${c.descripcion}: ¿qué día?');
              if (dia != null && context.mounted) await liberarClaseDia(context, c, dia);
            case 'borrar':
              final ok = await confirmar(context,
                  titulo: 'Borrar clase', texto: '¿Borrar "${c.descripcion}" de todas las semanas?', boton: 'Borrar');
              if (ok && context.mounted) await _guardar(context, () => Datos.borrarClase(c.id), 'Clase borrada.');
          }
        },
      ),
    ),
  );
}

/// Muestra las próximas fechas en que toca esa clase y devuelve la elegida.
Future<DateTime?> _elegirDia(BuildContext context, Clase c, String titulo) {
  final hoy = soloDia(DateTime.now());
  var primera = hoy;
  while (primera.weekday != c.diaSemana) {
    primera = primera.add(const Duration(days: 1));
  }
  final fechas = List.generate(8, (i) => primera.add(Duration(days: 7 * i)));

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      final s = Estilo.of(ctx);
      return AlertDialog(
        shape: formaDialogo(ctx),
        title: tituloDialogo(ctx, titulo),
        content: SizedBox(
          width: 320,
          child: ListView(shrinkWrap: true, children: [
            for (var i = 0; i < fechas.length; i++)
              ListTile(
                title: Text(capitalizar(fechaLarga(fechas[i])), style: s.texto(size: 15)),
                subtitle: i == 0 && fechas[i] == hoy ? Text('Hoy', style: s.texto(size: 12, color: s.suave)) : null,
                onTap: () => Navigator.pop(ctx, fechas[i]),
              ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))],
      );
    },
  );
}

Future<void> _editarClase(BuildContext context, Clase? c) async {
  var dia = c?.diaSemana ?? DateTime.monday;
  var inicio = c?.inicio ?? 10 * 60;
  var fin = c?.fin ?? 11 * 60;
  final desc = TextEditingController(text: c?.descripcion ?? '');
  final abrev = TextEditingController(text: c?.abreviatura ?? '');
  // De cuarto en cuarto de hora, para clases como 10:15–11:45.
  final horas = [for (var m = 7 * 60; m <= 24 * 60; m += 15) m];

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final s = Estilo.of(ctx);
      Widget campo(String etiqueta, Widget hijo) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(etiqueta, style: s.texto(size: 12, color: s.suave)),
              hijo,
            ]),
          );

      return StatefulBuilder(
        builder: (ctx, actualizar) => AlertDialog(
          shape: formaDialogo(ctx),
          title: tituloDialogo(ctx, c == null ? 'Nueva clase' : 'Editar clase'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              campo(
                'Día',
                DropdownButton<int>(
                  isExpanded: true,
                  value: dia,
                  items: [
                    for (var d = 1; d <= 7; d++)
                      DropdownMenuItem(value: d, child: Text(capitalizar(diasLargos[d - 1]))),
                  ],
                  onChanged: (v) => actualizar(() => dia = v!),
                ),
              ),
              Row(children: [
                Expanded(
                  child: campo(
                    'Empieza',
                    DropdownButton<int>(
                      isExpanded: true,
                      value: inicio,
                      items: [for (final m in horas) DropdownMenuItem(value: m, child: Text(horaTexto(m)))],
                      onChanged: (v) => actualizar(() => inicio = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: campo(
                    'Termina',
                    DropdownButton<int>(
                      isExpanded: true,
                      value: fin,
                      items: [for (final m in horas) DropdownMenuItem(value: m, child: Text(horaTexto(m)))],
                      onChanged: (v) => actualizar(() => fin = v!),
                    ),
                  ),
                ),
              ]),
              TextField(
                controller: desc,
                decoration: InputDecoration(
                  labelText: 'Descripción (p. ej. Natalia o Repertorio II)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(s.radio)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: abrev,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Abreviatura (opcional, p. ej. N o R2)',
                  helperText: 'Se usa cuando no cabe la descripción. Si la dejas vacía, se usa la primera letra.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(s.radio)),
                ),
              ),
              if (fin <= inicio)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('La hora de fin tiene que ser posterior a la de inicio.',
                      style: s.texto(size: 12, color: s.claseTexto)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: fin > inicio ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    },
  );

  if (ok != true || !context.mounted) return;
  final texto = desc.text.trim();
  await _guardar(
    context,
    () => Datos.guardarClase(Clase(
      id: c?.id ?? '',
      diaSemana: dia,
      inicio: inicio,
      fin: fin,
      descripcion: texto.isEmpty ? 'Clase' : texto,
      abreviatura: abrev.text.trim(),
    )),
    'Clase guardada.',
  );
}

// ───────────── Festivos ─────────────
class _CerradosTab extends StatelessWidget {
  const _CerradosTab();

  Future<void> _cerrar(BuildContext context) async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Día festivo',
    );
    if (dia == null || !context.mounted) return;
    final motivo = await pedirTexto(
      context,
      titulo: 'Festivo el ${fechaLarga(dia)}',
      etiqueta: 'Motivo (opcional, p. ej. Todos los Santos)',
      boton: 'Marcar festivo',
      permitirVacio: true,
    );
    if (motivo == null || !context.mounted) return;
    await _guardar(context, () => Datos.cerrarDia(fechaClave(dia), motivo), 'Festivo marcado.');
  }

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return StreamBuilder<List<DiaCerrado>>(
      stream: Datos.diasCerrados(),
      builder: (context, sd) {
        final hoy = fechaClave(DateTime.now());
        final dias = (sd.data ?? []).where((d) => d.fecha.compareTo(hoy) >= 0).toList();
        return _marco([
          _nota(s, 'Los festivos usan el horario de festivos y sus clases fijas se liberan solas, así que el aula '
              'se puede reservar. Los sábados y domingos ya son festivos, no hace falta marcarlos.'),
          _boton('Marcar un festivo', Icons.celebration_outlined, () => _cerrar(context)),
          for (final d in dias)
            _tarjeta(
              s,
              titulo: capitalizar(fechaLarga(deFechaClave(d.fecha))),
              subtitulo: d.motivo,
              onBorrar: () => _guardar(context, () => Datos.abrirDia(d.fecha), 'Ya no es festivo.'),
            ),
        ]);
      },
    );
  }
}

// ───────────── Avisos ─────────────
class _AvisosTab extends StatelessWidget {
  final Usuario yo;
  const _AvisosTab({required this.yo});

  Future<void> _publicar(BuildContext context) async {
    final texto = await pedirTexto(context, titulo: 'Nuevo aviso', etiqueta: 'Aviso', lineas: 3, boton: 'Publicar');
    if (texto == null || !context.mounted) return;
    await _guardar(context, () => Datos.publicarAviso(texto, yo.nombre), 'Aviso publicado.');
  }

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return StreamBuilder<List<Aviso>>(
      stream: Datos.avisos(),
      builder: (context, sa) {
        final avisos = sa.data ?? [];
        return _marco([
          _nota(s, 'Los tres avisos más recientes se muestran arriba en la pantalla de reservas.'),
          _boton('Publicar aviso', Icons.campaign_outlined, () => _publicar(context)),
          for (final a in avisos)
            _tarjeta(
              s,
              titulo: a.texto,
              subtitulo: '${a.autor} · ${fechaCorta(a.creado)}',
              onBorrar: () => _guardar(context, () => Datos.borrarAviso(a.id), 'Aviso quitado.'),
            ),
        ]);
      },
    );
  }
}
