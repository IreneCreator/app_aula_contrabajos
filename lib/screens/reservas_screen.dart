import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../estilo.dart';
import '../logic/fechas.dart';
import '../logic/reglas.dart';
import '../models/ajustes.dart';
import '../models/aviso.dart';
import '../models/clase.dart';
import '../models/dia_cerrado.dart';
import '../models/reserva.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/datos_service.dart';
import '../widgets/acciones_clase.dart';
import '../widgets/aviso_banner.dart';
import '../widgets/celda.dart';
import '../widgets/carcasa.dart';
import '../widgets/dialogos.dart';
import '../widgets/leyenda.dart';
import '../widgets/mascota.dart';
import '../widgets/resumen.dart';
import '../widgets/titulo_app.dart';
import 'ajustes_screen.dart';
import 'clases_screen.dart';
import 'gestion_screen.dart';
import 'mis_reservas_screen.dart';

class ReservasScreen extends StatefulWidget {
  final Usuario yo;
  const ReservasScreen({super.key, required this.yo});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  Ajustes _ajustes = const Ajustes();
  Map<String, Reserva> _reservas = {};
  List<Clase> _clases = [];
  List<Clase> _puntuales = [];
  Set<String> _liberaciones = {};
  Map<String, DiaCerrado> _cerrados = {};
  Map<String, Usuario> _usuarios = {};
  List<Aviso> _avisos = [];

  final List<StreamSubscription> _subs = [];
  Timer? _reloj;
  final _scroll = ScrollController();
  int _inicio = 0; // primer día visible, contado desde hoy (0 = hoy)

  // Reacciones de la mascota
  Reaccion? _reaccion;
  int _idReaccion = 0;
  String? _fraseReaccion;
  Timer? _timerFrase;
  bool _desplazado = false; // ya se ha llevado la rejilla a la hora actual

  // Medidas de cada fila, para saber cuánto desplazar.
  static const _altoFila = 34.0; // 30 de la franja + 4 de margen
  static const _separacionHora = 6.0; // espacio extra al empezar cada hora

  Usuario get yo => widget.yo;

  @override
  void initState() {
    super.initState();
    final hoy = fechaClave(DateTime.now());
    _subs.addAll([
      Datos.ajustes().listen((v) {
        setState(() => _ajustes = v);
        if (!_desplazado) {
          _desplazado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _irAHoraActual());
        }
      }, onError: _errorDatos),
      Datos.reservasDesde(hoy)
          .listen((v) => setState(() => _reservas = {for (final r in v) r.id: r}), onError: _errorDatos),
      Datos.clases().listen((v) => setState(() => _clases = v), onError: _errorDatos),
      Datos.clasesPuntuales().listen((v) => setState(() => _puntuales = v), onError: _errorDatos),
      Datos.liberaciones().listen((v) => setState(() => _liberaciones = v), onError: _errorDatos),
      Datos.diasCerrados()
          .listen((v) => setState(() => _cerrados = {for (final d in v) d.fecha: d}), onError: _errorDatos),
      Datos.usuarios()
          .listen((v) => setState(() => _usuarios = {for (final u in v) u.uid: u}), onError: _errorDatos),
      Datos.avisos().listen((v) => setState(() => _avisos = v), onError: _errorDatos),
    ]);
    // Refresca cada minuto para atenuar las franjas que ya han pasado.
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  /// Si falla una lectura, lo anotamos en la consola en vez de detener la app.
  void _errorDatos(Object error) {
    debugPrint('Error leyendo datos: $error');
    if (mounted) avisar(context, 'No se han podido cargar algunos datos. Recarga la página.');
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _reloj?.cancel();
    _scroll.dispose();
    _timerFrase?.cancel();
    super.dispose();
  }

  /// Índice de la franja en la que estamos ahora (o null si el aula está cerrada a esta hora).
  int? get _franjaActual {
    final ahora = DateTime.now();
    final minuto = ahora.hour * 60 + ahora.minute;
    final i = _franjas.indexWhere((m) => minuto >= m && minuto < m + minutosFranja);
    return i < 0 ? null : i;
  }

  /// Posición vertical de una franja dentro de la lista.
  double _posicion(int indice) {
    var y = 0.0;
    for (var i = 1; i <= indice; i++) {
      y += _altoFila;
      if (_franjas[i] % 60 == 0) y += _separacionHora;
    }
    return y;
  }

  /// Lleva la rejilla a la hora actual, dejando una franja de margen por arriba.
  void _irAHoraActual() {
    final i = _franjaActual;
    if (i == null || !_scroll.hasClients) return;
    final destino = (_posicion(i) - _altoFila).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(destino, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  EstadoAula get _estado => EstadoAula(
        ajustes: _ajustes,
        reservas: _reservas,
        clases: _clases,
        puntuales: _puntuales,
        liberaciones: _liberaciones,
        diasCerrados: _cerrados,
        usuarios: _usuarios,
      );

  /// Cuántos días se ven a la vez: la preferencia del usuario o, si es automático,
  /// 7 en pantallas grandes y los días que se pueden reservar en pantallas pequeñas.
  int _numDias(BuildContext context) {
    if (yo.diasVista > 0) return yo.diasVista.clamp(1, 7);
    final ancho = MediaQuery.sizeOf(context).width >= 680;
    return ancho ? 7 : (_ajustes.diasAntelacion + 1).clamp(1, 7);
  }

  /// Días visibles, empezando en [_inicio] días desde hoy.
  List<DateTime> _diasVisibles(int n) {
    final hoy = soloDia(DateTime.now());
    return List.generate(n, (i) => hoy.add(Duration(days: _inicio + i)));
  }

  /// Filas de la rejilla: desde la apertura más temprana hasta el cierre más tardío
  /// de los días visibles (los festivos tienen su propio horario).
  List<int> _franjasActuales = [];
  List<int> get _franjas => _franjasActuales;

  List<int> _calcularFranjas(EstadoAula e, List<DateTime> ds) {
    var abre = 24 * 60, cierra = 0;
    for (final d in ds) {
      final (a, c) = e.horarioDe(d);
      if (a < abre) abre = a;
      if (c > cierra) cierra = c;
    }
    if (cierra <= abre) return [];
    return [for (var m = abre; m < cierra; m += minutosFranja) m];
  }

  // ───────────── Acciones ─────────────
  /// Ejecuta una acción y avisa del resultado. Devuelve true si ha ido bien.
  Future<bool> _hacer(Future<void> Function() accion, String ok) async {
    try {
      await accion();
      if (mounted) avisar(context, ok);
      return true;
    } catch (_) {
      if (mounted) avisar(context, 'No se ha podido guardar. Puede que alguien se te haya adelantado.');
      return false;
    }
  }

  /// Hace reaccionar a la mascota y cambia su frase durante un momento.
  void _reaccionar(Reaccion r) {
    _timerFrase?.cancel();
    setState(() {
      _reaccion = r;
      _idReaccion++;
      _fraseReaccion = switch (r) {
        Reaccion.reservar => '¡Reservada!',
        Reaccion.ocupar => '¡Franja conseguida!',
        Reaccion.cancelar => 'Oh… otra vez será',
      };
    });
    _timerFrase = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _fraseReaccion = null);
    });
  }

  Future<void> _tocar(EstadoAula e, int indice, DateTime dia, int min) async {
    final fuera = e.fueraDeHorario(dia, min);
    final abierto = (yo.profesor || e.diaAbierto(indice)) && !fuera;
    final fecha = fechaClave(dia);
    final r = e.reservaEn(dia, min);
    final todas = e.clasesEn(dia, min);
    final activas = todas.where((c) => !e.liberada(c, dia)).toList();
    final liberadas = todas.where((c) => e.liberada(c, dia)).toList();

    // Franja con clase (o con clases liberadas que quien gestiona puede restaurar)
    if (activas.isNotEmpty || (r == null && liberadas.isNotEmpty && yo.gestiona)) {
      final eleccion = await _detalleClases(e, dia, min, activas, liberadas, permitirReservar: activas.isEmpty && abierto);
      if (eleccion == null) return;
      final (accion, clase) = eleccion;
      if (clase != null) {
        switch (accion) {
          case 'liberar':
            await _hacer(() => Datos.liberarClase(clase.id, fecha), '${clase.descripcion}: liberada el ${fechaCorta(dia)}.');
          case 'restaurar':
            // Si la clase se había movido, se deshace el movimiento; si no, solo se quita la liberación.
            final movida = e.movidaDesde(clase, dia);
            await _hacer(
              () => movida != null ? Datos.deshacerMovimiento(movida) : Datos.restaurarClase(clase.id, fecha),
              '${clase.descripcion}: vuelve a su sitio.',
            );
          case 'mover':
            await moverClaseConDialogo(context, clase, dia);
          case 'deshacer':
            await _hacer(() => Datos.deshacerMovimiento(clase), '${clase.descripcion}: vuelve a su sitio.');
          case 'quitar':
            await _hacer(() => Datos.quitarClasePuntual(clase.id), '${clase.descripcion}: quitada este día.');
        }
        return;
      }
      if (accion != 'reservar') return;
    }

    if (fuera) {
      avisar(context, e.esFestivo(dia) ? 'Fuera del horario de festivos.' : 'Fuera del horario del aula.');
      return;
    }

    // Los días que aún no se pueden reservar se comprueban después de las clases,
    // para que quien gestiona pueda liberar o mover clases de cualquier día visible.
    if (!abierto) {
      final abre = dia.subtract(Duration(days: _ajustes.diasAntelacion));
      avisar(context, 'Este día se abre el ${fechaCorta(abre)}.');
      return;
    }

    // Franja libre
    if (r == null) {
      // El profesor elige descripción y hasta qué hora bloquea.
      if (yo.profesor) {
        await _bloquearComoProfesor(e, dia, min);
        return;
      }
      final String mensaje;
      if (yo.profesor) {
        mensaje = 'Franja bloqueada a las ${horaTexto(min)}.';
      } else if (e.franjasDe(yo.uid, fecha) + 1 > _ajustes.franjasConPrioridad) {
        mensaje = 'Has pasado de ${horasBonitas(_ajustes.horasMaxDia)} h ese día: esta franja queda sin prioridad.';
      } else {
        mensaje = 'Reservada a las ${horaTexto(min)}.';
      }
      final ok = await _hacer(
        () => Datos.reservar(fecha: fecha, minuto: min, uid: yo.uid, deProfesor: yo.profesor),
        mensaje,
      );
      if (ok) _reaccionar(Reaccion.reservar);
      return;
    }

    // Franja propia del profesor: editar la descripción o desbloquear
    if (r.uid == yo.uid && r.deProfesor) {
      final op = await elegir(
        context,
        titulo: r.descripcion.isEmpty ? 'Franja bloqueada' : r.descripcion,
        texto: '${capitalizar(fechaCorta(dia))}, ${horaTexto(min)}–${horaTexto(min + minutosFranja)}',
        opciones: const {'descripcion': 'Cambiar descripción', 'desbloquear': 'Desbloquear'},
      );
      if (op == 'descripcion' && mounted) {
        final nueva = await pedirTexto(
          context,
          titulo: 'Descripción',
          etiqueta: 'Descripción (p. ej. Seccionales)',
          inicial: r.descripcion,
          permitirVacio: true,
        );
        if (nueva != null) await _hacer(() => Datos.cambiarDescripcion(r.id, nueva), 'Descripción guardada.');
      } else if (op == 'desbloquear') {
        final ok = await _hacer(() => Datos.cancelar(r.id), 'Franja desbloqueada.');
        if (ok) _reaccionar(Reaccion.cancelar);
      }
      return;
    }

    // Reserva propia: se cancela
    if (r.uid == yo.uid) {
      final ok = await _hacer(() => Datos.cancelar(r.id), r.deProfesor ? 'Franja desbloqueada.' : 'Reserva cancelada.');
      if (ok) _reaccionar(Reaccion.cancelar);
      return;
    }

    final nombre = e.nombreDe(r.uid);

    if (r.deProfesor) {
      avisar(context, r.descripcion.isEmpty ? 'Bloqueada por $nombre.' : '${r.descripcion} · $nombre.');
      return;
    }

    // El profesor puede bloquear encima de la reserva de un alumno
    if (yo.profesor) {
      final ok = await confirmar(
        context,
        titulo: 'Bloquear esta franja',
        texto: 'Se quitará la reserva de $nombre del ${fechaLarga(dia)} a las ${horaTexto(min)}.',
        boton: 'Bloquear',
      );
      if (ok &&
          await _hacer(
            () => Datos.ocupar(fecha: fecha, minuto: min, uidAnterior: r.uid, uid: yo.uid, deProfesor: true),
            'Franja bloqueada. $nombre la ha perdido.',
          )) {
        _reaccionar(Reaccion.ocupar);
      }
      return;
    }

    if (!e.tienePrioridad(r)) {
      final ok = await confirmar(
        context,
        titulo: 'Ocupar esta franja',
        texto: '$nombre ya tiene más de ${horasBonitas(_ajustes.horasMaxDia)} h ese día, '
            'así que puedes quedártela.',
        boton: 'Ocupar',
      );
      if (ok &&
          await _hacer(
            () => Datos.ocupar(fecha: fecha, minuto: min, uidAnterior: r.uid, uid: yo.uid, deProfesor: false),
            'Franja ocupada. $nombre la ha perdido.',
          )) {
        _reaccionar(Reaccion.ocupar);
      }
    } else {
      avisar(context, 'Reservada por $nombre. Tiene prioridad.');
    }
  }

  /// Ventanita con las clases de una franja y su horario exacto.
  /// Devuelve (acción, clase): 'liberar', 'restaurar', 'mover', 'deshacer', 'quitar',
  /// o ('reservar', null). Null si se cierra sin hacer nada.
  Future<(String, Clase?)?> _detalleClases(
    EstadoAula e,
    DateTime dia,
    int min,
    List<Clase> activas,
    List<Clase> liberadas, {
    bool permitirReservar = false,
  }) {
    return showDialog<(String, Clase?)>(
      context: context,
      builder: (c) {
        final s = Estilo.of(c);

        Widget boton(String texto, String accion, Clase clase) =>
            TextButton(onPressed: () => Navigator.pop(c, (accion, clase)), child: Text(texto));

        Widget fila(Clase clase, {required bool liberada}) {
          final movida = liberada ? e.movidaDesde(clase, dia) : null;
          var detalle = '${horaTexto(clase.inicio)}–${horaTexto(clase.fin)}';
          if (liberada) {
            detalle += movida != null
                ? ' · movida al ${fechaCorta(deFechaClave(movida.fecha!))} a las ${horaTexto(movida.inicio)}'
                : ' · liberada este día';
          } else if (clase.esMovida) {
            detalle += ' · movida desde el ${fechaCorta(deFechaClave(clase.origenFecha!))}';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                clase.descripcion,
                style: s
                    .texto(size: 15, peso: FontWeight.w600, color: liberada ? s.suave : s.tinta)
                    .copyWith(decoration: liberada ? TextDecoration.lineThrough : null),
              ),
              Text(detalle, style: s.texto(size: 12.5, color: s.suave)),
              if (yo.gestiona)
                Wrap(spacing: 4, children: [
                  if (liberada) boton('Restaurar', 'restaurar', clase),
                  if (!liberada && !clase.esPuntual) ...[
                    boton('Cambiar día u hora', 'mover', clase),
                    boton('Liberar', 'liberar', clase),
                  ],
                  if (!liberada && clase.esPuntual) ...[
                    boton('Cambiar día u hora', 'mover', clase),
                    if (clase.esMovida) boton('Devolver a su sitio', 'deshacer', clase),
                    boton('Quitar', 'quitar', clase),
                  ],
                ]),
            ]),
          );
        }

        return AlertDialog(
          shape: formaDialogo(c),
          title: tituloDialogo(c, 'Clases · ${capitalizar(fechaCorta(dia))}, ${horaTexto(min)}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final clase in activas) fila(clase, liberada: false),
              if (yo.gestiona)
                for (final clase in liberadas) fila(clase, liberada: true),
              if (yo.gestiona && activas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Cambiar o liberar una clase solo afecta a este día; el resto de semanas sigue igual.',
                  style: s.texto(size: 12, color: s.suave),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
            if (permitirReservar)
              FilledButton(onPressed: () => Navigator.pop(c, ('reservar', null)), child: const Text('Reservar')),
          ],
        );
      },
    );
  }

  /// Ventana del profesor para bloquear: descripción opcional y hora de fin
  /// (para bloquear varias franjas seguidas de una vez).
  Future<void> _bloquearComoProfesor(EstadoAula e, DateTime dia, int min) async {
    final (_, cierra) = e.horarioDe(dia);
    final fines = [for (var m = min + minutosFranja; m <= cierra; m += minutosFranja) m];
    if (fines.isEmpty) fines.add(min + minutosFranja);
    var fin = fines.first;
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, actualizar) {
          final s = Estilo.of(c);
          return AlertDialog(
            shape: formaDialogo(c),
            title: tituloDialogo(c, 'Bloquear franjas'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(capitalizar(fechaLarga(dia)), style: s.texto(size: 13, color: s.suave)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional, p. ej. Seccionales)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(s.radio)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('De ${horaTexto(min)} hasta las ', style: s.texto(size: 14)),
                DropdownButton<int>(
                  value: fin,
                  items: [for (final m in fines) DropdownMenuItem(value: m, child: Text(horaTexto(m)))],
                  onChanged: (v) => actualizar(() => fin = v!),
                ),
              ]),
              Text(
                'Solo se bloquean las franjas libres de ese tramo.',
                style: s.texto(size: 12, color: s.suave),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bloquear')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;

    final minutos = [for (var m = min; m < fin; m += minutosFranja) m];
    try {
      final n = await Datos.bloquearVarias(
        fecha: fechaClave(dia),
        minutos: minutos,
        uid: yo.uid,
        descripcion: ctrl.text.trim(),
      );
      if (!mounted) return;
      if (n == 0) {
        avisar(context, 'No había franjas libres en ese tramo.');
      } else {
        avisar(context, n == minutos.length
            ? 'Bloqueado de ${horaTexto(min)} a ${horaTexto(fin)}.'
            : 'Bloqueadas $n de ${minutos.length} franjas (las demás ya estaban ocupadas).');
        _reaccionar(Reaccion.reservar);
      }
    } catch (_) {
      if (mounted) avisar(context, 'No se ha podido guardar.');
    }
  }

  Future<void> _menu(String opcion) async {
    switch (opcion) {
      case 'mis':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MisReservasScreen(yo: yo)));
      case 'clases':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClasesScreen(yo: yo)));
      case 'gestion':
        Navigator.push(context, MaterialPageRoute(builder: (_) => GestionScreen(yo: yo)));
      case 'ajustes':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AjustesScreen(yo: yo)));
      case 'estilo':
        final elegido = await elegir(
          context,
          titulo: 'Estilo de la app',
          texto: 'Elige cómo quieres ver la app. Solo cambia para ti.',
          opciones: {for (final e in Estilo.todos) e.id: e.nombre},
        );
        if (elegido != null && elegido != yo.estilo) {
          await _hacer(() => Datos.cambiarEstilo(yo.uid, elegido), 'Estilo cambiado.');
        }
      case 'dias':
        final elegido = await elegir(
          context,
          titulo: 'Días que se ven',
          texto: 'Automático: 7 días en pantallas grandes y los días que se pueden reservar en el móvil. '
              'Solo cambia para ti.',
          opciones: {'0': 'Automático', for (var d = 1; d <= 7; d++) '$d': '$d'},
        );
        if (elegido != null) {
          await _hacer(() => Datos.cambiarDiasVista(yo.uid, int.parse(elegido)), 'Preferencia guardada.');
        }
      case 'nombre':
        final nuevo = await pedirTexto(context, titulo: 'Tu nombre', etiqueta: 'Nombre', inicial: yo.nombre);
        if (nuevo != null) await _hacer(() => Datos.cambiarNombre(yo.uid, nuevo), 'Nombre cambiado.');
      case 'salir':
        await AuthService.salir();
    }
  }

  // ───────────── Interfaz ─────────────
  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    final e = _estado;
    final n = _numDias(context);
    final maxInicio = (diasNavegables - n).clamp(0, diasNavegables);
    if (_inicio > maxInicio) _inicio = maxInicio;
    final ds = _diasVisibles(n);
    _franjasActuales = _calcularFranjas(e, ds);
    final hoy = soloDia(DateTime.now());
    final manana = hoy.add(const Duration(days: 1));
    final actual = _franjaActual;

    final tama = s.esTamagotchi;
    // En pantallas anchas, los resúmenes van arriba a la derecha.
    final ancho = MediaQuery.sizeOf(context).width >= 680;

    final rejilla = Column(children: [
      _navegacion(s, ds, maxInicio),
      _cabecera(s, e, ds),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          itemCount: _franjas.length,
          itemBuilder: (_, f) => _fila(s, e, ds, f, f == actual),
        ),
      ),
    ]);

    return Scaffold(
      body: Carcasa(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // En Tamagotchi con pantalla ancha, más ancho para que quepan las pegatinas a los lados.
              // Con muchos días, la app se ensancha para que las columnas no queden estrechas.
              constraints: BoxConstraints(
                maxWidth: n >= 5 ? (tama && ancho ? 1300 : 1200) : (tama && ancho ? 1000 : 820),
              ),
              child: Column(children: [
                _encabezado(s, hoy, manana, ancho),
                if (_avisos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Column(children: [
                      for (final a in _avisos.take(3))
                        AvisoBanner(aviso: a, onBorrar: yo.gestiona ? () => Datos.borrarAviso(a.id) : null),
                    ]),
                  ),
                if (!ancho)
                  Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, tama ? 16 : 12, 10),
                  child: Row(children: [
                    // En Tamagotchi, los resúmenes son pegatinas un poco torcidas.
                    Expanded(child: Transform.rotate(angle: tama ? -0.012 : 0, child: _resumen('Hoy', hoy))),
                    SizedBox(width: tama ? 14 : 10),
                    Expanded(child: Transform.rotate(angle: tama ? 0.01 : 0, child: _resumen('Mañana', manana))),
                  ]),
                ),
                Expanded(
                  child: tama
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: ancho ? 4 : 12),
                          child: Row(children: [
                            if (ancho) const LateralCarcasa(izquierdo: true),
                            Expanded(child: PantallaLcd(child: rejilla)),
                            if (ancho) const LateralCarcasa(izquierdo: false),
                          ]),
                        )
                      : rejilla,
                ),
                if (tama) _botonesAparato(s),
                Leyenda(horasMax: horasBonitas(_ajustes.horasMaxDia)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Una fila de la rejilla: la hora y una franja por cada día.
  Widget _fila(Estilo s, EstadoAula e, List<DateTime> ds, int f, bool esAhora) {
    final min = _franjas[f];
    final enPunto = min % 60 == 0;
    // Las horas pares llevan un fondo muy suave para agrupar cada hora a simple vista.
    final horaPar = (min ~/ 60).isEven;

    final Widget hora;
    if (esAhora) {
      hora = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: s.mia,
          borderRadius: BorderRadius.circular(s.radio + 2),
        ),
        child: Text(horaTexto(min), style: s.texto(size: 11.5, color: s.miaTexto, peso: FontWeight.w700)),
      );
    } else {
      hora = Text(
        horaTexto(min),
        style: enPunto
            ? s.texto(size: 12.5, color: s.tinta, peso: FontWeight.w700)
            : s.texto(size: 10.5, color: s.suave),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: enPunto && f > 0 ? _separacionHora : 0),
      decoration: BoxDecoration(
        color: esAhora
            ? s.mia.withValues(alpha: 0.10)
            : (horaPar ? s.tinta.withValues(alpha: 0.035) : Colors.transparent),
        borderRadius: BorderRadius.circular(s.radio + 2),
      ),
      child: Row(children: [
        SizedBox(width: 52, child: Align(alignment: Alignment.centerRight, child: hora)),
        const SizedBox(width: 6),
        for (var i = 0; i < ds.length; i++) Expanded(child: _celda(e, _inicio + i, ds[i], min)),
      ]),
    );
  }

  PopupMenuItem<String> _opcion(String valor, IconData icono, String texto) => PopupMenuItem(
        value: valor,
        child: Row(children: [
          Icon(icono, size: 20),
          const SizedBox(width: 12),
          Text(texto),
        ]),
      );

  List<PopupMenuEntry<String>> _opcionesMenu(BuildContext context) => [
        _opcion('mis', Icons.event_note_rounded, 'Mis reservas'),
        _opcion('clases', Icons.school_outlined, 'Clases de la semana'),
        if (yo.gestiona) _opcion('gestion', Icons.edit_calendar_rounded, 'Clases, avisos y festivos'),
        if (yo.admin) _opcion('ajustes', Icons.tune_rounded, 'Ajustes y permisos'),
        _opcion('estilo', Icons.palette_outlined, 'Estilo de la app'),
        _opcion('dias', Icons.view_week_outlined, 'Días que se ven'),
        _opcion('nombre', Icons.edit_outlined, 'Cambiar mi nombre'),
        _opcion('salir', Icons.logout_rounded, 'Cerrar sesión'),
        const PopupMenuDivider(),
        // Versión de la app, discreta al final del menú.
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'Versión $versionApp',
            style: Estilo.of(context).texto(size: 11, color: Estilo.of(context).suave),
          ),
        ),
      ];

  /// Humor de la mascota según tus horas de hoy.
  Humor _humor(DateTime hoy) {
    final n = _reservas.values.where((r) => r.uid == yo.uid && r.fecha == fechaClave(hoy)).length;
    if (n == 0) return Humor.dormido;
    if (!yo.profesor && n > _ajustes.franjasConPrioridad) return Humor.agobiado;
    return Humor.contento;
  }

  Widget _encabezado(Estilo s, DateTime hoy, DateTime manana, bool ancho) {
    final tama = s.esTamagotchi;
    final resumenes = <Widget>[
      if (ancho) ...[
        const SizedBox(width: 14),
        SizedBox(
          width: 165,
          child: Transform.rotate(angle: tama ? -0.03 : 0, child: _resumen('Hoy', hoy, cuadrado: true)),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 165,
          child: Transform.rotate(angle: tama ? 0.025 : 0, child: _resumen('Mañana', manana, cuadrado: true)),
        ),
      ],
    ];

    if (tama) {
      final humor = _humor(hoy);
      final frase = _fraseReaccion ??
          switch (humor) {
        Humor.dormido => 'Zzz… ¿estudiamos, ${yo.nombre}?',
        Humor.contento => '¡Hoy toca estudiar!',
        Humor.agobiado => '¡Uf, qué día!',
      };
      return Padding(
        padding: EdgeInsets.fromLTRB(ancho ? 8 : 18, 14, ancho ? 22 : 16, ancho ? 16 : 10),
        child: Row(children: [
          RepaintBoundary(
            child: Mascota(humor: humor, alto: ancho ? 130 : 60, reaccion: _reaccion, idReaccion: _idReaccion),
          ),
          SizedBox(width: ancho ? 18 : 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TituloApp(size: ancho ? 36 : 24),
              SizedBox(height: ancho ? 12 : 8),
              Transform.rotate(
                angle: -0.035,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: s.caja(),
                  child: Text(frase, style: s.texto(size: 12.5)),
                ),
              ),
            ]),
          ),
          ...resumenes,
        ]),
      );
    }

    // Concierto
    final inicial = yo.nombre.isEmpty ? '?' : yo.nombre[0].toUpperCase();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 12, ancho ? 16 : 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RESERVAS DEL AULA', style: s.etiqueta()),
            const TituloApp(size: 26),
            const SizedBox(height: 2),
            Text(
              'Hola, ${yo.nombre}${yo.profesor ? ' · profesor' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: s.texto(size: 13, color: s.suave),
            ),
          ]),
        ),
        ...resumenes,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Mis reservas',
          icon: Icon(Icons.event_note_rounded, color: s.tinta),
          onPressed: () => _menu('mis'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Menú',
          onSelected: _menu,
          itemBuilder: _opcionesMenu,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.mia, shape: BoxShape.circle),
            child: Text(inicial, style: s.titulo(size: 18, color: s.miaTexto)),
          ),
        ),
      ]),
    );
  }

  /// Los tres botones del aparato (solo Tamagotchi).
  Widget _botonesAparato(Estilo s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        BotonAparato(color: s.profe, etiqueta: 'Mis horas', onTap: () => _menu('mis')),
        BotonAparato(color: s.tarjeta, etiqueta: 'Ahora', onTap: _irAHoraActual),
        PopupMenuButton<String>(
          tooltip: 'Menú',
          onSelected: _menu,
          itemBuilder: _opcionesMenu,
          child: BotonAparato(color: s.clase, etiqueta: 'Menú'),
        ),
      ]),
    );
  }

  Widget _resumen(String titulo, DateTime dia, {bool cuadrado = false}) {
    final fecha = fechaClave(dia);
    final mias = _reservas.values.where((r) => r.uid == yo.uid && r.fecha == fecha).map((r) => r.minuto).toList()
      ..sort();
    return ResumenDia(
      titulo: titulo,
      minutos: mias,
      franjasMax: _ajustes.franjasConPrioridad,
      horasMax: _ajustes.horasMaxDia,
      esProfesor: yo.profesor,
      cuadrado: cuadrado,
    );
  }

  /// Flechas para moverse entre días, con el rango visible y un botón para volver a hoy.
  Widget _navegacion(Estilo s, List<DateTime> ds, int maxInicio) {
    final paso = ds.length; // cada flecha avanza tantos días como se ven
    final rango = ds.length == 1
        ? capitalizar(fechaLarga(ds.first))
        : '${capitalizar(fechaCorta(ds.first))} – ${fechaCorta(ds.last)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(children: [
        IconButton(
          tooltip: 'Días anteriores',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _inicio > 0 ? () => setState(() => _inicio = (_inicio - paso).clamp(0, maxInicio)) : null,
        ),
        Expanded(
          child: Text(rango, textAlign: TextAlign.center, style: s.texto(size: 13, peso: FontWeight.w600)),
        ),
        if (_inicio > 0) TextButton(onPressed: () => setState(() => _inicio = 0), child: const Text('Hoy')),
        IconButton(
          tooltip: 'Días siguientes',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _inicio < maxInicio ? () => setState(() => _inicio = (_inicio + paso).clamp(0, maxInicio)) : null,
        ),
      ]),
    );
  }

  Widget _cabecera(Estilo s, EstadoAula e, List<DateTime> ds) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(children: [
        SizedBox(
          width: 58,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: 'Ir a la hora actual',
              child: InkWell(
                onTap: _irAHoraActual,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text('Ahora', style: s.etiqueta(color: s.mia)),
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < ds.length; i++)
          Expanded(
            child: Center(
              child: Builder(builder: (_) {
                final festivo = e.esFestivo(ds[i]);
                final indice = _inicio + i; // días desde hoy
                final activo = yo.profesor || e.diaAbierto(indice);
                var texto = nombreDia(ds[i], indice);
                if (s.esTamagotchi) texto = texto.toUpperCase();
                final hoy = indice == 0;
                // Los festivos (y fines de semana) salen con el nombre en el color de las clases.
                final colorTexto = hoy
                    ? s.miaTexto
                    : festivo
                        ? s.claseTexto.withValues(alpha: activo ? 1 : 0.6)
                        : (activo ? s.tinta : s.suave.withValues(alpha: 0.7));
                final marcado = e.festivoMarcado(ds[i]);
                return Tooltip(
                  message: festivo
                      ? 'Horario de festivo${marcado != null && marcado.motivo.isNotEmpty ? ' · ${marcado.motivo}' : ''}'
                      : '',
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: hoy ? s.mia : Colors.transparent,
                    borderRadius: BorderRadius.circular(s.esTamagotchi ? s.radio : 999),
                  ),
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: s.esTamagotchi
                        ? s.titulo(size: 12, color: colorTexto)
                        : s.texto(
                            size: 12.5,
                            peso: FontWeight.w600,
                            color: colorTexto,
                            estiloFuente: festivo ? FontStyle.italic : null,
                          ),
                  ),
                ),
                );
              }),
            ),
          ),
      ]),
    );
  }

  Widget _celda(EstadoAula e, int i, DateTime dia, int min) {
    final pasada = franjaPasada(dia, min, DateTime.now());
    final r = e.reservaEn(dia, min);
    final todas = e.clasesEn(dia, min);
    final activas = todas.where((c) => !e.liberada(c, dia)).toList();

    TipoCelda tipo = TipoCelda.libre;
    String etiqueta = '';
    List<String> alternativas = const [];

    // Las clases se muestran siempre (aunque caigan fuera de horario, para poder corregirlas).
    if (activas.isNotEmpty) {
      tipo = TipoCelda.clase;
      final opciones = _etiquetasClase(activas, min);
      etiqueta = opciones.first;
      alternativas = opciones.sublist(1);
    } else if (r != null) {
      etiqueta = e.nombreDe(r.uid);
      alternativas = _alternativasNombre(etiqueta);
      if (r.deProfesor) {
        tipo = TipoCelda.profesor;
        // Con descripción: "Seccionales · Antonio" → "Seccionales" → iniciales.
        if (r.descripcion.isNotEmpty) {
          final nombre = etiqueta;
          etiqueta = '${r.descripcion} · $nombre';
          alternativas = [r.descripcion, ..._alternativasNombre(r.descripcion)];
        }
      } else if (!e.tienePrioridad(r)) {
        tipo = TipoCelda.sinPrioridad;
      } else if (r.uid == yo.uid) {
        tipo = TipoCelda.mia;
      } else {
        tipo = TipoCelda.otra;
      }
    } else if (e.fueraDeHorario(dia, min)) {
      tipo = TipoCelda.cerrado; // fuera del horario del aula ese día
    } else if (e.clasesLiberadasPorFestivo(dia).any((c) => c.contiene(min))) {
      // Clases fijas que no se dan por ser festivo: se ven en suave y la franja se puede reservar.
      tipo = TipoCelda.claseLiberada;
      final opciones = _etiquetasClase(
        e.clasesLiberadasPorFestivo(dia).where((c) => c.contiene(min)).toList(),
        min,
      );
      etiqueta = opciones.first;
      alternativas = opciones.sublist(1);
    } else if (todas.isNotEmpty && yo.gestiona) {
      // Clase liberada ese día: quien gestiona la ve para poder restaurarla
      tipo = TipoCelda.claseLiberada;
      etiqueta = 'liberada';
    } else if (!yo.profesor && !e.diaAbierto(i)) {
      tipo = TipoCelda.bloqueada;
    }

    return Celda(
      tipo: tipo,
      etiqueta: etiqueta,
      alternativas: alternativas,
      atenuada: pasada,
      onTap: pasada ? null : () => _tocar(e, i, dia, min),
    );
  }

  /// Versiones de un nombre, de la más larga a la más corta: "Natalia García" → "Natalia" → "NG".
  List<String> _alternativasNombre(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length < 2) return const [];
    return [partes.first, partes.map((p) => p[0].toUpperCase()).join()];
  }

  /// Textos posibles para una franja con clase, del más completo al más corto.
  /// La franja mostrará el primero que quepa.
  List<String> _etiquetasClase(List<Clase> clases, int min) {
    bool horaRaraAqui(Clase c) => c.empiezaEn(min) && c.inicio % minutosFranja != 0;
    String conHora(Clase c, String nombre) => horaRaraAqui(c) ? '$nombre ${horaTexto(c.inicio)}' : nombre;

    final List<String> opciones;
    if (clases.length == 1) {
      final c = clases.first;
      opciones = [
        if (c.empiezaEn(min) && c.horaRara) '${c.descripcion} · ${horaTexto(c.inicio)}–${horaTexto(c.fin)}',
        conHora(c, c.descripcion),
        c.descripcion,
        conHora(c, c.corta),
        c.corta,
      ];
    } else {
      opciones = [
        clases.map((c) => conHora(c, c.descripcion)).join(' / '),
        clases.map((c) => c.descripcion).join(' / '),
        clases.map((c) => conHora(c, c.corta)).join(' / '),
        clases.map((c) => c.corta).join(' / '),
      ];
    }
    // Sin repetidos, manteniendo el orden.
    final vistas = <String>{};
    return [for (final o in opciones) if (vistas.add(o)) o];
  }
}
