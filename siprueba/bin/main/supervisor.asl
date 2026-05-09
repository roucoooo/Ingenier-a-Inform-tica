/*******************************************************************************
 * SUPERVISOR — Agente de Monitorización, Métricas y Alertas
 *
 * Responsabilidades (Iteración 2):
 *   - Registrar métricas de rendimiento (contenedores procesados, errores)
 *   - Monitorizar el cumplimiento de deadlines
 *   - Detectar anomalías y generar alertas
 *   - NO coordina robots ni asigna tareas
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */
total_processed(0).
total_errors(0).
total_delivered_exit(0).

errors_by_type(container_too_heavy, 0).
errors_by_type(container_too_big,   0).
errors_by_type(shelf_full,          0).
errors_by_type(too_far,             0).
errors_by_type(deadline_missed,     0).

robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).
robot_status(robot_heavy2, idle).

output_phase_active(none).
system_start_time(0).

/* ============================================================================
 * ARRANQUE
 * ============================================================================ */
!init.

+!init : true <-
    .print("[SUPERVISOR] Monitorización activa. Modo: observación y métricas.");
    .time(H, M, S);
    StartSec = S + M*60 + H*3600;
    -+system_start_time(StartSec);
    !periodic_report.

/* ============================================================================
 * REPORTE PERIÓDICO (cada 60s)
 * ============================================================================ */
+!periodic_report : true <-
    .wait(60000);
    !generate_report;
    !periodic_report.

+!generate_report : true <-
    .print("===== SUPERVISOR REPORT =====");
    ?total_processed(P);
    ?total_errors(E);
    ?total_delivered_exit(D);
    .time(H, M, S);
    CurSec = S + M*60 + H*3600;
    ?system_start_time(StartSec);
    Uptime = CurSec - StartSec;
    .print("Uptime: ", Uptime, "s | Almacenados: ", P,
           " | Entregados zona salida: ", D, " | Errores: ", E);
    if (Uptime > 0 & P > 0) {
        Thr = (P * 60.0) / Uptime;
        .print("Throughput: ", Thr, " contenedores/min");
    };
    if (P + E > 0) {
        Eff = (P * 100.0) / (P + E);
        .print("Eficiencia: ", Eff, "%");
    };
    ?robot_status(robot_light, SL);
    ?robot_status(robot_medium, SM);
    ?robot_status(robot_heavy, SH);
    ?robot_status(robot_heavy2, SH2);
    .print("Flota: Light=", SL, " | Medium=", SM,
           " | Heavy=", SH, " | Heavy2=", SH2);
    .print("==============================").

/* Reporte cada 10 contenedores */
+total_processed(N) : N > 0 & (N mod 10 == 0) <-
    !generate_report.

/* ============================================================================
 * MÉTRICAS — ALMACENAMIENTO
 * ============================================================================ */
+stored(CId, ShelfId)[source(Robot)] : true <-
    ?total_processed(N);
    -+total_processed(N+1);
    -+robot_status(Robot, idle);
    .print("[SUPERVISOR] ✅ ", Robot, " almacenó ", CId, " en ", ShelfId).

+redirected(CId, OldShelf, NewShelf)[source(Robot)] : true <-
    .print("[SUPERVISOR] ↩ ", Robot, " redirigió ", CId,
           " de ", OldShelf, " a ", NewShelf).

/* ============================================================================
 * MÉTRICAS — ZONA DE SALIDA
 * ============================================================================ */
+container_delivered(CId, Robot)[source(percept)] : true <-
    ?total_delivered_exit(N);
    -+total_delivered_exit(N+1);
    .print("[SUPERVISOR] 🚚 ", Robot, " entregó ", CId, " a zona de salida").

+container_delivered_exit(CId, Robot)[source(Robot)] : true <-
    ?total_delivered_exit(N);
    -+total_delivered_exit(N+1);
    .print("[SUPERVISOR] 🚚 ", Robot, " entregó ", CId, " a zona de salida").

/* ============================================================================
 * GESTIÓN DE CICLOS DE SALIDA Y DEADLINES
 * ============================================================================ */
+output_phase_ended(Phase)[source(scheduler)] : true <-
    -+output_phase_active(none);
    .print("[SUPERVISOR] Ciclo de salida '", Phase, "' finalizado.").

+deadline_short_expired(Phase, Now, LD)[source(scheduler)] : true <-
    .print("[SUPERVISOR] ⚠ Deadline corto expirado para '", Phase,
           "'. Deadline largo en: ", LD).

/* ============================================================================
 * DETECCIÓN DE ERRORES
 * ============================================================================ */
+error(Type, Data)[source(Robot)] : true <-
    ?total_errors(N);
    -+total_errors(N+1);
    ?errors_by_type(Type, OldC);
    -+errors_by_type(Type, OldC+1);
    .print("[SUPERVISOR] ⚠ Error '", Type, "' en ", Robot, " | dato=", Data).

/* Detección de deadline missed: si un contenedor sigue pendiente tras LD */
+container_deadline_missed(CId, Type)[source(percept)] : true <-
    ?errors_by_type(deadline_missed, OldC);
    -+errors_by_type(deadline_missed, OldC+1);
    ?total_errors(N);
    -+total_errors(N+1);
    .print("[SUPERVISOR] ⏰ DEADLINE MISSED: ", CId, " tipo=", Type).

/* ============================================================================
 * ACTUALIZACIONES DE ESTADO DE ROBOTS
 * ============================================================================ */
+robot_done(Robot, CId)[source(Robot)] : true <-
    -+robot_status(Robot, idle);
    .print("[SUPERVISOR] ", Robot, " completó tarea de ", CId).