state(idle).
carrying(none).
autonomous_mode(none).       

home_x(1). home_y(3).

shelf_location("shelf_1",  10, 2). shelf_location("shelf_2",  12, 2).
shelf_location("shelf_3",  14, 2). shelf_location("shelf_4",  16, 2).
shelf_location("shelf_5",  10, 6). shelf_location("shelf_6",  13, 6).
shelf_location("shelf_7",  16, 6). shelf_location("shelf_8",  10, 10).
shelf_location("shelf_9",  14, 10).

!start.

+!start : true <-
    .print("[LIGHT] Iniciado. Capacidad: 10kg.");
    !!poll_entrance.

+!poll_entrance : state(idle) & autonomous_mode(none) <-
    query_containers_at_entrance; .wait(500); !check_entrance_candidates.

+!check_entrance_candidates : state(idle) & autonomous_mode(none) <-
    .findall(cand(CId, CX, CY, CT), container_at_entrance(CId, CX, CY, CT), Candidates);
    if (.length(Candidates) > 0) { !try_claim_container(Candidates); } else { .wait(3000); !!poll_entrance; }.

+!try_claim_container([]) : true <- .wait(3000); !!poll_entrance.
+!try_claim_container([cand(CId, CX, CY, CT) | Rest]) : state(idle) & autonomous_mode(none) <-
    query_container_info(CId); .wait(300);
    if (container_info(CId, CW, CH, CWeight, CT, CX, CY, "pending") & CWeight <= 10.0 & CW <= 1 & CH <= 1) {
        .broadcast(tell, claiming(CId)); .wait(500);   
        if (not claimed_by_other(CId)) {
            +claimed_container(CId); .abolish(container_at_entrance(CId,_,_,_)); !execute_store_task(CId, CX, CY);
        } else { !try_claim_container(Rest); };
    } else { !try_claim_container(Rest); }.

+claiming(OtherId)[source(OtherRobot)] : true <- +claimed_by_other(OtherId).

+!execute_store_task(CId, CX, CY) : state(idle) <-
    -+state(working);
    !navigate_adjacent(CX, CY); pickup(CId);
    !select_best_shelf(CId, ShelfId);
    query_location(ShelfId); .wait(200); ?location(ShelfId, SX, SY);
    PasilloY = SY - 1;
    !navigate_to(SX, PasilloY); drop_at(ShelfId);
    ?home_x(HX); ?home_y(HY); !navigate_to(HX, HY);
    -+state(idle);
    .abolish(claimed_container(_)); .abolish(claimed_by_other(_));
    .broadcast(tell, robot_done(robot_light, CId)); .send(supervisor, tell, stored(CId, ShelfId));
    !!poll_entrance.

-!execute_store_task(CId, CX, CY) : true <-
    -+state(idle);
    .abolish(claimed_container(_)); .abolish(claimed_by_other(_));
    ?home_x(HX); ?home_y(HY); !navigate_to(HX, HY); !!poll_entrance.

+!select_best_shelf(CId, BestShelf) : true <-
    !query_all_shelves; .wait(500);
    .findall(cand(OccW, SId), (shelf_info(SId, _, _, MaxW, MaxVol, CurW, CurVol) & container_info(CId, CW, CH, CWeight, _, _, _, _) & (CurW + CWeight) <= MaxW & (CurVol + CW*CH) <= MaxVol & OccW = CurW/MaxW), Candidates);
    .sort(Candidates, Sorted);
    if (.length(Sorted) > 0) { .nth(0, Sorted, cand(_, BestShelf)); } else { BestShelf = "shelf_1"; };
    .abolish(shelf_info(_,_,_,_,_,_,_)).

+!query_all_shelves : true <-
    .abolish(shelf_info(_,_,_,_,_,_,_));
    !query_shelf_loop(["shelf_1","shelf_2","shelf_3","shelf_4","shelf_5","shelf_6","shelf_7","shelf_8","shelf_9"]).

+!query_shelf_loop([]) : true <- true.
+!query_shelf_loop([S|Rest]) : true <- query_shelf_info(S); .wait(100); !query_shelf_loop(Rest).

+deadline_active(Type, SD, LD)[source(scheduler)] : true <-
    -+autonomous_mode(Type); -+deadline_long(LD); .abolish(claimed_by_other(_));
    if (Type \== none & state(idle)) { !!exit_cycle_loop; }.

+!exit_cycle_loop : autonomous_mode(Type) & Type \== none & state(idle) <-
    .time(H, M, S); Now = (H * 3600) + (M * 60) + S; ?deadline_long(LD);
    if (Now < LD) { !find_and_deliver(Type); } else { -+autonomous_mode(none); !!poll_entrance; }.
+!exit_cycle_loop : autonomous_mode(none) <- !!poll_entrance.

+!find_and_deliver(Type) : state(idle) <-
    query_containers_stored(Type); .wait(500);
    .findall(cand(CId, SId), container_stored(CId, SId, Type), Candidates);
    if (.length(Candidates) > 0) {
        .nth(0, Candidates, cand(CId, SId)); .broadcast(tell, claiming_exit(CId)); .wait(400);
        if (not claimed_exit_by_other(CId)) {
            +claimed_exit(CId); !deliver_to_exit(CId, SId);
        } else { .wait(1000); !!exit_cycle_loop; };
    } else { .wait(4000); !!exit_cycle_loop; }.

+claiming_exit(OtherId)[source(OtherRobot)] : true <- +claimed_exit_by_other(OtherId).

+!deliver_to_exit(CId, SId) : state(idle) <-
    -+state(working);
    query_location(SId); .wait(200); ?location(SId, SX, SY); PasilloY = SY - 1;
    !navigate_to(SX, PasilloY); pickup(CId); !navigate_to_exit_zone; drop_at_exit;
    .send(scheduler, tell, container_delivered_ok(CId, "any")); .send(supervisor, tell, container_delivered_exit(CId, robot_light));
    ?home_x(HX); ?home_y(HY); !navigate_to(HX, HY);
    -+state(idle);
    .abolish(claimed_exit(_)); .abolish(claimed_exit_by_other(_)); .abolish(container_stored(CId,_,_));
    !!exit_cycle_loop.

-!deliver_to_exit(CId, SId) : true <-
    -+state(idle); .abolish(claimed_exit(_)); .abolish(claimed_exit_by_other(_));
    ?home_x(HX); ?home_y(HY); !navigate_to(HX, HY); !!exit_cycle_loop.

// --- NAVEGACIÓN A PRUEBA DE ATASCOS ---
+!navigate_to(TX, TY) : true <- move_to(TX, TY).
-!navigate_to(TX, TY) : true <- .wait(1000); !!navigate_to(TX, TY).

+!navigate_adjacent(CX, CY) : true <-
    !try_adjacent_list(CX, CY, [ pos(CX, CY+1), pos(CX-1, CY), pos(CX+1, CY), pos(CX, CY-1) ]).

+!try_adjacent_list(CX, CY, [pos(AX, AY) | Rest]) : true <-
    if (AX >= 0 & AY >= 0) { !navigate_to(AX, AY); } else { !try_adjacent_list(CX, CY, Rest); }.

-!try_adjacent_list(CX, CY, [pos(AX, AY) | Rest]) : true <- !try_adjacent_list(CX, CY, Rest).

+!try_adjacent_list(CX, CY, []) : true <- 
    .print("⏳ Ligero atascado. Esperando turno...");
    .wait(1500); 
    !!navigate_adjacent(CX, CY).

+!navigate_to_exit_zone : true <-
    !try_exit_positions([pos(0,0), pos(1,0), pos(2,0), pos(0,1), pos(1,1), pos(2,1)]).

+!try_exit_positions([pos(EX, EY) | Rest]) : true <- !navigate_to(EX, EY).
-!try_exit_positions([pos(EX, EY) | Rest]) : true <- !try_exit_positions(Rest).
+!try_exit_positions([]) : true <- .wait(1500); !!navigate_to_exit_zone.

+error(Type, Data) : true <- -error(Type, Data).