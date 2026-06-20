model InfeccionRedesGIS_BDI

species sala {
	string nombre;

	aspect default {
		draw shape color: rgb(165, 75, 75, 100) border: #black;
	}

}

global {
	file nodos_file <- file("../includes/nodos.shp");
	file conexiones_file <- file("../includes/conexiones.shp");
	file salas_file <- file("../includes/sala.shp");
	geometry shape <- envelope(nodos_file); // Ajustado para evitar errores de límites (out of bounds)
	float firewall_strength <- 0.7;
	float containment_threshold <- 30.0;
	bool emergency_containment <- false;
	int cooldown_min <- 3;
	int cooldown_max <- 8;
	float initial_patch_level <- 10.0;

	// =======================================================
	// RUTAS DE ARCHIVOS PARA REGISTROS DE LOGS (.CSV)
	// =======================================================
	string log_general_path  <- "../front/public/results/log_general.csv";
    string log_eventos_path  <- "../front/public/results/log_eventos.csv";


	// -------------------------------------------------------
	// INIT: Carga de componentes e inicialización de logs
	// -------------------------------------------------------
	init {
		create sala from: salas_file {
			nombre <- string(read("nombre"));
		}

		create computer from: nodos_file {
			id <- int(read("id"));
			nombre <- string(read("nombre"));
			string tipoNodo <- string(read("tipo"));
			is_server <- tipoNodo = "server";
			is_internet <- tipoNodo = "internet";
			is_firewall <- tipoNodo = "firewall";
			is_switch <- tipoNodo = "switch";
			if is_internet {
				infected <- true;
			} else {
				infected <- false;
			}

			isolated <- false;
			patch_level <- int(initial_patch_level) + rnd(10);
			if tipoNodo = "pc" or is_server or is_switch or is_firewall {
				open_ports <- [445, 3389, 80];
			} else {
				open_ports <- [];
			}

			write "NODO CARGADO -> " + string(id) + " | " + nombre;
		}

		create connection from: conexiones_file {
			int o <- int(read("origen"));
			int d <- int(read("destino"));
			list<computer> so <- computer where (each.id = o);
			list<computer> de <- computer where (each.id = d);
			if !empty(so) and !empty(de) {
				source <- first(so);
				target <- first(de);
				write "CONEXION OK " + string(o) + " -> " + string(d);
			}

		}

		write "===== RESUMEN =====";
		write "Nodos: " + string(length(computer));
		write "Links: " + string(length(connection));

		// =======================================================
		// ESCRITURA LOG 1: DATA GENERAL (ESTÁTICO)
		// =======================================================
		string encabezado_gen <- "total_nodos,total_salas,total_pcs,total_switches,total_firewall";
		save encabezado_gen to: log_general_path rewrite: true;
		int t_nodos <- length(computer);
		int t_salas <- length(sala);
		int t_pcs <- length(computer where (not each.is_server and not each.is_internet and not each.is_firewall and not each.is_switch));
		int t_switches <- length(computer where each.is_switch);
		int t_firewalls <- length(computer where each.is_firewall);
		string datos_gen <- string(t_nodos) + "," + string(t_salas) + "," + string(t_pcs) + "," + string(t_switches) + "," + string(t_firewalls);
		save datos_gen to: log_general_path rewrite: false;

		// =======================================================
		// ESCRITURA LOG 3: NODOS (ESTÁTICO)
		// =======================================================
		string enc_nodos <- "id,nombre,tipo";
		save enc_nodos to: "../front/public/results/log_nodos.csv" rewrite: true;
		loop n over: computer {
			string tipo_nodo <- "pc";
			if n.is_internet {
				tipo_nodo <- "internet";
			} else if n.is_firewall {
				tipo_nodo <- "firewall";
			} else if n.is_switch {
				tipo_nodo <- "switch";
			} else if n.is_server {
				tipo_nodo <- "server";
			}

			string fila_nodo <- string(n.id) + "," + n.nombre + "," + tipo_nodo;
			save fila_nodo to: "../front/public/results/log_nodos.csv" rewrite: false;
		}

		// =======================================================
		// ESCRITURA LOG 4: TOPOLOGIA (ESTÁTICO)
		// =======================================================
// =======================================================
// ESCRITURA LOG TOPOLOGIA CON TIPOS
// =======================================================

string enc_topo <- "origen,destino,tipo_origen,tipo_destino";

save enc_topo 
to: "../front/public/results/log_topologia.csv" 
rewrite: true;


loop c over: connection {


    string tipo_source <- "pc";
    string tipo_target <- "pc";


    if c.source.is_internet {
        tipo_source <- "internet";
    } else if c.source.is_firewall {
        tipo_source <- "firewall";
    } else if c.source.is_switch {
        tipo_source <- "switch";
    } else if c.source.is_server {
        tipo_source <- "server";
    }



    if c.target.is_internet {
        tipo_target <- "internet";
    } else if c.target.is_firewall {
        tipo_target <- "firewall";
    } else if c.target.is_switch {
        tipo_target <- "switch";
    } else if c.target.is_server {
        tipo_target <- "server";
    }



    string fila_topo <- 
        c.source.nombre + "," +
        c.target.nombre + "," +
        tipo_source + "," +
        tipo_target;


    save fila_topo 
    to: "../front/public/results/log_topologia.csv" 
    rewrite: false;

}

		// =======================================================
		// INICIALIZACIÓN LOG 2: EVENTOS DE INFECCIÓN (DINÁMICO)
		// =======================================================
		string encabezado_evt <- "ciclo,nodo,evento,desde,probabilidad,patch_lv,infectados_total,intencion";
		save encabezado_evt to: log_eventos_path rewrite: true;
		write ">>> GENERACIÓN DE ARCHIVOS LOG CSV CONFIGURADA EN /results/ <<<";
		// =======================================================
		// INICIALIZACIÓN LOG 2: EVENTOS DE INFECCIÓN (DINÁMICO)
		// =======================================================
		string encabezado_evt <- "ciclo,nodo,evento,desde,probabilidad,patch_lv,infectados_total,intencion";
		save encabezado_evt to: log_eventos_path rewrite: true;
		write ">>> GENERACIÓN DE ARCHIVOS LOG CSV CONFIGURADA EN /results/ <<<";
	}

	// -------------------------------------------------------
	// GLOBAL BDI: coordinador de red
	// -------------------------------------------------------
	reflex BDI_global_perception {
		int total_nodos <- length(computer where !each.is_internet);
		int total_infectados <- length(computer where (each.infected and !each.is_internet));
		float tasa <- (total_nodos > 0) ? (float(total_infectados) / float(total_nodos) * 100.0) : 0.0;
		if tasa >= 80.0 and !emergency_containment {
			emergency_containment <- true;
			string fila_alerta <- string(cycle) + ",-,ALERTA_CRITICA,-,-,-," + string(length(computer where each.infected)) + ",-";
			save fila_alerta to: log_eventos_path rewrite: false;
			write "==============================";
			write " ALERTA CRITICA - BDI GLOBAL ";
			write " RED COMPROMETIDA AL " + string(int(tasa)) + "%";
			write " INTENCION: AISLAMIENTO TOTAL ";
			write "==============================";
			ask computer where !each.is_internet {
				isolated <- true;
				intention <- "isolated";
				write "*** AISLADO EMERGENCIA *** " + nombre;
				string fila_emergencia <- string(cycle) + "," + nombre + ",AISLADO_EMERGENCIA,-,-," + string(patch_level) + "," + string(length(computer where each.infected)) + ",isolated";
				save fila_emergencia to: log_eventos_path rewrite: false;
			}

		}

	}

	// -------------------------------------------------------
	// GLOBAL: contencion individual
	// -------------------------------------------------------
	reflex BDI_global_containment {
		list<computer> infectados_activos <- computer where (each.infected and !each.isolated and !each.is_internet and !each.detected);
		if !empty(infectados_activos) {
			computer victima <- one_of(infectados_activos);
			victima.detected <- true;
			if rnd(100) < containment_threshold {
				write "==============================";
				write "*** CONTENCION ACTIVADA ***";
				write "AMENAZA DETECTADA EN: " + victima.nombre;
				write "==============================";
				ask computer where (each.infected and !each.is_internet) {
					isolated <- true;
					intention <- "isolated";
					write "*** AISLADO *** " + nombre;

					// Registro de la acción de contención global en el log de eventos
					string fila_defensa <- string(cycle) + "," + nombre + ",Aislamiento_Contencion,Global,0.0," + string(patch_level) + "," + string(length(computer where
					each.infected)) + ",isolated";
					save fila_defensa to: log_eventos_path rewrite: false;
				}

			} else {
				write "*** CONTENCION FALLIDA SOBRE *** " + victima.nombre;
			}

		}

	}

	reflex emergency_check {
		int infectados <- length(computer where each.infected);
		int total <- length(computer);
		if infectados = total and !emergency_containment {
			emergency_containment <- true;
			write "==============================";
			write " ALERTA CRITICA - TODA LA RED COMPROMETIDA ";
			write "==============================";
			ask computer where !each.is_internet {
				isolated <- true;
				intention <- "isolated";
				write "*** AISLADO EMERGENCIA *** " + nombre;
			}

		}

	} }

	// ==========================================================
// SPECIES COMPUTER — arquitectura BDI completa
// ==========================================================
species computer {
	int id;
	string nombre;
	bool is_server <- false;
	bool is_internet <- false;
	bool is_firewall <- false;
	bool is_switch <- false;

	// Base State
	bool infected <- false;
	bool isolated <- false;
	bool detected <- false;

	// Beliefs
	bool bel_amenaza_cercana <- false;
	bool bel_red_comprometida <- false;
	bool bel_soy_vulnerable <- false;
	int bel_vecinos_infectados <- 0;
	float bel_riesgo <- 0.0;

	// Desires
	bool des_sobrevivir <- true;
	bool des_infectar <- false;
	bool des_aislarse <- false;
	bool des_parchear <- false;

	// Intentions
	string intention <- "normal";

	// Auxiliaries
	list<int> open_ports <- [];
	int patch_level <- 0;
	int cooldown <- 0;

	reflex BDI_perception {
		list<connection> links <- connection where (each.source = self or each.target = self);
		int infectados <- 0;
		loop c over: links {
			computer vecino <- (c.source = self) ? c.target : c.source;
			if vecino.infected {
				infectados <- infectados + 1;
			}

		}

		bel_vecinos_infectados <- infectados;
		bel_amenaza_cercana <- infectados > 0;
		bel_riesgo <- float(infectados) * 25.0;
		bel_soy_vulnerable <- (!empty(open_ports)) and (patch_level < 50);
		int total <- length(computer where !each.is_internet);
		int glob <- length(computer where (each.infected and !each.is_internet));
		bel_red_comprometida <- (total > 0) and ((float(glob) / float(total)) > 0.5);
	}

	reflex BDI_deliberation {
		des_infectar <- infected;
		des_aislarse <- bel_amenaza_cercana or bel_red_comprometida;
		des_parchear <- bel_soy_vulnerable and bel_amenaza_cercana;
		des_sobrevivir <- true;
	}

	reflex BDI_planning {
		if isolated {
			intention <- "isolated";
			return;
		}

		if des_aislarse and des_sobrevivir and bel_riesgo > 50.0 {
			if rnd(100) < containment_threshold {
				intention <- "isolate";
				return;
			}

		}

		if des_parchear and !infected {
			intention <- "patch";
			return;
		}

		if des_infectar {
			intention <- "spread";
			return;
		}

		intention <- "normal";
	}

	reflex BDI_execute {
		if cooldown > 0 {
			cooldown <- cooldown - 1;
		}

		if intention = "isolated" {
			return;
		}

		if intention = "isolate" {
			isolated <- true;
			intention <- "isolated";
			write "*** BDI AISLAMIENTO VOLUNTARIO *** " + nombre + " | riesgo=" + string(int(bel_riesgo)) + " | vecinos_infectados=" + string(bel_vecinos_infectados);
			string fila_aislado <- string(cycle) + "," + nombre + ",AISLADO,-,-," + string(patch_level) + "," + string(length(computer where each.infected)) + ",isolated";
			save fila_aislado to: log_eventos_path rewrite: false;
			return;
		}

		if intention = "patch" {
			patch_level <- min(100, patch_level + 10);
			if patch_level >= 50 {
				bel_soy_vulnerable <- false;
				des_parchear <- false;
			}

			write "*** BDI PARCHEO *** " + nombre + " => patch_level=" + string(patch_level);
			string fila_parcheo <- string(cycle) + "," + nombre + ",PARCHEO,-,-," + string(patch_level) + "," + string(length(computer where each.infected)) + ",patch";
			save fila_parcheo to: log_eventos_path rewrite: false;
			return;
		}

		if intention = "spread" {
			do spread_action;
			return;
		}

	}

	// ==========================================================
	// ACCION: propagar infeccion e inyectar logs al CSV
	// ==========================================================
	action spread_action {
		if cooldown > 0 {
			return;
		}

		if isolated {
			return;
		}

		list<connection> links <- connection where (each.source = self or each.target = self);
		if empty(links) {
			return;
		}

		connection c <- one_of(links);
		computer destino <- (c.source = self) ? c.target : c.source;
		if destino.is_internet {
			return;
		}

		if destino.isolated {
			return;
		}

		if destino.infected {
			return;
		}

		float p <- 0.35;
		if destino.is_firewall {
			p <- p * (1.0 - firewall_strength);
		}

		if 445 in destino.open_ports {
			p <- p * (1.0 - destino.patch_level / 150.0);
		}

		if flip(p) {
			destino.infected <- true;
			destino.detected <- false;

			// Consola nativa
			write "BDI INFECTA -> " + destino.nombre + " desde " + self.nombre + " | p=" + string(p);

			// =======================================================
			// EXTRACCIÓN Y ESCRITURA EN EL LOG DINÁMICO (.CSV)
			// =======================================================
			int ciclo_actual <- cycle;
			string nombre_nodo <- destino.nombre;
			string evento_tipo <- "Infeccion_Exitosa";
			string origen_inf <- self.nombre;
			float prob_infeccion <- p;
			int p_level <- destino.patch_level;
			int total_inf <- length(computer where each.infected);
			string intencion_bdi <- self.intention;
			string
			fila_evento <- string(ciclo_actual) + "," + nombre_nodo + "," + evento_tipo + "," + origen_inf + "," + string(prob_infeccion) + "," + string(p_level) + "," + string(total_inf) + "," + intencion_bdi;

			// Guarda sumando líneas al CSV existente (Se eliminó type: "text")
			save fila_evento to: log_eventos_path rewrite: false;
		}

		cooldown <- rnd(cooldown_max) + cooldown_min;
	}

	// Visual Base
	aspect default {
		float tam <- 0.2;
		if infected {
			draw circle(tam) color: #red;
		} else if is_firewall {
			draw square(tam) color: #blue;
		} else if is_switch {
			draw square(tam) color: #gray;
		} else if is_internet {
			draw circle(tam) color: #yellow;
		} else if is_server {
			draw square(tam) color: #purple;
		} else {
			draw circle(tam) color: #green;
		}

		if isolated {
			draw circle(tam * 1.4) color: #black;
		}

		draw string(nombre + " [" + intention + "]") at: location + {0, -0.5} color: #black font: font("SansSerif", 8, #bold);
	} }

	// =====================================================
// CONEXIONES
// =====================================================
species connection {
	computer source;
	computer target;

	aspect default {
		draw line([source.location, target.location]) color: #orange width: 2;
	}

}

// =====================================================
// EXPERIMENTO PRINCIPAL (GUI)
// =====================================================
experiment Infeccion type: gui {
	parameter "Nivel de Contencion (%)" type: float var: containment_threshold min: 0 max: 100 category: "Seguridad BDI";
	parameter "Fuerza Firewall (0-1)" type: float var: firewall_strength min: 0.0 max: 1.0 category: "Seguridad BDI";
	parameter "Nivel de Parche Inicial (%)" type: float var: initial_patch_level min: 0 max: 100 category: "Seguridad BDI";
	output {
		display mapa_red {
			species sala;
			species connection;
			species computer;
		}

		monitor "Infectados" value: length(computer where each.infected);
		monitor "Sanos" value: length(computer where (!each.infected and !each.is_internet));
		monitor "Aislados" value: length(computer where each.isolated);
		monitor "Intencion: spread" value: length(computer where (each.intention = "spread"));
		monitor "Intencion: isolate" value: length(computer where (each.intention = "isolate" or each.intention = "isolated"));
		monitor "Intencion: patch" value: length(computer where (each.intention = "patch"));
		monitor "Riesgo promedio" value: mean(computer collect each.bel_riesgo);
	}

}