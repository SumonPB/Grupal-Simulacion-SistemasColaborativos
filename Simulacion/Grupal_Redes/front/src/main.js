import { createApp } from 'vue'
import App from './App.vue'
import './style.css'
import VIcon from './components/VIcon.vue'

const app = createApp(App)
app.component('v-icon', VIcon)
app.mount('#app')
