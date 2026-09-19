<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->
<template>
  <div class="relationship-explorer-vue">
    <h2>Primate Clade Explorer (Vue Face)</h2>
    <marid-progress :value="progress.value" max="100" :status="progress.status" />

    <div style="margin-top: 1rem;">
      <button @click="runAnalysis">Run Cladistics Analysis</button>
    </div>

    <div v-if="result" style="margin-top: 1rem;">
      <h3>Phylogenetic Topology</h3>
      <pre>{{ result }}</pre>
    </div>

    <h3>Taxa Directory</h3>
    <div v-if="loading">Loading directory...</div>
    <ul v-else>
      <li v-for="taxon in taxa" :key="taxon.id">
        {{ taxon.name }} — <em>{{ taxon.rank }}</em>
      </li>
    </ul>
  </div>
</template>

<script>
import { ref } from "vue";
import { createVueComposables } from "../../../web/vue/src/index.js";
import "../../../web/elements/src/index.js";

export default {
  name: "RelationshipExplorerVue",
  setup() {
    const { useMaridClient, useMaridQuery, useMaridSubscription } = createVueComposables({
      ref,
      inject: (k) => window.__MARID_CLIENT__,
      onUnmounted: (fn) => window.addEventListener("beforeunload", fn)
    });

    const client = useMaridClient();
    const { data: taxa, loading } = useMaridQuery("/api/v1/taxa");
    const progress = ref({ value: 0, status: "Ready" });
    const result = ref(null);

    useMaridSubscription("taxa:updates", {
      onEvent: (evt) => console.log("Vue event:", evt)
    });

    const runAnalysis = async () => {
      progress.value = { value: 50, status: "Computing parsimony..." };
      try {
        const res = await client.fetchJson("/api/v1/analysis", { method: "POST" });
        progress.value = { value: 100, status: "Complete" };
        result.value = res;
      } catch (err) {
        progress.value = { value: 0, status: err.message };
      }
    };

    return { taxa, loading, progress, result, runAnalysis };
  }
};
</script>
