---
marp: true
title: Warehouse Management System - Presentación
theme: default
paginate: true
backgroundColor: '#f9fcffff'
color: '#140b3dff'
---

# Sistema Multiagente para Gestión de Almacén

**Universidad de Vigo - Sistemas Inteligentes**  
**Curso 2025-2026**

**Plataforma:** Jason/JaCaMo 3.3.0  
**Lenguaje:** AgentSpeak + Java

---

## ¿Qué vais a implementar?

Un **sistema multiagente inteligente** que coordina robots autónomos en un almacén automatizado.

**Tareas principales:**
- Coordinar 3 tipos de robots con diferentes capacidades
- Gestionar contenedores de distintos tamaños y pesos
- Optimizar almacenamiento en estanterías
- Manejar errores y situaciones excepcionales
- Monitorizar el sistema en tiempo real

---

## Los 3 Robots

| Robot | Capacidad | Tamaño Max | Velocidad | Color GUI |
|-------|-----------|------------|-----------|-----------|
| **Light** | 10 kg | 1×1 | Alta (3) | 🟢 Verde |
| **Medium** | 30 kg | 1×2 | Media (2) | 🔵 Azul |
| **Heavy** | 100 kg | 2×3 | Baja (1) | 🟣 Magenta |

**Objetivo:** Asignar el robot adecuado según el contenedor.

---

## Contenedores

**Generación automática** cada 5-10 segundos

**Características:**
- **Tamaños:** 1×1, 1×2, 2×2, 2×3
- **Pesos:** 5 a 100 kg
- **Tipos:**
  - 🔵 Standard (70%) - Normal
  - 🔴 Fragile (15%) - Requiere cuidado especial
  - 🟠 Urgent (15%) - Alta prioridad

---

## El entorno: almacén con grid 20×15

**Zonas funcionales:**

| Zona | Color | Ubicación | Función |
|------|-------|-----------|---------|
| 🟢 **Entrada** | Verde claro | (0-2, 0-1) | Recepción |
| 🟡 **Clasificación** | Amarillo | (3-6, 0-1) | Procesamiento |
| ⬜ **Navegación** | Blanco/Gris | Resto | Tránsito |
| 🟢 **Estanterías** | Verde oscuro | Distribuidas | Almacenamiento |

---

## Los agentes

### Robots (3 agentes)
- `robot_light.asl` - Robot ligero
- `robot_medium.asl` - Robot medio  
- `robot_heavy.asl` - Robot pesado

### Coordinadores (2 agentes)
- `scheduler.asl` - **Asigna tareas** a robots
- `supervisor.asl` - **Monitoriza** y gestiona errores

---

## Flujo de Trabajo

```
1. Contenedor aparece en zona de entrada
   ↓
2. Scheduler lo clasifica (peso, tamaño, tipo)
   ↓
3. Scheduler asigna robot apropiado
   ↓
4. Robot recibe tarea (contenedor → estantería)
   ↓
5. Robot ejecuta: mover → recoger → mover → depositar
   ↓
6. Robot solicita nueva tarea
   ↓
7. Supervisor monitoriza todo el proceso
```

---

## 🛠️ Acciones externas del Entorno

```asl
// Movimiento
move_to(X, Y)                  // Mover a posición

// Manipulación
pickup(ContainerId)            // Recoger contenedor
drop_at(ShelfId)               // Depositar en estantería

// Información
request_task()                 // Pedir nueva tarea
get_container_info(CId)        // Info del contenedor
get_free_shelf(CId)            // Buscar estantería disponible
scan_surroundings()            // Explorar alrededor
```

---

## Percepciones del Entorno

```asl
+robot_at(X,Y)                      // Mi posición actualizada
+task(ContainerId, ShelfId)         // Nueva tarea asignada
+picked(ContainerId)                // Contenedor recogido
+stored(ContainerId, ShelfId)       // Almacenamiento exitoso

+new_container(ContainerId)         // Nuevo contenedor generado
+container_info(CId,W,H,Weight,Type) // Detalles del contenedor

+error(Type, Data)                  // Error detectado
+blocked(X,Y)                       // Ruta bloqueada
```

---

## Gestión de Errores

```asl
+error(container_too_heavy, Data)  // Robot muy ligero
+error(container_too_big, Data)    // Robot muy pequeño
+error(shelf_full, Data)           // Sin espacio
+error(illegal_move, Data)         // Fuera de límites
+error(conflict, Data)             // Colisión entre robots
+error(route_blocked, Data)        // Camino obstruido
```

**Importante:** los agentes deben manejar al menos estos errores.

---

## GUI en Tiempo Real

**3 Áreas principales:**

1. **Centro:** Grid del almacén con robots, contenedores y estanterías
2. **Derecha:** Panel de información
   - Estadísticas (tiempo, procesados, errores)
   - Estado de cada robot
   - Ocupación de estanterías
3. **Inferior:** Consola de actividad con timestamps

---

## Estructura de Archivos

```
warehouse/
├── warehouse.mas2j              # Configuración del MAS
├── src/
│   ├── agt/                     # Agentes Jason
│   │   ├── robot_light.asl
│   │   ├── robot_medium.asl
│   │   ├── robot_heavy.asl
│   │   ├── scheduler.asl
│   │   └── supervisor.asl
│   └── env/warehouse/           # Entorno proporcionado
│       └── ... (Java files)
└── docs/                        # Documentación
```

---

## Cómo Ejecutar

```bash
# Navegar al proyecto
cd warehouse

# Ejecutar (abrirá GUI automáticamente)
jason warehouse.mas2j
```

**Requisitos:**
- Java 21+
- Jason 3.3.0


---

##  Vuestros Objetivos

### Funcionalidad Básica
- Robots reciben y ejecutan tareas
- Scheduler asigna según capacidades
- Todos los contenedores se almacenan
- Gestión básica de errores

---

##  Vuestros Objetivos
### Funcionalidad Avanzada
- Planificación de rutas inteligentes
- Evitar colisiones entre robots
- Priorización por tipo de contenedor
- Optimización de estanterías
- Métricas de eficiencia

---

## Recursos Disponibles

**Documentación del proyecto:**
- `README_ES.md` / `README_EN.md` - Guía completa del proyecto
- `QUICKSTART_ES.md` / `QUICKSTART_EN.md` - Inicio rápido
- `DEBUGGING_ES.md` / `DEBUGGING_EN.md` - Solución de problemas comunes
- `PROJECT_SUMMARY_ES.md` / `PROJECT_SUMMARY_EN.md` - Resumen del estado del proyecto

**Recursos externos:**
- [Libro Jason](https://jason-lang.github.io/book/) (Moovi)
- [Documentación oficial Jason](https://jason-lang.github.io)
- [GitHub Jason](https://github.com/jason-lang/jason)

---

## Consejos Prácticos

### Durante el desarrollo:
- Usar `.print()` extensivamente para debug
- Probar después de cada cambio
- Comentar la lógica compleja
- Empezar simple, luego optimizar

### Algunos errores comunes :
- No verificar capacidad antes de asignar
- No actualizar estado del robot
- No manejar caso sin robots disponibles
- Olvidar petición de nueva tarea

---

## Criterios de Evaluación

| Aspecto | Clave |
|---------|-------|
| **Funcionalidad** |  Sistema operativo completo |
| **Diseño Multiagente** | Buena arquitectura |
| **Representación Conocimiento** | Creencias y planes |
| **Gestión Errores** | Robustez |
| **Eficiencia** |  Optimización |
| **Código y Docs** |  Limpio y documentado |

---

## Trabajo en Grupo

**Configuración:**
- Grupos de hasta **7 estudiantes**
- **Recomendado:** Git/GitHub para colaborar

**Distribución sugerida:**
- 3 personas → Robots (1 por tipo)
- 2 personas → Scheduler
- 1 persona → Supervisor
- 1 persona → Documentación y testing

---

## Entregables

1. **Código fuente** completo (`.asl` implementados)
2. **Memoria técnica** (PDF):
   - Diseño del sistema
   - Decisiones de implementación
   - Representación del conocimiento
   - Análisis de resultados
   - Conclusiones
3. **Defensa oral** (todos los miembros participan)

> :warning: **Formato entrega:** Un ZIP con todo el proyecto con la estructura esperada + memoria PDF en el directorio docs/

---

## **Recordad:**
- Empezad simple, luego optimizad
- Probad frecuentemente
- Trabajad en equipo
- Preguntad cuando tengáis dudas



---

# ¿Preguntas?

📧 ivan.luis@uvigo.es  
💬 Foros Moovi  
📚 Documentación en el proyecto

