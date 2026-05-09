state(idle).
carrying(none).
autonomous_mode(none).
deadline_long(0).

home_x(4). home_y(3).

shelf_location("shelf_1",  10, 2). shelf_location("shelf_2",  12, 2).
shelf_location("shelf_3",  14, 2). shelf_location("shelf_4",  16, 2).
shelf_location("shelf_5",  10, 6). shelf_location("shelf_6",  13, 6).
shelf_location("shelf_7",  16, 6). shelf_location("shelf_8",  10, 10).
shelf_location("shelf_9",  14, 10).

!start.

+!start : true <-
    .print("[HEAVY2] Iniciado. Refuerzo 100kg.");
    !!poll_entrance.

+!poll_entrance : state(idle) & autonomous_mode(none) <-
    query_containers_at_entrance; .wait(500); !check_entrance_candidates.

+!check_entrance_candidates : state(idle) & autonomous_mode(none) <-
    .findall(cand(CId, CX, CY, CT), container_at_entrance(CId, CX, CY, CT), Candidates);
    if (.length(Candidates) > 0) { !try_claim_container(Candidates); } else { .wait(3500); !!poll_entrance; }.

+!try_claim_container([]) : true <- .wait(3000); !!poll_entrance.
+!try_claim_container([cand(CId, CX, CY, CT) | Rest]) : state(idle) & autonomous_mode(none) <-
    query_container_info(CId); .wait(300);
    if (container_info(CId, CW, CH, CWeight, CT, CX, CY, "pending") & CWeight > 30.0 & CW <= 2 & CH <= 3) {
        .broadcast(tell, claiming(CId)); .wait(800);
        if (not claimed_by_other(CId)) {
            +claimed_container(CId); .abolish(container_at_entrance(CId,_,_,_)); !execute_store_task(CId, CX, CY);
        } else { !try_claim_container(Rest); };
    } else { !try_claim_container(Rest); }.

+claiming(OtherId)[source(OtherRobot)] : true <- +claimed_by_other(OtherId).

// --- 1. TAREAS PRINCIPALES CON WAYPOINTS (PASILLO CENTRAL X=9) ---
+!execute_store_task(CId, CX, CY) : state(idle) <-
    -+state(working);
    .print("Iniciando recogida de contenedor: ", CId);
    !navigate_adjacent(CX, CY); 
    pickup(CId);
    .print("Contenedor recogido. Buscando estantería...");
    !select_best_shelf(CId, ShelfId); 
    query_location(ShelfId); 
    .wait(300);
    ?location(ShelfId, SX, SY);
    if (SY > 0) { PasilloY = SY - 1; } else { PasilloY = SY + 1; };
    
    .print("Navegando vía pasillo principal (X=9) hacia estantería ", ShelfId);
    !navigate_to(9, PasilloY);  // WAYPOINT 1: Salir al pasillo central seguro
    !navigate_to(SX, PasilloY); // WAYPOINT 2: Entrar a la estantería de frente
    drop_at(ShelfId);
    
    .print("Tarea finalizada. Regresando a base.");
    ?home_x(HX); ?home_y(HY);
    !navigate_to(9, PasilloY);  // WAYPOINT 3: Salir de la estantería al pasillo
    !navigate_to(9, HY);        // WAYPOINT 4: Alinear con la coordenada Y de casa
    !navigate_to(HX, HY);       // WAYPOINT 5: Volver a casa
    -+state(idle);
    !!poll_entrance.

+!deliver_to_exit(CId, SId) : state(idle) <-
    -+state(working); 
    query_location(SId); .wait(200);
    ?location(SId, SX, SY); PasilloY = SY - 1;
    
    !navigate_to(9, PasilloY);  // WAYPOINT 1
    !navigate_to(SX, PasilloY); // WAYPOINT 2
    pickup(CId); 
    
    !navigate_to(9, PasilloY);  // WAYPOINT 3
    !navigate_to_exit_zone; 
    drop_at_exit;
    
    .my_name(Me);
    .send(scheduler, tell, container_delivered_ok(CId, "any"));
    .send(supervisor, tell, container_delivered_exit(CId, Me));
    
    ?home_x(HX); ?home_y(HY); 
    !navigate_to(9, HY); 
    !navigate_to(HX, HY); 
    -+state(idle);
    .abolish(claimed_exit(_)); .abolish(claimed_exit_by_other(_)); .abolish(container_stored(CId,_,_)); 
    !!exit_cycle_loop.

-!deliver_to_exit(CId, SId) : true <-
    -+state(idle); .abolish(claimed_exit(_)); .abolish(claimed_exit_by_other(_));
    ?home_x(HX); ?home_y(HY); 
    !navigate_to(9, HY);
    !navigate_to(HX, HY); 
    !!exit_cycle_loop.

// --- 2. NAVEGACIÓN PASO A PASO (NUEVA, PARA QUE VAYAN EN PARALELO) ---
+!navigate_to(TX, TY) : true <- 
    .my_name(Me); .term2string(Me, MeStr);
    query_location(MeStr); .wait(50);
    ?location(MeStr, CX, CY);
    if (CX == TX & CY == TY) {
        .print("Destino alcanzado: (", TX, ",", TY, ")");
    } else {
        move_to(TX, TY);
        .wait(200); 
        !navigate_to(TX, TY); 
    }.

// Si move_to falla (porque está 100% acorralado), espera un segundo y reintenta
-!navigate_to(TX, TY) : true <- 
    .print("Esperando a que se despeje el camino hacia (", TX, ",", TY, ")...");
    .wait(1000); 
    !navigate_to(TX, TY).

// --- 3. ACERCAMIENTO Y SALIDA ---
+!navigate_adjacent(CX, CY) : true <-
    !try_adjacent_list(CX, CY, [ pos(CX, CY+1), pos(CX-1, CY), pos(CX+1, CY), pos(CX, CY-1), pos(CX+2, CY), pos(CX, CY+2) ]).

+!try_adjacent_list(CX, CY, [pos(AX, AY) | Rest]) : true <-
    if (AX >= 0 & AY >= 0) { 
        !navigate_to(AX, AY); 
    } else { 
        !try_adjacent_list(CX, CY, Rest); 
    }.

-!try_adjacent_list(CX, CY, [pos(AX, AY) | Rest]) : true <- 
    !try_adjacent_list(CX, CY, Rest).

+!try_adjacent_list(CX, CY, []) : true <- 
    .wait(1500); 
    !!navigate_adjacent(CX, CY).

+!navigate_to_exit_zone : true <-
    !try_exit_positions([pos(0,0), pos(1,0), pos(2,0), pos(0,1), pos(1,1), pos(2,1)]).

+!try_exit_positions([pos(EX, EY) | Rest]) : true <- !navigate_to(EX, EY).
-!try_exit_positions([pos(EX, EY) | Rest]) : true <- !try_exit_positions(Rest).

+!try_exit_positions([]) : true <- .wait(1500); !!navigate_to_exit_zone.

// --- 4. GESTIÓN DE ERRORES Y PLANES DE RESPALDO ANTI-CRASHES ---
+error(Type, Data) : true <- -error(Type, Data).

+!poll_entrance : true <- .wait(10).
+!check_entrance_candidates : true <- .wait(10).
+!try_claim_container(_) : true <- .wait(10).
+!exit_cycle_loop : true <- .wait(10).