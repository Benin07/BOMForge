# BOMForge

> Cost intelligence for complex builds — from EPC megaprojects to VLSI components.

BOMForge is a browser-based estimating workspace designed to connect macro-level Engineering, Procurement, and Construction planning with the fast-moving semiconductor supply chain.

It brings deeply nested Bills of Materials, parametric cost modeling, project snapshots, and VLSI lifecycle risk into one clear project-control surface.

## Why BOMForge

Capital projects rarely fail because one line item is difficult to price. They become difficult when thousands of dependent items, disciplines, factors, and supplier signals need to stay aligned.

BOMForge is designed around that problem:

- **One hierarchy:** Model a facility, cleanroom, process system, control board, and VLSI component in one recursive structure.
- **One cost language:** Roll material, labor, equipment, overhead, escalation, and location factors into a single estimate.
- **One change history:** Compare engineering, manufacturing, construction, baseline, and forecast snapshots.
- **One risk view:** Track MPN pricing, stock, lead times, lifecycle status, and obsolescence signals alongside cost.

## Current build

The repository currently contains a polished, self-contained browser prototype and a production-oriented PostgreSQL schema.

### Project control dashboard

- Installed cost, committed cost, remaining scope, and at-risk component metrics.
- Discipline-level cost breakdown for equipment, construction, VLSI and controls, and engineering.
- Supply-chain watchlist with lead-time severity states.
- Recent-activity feed for estimate and procurement changes.

### BOM Explorer

- Hierarchical BOM display with project, assembly, equipment, and VLSI node types.
- Search across node names, codes, MPNs, and disciplines.
- At-risk and VLSI filters.
- CSV export for estimate handoffs.
- UI sized around a 10,000+ node estimate workflow.

### Data model foundation

- Recursive `bom_nodes` table with parent-child relationships.
- PostgreSQL `ltree` materialized paths for fast subtree reads.
- `bom_closure` table for ancestor, descendant, and cost roll-up queries.
- Project snapshots for eBOM, mBOM, construction, baseline, and forecast states.
- Cost models and project factors for labor, material, equipment, overhead, escalation, inflation, and location adjustments.
- VLSI supply snapshots for price breaks, stock, lead time, lifecycle, and obsolescence risk.
- Variance records for engineering-to-manufacturing and baseline-to-current comparisons.

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         BOMForge UI                            │
│  Project dashboard · BOM Explorer · Scenario lab · Supplier watch│
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                    Estimating & rules engine                    │
│  Recursive roll-ups · labor rates · escalation · location factors│
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                         PostgreSQL                              │
│  bom_nodes · bom_closure · snapshots · cost_models · project_factors│
│  vlsi_supply_snapshots · bom_node_variances                     │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                 Supplier and engineering systems                │
│  Octopart · SiliconExpert · DigiKey · ERP / PLM / procurement    │
└─────────────────────────────────────────────────────────────────┘
```

## Repository layout

```text
.
├── index.html       # Browser prototype entry point
├── styles.css       # Responsive BOMForge visual system
├── app.js           # Dashboard, BOM filtering, search, export, and UI state
├── schema.sql       # PostgreSQL 15+ recursive BOM schema
└── README.md        # Project documentation
```

## Run the prototype

No build step is required for the current prototype.

1. Download or clone the repository.
2. Open `index.html` in a modern browser.
3. Select **BOM Explorer** to search and filter the sample hierarchy.
4. Select **View data model** to see the recursive schema concept.

For a local server, use any static file server and open `/index.html` from the project directory.

## Deploy to Vercel

The repository includes a root-level `index.html` and `vercel.json`, so it can be deployed as a static site without a build step.

### Recommended GitHub import

1. Upload the contents of this project to the repository root, including `index.html`, `styles.css`, `app.js`, and `vercel.json`.
2. In Vercel, import the GitHub repository.
3. Leave **Root Directory** set to `.`.
4. Select **Other** or **No Framework**.
5. Leave **Build Command** empty.
6. Leave **Output Directory** as `.`.
7. Deploy and open the generated root URL.

If you keep the files inside `outputs/bomforge` instead, set Vercel's **Root Directory** to `outputs/bomforge` before deploying. Do not deploy the parent folder with the root directory pointing somewhere that does not contain `index.html`.

## PostgreSQL schema

`schema.sql` targets PostgreSQL 15+ and enables the `pgcrypto` and `ltree` extensions.

The key tables are:

| Table | Purpose |
| --- | --- |
| `projects` | Project identity, status, currency, and baseline snapshot |
| `bom_snapshots` | Versioned eBOM, mBOM, construction, baseline, and forecast states |
| `bom_nodes` | Recursive BOM hierarchy and VLSI attributes |
| `bom_closure` | Fast ancestor and descendant traversal |
| `cost_models` | Labor, material, equipment, overhead, and escalation factors |
| `project_factors` | Location, inflation, and project-specific multipliers |
| `vlsi_supply_snapshots` | Supplier price, stock, lead-time, and lifecycle observations |
| `bom_node_variances` | Cost and quantity differences between snapshots |

The schema includes two core functions:

- `bomforge_rollup_cost(...)` recursively calculates installed cost while multiplying quantities through every level of the hierarchy.
- `bomforge_refresh_closure(...)` rebuilds closure rows after a snapshot hierarchy changes.

## Production roadmap

### Phase 1 — Estimating foundation

- Move the prototype into a Next.js App Router application.
- Add Prisma models and SQL migrations for `ltree` and closure-table maintenance.
- Add authenticated project, snapshot, and BOM CRUD APIs.

### Phase 2 — High-volume workflows

- Replace the prototype table with AG Grid Server-Side Row Model.
- Add cursor-based pagination and virtualized rendering for 100,000+ line items.
- Add bulk editing, validation, import templates, and estimate audit history.

### Phase 3 — Live VLSI intelligence

- Add provider adapters for Octopart, SiliconExpert, and DigiKey.
- Normalize MPN, manufacturer, packaging, footprint, stock, and lead-time data.
- Add scheduled refreshes, stale-data indicators, and supplier confidence scores.

### Phase 4 — Enterprise controls

- Add role-based access control and project-level permissions.
- Add approval workflows for estimate baselines and design freezes.
- Add ERP, PLM, procurement, and document-management integrations.

## Design principles

- **Performance first:** Treat large BOMs as data sets, not static tables.
- **Traceable estimates:** Every cost should be explainable back to a node, factor, model, and snapshot.
- **Supplier-aware engineering:** A part is not just a unit cost; it also has availability, lifecycle, and schedule exposure.
- **Snapshot everything:** Preserve the estimate state used for decisions.
- **Keep the model extensible:** EPC disciplines and semiconductor components share the same hierarchy, but not necessarily the same cost rules.

## Project status

The current release is a UI and data-model foundation intended for product exploration, design review, and GitHub showcasing. Supplier integrations, authentication, API persistence, and the full production Next.js stack are planned roadmap items rather than completed features.

## License

Choose and add a license before public distribution. A permissive option such as MIT is a common fit for an open-source starter project.
