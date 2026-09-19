// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import React, { useState } from "react";
import { createMaridContext } from "../../../web/react/src/index.js";
import "../../../web/elements/src/index.js";

const { useMaridClient, useMaridQuery, useMaridSubscription } = createMaridContext(React);

export function RelationshipExplorerReact() {
  const client = useMaridClient();
  const { data: taxa, loading } = useMaridQuery("/api/v1/taxa");
  const [progress, setProgress] = useState({ value: 0, status: "Idle" });
  const [result, setResult] = useState(null);

  // Live updates subscription
  useMaridSubscription("taxa:updates", {
    onEvent: (evt) => {
      console.log("Live update received:", evt);
    }
  });

  const handleRunAnalysis = async () => {
    setProgress({ value: 30, status: "Calculating character distances..." });
    try {
      const res = await client.fetchJson("/api/v1/analysis", { method: "POST" });
      setProgress({ value: 100, status: "Analysis Complete" });
      setResult(res);
    } catch (err) {
      setProgress({ value: 0, status: `Error: ${err.message}` });
    }
  };

  return (
    <div className="relationship-explorer">
      <h2>Primate Clade Explorer (React)</h2>
      <marid-progress value={progress.value} max="100" status={progress.status} />
      <button onClick={handleRunAnalysis} style={{ marginTop: "1rem" }}>
        Run Cladistics Analysis
      </button>

      {result && (
        <div style={{ marginTop: "1rem" }}>
          <h3>Analysis Output</h3>
          <pre>{JSON.stringify(result, null, 2)}</pre>
        </div>
      )}

      <h3>Known Taxa</h3>
      {loading ? <p>Loading taxa...</p> : (
        <ul>
          {taxa && taxa.map((t) => (
            <li key={t.id}>{t.name} ({t.rank})</li>
          ))}
        </ul>
      )}
    </div>
  );
}
