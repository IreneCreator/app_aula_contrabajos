import 'package:flutter/material.dart';

import '../estilo.dart';
import '../logic/fechas.dart';
import '../models/ajustes.dart';
import '../models/usuario.dart';
import '../services/datos_service.dart';
import '../widgets/dialogos.dart';

/// Ajustes generales y permisos. Solo para administradores.
class AjustesScreen extends StatefulWidget {
  final Usuario yo;
  const AjustesScreen({super.key, required this.yo});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  Ajustes? _a;

  @override
  void initState() {
    super.initState();
    Datos.ajustes().first.then((a) {
      if (mounted) setState(() => _a = a);
    });
  }

  Future<void> _guardar() async {
    try {
      await Datos.guardarAjustes(_a!);
      if (mounted) avisar(context, 'Ajustes guardados.');
    } catch (_) {
      if (mounted) avisar(context, 'No se han podido guardar los ajustes.');
    }
  }

  void _cambiar(Ajustes nuevo) => setState(() => _a = nuevo);

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final a = _a;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes y permisos')),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 20, 24), children: [
                  _Titulo('Reservas', s),
                  _Contador(
                    etiqueta: 'Días de antelación para reservar',
                    ayuda: a.diasAntelacion == 0
                        ? 'Solo se puede reservar el mismo día'
                        : 'Hoy y ${a.diasAntelacion == 1 ? 'mañana' : 'los ${a.diasAntelacion} días siguientes'}',
                    valor: '${a.diasAntelacion}',
                    menos: a.diasAntelacion > 0 ? () => _cambiar(a.copyWith(diasAntelacion: a.diasAntelacion - 1)) : null,
                    mas: a.diasAntelacion < 6
                        ? () => _cambiar(a.copyWith(diasAntelacion: a.diasAntelacion + 1))
                        : null,
                  ),
                  _Contador(
                    etiqueta: 'Horas con prioridad por persona y día',
                    valor: '${horasBonitas(a.horasMaxDia)} h',
                    menos: a.horasMaxDia > 0.5 ? () => _cambiar(a.copyWith(horasMaxDia: a.horasMaxDia - 0.5)) : null,
                    mas: a.horasMaxDia < 12 ? () => _cambiar(a.copyWith(horasMaxDia: a.horasMaxDia + 0.5)) : null,
                  ),
                  const SizedBox(height: 12),
                  _Titulo('Horario de días normales', s),
                  _Contador(
                    etiqueta: 'El aula abre a las',
                    valor: '${a.horaInicio}:00',
                    menos: a.horaInicio > 0 ? () => _cambiar(a.copyWith(horaInicio: a.horaInicio - 1)) : null,
                    mas: a.horaInicio < a.horaFin - 1 ? () => _cambiar(a.copyWith(horaInicio: a.horaInicio + 1)) : null,
                  ),
                  _Contador(
                    etiqueta: 'El aula cierra a las',
                    valor: '${a.horaFin}:00',
                    menos: a.horaFin > a.horaInicio + 1 ? () => _cambiar(a.copyWith(horaFin: a.horaFin - 1)) : null,
                    mas: a.horaFin < 24 ? () => _cambiar(a.copyWith(horaFin: a.horaFin + 1)) : null,
                  ),
                  const SizedBox(height: 12),
                  _Titulo('Horario de festivos, sábados y domingos', s),
                  _Contador(
                    etiqueta: 'El aula abre a las',
                    valor: '${a.horaInicioFestivo}:00',
                    menos: a.horaInicioFestivo > 0
                        ? () => _cambiar(a.copyWith(horaInicioFestivo: a.horaInicioFestivo - 1))
                        : null,
                    mas: a.horaInicioFestivo < a.horaFinFestivo - 1
                        ? () => _cambiar(a.copyWith(horaInicioFestivo: a.horaInicioFestivo + 1))
                        : null,
                  ),
                  _Contador(
                    etiqueta: 'El aula cierra a las',
                    valor: '${a.horaFinFestivo}:00',
                    menos: a.horaFinFestivo > a.horaInicioFestivo + 1
                        ? () => _cambiar(a.copyWith(horaFinFestivo: a.horaFinFestivo - 1))
                        : null,
                    mas: a.horaFinFestivo < 24 ? () => _cambiar(a.copyWith(horaFinFestivo: a.horaFinFestivo + 1)) : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: FilledButton(onPressed: _guardar, child: const Text('Guardar ajustes')),
                  ),
                  const SizedBox(height: 28),
                  _Titulo('Permisos', s),
                  Text(
                    'Profesor: bloquea horas sin límite.\n'
                    'Gestiona: clases, avisos y festivos.\n'
                    'Admin: ajustes y permisos.',
                    style: s.texto(size: 13, color: s.suave),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Usuario>>(
                    stream: Datos.usuarios(),
                    builder: (context, su) => Column(children: [
                      for (final u in su.data ?? <Usuario>[]) _permisos(s, u),
                    ]),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _permisos(Estilo s, Usuario u) {
    Future<void> cambiar(String campo, bool v) async {
      try {
        await Datos.cambiarPermiso(u.uid, campo, v);
      } catch (_) {
        if (mounted) avisar(context, 'No se ha podido cambiar el permiso.');
      }
    }

    Widget interruptor(String texto, bool valor, String campo, {bool activo = true}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: valor, activeTrackColor: s.mia, onChanged: activo ? (v) => cambiar(campo, v) : null),
            Text(texto, style: s.texto(size: 13)),
          ],
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: s.caja(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u.nombre, style: s.texto(size: 15, peso: FontWeight.w600)),
        if (u.email.isNotEmpty) Text(u.email, style: s.texto(size: 12, color: s.suave)),
        Wrap(spacing: 8, children: [
          interruptor('Profesor', u.profesor, 'profesor'),
          interruptor('Gestiona', u.gestorClases, 'gestorClases'),
          // No te puedes quitar a ti misma el permiso de admin, para no quedarte fuera.
          interruptor('Admin', u.admin, 'admin', activo: u.uid != widget.yo.uid),
        ]),
      ]),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  final Estilo s;
  const _Titulo(this.texto, this.s);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(texto, style: s.titulo(size: 22)),
      );
}

class _Contador extends StatelessWidget {
  final String etiqueta;
  final String? ayuda;
  final String valor;
  final VoidCallback? menos;
  final VoidCallback? mas;

  const _Contador({required this.etiqueta, this.ayuda, required this.valor, this.menos, this.mas});

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: s.caja(),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta, style: s.texto(size: 14)),
            if (ayuda != null) Text(ayuda!, style: s.texto(size: 12, color: s.suave)),
          ]),
        ),
        IconButton(onPressed: menos, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 56,
          child: Text(valor, textAlign: TextAlign.center, style: s.titulo(size: 18)),
        ),
        IconButton(onPressed: mas, icon: const Icon(Icons.add_rounded)),
      ]),
    );
  }
}
