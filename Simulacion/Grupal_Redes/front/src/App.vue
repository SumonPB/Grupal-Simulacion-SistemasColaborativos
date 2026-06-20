<template>
  <div class="dashboard">
    <header class="header">
      <div class="header-left">
        <span class="header-tag">BDI · GAMA Platform</span>
        <h1 class="header-title">WannaCry Network Simulation</h1>
      </div>
      <div class="header-stats">
        <div class="stat" :class="{ danger: stats.infectados > 0 }">
          <span class="stat-value">{{ stats.infectados }}</span>
          <span class="stat-label">Infectados</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ stats.sanos }}</span>
          <span class="stat-label">Sanos</span>
        </div>
        <div class="stat warn">
          <span class="stat-value">{{ stats.aislados }}</span>
          <span class="stat-label">Aislados</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ stats.ciclo }}</span>
          <span class="stat-label">Ciclo</span>
        </div>
        <div class="pulse-dot" :class="pollingActive ? 'active' : 'inactive'"></div>
      </div>
    </header>

    <section class="map-section">
      <div class="section-label">Red · Topología en vivo</div>
      <div ref="cyContainer" class="cy-container"></div>
      <div class="legend">
        <span class="leg-item"><span class="dot" style="background:#22c55e"></span>Sano</span>
        <span class="leg-item"><span class="dot" style="background:#ef4444"></span>Infectado</span>
        <span class="leg-item"><span class="dot"
            style="background:#1e293b;border:2px solid #475569"></span>Aislado</span>

        <span class="leg-item">
          <v-icon icon="mdi-monitor" size="20" class="mr-1" color="slate-light"></v-icon> PC
        </span>
        <span class="leg-item">
          <v-icon icon="mdi-shield-lock" size="20" class="mr-1" color="blue"></v-icon> Firewall
        </span>
        <span class="leg-item">
          <v-icon icon="mdi-swap-horizontal" size="20" class="mr-1" color="slate"></v-icon> Switch
        </span>
        <span class="leg-item">
          <v-icon icon="mdi-cloud" size="20" class="mr-1" color="amber"></v-icon> Internet
        </span>
        <span class="leg-item">
          <v-icon icon="mdi-server" size="20" class="mr-1" color="purple"></v-icon> Server
        </span>
      </div>
    </section>

    <section class="charts-section">
      <div class="chart-card">
        <div class="chart-label">Infectados por ciclo</div>
        <div ref="chartInfectados" class="chart-box"></div>
      </div>
      <div class="chart-card">
        <div class="chart-label">Patch level promedio</div>
        <div ref="chartPatch" class="chart-box"></div>
      </div>
      <div class="chart-card">
        <div class="chart-label">Intenciones BDI</div>
        <div ref="chartIntenciones" class="chart-box"></div>
      </div>
      <div class="chart-card events-card">
        <div class="chart-label">Eventos en tiempo real</div>
        <div class="events-table-wrap">
          <table class="events-table">
            <thead>
              <tr>
                <th>Ciclo</th>
                <th>Nodo</th>
                <th>Evento</th>
                <th>Desde</th>
                <th>P</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(ev, i) in eventosRecientes" :key="i" :class="rowClass(ev.evento)">
                <td>{{ ev.ciclo }}</td>
                <td>{{ ev.nodo }}</td>
                <td><span class="badge" :class="badgeClass(ev.evento)">{{ ev.evento }}</span></td>
                <td>{{ ev.desde }}</td>
                <td>{{ ev.probabilidad && ev.probabilidad !== '-' ? parseFloat(ev.probabilidad).toFixed(3) : '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import Papa from 'papaparse'
import * as echarts from 'echarts'
import cytoscape from 'cytoscape'

const BASE = '/results'

const cyContainer = ref(null)
const chartInfectados = ref(null)
const chartPatch = ref(null)
const chartIntenciones = ref(null)

let cy = null
let ecInfectados = null
let ecPatch = null
let ecIntenciones = null
let pollTimer = null

const pollingActive = ref(false)
const eventos = ref([])
const nodoEstado = ref({})

// ── helper: limpia espacios en claves del CSV ──────────────
function cleanRow(row) {
  const out = {}
  Object.keys(row).forEach(k => { out[k.trim()] = typeof row[k] === 'string' ? row[k].trim() : row[k] })
  return out
}

const stats = computed(() => {
  const vals = Object.values(nodoEstado.value)
  const infectados = vals.filter(n => n.infected && !n.is_internet).length
  const aislados = vals.filter(n => n.isolated).length
  const sanos = vals.filter(n => !n.infected && !n.is_internet && !n.isolated).length
  const ultimo = eventos.value.length ? eventos.value[eventos.value.length - 1].ciclo : 0
  return { infectados, aislados, sanos, ciclo: ultimo }
})

const eventosRecientes = computed(() => [...eventos.value].reverse().slice(0, 50))

// ───────────────────────────────────────────────────────────
// ICONOS SVG (base64)
// ───────────────────────────────────────────────────────────
function svgToDataUri(svg) {
  return 'data:image/svg+xml;base64,' + btoa(svg)
}

const ICON_PC = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="8" y="10" width="48" height="32" rx="2" fill="#1e293b" stroke="#22c55e" stroke-width="2.5"/>
  <rect x="13" y="15" width="38" height="22" fill="#0f172a"/>
  <rect x="24" y="44" width="16" height="4" fill="#475569"/>
  <rect x="16" y="48" width="32" height="4" rx="1" fill="#475569"/>
</svg>`)

const ICON_PC_INFECTED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="8" y="10" width="48" height="32" rx="2" fill="#1e293b" stroke="#ef4444" stroke-width="2.5"/>
  <rect x="13" y="15" width="38" height="22" fill="#450a0a"/>
  <text x="32" y="31" font-size="16" fill="#ef4444" text-anchor="middle" font-family="monospace">!</text>
  <rect x="24" y="44" width="16" height="4" fill="#475569"/>
  <rect x="16" y="48" width="32" height="4" rx="1" fill="#475569"/>
</svg>`)

const ICON_PC_ISOLATED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="8" y="10" width="48" height="32" rx="2" fill="#1e293b" stroke="#475569" stroke-width="2.5"/>
  <rect x="13" y="15" width="38" height="22" fill="#0f172a"/>
  <line x1="6" y1="6" x2="58" y2="58" stroke="#475569" stroke-width="3"/>
  <rect x="24" y="44" width="16" height="4" fill="#334155"/>
  <rect x="16" y="48" width="32" height="4" rx="1" fill="#334155"/>
</svg>`)

const ICON_FIREWALL = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="10" y="8" width="44" height="48" rx="3" fill="#1e3a8a" stroke="#3b82f6" stroke-width="2.5"/>
  <path d="M20 18 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#93c5fd" stroke-width="2"/>
  <path d="M20 28 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#93c5fd" stroke-width="2"/>
  <path d="M20 38 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#93c5fd" stroke-width="2"/>
  <path d="M20 48 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#93c5fd" stroke-width="2"/>
</svg>`)

const ICON_FIREWALL_INFECTED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="10" y="8" width="44" height="48" rx="3" fill="#7f1d1d" stroke="#ef4444" stroke-width="2.5"/>
  <path d="M20 18 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#fca5a5" stroke-width="2"/>
  <path d="M20 28 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#fca5a5" stroke-width="2"/>
  <path d="M20 38 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#fca5a5" stroke-width="2"/>
  <path d="M20 48 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#fca5a5" stroke-width="2"/>
</svg>`)

const ICON_FIREWALL_ISOLATED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="10" y="8" width="44" height="48" rx="3" fill="#1e293b" stroke="#475569" stroke-width="2.5"/>
  <path d="M20 18 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#64748b" stroke-width="2"/>
  <path d="M20 28 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#64748b" stroke-width="2"/>
  <path d="M20 38 q6 -6 12 0 q6 -6 12 0" fill="none" stroke="#64748b" stroke-width="2"/>
  <line x1="6" y1="6" x2="58" y2="58" stroke="#475569" stroke-width="3"/>
</svg>`)

const ICON_SWITCH = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="6" y="22" width="52" height="20" rx="2" fill="#334155" stroke="#94a3b8" stroke-width="2.5"/>
  <rect x="12" y="28" width="5" height="5" fill="#22c55e"/>
  <rect x="20" y="28" width="5" height="5" fill="#22c55e"/>
  <rect x="28" y="28" width="5" height="5" fill="#22c55e"/>
  <rect x="36" y="28" width="5" height="5" fill="#22c55e"/>
  <rect x="44" y="28" width="5" height="5" fill="#22c55e"/>
</svg>`)

const ICON_SWITCH_INFECTED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="6" y="22" width="52" height="20" rx="2" fill="#451a1a" stroke="#ef4444" stroke-width="2.5"/>
  <rect x="12" y="28" width="5" height="5" fill="#ef4444"/>
  <rect x="20" y="28" width="5" height="5" fill="#ef4444"/>
  <rect x="28" y="28" width="5" height="5" fill="#ef4444"/>
  <rect x="36" y="28" width="5" height="5" fill="#ef4444"/>
  <rect x="44" y="28" width="5" height="5" fill="#ef4444"/>
</svg>`)

const ICON_SWITCH_ISOLATED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="6" y="22" width="52" height="20" rx="2" fill="#0f172a" stroke="#475569" stroke-width="2.5"/>
  <rect x="12" y="28" width="5" height="5" fill="#334155"/>
  <circle cx="44" cy="32" r="2" fill="#334155"/>
  <line x1="6" y1="14" x2="58" y2="50" stroke="#475569" stroke-width="3"/>
</svg>`)

const ICON_CLOUD = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <path d="M18 40 a10 10 0 0 1 0 -20 a13 13 0 0 1 25 -4 a10 10 0 0 1 3 24 z"
        fill="#facc15" stroke="#854d0e" stroke-width="2"/>
</svg>`)

const ICON_SERVER = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="12" y="8" width="40" height="14" rx="2" fill="#581c87" stroke="#a855f7" stroke-width="2"/>
  <rect x="12" y="25" width="40" height="14" rx="2" fill="#581c87" stroke="#a855f7" stroke-width="2"/>
  <rect x="12" y="42" width="40" height="14" rx="2" fill="#581c87" stroke="#a855f7" stroke-width="2"/>
  <circle cx="44" cy="15" r="2" fill="#22c55e"/>
  <circle cx="44" cy="32" r="2" fill="#22c55e"/>
  <circle cx="44" cy="49" r="2" fill="#22c55e"/>
</svg>`)

const ICON_SERVER_INFECTED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="12" y="8" width="40" height="14" rx="2" fill="#7f1d1d" stroke="#ef4444" stroke-width="2"/>
  <rect x="12" y="25" width="40" height="14" rx="2" fill="#7f1d1d" stroke="#ef4444" stroke-width="2"/>
  <rect x="12" y="42" width="40" height="14" rx="2" fill="#7f1d1d" stroke="#ef4444" stroke-width="2"/>
  <circle cx="44" cy="15" r="2" fill="#ef4444"/>
  <circle cx="44" cy="32" r="2" fill="#ef4444"/>
  <circle cx="44" cy="49" r="2" fill="#ef4444"/>
</svg>`)

const ICON_SERVER_ISOLATED = svgToDataUri(`
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="12" y="8" width="40" height="14" rx="2" fill="#0f172a" stroke="#475569" stroke-width="2"/>
  <rect x="12" y="25" width="40" height="14" rx="2" fill="#0f172a" stroke="#475569" stroke-width="2"/>
  <rect x="12" y="42" width="40" height="14" rx="2" fill="#0f172a" stroke="#475569" stroke-width="2"/>
  <line x1="6" y1="4" x2="58" y2="60" stroke="#475569" stroke-width="3"/>
</svg>`)

// ── INIT ──────────────────────────────────────────────────
onMounted(async () => {
  await initCytoscape()
  initCharts()
  startPolling()
})

onUnmounted(() => clearInterval(pollTimer))

// ── CYTOSCAPE ─────────────────────────────────────────────
async function initCytoscape() {
  const [nodosRaw, topoRaw] = await Promise.all([
    fetchCSVSkipFirstLine(`${BASE}/log_nodos.csv`),
    fetchCSVSkipFirstLine(`${BASE}/log_topologia.csv`),
  ])

  const nodos = nodosRaw.map(cleanRow).filter(n => n.nombre && n.nombre !== '')
  const topo = topoRaw.map(cleanRow).filter(t => t.origen && t.destino && t.origen !== '' && t.destino !== '')

  nodos.forEach(n => {
    nodoEstado.value[n.nombre] = {
      tipo: n.tipo,
      infected: false,
      isolated: false,
      is_internet: n.tipo === 'internet',
    }
  })

  const elements = [
    ...nodos.map(n => ({
      data: { id: n.nombre, label: n.nombre, tipo: n.tipo },
    })),
    ...topo.map(t => ({
      data: { id: `${t.origen}-${t.destino}`, source: t.origen, target: t.destino },
    })),
  ]

  cy = cytoscape({
    container: cyContainer.value,
    elements,
    style: cyStyles(),
    layout: { name: 'breadthfirst', directed: false, padding: 60, spacingFactor: 2.8 },
    userZoomingEnabled: true,
    userPanningEnabled: true,
  })

  const internetNodo = nodos.find(n => n.tipo === 'internet')
  if (internetNodo) {
    nodoEstado.value[internetNodo.nombre].infected = true
    updateCyNode(internetNodo.nombre, true, false, false)
  }
}

function cyStyles() {
  return [
    {
      selector: 'node',
      style: {
        label: 'data(label)',
        'font-size': '40px',
        'font-family': 'monospace',
        color: '#e2e8f0',
        'text-valign': 'bottom',
        'text-margin-y': '10px',
        width: '60px',
        height: '60px',
        shape: 'rectangle',
        'background-fit': 'contain',
        'background-clip': 'none',
        'background-opacity': 0,
        'border-width': 0,
        'background-image': ICON_PC,
      },
    },
    { selector: 'node[tipo="pc"]', style: { 'background-image': ICON_PC, width: '120px', height: '120px' } },
    { selector: 'node[tipo="server"]', style: { 'background-image': ICON_SERVER, width: '120px', height: '120px' } },
    { selector: 'node[tipo="firewall"]', style: { 'background-image': ICON_FIREWALL, width: '120px', height: '120px' } },
    { selector: 'node[tipo="switch"]', style: { 'background-image': ICON_SWITCH, width: '120px', height: '120px' } },
    { selector: 'node[tipo="internet"]', style: { 'background-image': ICON_CLOUD, width: '120px', height: '120px' } },

    { selector: 'node.infected[tipo="pc"]', style: { 'background-image': ICON_PC_INFECTED } },
    { selector: 'node.infected[tipo="firewall"]', style: { 'background-image': ICON_FIREWALL_INFECTED } },
    { selector: 'node.infected[tipo="switch"]', style: { 'background-image': ICON_SWITCH_INFECTED } },
    { selector: 'node.infected[tipo="server"]', style: { 'background-image': ICON_SERVER_INFECTED } },

    { selector: 'node.isolated[tipo="pc"]', style: { 'background-image': ICON_PC_ISOLATED } },
    { selector: 'node.isolated[tipo="firewall"]', style: { 'background-image': ICON_FIREWALL_ISOLATED } },
    { selector: 'node.isolated[tipo="switch"]', style: { 'background-image': ICON_SWITCH_ISOLATED } },
    { selector: 'node.isolated[tipo="server"]', style: { 'background-image': ICON_SERVER_ISOLATED } },

    {
      selector: 'edge',
      style: {
        width: 3,
        'line-color': '#f97316',
        'target-arrow-color': '#f97316',
        'target-arrow-shape': 'triangle',
        'curve-style': 'bezier',
        opacity: 0.8,
      },
    },
    {
      selector: 'edge.attack',
      style: {
        'line-color': '#ef4444',
        'target-arrow-color': '#ef4444',
        width: 6,
        opacity: 1,
        'line-style': 'solid'
      }
    }
  ]
}

function updateCyNode(nombre, infected, isolated) {
  if (!cy) return
  const node = cy.getElementById(nombre)
  if (!node || !node.length) return

  node.removeClass('infected isolated')

  if (isolated) {
    node.addClass('isolated')
  } else if (infected) {
    node.addClass('infected')
    const baseW = node.numericStyle('width')
    const baseH = node.numericStyle('height')
    node.animate(
      { style: { width: baseW * 1.4, height: baseH * 1.4 } },
      {
        duration: 300,
        complete: function () {
          node.animate({ style: { width: baseW, height: baseH } }, { duration: 300 })
        }
      }
    )
  }
}

// ── ECHARTS ───────────────────────────────────────────────
function initCharts() {
  ecInfectados = echarts.init(chartInfectados.value, 'dark')
  ecPatch = echarts.init(chartPatch.value, 'dark')
  ecIntenciones = echarts.init(chartIntenciones.value, 'dark')

  const baseOpt = {
    backgroundColor: 'transparent',
    grid: { left: 44, right: 16, top: 16, bottom: 36 },
    xAxis: { type: 'category', data: [], axisLabel: { color: '#94a3b8', fontSize: 10 } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8', fontSize: 10 }, splitLine: { lineStyle: { color: '#1e293b' } } },
    tooltip: { trigger: 'axis' },
  }

  ecInfectados.setOption({
    ...baseOpt,
    series: [{ name: 'Infectados', type: 'line', data: [], smooth: true, itemStyle: { color: '#ef4444' }, areaStyle: { color: 'rgba(239,68,68,0.15)' } }],
  })

  ecPatch.setOption({
    ...baseOpt,
    series: [{ name: 'Patch avg', type: 'line', data: [], smooth: true, itemStyle: { color: '#22c55e' }, areaStyle: { color: 'rgba(34,197,94,0.15)' } }],
  })

  ecIntenciones.setOption({
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: function (params) {
        const map = { spread: 'Propagar', patch: 'Parchar', isolated: 'Aislar', normal: 'Normal' }
        let res = `<div style="font-family: monospace;">Ciclo: ${params[0].name}</div>`
        params.forEach(item => {
          if (item.value > 0) {
            const label = map[item.seriesName] || item.seriesName
            res += `<div style="font-family: monospace;">${item.marker} ${label}: <b>${item.value}</b></div>`
          }
        })
        return res
      }
    },
    legend: {
      data: ['spread', 'patch', 'isolated', 'normal'],
      textStyle: { color: '#94a3b8', fontSize: 10 },
      top: 4,
      formatter: function (name) {
        const map = { spread: 'Propagar', patch: 'Parchar', isolated: 'Aislar', normal: 'Normal' }
        return map[name] || name
      }
    },
    grid: { left: 44, right: 16, top: 36, bottom: 36 },
    xAxis: { type: 'category', data: [], axisLabel: { color: '#94a3b8', fontSize: 10 } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8', fontSize: 10 }, splitLine: { lineStyle: { color: '#1e293b' } } },
    series: [
      { name: 'spread', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#ef4444' } },
      { name: 'patch', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#22c55e' } },
      { name: 'isolated', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#475569' } },
      { name: 'normal', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#1e293b' } },
    ],
  })
}

// ── POLLING ───────────────────────────────────────────────
let lastRowCount = 0

function startPolling() {
  pollingActive.value = true
  pollTimer = setInterval(pollCSV, 2000)
  pollCSV()
}

async function pollCSV() {
  try {

    const rawRows =
      await fetchCSV(`${BASE}/log_eventos.csv`)

    const rows =
      rawRows.map(cleanRow)

    if (rows.length <= lastRowCount)
      return

    const nuevas =
      rows.slice(lastRowCount)

    lastRowCount =
      rows.length

    nuevas.forEach(procesarEvento)

    // fuerza reactividad
    eventos.value = [...rows]

    updateCharts(rows)

    if (cy) {
      cy.resize()
      cy.fit(undefined, 40)
    }

  } catch (e) {

    console.warn(
      'Poll error',
      e
    )

  }
}

function procesarEvento(ev) {

  const nodo = ev.nodo
  const evento = ev.evento
  const desde = ev.desde

  if (!nodo || nodo === '-')
    return


  // INFECCIÓN
  if (evento === 'Infeccion_Exitosa') {

    if (nodoEstado.value[nodo]) {
      nodoEstado.value[nodo].infected = true
      nodoEstado.value[nodo].isolated = false
    }

    updateCyNode(
      nodo,
      true,
      false
    )

    if (
      desde &&
      desde !== '-' &&
      cy
    ) {

      const edge =
        cy
          .edges()
          .filter(e =>
            (
              e.data('source') === desde &&
              e.data('target') === nodo
            )
            ||
            (
              e.data('source') === nodo &&
              e.data('target') === desde
            )
          )

      if (edge.length) {

        edge.addClass(
          'attack'
        )

      }

    }

  }


  // AISLAMIENTO
  if (

    evento ===
      'AISLADO'

    ||

    evento ===
      'AISLADO_EMERGENCIA'

    ||

    evento ===
      'Aislamiento_Contencion'

  ) {

    if (
      nodoEstado.value[nodo]
    ) {

      nodoEstado.value[
        nodo
      ].infected = true

      nodoEstado.value[
        nodo
      ].isolated = true

    }

    updateCyNode(
      nodo,
      true,
      true
    )

  }


  // PARCHEO
  if (
    evento ===
    'PARCHEO'
  ) {

    if (
      nodoEstado.value[
        nodo
      ]
    ) {

      nodoEstado.value[
        nodo
      ].infected =
        false

      nodoEstado.value[
        nodo
      ].isolated =
        false

    }

    updateCyNode(
      nodo,
      false,
      false
    )

  }

}

function updateCharts(rows) {
  const ciclosSet = [...new Set(rows.map(r => r.ciclo))].sort((a, b) => parseInt(a) - parseInt(b))

  const infectSerie = ciclosSet.map(c => {
    const filasC = rows.filter(r => r.ciclo === c && r.infectados_total && r.infectados_total !== '-')
    if (!filasC.length) return null
    return parseInt(filasC[filasC.length - 1].infectados_total)
  })

  const patchRows = rows.filter(r => r.evento === 'PARCHEO')
  const patchCiclos = [...new Set(patchRows.map(r => r.ciclo))].sort((a, b) => parseInt(a) - parseInt(b))
  const patchSerie = patchCiclos.map(c => {
    const vals = patchRows.filter(r => r.ciclo === c).map(r => parseInt(r.patch_lv)).filter(v => !isNaN(v))
    return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : 0
  })

  const spreadSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'spread').length)
  const patchISerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'patch').length)
  const isolateSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && (r.intencion === 'isolated' || r.intencion === 'isolate')).length)
  const normalSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'normal').length)

  ecInfectados.setOption({ xAxis: { data: ciclosSet }, series: [{ data: infectSerie }] })
  ecPatch.setOption({ xAxis: { data: patchCiclos }, series: [{ data: patchSerie }] })

  if (!ecIntenciones) {
    ecIntenciones = echarts.init(chartIntenciones.value, 'dark')
  }

  ecIntenciones.setOption({
    xAxis: { data: ciclosSet },
    series: [
      { name: 'spread', data: spreadSerie },
      { name: 'patch', data: patchISerie },
      { name: 'isolated', data: isolateSerie },
      { name: 'normal', data: normalSerie },
    ],
  })
}

// ── CSV HELPER ────────────────────────────────────────────
async function fetchCSVSkipFirstLine(path) {
  const res = await fetch(path)
  const text = await res.text()
  const lines = text.split('\n')

  const primeraLinea = lines[0].trim()
  const esBasura = primeraLinea && !primeraLinea.includes(',')
  const textoLimpio = esBasura ? lines.slice(1).join('\n') : text

  return new Promise((resolve, reject) => {
    Papa.parse(textoLimpio, {
      header: true,
      skipEmptyLines: true,
      transformHeader: h => h.trim(),
      complete: r => resolve(r.data),
      error: reject,
    })
  })
}

function fetchCSV(path) {
  return new Promise((resolve, reject) => {
    Papa.parse(path, {
      download: true,
      header: true,
      skipEmptyLines: true,
      transformHeader: h => h.trim(),
      complete: r => resolve(r.data),
      error: reject,
    })
  })
}

function rowClass(evento) {

  if (
    evento ===
    'Infeccion_Exitosa'
  )
    return 'row-infected'

  if (
    evento?.includes(
      'AISLADO'
    )
  )
    return 'row-isolated'

  if (
    evento ===
    'ALERTA_CRITICA'
  )
    return 'row-alert'

  if (
    evento ===
    'PARCHEO'
  )
    return 'row-patch'

  return ''

}

function badgeClass(evento) {

  if (
    evento ===
    'Infeccion_Exitosa'
  )
    return 'badge-red'

  if (
    evento?.includes(
      'AISLADO'
    )
  )
    return 'badge-dark'

  if (
    evento ===
    'ALERTA_CRITICA'
  )
    return 'badge-orange'

  if (
    evento ===
    'PARCHEO'
  )
    return 'badge-green'

  return 'badge-gray'

}
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Inter:wght@400;500;600&display=swap');

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

.dashboard {
  min-height: 100vh;
  background: #0a0f1e;
  color: #e2e8f0;
  font-family: 'Inter', sans-serif;
  display: flex;
  flex-direction: column;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 24px;
  background: #0d1526;
  border-bottom: 1px solid #1e293b;
}

.header-tag {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #f97316;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  display: block;
  margin-bottom: 2px;
}

.header-title {
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: #f1f5f9;
}

.header-stats {
  display: flex;
  align-items: center;
  gap: 24px;
}

.stat {
  text-align: center;
}

.stat-value {
  display: block;
  font-family: 'JetBrains Mono', monospace;
  font-size: 22px;
  font-weight: 600;
  color: #f1f5f9;
  line-height: 1;
}

.stat-label {
  display: block;
  font-size: 10px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  margin-top: 2px;
}

.stat.danger .stat-value {
  color: #ef4444;
}

.stat.warn .stat-value {
  color: #f97316;
}

.pulse-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.pulse-dot.active {
  background: #22c55e;
  box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.3);
  animation: pulse 1.5s infinite;
}

.pulse-dot.inactive {
  background: #334155;
}

@keyframes pulse {

  0%,
  100% {
    box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.3)
  }

  50% {
    box-shadow: 0 0 0 6px rgba(34, 197, 94, 0.1)
  }
}

.map-section {
  padding: 16px 24px 8px;
}

.section-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: 8px;
}

.cy-container {
  width: 100%;
  height: 600px;
  background: #0d1526;
  border: 1px solid #1e293b;
  border-radius: 8px;
}

.legend {
  display: flex;
  gap: 16px;
  margin-top: 8px;
  flex-wrap: wrap;
}

.leg-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: #64748b;
}

.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}

.charts-section {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 12px;
  padding: 8px 24px 24px;
}

.chart-card {
  background: #0d1526;
  border: 1px solid #1e293b;
  border-radius: 8px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.chart-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.chart-box {
  height: 180px;
}

.events-card {
  overflow: hidden;
}

.events-table-wrap {
  height: 180px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: #1e293b transparent;
}

.events-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
  font-family: 'JetBrains Mono', monospace;
}

.events-table th {
  position: sticky;
  top: 0;
  background: #0d1526;
  color: #475569;
  text-align: left;
  padding: 4px 6px;
  font-size: 10px;
  text-transform: uppercase;
  border-bottom: 1px solid #1e293b;
}

.events-table td {
  padding: 4px 6px;
  color: #94a3b8;
  border-bottom: 1px solid #0f172a;
}

.row-infected td {
  background: rgba(239, 68, 68, 0.07);
}

.row-isolated td {
  background: rgba(30, 41, 59, 0.5);
}

.row-alert td {
  background: rgba(249, 115, 22, 0.1);
}

.row-patch td {
  background: rgba(34, 197, 94, 0.06);
}

.badge {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.05em;
}

.badge-red {
  background: rgba(239, 68, 68, 0.2);
  color: #f87171;
}

.badge-dark {
  background: rgba(15, 23, 42, 0.8);
  color: #94a3b8;
}

.badge-orange {
  background: rgba(249, 115, 22, 0.2);
  color: #fb923c;
}

.badge-green {
  background: rgba(34, 197, 94, 0.2);
  color: #4ade80;
}

.badge-gray {
  background: rgba(51, 65, 85, 0.5);
  color: #64748b;
}
</style>