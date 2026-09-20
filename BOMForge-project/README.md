# BOMForge

BOMForge is a browser-based EPC cost intelligence workspace for deeply nested BOMs and VLSI supply-chain risk.

## Prototype

Open `index.html` in a browser. The prototype includes:

- A project control dashboard with installed cost, committed cost, open scope, and component-risk metrics.
- Cost breakdown and supply-chain watchlist views.
- A BOM Explorer with filtering, search, hierarchy display, CSV export, and a 10,248-node performance target.
- Snapshot comparison, supplier-sync, and recursive data-model interaction states.

## Data model

`schema.sql` is a PostgreSQL 15+ schema. It uses both a materialized `ltree` path and a `bom_closure` table: the path supports fast subtree reads, while the closure table provides predictable ancestor/descendant queries for recursive cost roll-ups. The schema also includes project snapshots, cost models, project factors, supplier snapshots, and eBOM/mBOM variance records.

The SQL function `bomforge_rollup_cost` recursively sums material, labor, and equipment costs, applying cost-model factors and a location multiplier. `bomforge_refresh_closure` rebuilds closure rows for a snapshot after BOM edits.

## Next production steps

1. Move `app.js` behavior into a Next.js App Router application and replace the prototype table with AG Grid Server-Side Row Model.
2. Add Prisma models matching `schema.sql`, keeping `ltree` and closure-table maintenance in SQL migrations.
3. Replace the simulated supplier state with authenticated Octopart, SiliconExpert, or DigiKey provider adapters.
