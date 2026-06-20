# Grupal-Simulacion-SistemasColaborativos
Trabajo Grupal de la catedra Sistemas Colaborativos

## Integrantes
- Trujillo Vistin Dennis Adrian
- Loya Cadena Bryan Eduardo
- Condolo Narvaez Byron Paul

## Descripción del proyecto

Simulación basada en agentes con arquitectura **BDI (Belief-Desire-Intention)** que modela la propagación de un ransomware tipo **WannaCry** dentro de una red LAN universitaria. El proyecto combina dos componentes que se comunican a través de archivos CSV:

- **Motor de simulación** en GAMA Platform (GAML), donde cada equipo de la red es un agente que percibe su entorno, delibera y actúa según el modelo BDI.
- **Dashboard de monitoreo en tiempo real** en Vue 3, que visualiza la topología de red, el estado de cada nodo y métricas de propagación mientras la simulación corre.

## Estructura del monorepo

```
Grupal-Simulacion-SistemasColaborativos/
├── Simulacion/                    ← Código fuente del proyecto en GAMA
│   ├── includes/                  ← Shapefiles de la red (.shp)
│   │   ├── nodos.shp              ← Nodos: id, nombre, tipo
│   │   ├── conexiones.shp         ← Enlaces: origen, destino
│   │   └── sala.shp               ← Polígonos de laboratorios
│   ├── models/
│   │   └── InfeccionRedes.gaml    ← Modelo principal (BDI)
│   └── front/                     ← Dashboard de monitoreo (Vue 3)
│       ├── public/
│       │   └── results/           ← CSVs generados por GAMA (se crean al correr)
│       ├── src/
│       │   ├── App.vue
│       │   ├── main.js
│       │   └── style.css
│       ├── index.html
│       ├── package.json
│       └── vite.config.js
├── Documentacion/                 ← Documentación del proyecto en LaTeX
└── README.md
```

## Requisitos previos

| Herramienta | Versión mínima | Uso |
|---|---|---|
| [GAMA Platform](https://gama-platform.org/download) | 1.9.0 | Motor de simulación (GAML) |
| [Node.js](https://nodejs.org/) | 18.x | Entorno para el dashboard Vue |
| npm | 9.x | Gestión de dependencias del dashboard |
| [QGIS](https://qgis.org/download/) | — | **Opcional.** Solo necesario si quieres crear o modificar tu propia red (shapefiles). Con los `.shp` incluidos en `Simulacion/includes/` el proyecto funciona sin instalar QGIS. |

## Despliegue y ejecución

### 1. Clonar el repositorio

```bash
git clone <url-del-repo>
cd Grupal-Simulacion-SistemasColaborativos
```

### 2. Preparar la carpeta de resultados

El modelo GAML escribe los archivos CSV directamente en `Simulacion/front/public/results/`, para que Vite pueda servirlos como estáticos sin configuración adicional. Crea la carpeta antes de la primera ejecución:

```bash
mkdir -p Simulacion/front/public/results
```

### 3. Correr la simulación en GAMA

1. Abre **GAMA Platform**.
2. Importa el proyecto apuntando a la carpeta `Simulacion/`.
3. Abre `models/InfeccionRedes.gaml`.
4. Ejecuta el experimento **`Infeccion`**.
5. Desde el panel de parámetros puedes ajustar:

   | Parámetro | Rango | Efecto |
   |---|---|---|
   | Nivel de Contención (%) | 0–100 | Probabilidad de que la red aísle nodos infectados. |
   | Fuerza Firewall (0–1) | 0.0–1.0 | Reducción de probabilidad de infección al atravesar el firewall. |
   | Nivel de Parche Inicial (%) | 0–100 | Patch level inicial de todos los equipos (vulnerabilidad a SMB/445). |

Al iniciar, GAMA genera automáticamente 4 archivos en `Simulacion/front/public/results/`:

- `log_general.csv` — conteo total de nodos, salas, PCs, switches y firewalls.
- `log_nodos.csv` — listado de nodos con su tipo.
- `log_topologia.csv` — conexiones entre nodos.
- `log_eventos.csv` — eventos de la simulación en tiempo real (infecciones, parcheos, aislamientos).

### 4. Levantar el dashboard

En una terminal aparte, sin cerrar GAMA:

```bash
cd Simulacion/front
npm install
npm run dev
```

Abre el navegador en la URL que indique Vite (por defecto `http://localhost:5173`). El dashboard hace polling cada 2 segundos sobre `log_eventos.csv`, así que empieza a poblarse automáticamente mientras GAMA sigue corriendo.

### 5. Build de producción (opcional)

Si necesitas generar una versión estática del dashboard:

```bash
cd Simulacion/front
npm run build
npm run preview   # sirve el build en un puerto local para verificarlo
```

## Escenarios de prueba sugeridos

Estos escenarios permiten contrastar distintas condiciones de seguridad de red ajustando los 3 parámetros del experimento:

| Escenario | Descripción | Fuerza Firewall | Parche Inicial | Contención |
|---|---|---|---|---|
| **E1 — Real 2017** | Red sin preparación, replica el ataque original | 0.1 | 5 | 5 |
| **E2 — Solo firewall** | Firewall fuerte pero equipos sin actualizar | 0.9 | 5 | 10 |
| **E3 — Solo parches** | Equipos parcheados, sin firewall efectivo | 0.1 | 80 | 20 |
| **E4 — SOC activo** | Equipo de seguridad con contención rápida | 0.5 | 30 | 80 |
| **E5 — Red segura** | Todas las defensas configuradas al máximo | 1.0 | 100 | 90 |

Para cada escenario, observar en el dashboard: ciclo de la primera infección, ciclo de la alerta crítica (80% de la red comprometida), porcentaje final de nodos infectados, y cantidad de nodos que lograron parchearse antes de ser comprometidos.

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| El dashboard no muestra nodos | La carpeta `results/` no existe o GAMA aún no escribió los CSV | Verifica que `Simulacion/front/public/results/` exista y que la simulación haya iniciado al menos un ciclo. |
| Las conexiones del grafo no se resaltan | CSV con formato inesperado (encabezado duplicado) | Recarga el navegador después de que GAMA haya generado los CSV completos. |
| `npm install` falla | Versión de Node.js incompatible | Verifica `node -v` ≥ 18. |

## Licencia

Este proyecto esta bajo licencia MIT.
