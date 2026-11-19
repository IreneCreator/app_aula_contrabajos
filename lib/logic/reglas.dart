// Reglas del aula. Son funciones puras (sin Firebase), así se pueden probar con tests.
import '../config.dart';
import '../models/ajustes.dart';
import '../models/clase.dart';
import '../models/dia_cerrado.dart';
import '../models/reserva.dart';
import '../models/usuario.dart';
import 'fechas.dart';

String idLiberacion(String claseId, String fecha) => '${claseId}_$fecha';

bool franjaPasada(DateTime dia, int minuto, DateTime ahora) =>
    soloDia(dia).add(Duration(minutes: minuto + minutosFranja)).isBefore(ahora);

/// Foto de todos los datos del aula en un momento dado.
class EstadoAula {
  final Ajustes ajustes;
  final Map<String, Reserva> reservas; // por id
  final List<Clase> clases; // fijas
  final List<Clase> puntuales; // de un solo día (clases movidas)
  final Set<String> liberaciones;
  final Map<String, DiaCerrado> diasCerrados; // festivos marcados, por fecha
  final Map<String, Usuario> usuarios; // por uid

  const EstadoAula({
    required this.ajustes,
    required this.reservas,
    this.clases = const [],
    this.puntuales = const [],
    this.liberaciones = const {},
    this.diasCerrados = const {},
    this.usuarios = const {},
  });

  String nombreDe(String uid) => usuarios[uid]?.nombre ?? '…';

  Reserva? reservaEn(DateTime dia, int minuto) => reservas[claveReserva(dia, minuto)];

  /// Todas las clases del horario fijo que tocan esa franja (aunque estén liberadas),
  /// ordenadas por hora de inicio.
  List<Clase> clasesEn(DateTime dia, int minuto) =>
      clasesDelDia(dia).where((c) => c.contiene(minuto)).toList();

  /// Clases de un día, ordenadas por hora: las fijas de ese día de la semana
  /// (salvo en festivos, en los que se liberan solas) y las puntuales de esa fecha.
  List<Clase> clasesDelDia(DateTime dia) {
    final fecha = fechaClave(dia);
    return [
      if (!esFestivo(dia)) ...clases.where((c) => c.diaSemana == dia.weekday),
      ...puntuales.where((c) => c.fecha == fecha),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  /// Clases fijas que tocarían ese día pero no se dan por ser festivo.
  List<Clase> clasesLiberadasPorFestivo(DateTime dia) => esFestivo(dia)
      ? (clases.where((c) => c.diaSemana == dia.weekday).toList()..sort((a, b) => a.inicio.compareTo(b.inicio)))
      : const [];

  /// Si una clase fija se ha movido desde ese día, la clase puntual a la que se movió.
  Clase? movidaDesde(Clase fija, DateTime dia) {
    final fecha = fechaClave(dia);
    for (final p in puntuales) {
      if (p.origenId == fija.id && p.origenFecha == fecha) return p;
    }
    return null;
  }

  /// Clase fija liberada (o movida) ese día. Las puntuales nunca están "liberadas": se borran.
  bool liberada(Clase c, DateTime dia) =>
      !c.esPuntual && liberaciones.contains(idLiberacion(c.id, fechaClave(dia)));

  /// Festivo marcado a mano (con su motivo), o null.
  DiaCerrado? festivoMarcado(DateTime dia) => diasCerrados[fechaClave(dia)];

  /// Sábados, domingos y días marcados como festivos.
  bool esFestivo(DateTime dia) => dia.weekday >= DateTime.saturday || festivoMarcado(dia) != null;

  /// Horario del aula ese día, en minutos: (apertura, cierre).
  (int, int) horarioDe(DateTime dia) => esFestivo(dia)
      ? (ajustes.horaInicioFestivo * 60, ajustes.horaFinFestivo * 60)
      : (ajustes.horaInicio * 60, ajustes.horaFin * 60);

  /// La franja cae fuera del horario del aula ese día.
  bool fueraDeHorario(DateTime dia, int minuto) {
    final (abre, cierra) = horarioDe(dia);
    return minuto < abre || minuto + minutosFranja > cierra;
  }

  /// Día por índice (0 = hoy) abierto a reservas de alumnos.
  bool diaAbierto(int indice) => indice <= ajustes.diasAntelacion;

  /// Reservas de alumno de una persona en un día, por orden de reserva.
  List<Reserva> deUsuarioEnDia(String uid, String fecha) => reservas.values
      .where((r) => r.uid == uid && r.fecha == fecha && !r.deProfesor)
      .toList()
    ..sort((a, b) => a.creada.compareTo(b.creada));

  int franjasDe(String uid, String fecha) => deUsuarioEnDia(uid, fecha).length;

  /// El profesor siempre tiene prioridad. Un alumno, solo en sus primeras
  /// franjas del día (hasta el máximo de horas), por orden de reserva.
  bool tienePrioridad(Reserva r) {
    if (r.deProfesor) return true;
    final orden = deUsuarioEnDia(r.uid, r.fecha).indexWhere((x) => x.id == r.id);
    return orden < ajustes.franjasConPrioridad;
  }
}
