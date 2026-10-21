<template>
  <section class="bweather-settings" aria-label="BeamNg.weather rain settings">
    <header class="bw-heading">
      <div><h1>BeamNg.weather</h1><p>Atmospheric rain settings</p></div>
      <button type="button" class="bw-power" :disabled="!state" :aria-pressed="!!state?.enabled" @click="toggle">{{ state?.enabled ? 'Stop rain' : 'Enable rain' }}</button>
    </header>
    <p class="bw-status" role="status">{{ statusText }}</p>
    <p v-if="error" class="bw-error" role="alert">{{ error }} <button type="button" @click="refresh">Retry</button></p>
    <template v-if="state">
      <section class="bw-section" aria-label="Rain presets">
        <h2>Choose a rain preset</h2>
        <div class="bw-presets"><button v-for="preset in state.presets" :key="preset.id" type="button" :aria-pressed="state.preset === preset.id" :class="{ 'is-selected': state.preset === preset.id }" @click="selectPreset(preset.id)">{{ preset.name }}</button></div>
        <p class="bw-hint">{{ presetDescription }}</p>
      </section>
      <section class="bw-section" aria-label="Rain appearance">
        <h2>Rain appearance</h2>
        <div class="bw-sliders">
          <label v-for="control in controls" :key="control.key" class="bw-slider">
            <span>{{ control.label }}</span><output>{{ format(control) }}</output>
            <input v-model.number="form[control.key]" type="range" :min="control.min" :max="control.max" :step="control.step" :aria-label="control.label" @focus="editingKey = control.key" @blur="editingKey = null" @change="apply(control.key)">
          </label>
        </div>
      </section>
      <section class="bw-section bw-options" aria-label="Performance and rendering">
        <div>
          <label class="bw-quality">Particle budget<select v-model="form.quality" @change="apply('quality')"><option value="low">Low / 2,400</option><option value="medium">Balanced / 6,000</option><option value="high">High / 12,000</option><option value="ultra">Ultra / 20,000</option></select></label>
          <p class="bw-hint">{{ state.activeDrops.toLocaleString('en-US') }} active droplets / {{ state.maxDrops.toLocaleString('en-US') }} max.</p>
          <p class="bw-hint">Increasing coverage spreads the same droplets over a larger volume.</p>
        </div>
        <div class="bw-checks">
          <label><input v-model="form.collisions" type="checkbox" @change="apply('collisions')">Collide with scenery and vehicles</label>
          <label><input v-model="form.wind" type="checkbox" @change="apply('wind')">Follow the map's existing wind</label>
          <label><input v-model="form.lighting" type="checkbox" @change="apply('lighting')">Match droplets to sky lighting</label>
        </div>
      </section>
      <section class="bw-section" aria-label="Custom presets">
        <h2>My presets</h2>
        <div class="bw-slots">
          <div v-for="slot in state.personalPresets" :key="slot.slot" class="bw-slot">
            <strong>Custom {{ slot.slot }} <small>{{ slot.saved ? 'Saved' : 'Empty' }}</small></strong>
            <div><button type="button" :disabled="!slot.saved" @click="loadSlot(slot.slot)">Load</button><button type="button" @click="saveSlot(slot.slot)">{{ slot.saved ? 'Overwrite' : 'Save' }}</button><button type="button" :disabled="!slot.saved" :aria-label="'Delete preset ' + slot.slot" @click="deleteSlot(slot.slot)">Delete</button></div>
          </div>
        </div>
      </section>
      <p v-if="state.error" class="bw-error" role="alert">{{ state.error }}</p>
    </template>
    <footer>Settings are saved automatically. Visual rain only: no windshield effects, puddles or grip changes.</footer>
  </section>
</template>

<script>
import { ref, reactive, computed, onMounted, onUnmounted } from "vue"
import { lua } from "@/bridge"
import { useEvents } from "@/services/events"

export default {
  name: "BeamngWeatherPauseSettings",
  setup() {
    const state = ref(null)
    const form = reactive({})
    const error = ref("")
    const editingKey = ref(null)
    const events = useEvents()
    let disposed = false
    const controls = [
      { key: "intensity", label: "Intensity", min: 0, max: 1, step: 0.01, unit: "percent" },
      { key: "dropScale", label: "Droplet size", min: 0.5, max: 2, step: 0.05, unit: "factor" },
      { key: "fallSpeed", label: "Fall speed", min: 0.4, max: 1.8, step: 0.05, unit: "factor" },
      { key: "turbulence", label: "Turbulence", min: 0, max: 1, step: 0.01, unit: "percent" },
      { key: "variability", label: "Density variation", min: 0, max: 0.6, step: 0.01, unit: "percent" },
      { key: "contrast", label: "Droplet visibility", min: 0.35, max: 1.5, step: 0.05, unit: "factor" },
      { key: "volume", label: "Rain coverage", min: 0.65, max: 1.6, step: 0.05, unit: "factor" },
      { key: "transition", label: "Intensity transition", min: 0, max: 5, step: 0.1, unit: "seconds" }
    ]
    const labels = { waiting: "Load a map to see the rain.", raining: "Raining", stopped: "Rain stopped", unavailable: "Rain unavailable: see the diagnostic below." }
    const statusText = computed(() => state.value ? labels[state.value.status] || state.value.status : "Connecting to the rain controller…")
    const presetDescription = computed(() => state.value?.presets?.find(p => p.id === state.value.preset)?.description || "Your custom settings")

    function receive(data) {
      if (disposed || !data || typeof data !== "object") return
      state.value = data
      for (const control of controls) if (editingKey.value !== control.key) form[control.key] = data[control.key]
      for (const key of ["quality", "collisions", "wind", "lighting"]) form[key] = data[key]
    }
    async function refresh() {
      try {
        const data = await lua.extensions.beamngWeather_hashk014.getState()
        if (!disposed) { receive(data); error.value = "" }
      } catch {
        if (!disposed) error.value = "Cannot connect to BeamNg.weather. Check that the mod is enabled, then retry."
      }
    }
    async function send(method, value) {
      try {
        await lua.extensions.beamngWeather_hashk014[method](value)
        if (!disposed) error.value = ""
      } catch {
        if (!disposed) error.value = "The setting could not be applied. Check the game console, then retry."
      }
    }
    function apply(key) {
      const control = controls.find(item => item.key === key)
      if (control) {
        const value = Number(form[key])
        if (!Number.isFinite(value)) return
        return send("configure", { [key]: Math.max(control.min, Math.min(control.max, value)) })
      }
      if (key === "quality" && ["low", "medium", "high", "ultra"].includes(form.quality)) return send("configure", { quality: form.quality })
      if (["collisions", "wind", "lighting"].includes(key)) return send("configure", { [key]: !!form[key] })
    }
    function toggle() { if (state.value) return send("setEnabled", !state.value.enabled) }
    function selectPreset(id) { if (state.value?.presets?.some(p => p.id === id)) return send("applyPreset", id) }
    function validSlot(slot) { return Number.isInteger(slot) && slot >= 1 && slot <= 3 }
    function saveSlot(slot) { if (validSlot(slot)) return send("savePersonalPreset", slot) }
    function loadSlot(slot) { if (validSlot(slot)) return send("loadPersonalPreset", slot) }
    function deleteSlot(slot) { if (validSlot(slot)) return send("deletePersonalPreset", slot) }
    function format(control) {
      const value = Number(form[control.key])
      if (!Number.isFinite(value)) return "…"
      if (control.unit === "percent") return Math.round(value * 100) + "%"
      return value.toFixed(control.unit === "seconds" ? 1 : 2) + (control.unit === "seconds" ? " s" : " ×")
    }
    events.on("BeamngWeatherHashk014State", receive)
    onMounted(refresh)
    // useEvents removes its listener automatically when this component unmounts.
    onUnmounted(() => { disposed = true })
    return { state, form, error, editingKey, controls, statusText, presetDescription, refresh, apply, toggle, selectPreset, saveSlot, loadSlot, deleteSlot, format }
  }
}
</script>

<style scoped>
.bweather-settings{--bw-rain:#a0d4e5;--bw-text:#eef5f8;--bw-muted:#b5c9d4;box-sizing:border-box;min-width:0;width:100%;padding:20px 24px;color:var(--bw-text);font:15px/1.4 "Segoe UI",sans-serif}
.bweather-settings *{box-sizing:border-box}
.bweather-settings .bw-heading{display:flex;gap:15px;align-items:center;justify-content:space-between}
.bweather-settings h1{font-size:27px;letter-spacing:-.6px;font-weight:600;margin:0}
.bweather-settings h2{font-size:15px;font-weight:600;margin:0 0 12px}
.bweather-settings .bw-heading p{margin:3px 0 0;color:var(--bw-muted);font-size:13px}
.bweather-settings button,.bweather-settings select{font:inherit;font-size:13px;color:var(--bw-text);background:#304c60;border:1px solid #58788b;border-radius:5px;padding:8px 12px;cursor:pointer}
.bweather-settings button:hover:not(:disabled){background:#42657b}
.bweather-settings button:disabled{opacity:.4;cursor:default}
.bweather-settings .bw-power,.bweather-settings .is-selected{background:#bee4f1;color:#203b4c;border-color:#bee4f1}
.bweather-settings button.is-selected:hover:not(:disabled),.bweather-settings button.bw-power:hover:not(:disabled){background:#d0edf7;color:#203b4c}
.bweather-settings .bw-status{font-size:13px;color:var(--bw-rain);margin:15px 0 0}
.bweather-settings .bw-section{padding:18px 0;border-bottom:1px solid #425c70}
.bweather-settings .bw-presets{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px}
.bweather-settings .bw-hint{font-size:12px;color:var(--bw-muted);margin:9px 0 0}
.bweather-settings .bw-sliders,.bweather-settings .bw-options{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px 26px}
.bweather-settings .bw-slider{display:block;font-size:13px;min-width:0}
.bweather-settings output{float:right;color:var(--bw-rain);font-variant-numeric:tabular-nums}
.bweather-settings input[type=range]{display:block;width:100%;margin:8px 0 0;accent-color:var(--bw-rain);cursor:pointer}
.bweather-settings .bw-quality{display:flex;flex-direction:column;gap:8px;font-size:13px}
.bweather-settings .bw-checks label{display:flex;align-items:center;gap:8px;font-size:12px;margin:8px 0;cursor:pointer}
.bweather-settings input[type=checkbox]{accent-color:var(--bw-rain);margin:0}
.bweather-settings .bw-slots{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.bweather-settings .bw-slot strong{display:flex;justify-content:space-between;gap:8px;font-size:13px;font-weight:600}
.bweather-settings .bw-slot small{font-weight:400;color:var(--bw-muted);font-size:11px}
.bweather-settings .bw-slot>div{display:flex;gap:5px;margin-top:8px;flex-wrap:wrap}
.bweather-settings .bw-slot button{padding:5px 8px;font-size:12px}
.bweather-settings footer{margin-top:15px;font-size:11px;color:var(--bw-muted)}
.bweather-settings .bw-error{font-size:13px;color:#ffcead;overflow-wrap:anywhere}
.bweather-settings button:focus-visible,.bweather-settings input:focus-visible,.bweather-settings select:focus-visible{outline:2px solid #e9f6fc;outline-offset:3px}
@media(max-width:650px){.bweather-settings{padding:16px}.bweather-settings .bw-presets{grid-template-columns:repeat(3,minmax(0,1fr))}.bweather-settings .bw-sliders,.bweather-settings .bw-options{grid-template-columns:1fr}.bweather-settings .bw-slots{grid-template-columns:1fr}}
</style>
