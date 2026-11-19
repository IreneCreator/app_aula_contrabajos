import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/fechas.dart';
import '../logic/reglas.dart';
import '../models/ajustes.dart';
import '../models/aviso.dart';
import '../models/clase.dart';
import '../models/dia_cerrado.dart';
import '../models/reserva.dart';
import '../models/usuario.dart';

/// Todo lo que se lee y escribe en Firestore pasa por aquí.
class Datos {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> _col(String nombre) => _db.collection(nombre);

  // ───────────── Usuarios ─────────────
  /// Solo emite datos ya confirmados por el servidor, para no entrar en la app
  /// con una ficha que aún no existe de verdad.
  static Stream<Usuario?> usuario(String uid) => _col('usuarios')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((d) => !d.metadata.hasPendingWrites)
      .map((d) => d.exists ? Usuario.desdeDoc(d) : null);

  static Stream<List<Usuario>> usuarios() => _col('usuarios').snapshots().map((q) =>
      q.docs.map(Usuario.desdeDoc).toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));

  static Future<void> crearUsuario({required String uid, required String nombre, String? email}) =>
      _col('usuarios').doc(uid).set({
        'nombre': nombre,
        'email': email ?? '',
        'estilo': 'concierto',
        'admin': false,
        'profesor': false,
        'gestorClases': false,
        'creado': FieldValue.serverTimestamp(),
      });

  static Future<void> cambiarNombre(String uid, String nombre) =>
      _col('usuarios').doc(uid).update({'nombre': nombre});

  /// Días que quiere ver el usuario en la rejilla (0 = automático).
  static Future<void> cambiarDiasVista(String uid, int dias) =>
      _col('usuarios').doc(uid).update({'diasVista': dias});

  /// estilo: 'concierto' o 'tamagotchi'
  static Future<void> cambiarEstilo(String uid, String estilo) =>
      _col('usuarios').doc(uid).update({'estilo': estilo});

  /// campo: 'admin', 'profesor' o 'gestorClases'
  static Future<void> cambiarPermiso(String uid, String campo, bool valor) =>
      _col('usuarios').doc(uid).update({campo: valor});

  // ───────────── Ajustes ─────────────
  static DocumentReference<Map<String, dynamic>> get _ajustes =>
      _col('ajustes').doc('general');

  static Stream<Ajustes> ajustes() => _ajustes.snapshots().map((d) => Ajustes.desdeMapa(d.data()));

  static Future<void> guardarAjustes(Ajustes a) => _ajustes.set(a.toMapa());

  // ───────────── Reservas ─────────────
  static Stream<List<Reserva>> reservasDesde(String fecha) => _col('reservas')
      .where('fecha', isGreaterThanOrEqualTo: fecha)
      .snapshots()
      .map((q) => q.docs.map(Reserva.desdeDoc).toList());

  static Map<String, dynamic> _datosReserva(
    String fecha,
    int minuto,
    String uid,
    bool deProfesor, {
    String descripcion = '',
  }) =>
      {
        'fecha': fecha,
        'minuto': minuto,
        'uid': uid,
        'deProfesor': deProfesor,
        if (descripcion.isNotEmpty) 'descripcion': descripcion,
        'creada': FieldValue.serverTimestamp(),
      };

  /// Reserva una franja libre. Falla si alguien la ha cogido justo antes.
  static Future<void> reservar({
    required String fecha,
    required int minuto,
    required String uid,
    required bool deProfesor,
  }) {
    final ref = _col('reservas').doc(idReserva(fecha, minuto));
    return _db.runTransaction<void>((tx) async {
      final actual = await tx.get(ref);
      if (actual.exists) throw StateError('ocupada');
      tx.set(ref, _datosReserva(fecha, minuto, uid, deProfesor));
    });
  }

  /// Se queda una franja que tenía otra persona. Falla si ha cambiado mientras tanto.
  static Future<void> ocupar({
    required String fecha,
    required int minuto,
    required String uidAnterior,
    required String uid,
    required bool deProfesor,
  }) {
    final ref = _col('reservas').doc(idReserva(fecha, minuto));
    return _db.runTransaction<void>((tx) async {
      final actual = await tx.get(ref);
      if (!actual.exists || actual.data()?['uid'] != uidAnterior) throw StateError('cambiada');
      tx.set(ref, _datosReserva(fecha, minuto, uid, deProfesor));
    });
  }

  static Future<void> cancelar(String id) => _col('reservas').doc(id).delete();

  /// El profesor bloquea varias franjas seguidas de una vez, con una descripción opcional.
  /// Solo coge las que estén libres; devuelve cuántas ha bloqueado.
  static Future<int> bloquearVarias({
    required String fecha,
    required List<int> minutos,
    required String uid,
    String descripcion = '',
  }) {
    final refs = [for (final m in minutos) (m, _col('reservas').doc(idReserva(fecha, m)))];
    return _db.runTransaction<int>((tx) async {
      final libres = <(int, DocumentReference<Map<String, dynamic>>)>[];
      for (final (m, ref) in refs) {
        if (!(await tx.get(ref)).exists) libres.add((m, ref));
      }
      for (final (m, ref) in libres) {
        tx.set(ref, _datosReserva(fecha, m, uid, true, descripcion: descripcion));
      }
      return libres.length;
    });
  }

  /// Cambia (o quita, si se deja vacía) la descripción de una franja del profesor.
  static Future<void> cambiarDescripcion(String id, String descripcion) =>
      _col('reservas').doc(id).update({'descripcion': descripcion});

  // ───────────── Clases ─────────────
  static Stream<List<Clase>> clases() => _col('clases').snapshots().map((q) =>
      q.docs.map(Clase.desdeDoc).toList()
        ..sort((a, b) =>
            a.diaSemana != b.diaSemana ? a.diaSemana.compareTo(b.diaSemana) : a.inicio.compareTo(b.inicio)));

  static Future<void> guardarClase(Clase c) async {
    if (c.id.isEmpty) {
      await _col('clases').add(c.toMapa());
    } else {
      await _col('clases').doc(c.id).set(c.toMapa());
    }
  }

  static Future<void> borrarClase(String id) => _col('clases').doc(id).delete();

  // Clases puntuales (de un solo día, por ejemplo clases movidas)
  static Stream<List<Clase>> clasesPuntuales() =>
      _col('clasesPuntuales').snapshots().map((q) => q.docs.map(Clase.desdeDoc).toList());

  /// Mueve una clase a otro día u hora solo para esa ocasión.
  /// Si es fija: la libera en su día original y crea una clase puntual en el nuevo sitio.
  /// Si ya era puntual (movida antes): simplemente cambia su día y hora.
  static Future<void> moverClase({
    required Clase clase,
    required String fechaOrigen,
    required String fechaDestino,
    required int diaSemanaDestino,
    required int inicio,
    required int fin,
  }) async {
    final lote = _db.batch();
    if (clase.esPuntual) {
      lote.update(_col('clasesPuntuales').doc(clase.id), {
        'fecha': fechaDestino,
        'diaSemana': diaSemanaDestino,
        'inicio': inicio,
        'fin': fin,
      });
    } else {
      lote.set(
        _col('liberaciones').doc(idLiberacion(clase.id, fechaOrigen)),
        {'claseId': clase.id, 'fecha': fechaOrigen},
      );
      lote.set(_col('clasesPuntuales').doc(), {
        'descripcion': clase.descripcion,
        'abreviatura': clase.abreviatura,
        'diaSemana': diaSemanaDestino,
        'inicio': inicio,
        'fin': fin,
        'fecha': fechaDestino,
        'origenId': clase.id,
        'origenFecha': fechaOrigen,
      });
    }
    await lote.commit();
  }

  /// Deshace un movimiento: borra la clase puntual y vuelve a poner la original en su sitio.
  static Future<void> deshacerMovimiento(Clase puntual) async {
    final lote = _db.batch();
    lote.delete(_col('clasesPuntuales').doc(puntual.id));
    if (puntual.origenId != null && puntual.origenFecha != null) {
      lote.delete(_col('liberaciones').doc(idLiberacion(puntual.origenId!, puntual.origenFecha!)));
    }
    await lote.commit();
  }

  /// Quita una clase puntual (la original, si la había, sigue liberada: ese día no hay clase).
  static Future<void> quitarClasePuntual(String id) => _col('clasesPuntuales').doc(id).delete();

  // Clases liberadas para un día concreto
  static Stream<Set<String>> liberaciones() =>
      _col('liberaciones').snapshots().map((q) => q.docs.map((d) => d.id).toSet());

  static Future<void> liberarClase(String claseId, String fecha) =>
      _col('liberaciones').doc(idLiberacion(claseId, fecha)).set({'claseId': claseId, 'fecha': fecha});

  static Future<void> restaurarClase(String claseId, String fecha) =>
      _col('liberaciones').doc(idLiberacion(claseId, fecha)).delete();

  // ───────────── Días cerrados ─────────────
  static Stream<List<DiaCerrado>> diasCerrados() => _col('diasCerrados').snapshots().map(
      (q) => q.docs.map(DiaCerrado.desdeDoc).toList()..sort((a, b) => a.fecha.compareTo(b.fecha)));

  static Future<void> cerrarDia(String fecha, String motivo) =>
      _col('diasCerrados').doc(fecha).set({'motivo': motivo});

  static Future<void> abrirDia(String fecha) => _col('diasCerrados').doc(fecha).delete();

  // ───────────── Avisos ─────────────
  static Stream<List<Aviso>> avisos() => _col('avisos')
      .orderBy('creado', descending: true)
      .snapshots()
      .map((q) => q.docs.map(Aviso.desdeDoc).toList());

  static Future<void> publicarAviso(String texto, String autor) => _col('avisos').add({
        'texto': texto,
        'autor': autor,
        'creado': FieldValue.serverTimestamp(),
      });

  static Future<void> borrarAviso(String id) => _col('avisos').doc(id).delete();
}
