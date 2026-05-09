package warehouse;

import jason.asSyntax.*;
import jason.environment.Environment;

import java.util.*;
import java.util.concurrent.*;

/**
 * Artefacto del almacén — entorno DELGADO (thin environment).
 *
 * Responsabilidad: proporcionar SOLO percepciones primitivas sobre el mundo.
 *   - Posición de robots
 *   - Posición de estanterías (coordenadas, capacidad raw)
 *   - Posición y estado mínimo de contenedores
 *
 * El entorno NO:
 *   - Asigna estanterías a contenedores
 *   - Calcula rutas (A*, BFS, etc.)
 *   - Evalúa qué robot es "el mejor" para una tarea
 *   - Genera estadísticas de planificación
 *
 * Todo el razonamiento, planificación y coordinación reside en los agentes.
 */
public class WarehouseArtifact extends Environment {

    private static final int GRID_WIDTH  = 20;
    private static final int GRID_HEIGHT = 15;

    private static final int EXIT_X_MIN = 0;
    private static final int EXIT_X_MAX = 2;
    private static final int EXIT_Y_MIN = 0;
    private static final int EXIT_Y_MAX = 1;

    private static final int ENTRANCE_X_MIN = 5;
    private static final int ENTRANCE_X_MAX = 7;

    private CellType[][]       grid;
    private Map<String, Robot>      robots;
    private Map<String, Container>  containers;
    private Map<String, Shelf>      shelves;

    private WarehouseView view;
    private int  containerCounter = 0;
    private int  totalContainersProcessed = 0;
    private int  totalErrors = 0;
    private long startTime;

    private ExecutorService containerGeneratorExecutor;
    private volatile boolean running = true;

    // =========================================================================
    // Inicialización
    // =========================================================================
    @Override
    public void init(String[] args) {
        super.init(args);

        grid       = new CellType[GRID_WIDTH][GRID_HEIGHT];
        robots     = new ConcurrentHashMap<>();
        containers = new ConcurrentHashMap<>();
        shelves    = new ConcurrentHashMap<>();

        initializeGrid();
        initializeRobots();
        initializeShelves();

        view = new WarehouseView(this, GRID_WIDTH, GRID_HEIGHT);
        view.setVisible(true);

        log("✨ ========================================");
        log("🏢 Warehouse Management System — Thin Environment");
        log("   Grid: " + GRID_WIDTH + "x" + GRID_HEIGHT);
        log("   Robots: " + robots.size());
        log("   Shelves: " + shelves.size());
        log("✨ ========================================");

        startContainerGenerator();
        Runtime.getRuntime().addShutdownHook(new Thread(this::stop));
        startTime = System.currentTimeMillis();
    }

    private void initializeGrid() {
        for (int x = 0; x < GRID_WIDTH; x++)
            for (int y = 0; y < GRID_HEIGHT; y++)
                grid[x][y] = CellType.EMPTY;

        for (int x = EXIT_X_MIN; x <= EXIT_X_MAX; x++)
            for (int y = EXIT_Y_MIN; y <= EXIT_Y_MAX; y++)
                grid[x][y] = CellType.EXIT;

        for (int x = 3; x <= 4; x++)
            for (int y = 0; y < 2; y++)
                grid[x][y] = CellType.CLASSIFICATION;

        for (int x = ENTRANCE_X_MIN; x <= ENTRANCE_X_MAX; x++)
            for (int y = 0; y < 2; y++)
                grid[x][y] = CellType.ENTRANCE;
    }

    private void initializeRobots() {
        addRobot("robot_light",  "light",  10,  1, 1, 3, 1, 3);
        addRobot("robot_medium", "medium", 30,  1, 2, 2, 2, 3);
        addRobot("robot_heavy",  "heavy",  100, 2, 3, 1, 3, 3);
        addRobot("robot_heavy2", "heavy",  100, 2, 3, 1, 4, 3);
    }

    private void addRobot(String id, String type, double maxW, int maxWid, int maxH,
                          int speed, int startX, int startY) {
        Robot r = new Robot(id, type, maxW, maxWid, maxH, speed);
        r.setPosition(startX, startY);
        robots.put(id, r);
    }

    private void initializeShelves() {
        int sid = 1;
        for (int x = 10; x < 18; x += 2) {
            Shelf s = new Shelf("shelf_" + sid++, x, 2, 2, 2, 50, 8);
            shelves.put(s.getId(), s); markShelf(s);
        }
        for (int x = 10; x < 19; x += 3) {
            Shelf s = new Shelf("shelf_" + sid++, x, 6, 3, 2, 100, 12);
            shelves.put(s.getId(), s); markShelf(s);
        }
        for (int x = 10; x < 16; x += 4) {
            Shelf s = new Shelf("shelf_" + sid++, x, 10, 4, 3, 200, 20);
            shelves.put(s.getId(), s); markShelf(s);
        }
    }

    private void markShelf(Shelf s) {
        for (int dx = 0; dx < s.getWidth(); dx++)
            for (int dy = 0; dy < s.getHeight(); dy++) {
                int gx = s.getX() + dx, gy = s.getY() + dy;
                if (gx < GRID_WIDTH && gy < GRID_HEIGHT)
                    grid[gx][gy] = CellType.SHELF;
            }
    }

    // =========================================================================
    // Generador de contenedores
    // =========================================================================
    private void startContainerGenerator() {
        containerGeneratorExecutor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "ContainerGenerator");
            t.setDaemon(true);
            return t;
        });
        containerGeneratorExecutor.submit(() -> {
            Random rand = new Random();
            while (running) {
                try {
                    Thread.sleep(3000 + rand.nextInt(3000));
                    if (!running) break;
                    int[] pos = findFreeEntranceCell();
                    if (pos != null) {
                        Container c = generateRandomContainer(pos[0], pos[1]);
                        containers.put(c.getId(), c);
                        log("🆕 " + c.getId() + " en (" + pos[0] + "," + pos[1] + ") tipo=" + c.getType());

                        // Percepción primitiva para scheduler — solo ubicación y tipo
                        addPercept("scheduler",
                            Literal.parseLiteral("new_container(\"" + c.getId() + "\","
                                + pos[0] + "," + pos[1] + ",\"" + c.getType() + "\")"));

                        if (view != null) view.update();
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt(); break;
                } catch (Exception e) { e.printStackTrace(); }
            }
        });
    }

    private int[] findFreeEntranceCell() {
        List<int[]> positions = Arrays.asList(
            new int[]{5,0}, new int[]{5,1}, new int[]{6,0},
            new int[]{6,1}, new int[]{7,0}, new int[]{7,1}
        );
        Collections.shuffle(positions);
        for (int[] p : positions) {
            boolean busy = containers.values().stream()
                .anyMatch(c -> !c.isPicked() && c.getAssignedShelf() == null
                            && c.getX() == p[0] && c.getY() == p[1]);
            if (!busy) return p;
        }
        return null;
    }

    private Container generateRandomContainer(int x, int y) {
        Random rand = new Random();
        String id = "container_" + (++containerCounter);
        int w, h; double weight;
        double r = rand.nextDouble();
        if      (r < 0.33) { w=1; h=1; weight = 5  + rand.nextDouble()*5;  }
        else if (r < 0.66) { w=1; h=2; weight = 12 + rand.nextDouble()*15; }
        else               { w=2; h=2+rand.nextInt(2); weight = 35 + rand.nextDouble()*45; }

        double tr = rand.nextDouble();
        String type = tr < 0.2 ? "urgent" : tr < 0.45 ? "fragile" : "standard";

        Container c = new Container(id, w, h, weight, type);
        c.setPosition(x, y);
        return c;
    }

    public void stop() {
        running = false;
        if (containerGeneratorExecutor != null) containerGeneratorExecutor.shutdownNow();
    }

    // =========================================================================
    // Despacho de acciones
    // =========================================================================
    @Override
    public boolean executeAction(String agName, Structure action) {
        try {
            switch (action.getFunctor()) {
                case "move_to":                      return doMoveTo(agName, action);
                case "pickup":                       return doPickup(agName, action);
                case "drop_at":                      return doDropAt(agName, action);
                case "drop_at_exit":                 return doDropAtExit(agName);
                case "query_location":               return doQueryLocation(agName, action);
                case "query_shelf_info":             return doQueryShelfInfo(agName, action);
                case "query_container_info":         return doQueryContainerInfo(agName, action);
                case "query_containers_at_entrance": return doQueryContainersAtEntrance(agName);
                case "query_containers_stored":      return doQueryContainersStored(agName, action);
                default:
                    System.err.println("[ENV] Unknown action: " + action.getFunctor());
                    return false;
            }
        } catch (Exception e) { e.printStackTrace(); return false; }
    }

    // =========================================================================
    // move_to(X, Y)
    // Ejecuta movimiento PASO A PASO greedy. El agente planifica su ruta;
    // el entorno solo valida y ejecuta un paso por iteración.
    // Si hay obstáculo devuelve false -> el agente debe replantear.
    // =========================================================================
    private boolean doMoveTo(String agName, Structure action) {
        try {
            int tx = (int)((NumberTerm) action.getTerm(0)).solve();
            int ty = (int)((NumberTerm) action.getTerm(1)).solve();
            Robot robot = robots.get(agName);
            if (robot == null) return false;
            if (outOfBounds(tx, ty) || grid[tx][ty] == CellType.SHELF
                                    || grid[tx][ty] == CellType.BLOCKED) return false;

            int sleepMs = Math.max(100, 800 / robot.getSpeed());
            Random rand = new Random();
            int retries = 0;

            while (robot.getX() != tx || robot.getY() != ty) {
                int cx = robot.getX(), cy = robot.getY();
                // Paso greedy: primero X luego Y
                int nx = cx, ny = cy;
                if      (cx < tx) nx++;
                else if (cx > tx) nx--;
                else if (cy < ty) ny++;
                else if (cy > ty) ny--;

                if (outOfBounds(nx, ny) || grid[nx][ny] == CellType.SHELF
                                        || grid[nx][ny] == CellType.BLOCKED)
                    return false; // el agente debe replantear

                if (isOtherRobotAt(nx, ny, agName)) {
                    if (++retries > 5) return false; // deadlock -> agente replanifica
                    Thread.sleep(200 + rand.nextInt(300));
                    continue;
                }
                retries = 0;
                robot.setPosition(nx, ny);
                if (view != null) view.update();
                Thread.sleep(sleepMs);
            }
            return true;
        } catch (Exception e) { return false; }
    }

    private boolean outOfBounds(int x, int y) {
        return x < 0 || x >= GRID_WIDTH || y < 0 || y >= GRID_HEIGHT;
    }

    private boolean isOtherRobotAt(int x, int y, String exclude) {
        for (Robot r : robots.values())
            if (!r.getId().equals(exclude) && r.getX() == x && r.getY() == y) return true;
        return false;
    }

    // =========================================================================
    // pickup("containerId")
    // =========================================================================
    private boolean doPickup(String agName, Structure action) {
        try {
            String cid = unquote(action.getTerm(0).toString());
            Robot robot = robots.get(agName);
            Container c = containers.get(cid);
            if (robot == null || c == null || c.isPicked()) return false;
            if (robot.distanceTo(c.getX(), c.getY()) > 2) { emitError(agName,"too_far",cid); return false; }
            if (!robot.canCarry(c)) {
                emitError(agName, c.getWeight() > robot.getMaxWeight()
                    ? "container_too_heavy" : "container_too_big", cid);
                return false;
            }
            if (!robot.pickup(c)) return false;
            c.setPicked(true);
            log("📦 " + agName + " recogió " + cid);
            if (view != null) view.update();
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // drop_at("shelfId")
    // =========================================================================
    private boolean doDropAt(String agName, Structure action) {
        try {
            String shelfId = unquote(action.getTerm(0).toString());
            Robot robot = robots.get(agName);
            Shelf shelf = shelves.get(shelfId);
            if (robot == null || shelf == null || !robot.isCarrying()) return false;
            if (robot.distanceTo(shelf.getX(), shelf.getY()) > 2) return false;
            Container c = robot.getCarriedContainer();
            if (!shelf.canStore(c)) { emitError(agName,"shelf_full",shelfId); return false; }
            shelf.store(c);
            robot.drop();
            c.setAssignedShelf(shelfId);
            totalContainersProcessed++;
            log("✅ " + agName + " almacenó " + c.getId() + " en " + shelfId);
            if (view != null) view.update();
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // drop_at_exit
    // =========================================================================
    private boolean doDropAtExit(String agName) {
        try {
            Robot robot = robots.get(agName);
            if (robot == null || !robot.isCarrying()) return false;
            int rx = robot.getX(), ry = robot.getY();
            if (rx < EXIT_X_MIN || rx > EXIT_X_MAX || ry < EXIT_Y_MIN || ry > EXIT_Y_MAX) return false;
            Container c = robot.getCarriedContainer();
            robot.drop();
            c.setAssignedShelf("exit_zone");
            totalContainersProcessed++;
            log("🚚 " + agName + " entregó " + c.getId() + " a zona de salida");
            if (view != null) view.update();
            addPercept("supervisor",
                Literal.parseLiteral("container_delivered(\"" + c.getId() + "\",\"" + agName + "\")"));
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // query_location("entityId")
    // Devuelve: location("id", X, Y)
    // =========================================================================
    private boolean doQueryLocation(String agName, Structure action) {
        try {
            String eid = unquote(action.getTerm(0).toString());
            if (robots.containsKey(eid)) {
                Robot r = robots.get(eid);
                addPercept(agName, Literal.parseLiteral(
                    "location(\""+eid+"\","+r.getX()+","+r.getY()+")"));
                return true;
            }
            if (shelves.containsKey(eid)) {
                Shelf s = shelves.get(eid);
                addPercept(agName, Literal.parseLiteral(
                    "location(\""+eid+"\","+s.getX()+","+s.getY()+")"));
                return true;
            }
            if (containers.containsKey(eid)) {
                Container c = containers.get(eid);
                addPercept(agName, Literal.parseLiteral(
                    "location(\""+eid+"\","+c.getX()+","+c.getY()+")"));
                return true;
            }
            return false;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // query_shelf_info("shelfId")
    // Devuelve: shelf_info("id", X, Y, MaxWeight, MaxVol, CurWeight, CurVol)
    // =========================================================================
    private boolean doQueryShelfInfo(String agName, Structure action) {
        try {
            String sid = unquote(action.getTerm(0).toString());
            Shelf s = shelves.get(sid);
            if (s == null) return false;
            addPercept(agName, Literal.parseLiteral(
                "shelf_info(\""+sid+"\","+s.getX()+","+s.getY()+","
                +s.getMaxWeight()+","+s.getMaxVolume()+","
                +s.getCurrentWeight()+","+s.getCurrentVolume()+")"));
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // query_container_info("containerId")
    // Devuelve: container_info("id", W, H, Weight, "type", X, Y, "status")
    // =========================================================================
    private boolean doQueryContainerInfo(String agName, Structure action) {
        try {
            String cid = unquote(action.getTerm(0).toString());
            Container c = containers.get(cid);
            if (c == null) return false;
            String status = c.isPicked() ? "picked"
                          : c.getAssignedShelf() != null ? "stored" : "pending";
            addPercept(agName, Literal.parseLiteral(
                "container_info(\""+cid+"\","+c.getWidth()+","+c.getHeight()+","
                +String.format(Locale.US,"%.2f",c.getWeight())+",\""
                +c.getType()+"\","+c.getX()+","+c.getY()+",\""+status+"\")"));
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // query_containers_at_entrance
    // Devuelve: container_at_entrance("id", X, Y, "type") por cada pendiente
    // =========================================================================
    private boolean doQueryContainersAtEntrance(String agName) {
        try {
            removePerceptsByUnif(agName,
                Literal.parseLiteral("container_at_entrance(_,_,_,_)"));
            containers.values().stream()
                .filter(c -> !c.isPicked() && c.getAssignedShelf() == null
                          && c.getX() >= ENTRANCE_X_MIN && c.getX() <= ENTRANCE_X_MAX)
                .forEach(c -> addPercept(agName, Literal.parseLiteral(
                    "container_at_entrance(\""+c.getId()+"\","
                    +c.getX()+","+c.getY()+",\""+c.getType()+"\")")));
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // query_containers_stored("type"|"any")
    // Devuelve: container_stored("id", "shelfId", "type") por cada almacenado
    // =========================================================================
    private boolean doQueryContainersStored(String agName, Structure action) {
        try {
            String ft = unquote(action.getTerm(0).toString());
            removePerceptsByUnif(agName, Literal.parseLiteral("container_stored(_,_,_)"));
            containers.values().stream()
                .filter(c -> c.getAssignedShelf() != null
                          && !c.getAssignedShelf().equals("exit_zone")
                          && (ft.equals("any") || c.getType().equals(ft)))
                .forEach(c -> addPercept(agName, Literal.parseLiteral(
                    "container_stored(\""+c.getId()+"\",\""
                    +c.getAssignedShelf()+"\",\""+c.getType()+"\")")));
            return true;
        } catch (Exception e) { return false; }
    }

    // =========================================================================
    // Helpers
    // =========================================================================
    private void emitError(String agName, String type, String data) {
        totalErrors++;
        addPercept(agName, Literal.parseLiteral("error("+type+",\""+data+"\")"));
        System.err.println("ERROR ["+agName+"]: "+type+" - "+data);
    }

    private void log(String msg) {
        if (view != null) view.logMessage(msg); else System.out.println(msg);
    }

    private String unquote(String s) { return s.replace("\"",""); }

    // =========================================================================
    // Getters para WarehouseView
    // =========================================================================
    public CellType[][]           getGrid()       { return grid; }
    public Map<String,Robot>      getRobots()     { return robots; }
    public Map<String,Container>  getContainers() { return containers; }
    public Map<String,Shelf>      getShelves()    { return shelves; }
    public int getPendingContainersCount() {
        return (int) containers.values().stream()
            .filter(c -> !c.isPicked() && c.getAssignedShelf() == null).count();
    }
    public int getTotalContainersProcessed() { return totalContainersProcessed; }
    public int getTotalErrors()              { return totalErrors; }
    public String getStatistics() {
        long e = (System.currentTimeMillis() - startTime) / 1000;
        return String.format("Time: %ds | Processed: %d | Pending: %d | Errors: %d",
            e, totalContainersProcessed, getPendingContainersCount(), totalErrors);
    }
}