package warehouse;

/**
 * Tipos de celdas en el almacén
 */
public enum CellType {
    EMPTY,          // Pasillo vacío
    EXIT,           // Zona de salida de contenedores
    ENTRANCE,       // Zona de entrada de contenedores
    CLASSIFICATION, // Zona de clasificación
    STORAGE,        // Área de almacenamiento
    SHELF,          // Estantería
    BLOCKED,        // Celda bloqueada
    ROBOT           // Posición de un robot
}
