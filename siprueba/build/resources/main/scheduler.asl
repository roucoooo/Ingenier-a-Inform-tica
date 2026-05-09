!start_scheduler.

+!start_scheduler : true <-
    .print("[SCHEDULER] Iniciado. Modo: señalizador de deadlines.");
    !!deadline_monitor.

+new_container(CId, X, Y, Type)[source(percept)] : true <-
    if (pending_count(Type, OldN)) {
        NewN = OldN + 1;
        -+pending_count(Type, NewN);
    } else {
        NewN = 1;
        +pending_count(Type, NewN);
    };
    ?overflow_threshold(Thr);
    if (NewN >= Thr) { !evaluate_output_phase(Type); }.

+!evaluate_output_phase(Type) : output_phase_active(none) <-
    .print("[SCHEDULER] Saturación detectada para tipo '", Type, "'. Iniciando salida.");
    .time(H, M, S);
    T0val = (H * 3600) + (M * 60) + S;
    -+t0(T0val);
    ?delta_t(DT);
    SD = T0val + DT;
    LD = T0val + (3 * DT);
    -+deadline_short(SD);
    -+deadline_long(LD);
    -+output_phase_active(Type);
    !broadcast_deadline(Type, SD, LD).

+!evaluate_output_phase(Type) : output_phase_active(ActiveType) & ActiveType \== none <- true.

+!broadcast_deadline(Type, SD, LD) : true <-
    ?known_robots(Robots);
    !send_deadline_to_all(Robots, Type, SD, LD).

+!send_deadline_to_all([], _, _, _) : true <- true.
+!send_deadline_to_all([Robot | Rest], Type, SD, LD) : true <-
    .send(Robot, tell, deadline_active(Type, SD, LD));
    !send_deadline_to_all(Rest, Type, SD, LD).

+!deadline_monitor : true <-
    !check_deadline_status;
    .wait(5000);
    !!deadline_monitor.

+!check_deadline_status : output_phase_active(none) <- true.
+!check_deadline_status : output_phase_active(Phase) & Phase \== none <-
    .time(H, M, S);
    Now = (H * 3600) + (M * 60) + S;
    ?deadline_short(SD);
    ?deadline_long(LD);
    if (Now >= LD) {
        -+output_phase_active(none);
        -+t0(0); -+deadline_short(0); -+deadline_long(0);
        -+pending_count(Phase, 0);
        !broadcast_phase_ended(Phase);
        .send(supervisor, tell, output_phase_ended(Phase));
    } elif (Now >= SD) {
        .send(supervisor, tell, deadline_short_expired(Phase, Now, LD));
    }.

+!broadcast_phase_ended(Phase) : true <-
    ?known_robots(Robots);
    !send_phase_ended_to_all(Robots, Phase).

+!send_phase_ended_to_all([], _) : true <- true.
+!send_phase_ended_to_all([R | Rest], Phase) : true <-
    .send(R, tell, deadline_active(none, 0, 0));
    !send_phase_ended_to_all(Rest, Phase).

+container_delivered_ok(CId, Type)[source(Robot)] : true <-
    if (pending_count(Type, N) & N > 0) {
        -+pending_count(Type, N - 1);
    } else {
        -+pending_count(Type, 0);
    }.

output_phase_active(none).   
t0(0).
deadline_short(0).
deadline_long(0).
delta_t(30).                 
pending_count("urgent",   0).
pending_count("standard", 0).
pending_count("fragile",  0).
overflow_threshold(3).
known_robots([robot_light, robot_medium, robot_heavy, robot_heavy2]).