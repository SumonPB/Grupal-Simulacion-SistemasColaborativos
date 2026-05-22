model InfeccionRedes

global {

	// =====================================================
	// PARÁMETROS CONFIGURABLES
	// =====================================================

	int num_aulas <- 3;

	int nodos_por_aula <- 15;

	float global_speed <- 0.5;

	float probabilidad_infeccion <- 0.45;

	float probabilidad_scan <- 0.35;

	int conexiones_locales <- 2;

	int patch_min <- 0;

	int patch_max <- 100;

	int cooldown_min <- 3;

	int cooldown_max <- 8;

	float distancia_conexion <- 40.0;

	// =====================================================
	// INICIALIZACIÓN
	// =====================================================

	init {

		// =====================================================
		// CREAR SERVIDOR CENTRAL
		// =====================================================

		create computer number: 1 {

			is_server <- true;

			location <- {150,150};

			open_ports <- [445,3389,80];

			patch_level <- 20;

			infected <- true;
		}

		computer servidor <- first(computer);

		// =====================================================
		// CREAR AULAS
		// =====================================================

		loop aula from: 0 to: num_aulas - 1 {

			float base_x <- 60 + (aula * 120);

			float base_y <- 40;

			create computer number: nodos_por_aula {

				is_server <- false;

				int idx <- index;

				float offset_x <- (idx mod 5) * 15;

				float offset_y <- int(idx / 5) * 15;

				location <- {
					base_x + offset_x,
					base_y + offset_y
				};

				// =====================================================
				// PATCH ALEATORIO
				// =====================================================

				patch_level <- rnd(
					patch_max - patch_min
				) + patch_min;

				// =====================================================
				// PUERTOS ABIERTOS
				// =====================================================

				list<int> all_ports <- shuffle([
					22,
					80,
					443,
					445,
					3389
				]);

				int n_ports <- rnd(3) + 1;

				open_ports <- [];

				loop i from: 0 to: min(
					n_ports - 1,
					length(all_ports) - 1
				) {

					add all_ports[i] to: open_ports;
				}
			}
		}

		// =====================================================
		// CONEXIONES
		// =====================================================

		ask computer where (!each.is_server) {

			// =====================================================
			// CONEXIÓN AL SERVIDOR
			// =====================================================

			create connection {

				source <- servidor;

				target <- myself;
			}

			// =====================================================
			// CONEXIONES LOCALES
			// =====================================================

			list<computer> vecinos <- computer where (

				each != self and
				!each.is_server and

				(each.location distance_to self.location)
					< distancia_conexion
			);

			vecinos <- shuffle(vecinos);

			int conexiones_actuales <- min(
				conexiones_locales,
				length(vecinos)
			);

			loop i from: 0 to: conexiones_actuales - 1 {

				create connection {

					source <- self;

					target <- vecinos[i];
				}
			}
		}

		write "===================================";
		write "RED INICIALIZADA";
		write "Servidor infectado inicialmente";
		write "Aulas: " + num_aulas;
		write "Nodos por aula: " + nodos_por_aula;
		write "===================================";
	}

	// =====================================================
	// MONITOR GLOBAL
	// =====================================================

	reflex monitor {

		int infectados <- length(
			computer where each.infected
		);

		int sanos <- length(
			computer where (
				!each.infected and !each.secured
			)
		);

		int asegurados <- length(
			computer where each.secured
		);

		write "Infectados: "
			+ infectados
			+ " | Sanos: "
			+ sanos
			+ " | Asegurados: "
			+ asegurados;

		if sanos = 0 {

			write "=== SIMULACIÓN COMPLETADA ===";

			do pause;
		}
	}
}

species computer {

	// =====================================================
	// VARIABLES
	// =====================================================

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

			list<connection> conexiones <- connection where (
				each.source = self
			);

			if length(conexiones) > 0 {

				list<computer> objetivos_disponibles <- (

					conexiones collect each.target

				) where (

					!each.secured and
					!each.isolated and
					!each.infected
				);

				if length(objetivos_disponibles) > 0 {

					computer objetivo <- first(

						objetivos_disponibles
							sort_by each.failed_attempts
					);

					objetivo.failed_attempts <-
						objetivo.failed_attempts + 1;

					objetivo.scanned <- true;

					objetivo.scan_timer <- 8;

					bool vulnerable <- false;

					// =====================================================
					// DETECCIÓN DE VULNERABILIDAD
					// =====================================================

					if 445 in objetivo.open_ports {

						vulnerable <- true;

						objetivo.scanned_port <- "445";

					} else if 3389 in objetivo.open_ports {

						vulnerable <- true;

						objetivo.scanned_port <- "3389";

					} else {

						objetivo.scanned_port <- "SAFE";
					}

					// =====================================================
					// INFECCIÓN
					// =====================================================

					if vulnerable and !objetivo.infected {

						float probabilidad <- (

							1.0 -
							(objetivo.patch_level / 150.0)

						) * probabilidad_infeccion;

						if flip(probabilidad) {

							objetivo.infected <- true;

							objetivo.cooldown <- 0;

							objetivo.failed_attempts <- 0;

							objetivo.secured <- false;

							write "*** NODO INFECTADO ***";
						}
					}

					// =====================================================
					// ASEGURAR NODO
					// =====================================================

					if objetivo.failed_attempts >= 5 {

						objetivo.secured <- true;

						write "Nodo asegurado";
					}
				}
			}

			// =====================================================
			// COOLDOWN
			// =====================================================

			cooldown <- rnd(
				cooldown_max - cooldown_min
			) + cooldown_min;
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

			draw square(10)
				color: #purple
				border: #white;

		} else if isolated {

			draw circle(5)
				color: #blue
				border: #white;

		} else if infected {

			draw circle(5)
				color: #red
				border: #white;

		} else if scanned {

			draw circle(5)
				color: #orange
				border: #black;

		} else if secured {

			draw circle(5)
				color: #darkblue
				border: #white;

		} else {

			draw circle(5)
				color: #green
				border: #white;
		}

		// =====================================================
		// PATCH LEVEL
		// =====================================================

		draw string(patch_level)

			at: location + {-2,-2}

			color: #black;

		// =====================================================
		// PUERTO ESCANEADO
		// =====================================================

		if scanned {

			draw string(scanned_port)

				at: location + {0,8}

				color: #black;
		}

		// =====================================================
		// ETIQUETA WORM
		// =====================================================

		if infected {

			draw string("WORM")

				at: location + {-2,10}

				color: #red;
		}

		// =====================================================
		// ETIQUETA SERVIDOR
		// =====================================================

		if is_server {

			draw string("SERVER")

				at: location + {-5,12}

				color: #white;
		}
	}
}

species connection {

	computer source;

	computer target;

	aspect default {

		draw line([
			source.location,
			target.location
		])

		color: rgb(150,150,150,80);
	}
}

experiment LAN type: gui {

	// =====================================================
	// PARÁMETROS EN INTERFAZ
	// =====================================================

	parameter "Número de aulas"

		var: num_aulas

		min: 1

		max: 10

		category: "Topología";

	parameter "Nodos por aula"

		var: nodos_por_aula

		min: 1

		max: 50

		category: "Topología";

	parameter "Velocidad global"

		var: global_speed

		min: 0.1

		max: 2.0

		category: "Simulación";

	parameter "Probabilidad escaneo"

		var: probabilidad_scan

		min: 0.0

		max: 1.0

		category: "Virus";

	parameter "Probabilidad infección"

		var: probabilidad_infeccion

		min: 0.0

		max: 1.0

		category: "Virus";

	parameter "Conexiones locales"

		var: conexiones_locales

		min: 0

		max: 10

		category: "Red";

	parameter "Patch mínimo"

		var: patch_min

		min: 0

		max: 100

		category: "Seguridad";

	parameter "Patch máximo"

		var: patch_max

		min: 0

		max: 100

		category: "Seguridad";

	parameter "Cooldown mínimo"

		var: cooldown_min

		min: 1

		max: 20

		category: "Virus";

	parameter "Cooldown máximo"

		var: cooldown_max

		min: 1

		max: 30

		category: "Virus";

	parameter "Distancia conexión"

		var: distancia_conexion

		min: 10

		max: 100

		category: "Red";

	// =====================================================
	// OUTPUTS
	// =====================================================

	output {

		display network_display {

			species connection;

			species computer;
		}

		monitor "Infectados"

			value: length(
				computer where each.infected
			);

		monitor "Sanos"

			value: length(
				computer where (
					!each.infected and
					!each.secured
				)
			);

		monitor "Asegurados"

			value: length(
				computer where each.secured
			);

		monitor "Total nodos"

			value: length(computer);
	}
}