model InfeccionRedesGIS

global {

// =====================================================
// ARCHIVOS SHAPE
// =====================================================
	file nodos_file <- file("../includes/nodos.shp");
	file conexiones_file <- file("../includes/conexiones.shp");
	file salas_file <- file("../includes/sala.shp");
	geometry shape <- envelope(salas_file);
	// =====================================================
	// PARÁMETROS
	// =====================================================
	float probabilidad_infeccion <- 0.45;
	float probabilidad_scan <- 0.35;
	int cooldown_min <- 3;
	int cooldown_max <- 8;

	// =====================================================
	// INIT
	// =====================================================
	init {
		write "===================================";
		write "CARGANDO SHAPEFILES...";
		write "===================================";

		// =====================================================
		// CREAR SALAS
		// =====================================================
		create sala from: salas_file {
			nombre <- string(read("nombre"));
		}

		write "Salas cargadas: " + length(sala);

		// =====================================================
		// CREAR COMPUTADORAS
		// =====================================================
		create computer from: nodos_file {

		// -------------------------------------------------
		// ATRIBUTOS DESDE SHP
		// -------------------------------------------------
			id <- int(read("id"));
			nombre <- string(read("nombre"));
			string tipoNodo <- string(read("tipo"));

			// -------------------------------------------------
			// UBICACIÓN
			// -------------------------------------------------
location <- shape.location;
			// -------------------------------------------------
			// TIPO DE NODO
			// -------------------------------------------------
			is_server <- (tipoNodo = "server");

			// -------------------------------------------------
			// CONFIGURACIÓN INICIAL
			// -------------------------------------------------
			infected <- false;
			patch_level <- rnd(100);
			open_ports <- [445, 3389, 80];
			failed_attempts <- 0;
			secured <- false;
			isolated <- false;
		}

		write "Computadoras cargadas: " + length(computer);

		// =====================================================
		// INFECTAR SERVIDOR INICIAL
		// =====================================================
		ask first(computer where each.is_server) {
			infected <- true;
			write "Servidor infectado inicialmente";
		}

		// =====================================================
		// CREAR CONEXIONES
		// =====================================================
		create connection from: conexiones_file {
			int origen_id <- int(read("origen"));
			int destino_id <- int(read("destino"));
			source <- one_of(computer where (each.id = origen_id));
			target <- one_of(computer where (each.id = destino_id));
		}

		write "Conexiones cargadas: " + length(connection);
		write "===================================";
		write "SIMULACIÓN INICIALIZADA";
		write "===================================";
	}

	// =====================================================
	// MONITOR GLOBAL
	// =====================================================
	reflex monitor {
		int infectados <- length(computer where each.infected);
		int sanos <- length(computer where (!each.infected and !each.secured));
		int asegurados <- length(computer where each.secured);
		write "Infectados: " + infectados + " | Sanos: " + sanos + " | Asegurados: " + asegurados;
		if sanos = 0 {
			write "=== SIMULACIÓN COMPLETADA ===";
			do pause;
		}

	}

}

// =====================================================
// SALAS
// =====================================================
species sala {
	string nombre;

	aspect default {
		draw shape color: rgb(220, 220, 220) border: #black;
		draw string(nombre) at: location color: #black;
	}

}

// =====================================================
// COMPUTADORAS
// =====================================================
species computer {

// =====================================================
// VARIABLES
// =====================================================
	int id;
	string nombre;
	bool is_server <- false;
	int patch_level <- 0;
	bool infected <- false;
	bool isolated <- false;
	bool scanned <- false;
	string scanned_port <- "";
	float cpu_usage <- rnd(100) / 100.0;
	int cooldown <- 0;
	int scan_timer <- 0;
	int failed_attempts <- 0;
	bool secured <- false;
	list<int> open_ports <- [];

	// =====================================================
	// ACTIVIDAD
	// =====================================================
	reflex activity {
		cpu_usage <- rnd(100) / 100.0;
		if scan_timer > 0 {
			scan_timer <- scan_timer - 1;
		} else {
			scanned <- false;
		}

	}

	// =====================================================
	// PROPAGACIÓN
	// =====================================================
	reflex spread when: infected and !isolated {
		if cooldown > 0 {
			cooldown <- cooldown - 1;
			return;
		}

		if flip(probabilidad_scan) {
			list<connection> conexiones <- connection where (each.source = self);
			if length(conexiones) > 0 {
				list<computer> objetivos_disponibles <- (conexiones collect each.target) where (!each.secured and !each.isolated and !each.infected);
				if length(objetivos_disponibles) > 0 {
					computer objetivo <- first(objetivos_disponibles sort_by each.failed_attempts);
					objetivo.failed_attempts <- objetivo.failed_attempts + 1;
					objetivo.scanned <- true;
					objetivo.scan_timer <- 8;
					bool vulnerable <- false;

					// =================================================
					// DETECCIÓN DE VULNERABILIDAD
					// =================================================
					if 445 in objetivo.open_ports {
						vulnerable <- true;
						objetivo.scanned_port <- "445";
					} else if 3389 in objetivo.open_ports {
						vulnerable <- true;
						objetivo.scanned_port <- "3389";
					} else {
						objetivo.scanned_port <- "SAFE";
					}

					// =================================================
					// INFECCIÓN
					// =================================================
					if vulnerable and !objetivo.infected {
						float probabilidad <- (1.0 - (objetivo.patch_level / 150.0)) * probabilidad_infeccion;
						if flip(probabilidad) {
							objetivo.infected <- true;
							objetivo.cooldown <- 0;
							objetivo.failed_attempts <- 0;
							objetivo.secured <- false;
							write "*** NODO INFECTADO: " + objetivo.nombre;
						}

					}

					// =================================================
					// ASEGURAR NODO
					// =================================================
					if objetivo.failed_attempts >= 5 {
						objetivo.secured <- true;
						write "Nodo asegurado: " + objetivo.nombre;
					}

				}

			}

			// =====================================================
			// COOLDOWN
			// =====================================================
			cooldown <- rnd(cooldown_max - cooldown_min) + cooldown_min;
		}

	}

	// =====================================================
	// VISUALIZACIÓN
	// =====================================================
	aspect default {

	// =====================================================
	// SERVIDOR
	// =====================================================
		if is_server {
			draw square(5000) color: #purple border: #white;
		} else if isolated {
			draw circle(5000) color: #blue border: #white;
		} else if infected {
			draw circle(5000) color: #red border: #white;
		} else if scanned {
			draw circle(5000) color: #orange border: #black;
		} else if secured {
			draw circle(5000) color: #darkblue border: #white;
		} else {
			draw circle(5000) color: #green border: #white;
		}

		// =====================================================
		// NOMBRE
		// =====================================================
		draw string(nombre) at: location + {-5, 8} color: #black;


 } }

		// =====================================================
// CONEXIONES
// =====================================================
species connection {
	computer source;
	computer target;

	aspect default {
		draw line([
	source.location,
	target.location
])

color: #black
width: 2;
	}

}

// =====================================================
// EXPERIMENTO
// =====================================================
experiment LAN type: gui {
	parameter "Probabilidad escaneo" var: probabilidad_scan min: 0.0 max: 1.0 category: "Virus";
	parameter "Probabilidad infección" var: probabilidad_infeccion min: 0.0 max: 1.0 category: "Virus";
	parameter "Cooldown mínimo" var: cooldown_min min: 1 max: 20 category: "Virus";
	parameter "Cooldown máximo" var: cooldown_max min: 1 max: 30 category: "Virus";
	output {
		display network_display {
			species sala;
			species connection;
			species computer;
		}

		monitor "Infectados" value: length(computer where each.infected);
		monitor "Sanos" value: length(computer where (!each.infected and !each.secured));
		monitor "Asegurados" value: length(computer where each.secured);
		monitor "Total nodos" value: length(computer);
	}

}