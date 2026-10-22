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
      <section class="bw-section bw-sliders" aria-label="Native clouds">
        <div>
          <h2>Native clouds</h2>
          <div class="bw-choice" @keydown.esc.stop.prevent="openChoice = null">
            <span id="bw-cloud-label">Cloud control</span>
            <button type="button" aria-labelledby="bw-cloud-label bw-cloud-value" aria-controls="bw-cloud-options" :aria-expanded="openChoice === 'cloudMode'" @click="toggleChoice('cloudMode')"><span id="bw-cloud-value">{{ choiceLabel('cloudMode') }}</span><span aria-hidden="true">{{ openChoice === 'cloudMode' ? '−' : '+' }}</span></button>
            <div v-if="openChoice === 'cloudMode'" id="bw-cloud-options" class="bw-choice-options" role="group" aria-label="Cloud control options"><button v-for="option in choices.cloudMode" :key="option.value" type="button" :aria-pressed="form.cloudMode === option.value" :class="{ 'is-selected': form.cloudMode === option.value }" @click="choose('cloudMode', option.value)">{{ option.label }}</button></div>
          </div>
          <p class="bw-hint">Automatic mode uses 80–100% of the native cloud range for a heavily covered sky. Stopping rain restores the previous sky.</p>
          <p v-if="state.clouds?.warning" class="bw-error" role="status">{{ state.clouds.warning }}</p>
        </div>
        <label class="bw-slider">Cloud cover<output>{{ Math.round((form.cloudMode === 'auto' ? state.clouds?.coverage ?? 0 : form.cloudCoverage) * 100) }}%</output><input :value="form.cloudMode === 'auto' ? state.clouds?.coverage ?? 0 : form.cloudCoverage" @input="form.cloudCoverage = Number($event.target.value)" type="range" min="0" max="1" step="0.01" :disabled="form.cloudMode !== 'manual'" aria-label="Cloud cover" @focus="editingKey = 'cloudCoverage'" @blur="editingKey = null" @change="apply('cloudCoverage')"><p class="bw-hint">Adjustable in manual mode. Uses the map's native cloud layers.</p></label>
      </section>
      <section class="bw-section bw-options" aria-label="Performance and rendering">
        <div>
          <div class="bw-choice" @keydown.esc.stop.prevent="openChoice = null">
            <span id="bw-budget-label">Particle budget</span>
            <button type="button" aria-labelledby="bw-budget-label bw-budget-value" aria-controls="bw-budget-options" :aria-expanded="openChoice === 'quality'" @click="toggleChoice('quality')"><span id="bw-budget-value">{{ choiceLabel('quality') }}</span><span aria-hidden="true">{{ openChoice === 'quality' ? '−' : '+' }}</span></button>
            <div v-if="openChoice === 'quality'" id="bw-budget-options" class="bw-choice-options" role="group" aria-label="Particle budget options"><button v-for="option in choices.quality" :key="option.value" type="button" :aria-pressed="form.quality === option.value" :class="{ 'is-selected': form.quality === option.value }" @click="choose('quality', option.value)">{{ option.label }}</button></div>
          </div>
          <p class="bw-hint">{{ state.activeDrops.toLocaleString('en-US') }} active droplets / {{ state.maxDrops.toLocaleString('en-US') }} max.</p>
          <p class="bw-hint">Increasing coverage spreads the same droplets over a larger volume.</p>
          <p class="bw-hint">Native rain coverage profile: {{ state.rainCoverage?.source || 'Mod fallback' }}.</p>
        </div>
        <div class="bw-checks">
          <label><input v-model="form.collisions" type="checkbox" @change="apply('collisions')">Collide with scenery and vehicles</label>
          <label><input v-model="form.wind" type="checkbox" @change="apply('wind')">Follow the map's existing wind</label>
          <label><input v-model="form.lighting" type="checkbox" @change="apply('lighting')">Match droplets to sky lighting</label>
        </div>
      </section>
      <section class="bw-section" aria-label="Vehicle windows">
        <h2>Vehicle windows</h2>
        <div class="bw-checks">
          <label><input v-model="form.cabinProtection" type="checkbox" @change="apply('cabinProtection')">Keep airborne rain outside the cabin</label>
          <label><input v-model="form.glassDrops" type="checkbox" @change="apply('glassDrops')">Enable droplets on detected exterior windows</label>
        </div>
        <div class="bw-sliders"><label v-for="control in glassControls" :key="control.key" class="bw-slider"><span>{{ control.label }}</span><output>{{ format(control) }}</output><input v-model.number="form[control.key]" type="range" :min="control.min" :max="control.max" :step="control.step" :aria-label="control.label" @focus="editingKey = control.key" @blur="editingKey = null" @change="apply(control.key)"></label></div>
        <p class="bw-hint">{{ state.vehicleRain?.panels || 0 }} detected window meshes / {{ state.vehicleRain?.glassDrops || 0 }} surface droplets. Movement follows vehicle velocity. Escape pauses the simulation.</p>
        <p class="bw-hint">Cabin protection uses a conservative envelope near the active vehicle. Disable it for open-top vehicles. Glass damage and moving windows are experimental.</p>
        <p v-if="state.vehicleRain?.warning" class="bw-error" role="status">{{ state.vehicleRain.warning }}</p>
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
    <footer>Settings are saved automatically. Visual rain and window droplets. No puddles or grip changes.</footer>
  </section>
</template>

<script>
import { ref, reactive, computed, onMounted, onUnmounted } from "vue"
import { run } from "@/bridge/libs/Lua.js"
import { useEvents } from "@/services/events"

export default {
  name: "BeamngWeatherPauseSettings",
  setup() {
    const state = ref(null)
    const form = reactive({})
    const error = ref("")
    const editingKey = ref(null)
    const glassControls = [
      { key: "glassAmount", label: "Window droplet amount", min: 0, max: 4, step: 0.05, unit: "factor" },
      { key: "glassScale", label: "Window droplet size", min: 0.5, max: 2, step: 0.05, unit: "factor" },
      { key: "glassDistortion", label: "Refraction strength (0 disables)", min: 0, max: 2, step: 0.05, unit: "factor" }
    ]
    const openChoice = ref(null)
    const choices = {
      cloudMode: [{ value: "auto", label: "Follow rain intensity" }, { value: "manual", label: "Manual cloud cover" }, { value: "map", label: "Keep map settings" }],
      quality: [{ value: "low", label: "Low / 2,400" }, { value: "medium", label: "Balanced / 6,000" }, { value: "high", label: "High / 12,000" }, { value: "ultra", label: "Ultra / 20,000" }]
    }
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
      error.value = ""
      for (const control of [...controls, ...glassControls]) if (editingKey.value !== control.key) form[control.key] = data[control.key]
      for (const key of ["quality", "collisions", "wind", "lighting", "cloudMode", "cloudCoverage", "glassDrops", "cabinProtection"]) if (editingKey.value !== key) form[key] = data[key]
    }
    async function request(method, value = null) {
      let timer
      try {
        // The static lua signature registry does not include third-party extensions.
        const reply = await Promise.race([
          run("extensions.beamngWeather_hashk014.uiRequest", [method, value], {}),
          new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("The rain controller did not respond. Retry after the map has loaded.")), 8000) })
        ])
        if (!reply?.ok || !reply.state) throw new Error(reply?.error || "The rain controller returned an invalid response.")
        receive(reply.state)
      } catch (failure) {
        if (!disposed) error.value = failure.message || "The setting could not be applied. Retry or check the game console."
      } finally {
        clearTimeout(timer)
      }
    }
    function refresh() { return request("getState") }
    function send(method, value) { return request(method, value) }
    function choiceLabel(key) { return choices[key]?.find(option => option.value === form[key])?.label || "Choose an option" }
    function toggleChoice(key) { if (choices[key]) openChoice.value = openChoice.value === key ? null : key }
    function choose(key, value) {
      if (!choices[key]?.some(option => option.value === value)) return
      form[key] = value
      openChoice.value = null
      return apply(key)
    }
    function apply(key) {
      const control = [...controls, ...glassControls].find(item => item.key === key)
      if (control) {
        const value = Number(form[key])
        if (!Number.isFinite(value)) return
        return send("configure", { [key]: Math.max(control.min, Math.min(control.max, value)) })
      }
      if (key === "quality" && ["low", "medium", "high", "ultra"].includes(form.quality)) return send("configure", { quality: form.quality })
      if (key === "cloudMode" && ["auto", "manual", "map"].includes(form.cloudMode)) return send("configure", { cloudMode: form.cloudMode })
      if (key === "cloudCoverage" && Number.isFinite(Number(form.cloudCoverage))) return send("configure", { cloudCoverage: Math.max(0, Math.min(1, Number(form.cloudCoverage))) })
      if (["collisions", "wind", "lighting", "glassDrops", "cabinProtection"].includes(key)) return send("configure", { [key]: !!form[key] })
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
    return { state, form, error, editingKey, openChoice, choices, choiceLabel, toggleChoice, choose, controls, glassControls, statusText, presetDescription, refresh, apply, toggle, selectPreset, saveSlot, loadSlot, deleteSlot, format }
  }
}
</script>

<style scoped>
.bweather-settings{--bw-rain:#f68b1f;--bw-text:#eeeeee;--bw-muted:#bdbdbd;box-sizing:border-box;min-width:0;width:100%;padding:20px 24px;background:#2b2b2b;color-scheme:dark;color:var(--bw-text);font:15px/1.4 "Segoe UI",sans-serif}
.bweather-settings *{box-sizing:border-box}
.bweather-settings .bw-heading{display:flex;gap:15px;align-items:center;justify-content:space-between}
.bweather-settings h1{font-size:27px;letter-spacing:-.6px;font-weight:600;margin:0}
.bweather-settings h2{font-size:15px;font-weight:600;margin:0 0 12px}
.bweather-settings .bw-heading p{margin:3px 0 0;color:var(--bw-muted);font-size:13px}
.bweather-settings button{font:inherit;font-size:13px;color:var(--bw-text);background:#414141;border:1px solid #666666;border-radius:2px;padding:8px 12px;cursor:pointer}
.bweather-settings button:hover:not(:disabled){background:#505050}
.bweather-settings button:disabled{opacity:.4;cursor:default}
.bweather-settings .bw-power,.bweather-settings .is-selected{background:#f68b1f;color:#202020;border-color:#f68b1f}
.bweather-settings button.is-selected:hover:not(:disabled),.bweather-settings button.bw-power:hover:not(:disabled){background:#ffa340;color:#202020}
.bweather-settings .bw-status{font-size:13px;color:var(--bw-rain);margin:15px 0 0}
.bweather-settings .bw-section{padding:18px 0;border-bottom:1px solid #505050}
.bweather-settings .bw-presets{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px}
.bweather-settings .bw-hint{font-size:12px;color:var(--bw-muted);margin:9px 0 0}
.bweather-settings .bw-sliders,.bweather-settings .bw-options{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px 26px}
.bweather-settings .bw-slider{display:block;font-size:13px;min-width:0}
.bweather-settings output{float:right;color:var(--bw-rain);font-variant-numeric:tabular-nums}
.bweather-settings input[type=range]{display:block;width:100%;margin:8px 0 0;accent-color:var(--bw-rain);cursor:pointer}
.bweather-settings .bw-choice{display:flex;flex-direction:column;gap:8px;font-size:13px}
.bweather-settings .bw-choice>button{display:flex;justify-content:space-between;gap:10px;text-align:left;width:100%}
.bweather-settings .bw-choice-options{display:flex;flex-direction:column;gap:4px;padding:6px;background:#242424;border:1px solid #666666}
.bweather-settings .bw-choice-options button{text-align:left;width:100%}
.bweather-settings .bw-checks label{display:flex;align-items:center;gap:8px;font-size:12px;margin:8px 0;cursor:pointer}
.bweather-settings input[type=checkbox]{accent-color:var(--bw-rain);margin:0}
.bweather-settings .bw-slots{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.bweather-settings .bw-slot strong{display:flex;justify-content:space-between;gap:8px;font-size:13px;font-weight:600}
.bweather-settings .bw-slot small{font-weight:400;color:var(--bw-muted);font-size:11px}
.bweather-settings .bw-slot>div{display:flex;gap:5px;margin-top:8px;flex-wrap:wrap}
.bweather-settings .bw-slot button{padding:5px 8px;font-size:12px}
.bweather-settings footer{margin-top:15px;font-size:11px;color:var(--bw-muted)}
.bweather-settings .bw-error{font-size:13px;color:#ffcead;overflow-wrap:anywhere}
.bweather-settings button:focus-visible,.bweather-settings input:focus-visible,.bweather-settings select:focus-visible{outline:2px solid #ffffff;outline-offset:3px}
@media(max-width:650px){.bweather-settings{padding:16px}.bweather-settings .bw-presets{grid-template-columns:repeat(3,minmax(0,1fr))}.bweather-settings .bw-sliders,.bweather-settings .bw-options{grid-template-columns:1fr}.bweather-settings .bw-slots{grid-template-columns:1fr}}
</style>
