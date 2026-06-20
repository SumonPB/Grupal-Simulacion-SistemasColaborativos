<template>
  <i :class="iconClasses" :style="styleObj" aria-hidden="true"></i>
</template>

<script>
export default {
  name: 'VIcon',
  props: {
    icon: { type: String, required: true },
    size: { type: [String, Number], default: null },
    color: { type: String, default: null },
    minWidth: { type: [String, Number], default: null },
    height: { type: [String, Number], default: null },
  },
  computed: {
    iconClasses() {
      const base = this.icon && this.icon.startsWith('mdi-') ? this.icon : `mdi-${this.icon}`
      return ['mdi', base].filter(Boolean).join(' ')
    },
    styleObj() {
      const s = {}
      const fmt = v => (typeof v === 'number' || String(v).match(/^\d+$/)) ? `${v}px` : v
      if (this.size) s.fontSize = fmt(this.size)
      if (this.color) s.color = this.color
      if (this.minWidth) s.minWidth = fmt(this.minWidth)
      if (this.height) s.lineHeight = fmt(this.height)
      return s
    }
  }
}
</script>

<style scoped>
/* ensure icons align nicely */
.mdi { vertical-align: middle; display: inline-block }
</style>
