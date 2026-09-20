-- BOMForge recursive EPC + VLSI estimating schema
-- PostgreSQL 15+. The materialized path accelerates subtree reads;
-- bom_closure supports fast ancestor/descendant and roll-up queries.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TYPE project_status AS ENUM ('DRAFT', 'ACTIVE', 'ON_HOLD', 'COMPLETE', 'ARCHIVED');
CREATE TYPE bom_node_type AS ENUM ('PROJECT', 'DISCIPLINE', 'ASSEMBLY', 'EQUIPMENT', 'MATERIAL', 'PART', 'VLSI_COMPONENT');
CREATE TYPE bom_lifecycle AS ENUM ('UNKNOWN', 'ACTIVE', 'NRND', 'EOL', 'OBSOLETE');
CREATE TYPE snapshot_kind AS ENUM ('ENGINEERING', 'MANUFACTURING', 'CONSTRUCTION', 'BASELINE', 'FORECAST');

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  status project_status NOT NULL DEFAULT 'DRAFT',
  baseline_snapshot_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE bom_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  kind snapshot_kind NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  source_snapshot_id UUID REFERENCES bom_snapshots(id),
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  captured_by TEXT NOT NULL,
  notes TEXT,
  UNIQUE (project_id, kind, version)
);

ALTER TABLE projects ADD CONSTRAINT projects_baseline_snapshot_fk
  FOREIGN KEY (baseline_snapshot_id) REFERENCES bom_snapshots(id) ON DELETE SET NULL;

CREATE TABLE bom_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id UUID NOT NULL REFERENCES bom_snapshots(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES bom_nodes(id) ON DELETE CASCADE,
  node_type bom_node_type NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  path LTREE NOT NULL,
  depth INTEGER NOT NULL DEFAULT 0 CHECK (depth >= 0),
  sort_order INTEGER NOT NULL DEFAULT 0,
  quantity NUMERIC(20,6) NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  unit TEXT NOT NULL DEFAULT 'ea',
  material_unit_cost NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (material_unit_cost >= 0),
  labor_hours NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (labor_hours >= 0),
  equipment_unit_cost NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (equipment_unit_cost >= 0),
  cost_model_id UUID,
  manufacturer TEXT,
  manufacturer_part_number TEXT,
  lifecycle_status bom_lifecycle NOT NULL DEFAULT 'UNKNOWN',
  footprint TEXT,
  lead_time_days INTEGER CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
  is_virtual BOOLEAN NOT NULL DEFAULT false,
  source_system TEXT,
  external_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (snapshot_id, code),
  UNIQUE (id, snapshot_id)
);

CREATE INDEX bom_nodes_snapshot_path_gist ON bom_nodes USING GIST (path);
CREATE INDEX bom_nodes_snapshot_parent_idx ON bom_nodes (snapshot_id, parent_id, sort_order);
CREATE INDEX bom_nodes_mpn_idx ON bom_nodes (manufacturer_part_number) WHERE manufacturer_part_number IS NOT NULL;
CREATE INDEX bom_nodes_lead_time_idx ON bom_nodes (lead_time_days) WHERE lead_time_days IS NOT NULL;

CREATE TABLE bom_closure (
  snapshot_id UUID NOT NULL REFERENCES bom_snapshots(id) ON DELETE CASCADE,
  ancestor_id UUID NOT NULL REFERENCES bom_nodes(id) ON DELETE CASCADE,
  descendant_id UUID NOT NULL REFERENCES bom_nodes(id) ON DELETE CASCADE,
  depth INTEGER NOT NULL CHECK (depth >= 0),
  PRIMARY KEY (ancestor_id, descendant_id),
  CHECK ((depth = 0 AND ancestor_id = descendant_id) OR depth > 0)
);

CREATE INDEX bom_closure_descendant_idx ON bom_closure (descendant_id, depth);
CREATE INDEX bom_closure_rollup_idx ON bom_closure (ancestor_id, depth, descendant_id);

CREATE TABLE cost_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  labor_rate NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (labor_rate >= 0),
  material_factor NUMERIC(12,6) NOT NULL DEFAULT 1 CHECK (material_factor >= 0),
  equipment_rate NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (equipment_rate >= 0),
  overhead_factor NUMERIC(12,6) NOT NULL DEFAULT 1 CHECK (overhead_factor >= 0),
  escalation_factor NUMERIC(12,6) NOT NULL DEFAULT 1 CHECK (escalation_factor >= 0),
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (project_id, name, effective_from),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

ALTER TABLE bom_nodes ADD CONSTRAINT bom_nodes_cost_model_fk
  FOREIGN KEY (cost_model_id) REFERENCES cost_models(id) ON DELETE SET NULL;

CREATE TABLE project_factors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  factor_key TEXT NOT NULL,
  factor_value NUMERIC(20,8) NOT NULL,
  unit TEXT,
  source TEXT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  UNIQUE (project_id, factor_key, effective_from),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE vlsi_supply_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bom_node_id UUID NOT NULL REFERENCES bom_nodes(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  price_breaks JSONB NOT NULL DEFAULT '[]'::jsonb,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  stock_quantity NUMERIC(20,6),
  lead_time_days INTEGER CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
  lifecycle_status bom_lifecycle,
  obsolescence_risk NUMERIC(5,4) CHECK (obsolescence_risk BETWEEN 0 AND 1),
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX vlsi_supply_latest_idx ON vlsi_supply_snapshots (bom_node_id, fetched_at DESC);

CREATE TABLE bom_node_variances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_node_id UUID NOT NULL REFERENCES bom_nodes(id) ON DELETE CASCADE,
  comparison_node_id UUID REFERENCES bom_nodes(id) ON DELETE SET NULL,
  quantity_delta NUMERIC(20,6) NOT NULL DEFAULT 0,
  unit_cost_delta NUMERIC(20,6) NOT NULL DEFAULT 0,
  extended_cost_delta NUMERIC(20,6) NOT NULL DEFAULT 0,
  variance_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION bomforge_rollup_cost(p_node_id UUID, p_location_factor NUMERIC DEFAULT 1)
RETURNS NUMERIC
LANGUAGE SQL
STABLE
AS $$
  WITH RECURSIVE descendants AS (
    SELECT n.id, n.parent_id, n.quantity AS multiplied_quantity,
           n.material_unit_cost, n.labor_hours, n.equipment_unit_cost,
           n.cost_model_id
    FROM bom_nodes n WHERE n.id = p_node_id
    UNION ALL
    SELECT child.id, child.parent_id, d.multiplied_quantity * child.quantity,
           child.material_unit_cost, child.labor_hours, child.equipment_unit_cost,
           child.cost_model_id
    FROM bom_nodes child JOIN descendants d ON child.parent_id = d.id
  )
  SELECT COALESCE(SUM(
    d.multiplied_quantity * (
      (d.material_unit_cost * COALESCE(cm.material_factor, 1)) +
      (d.labor_hours * COALESCE(cm.labor_rate, 0)) +
      (d.equipment_unit_cost * COALESCE(cm.equipment_rate, 1))
    ) * COALESCE(cm.overhead_factor, 1) * COALESCE(cm.escalation_factor, 1) * p_location_factor
  ), 0)
  FROM descendants d LEFT JOIN cost_models cm ON cm.id = d.cost_model_id;
$$;

CREATE OR REPLACE FUNCTION bomforge_refresh_closure(p_snapshot_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM bom_closure WHERE snapshot_id = p_snapshot_id;
  INSERT INTO bom_closure (snapshot_id, ancestor_id, descendant_id, depth)
  WITH RECURSIVE tree AS (
    SELECT n.id AS ancestor_id, n.id AS descendant_id, 0 AS depth
    FROM bom_nodes n WHERE n.snapshot_id = p_snapshot_id
    UNION ALL
    SELECT t.ancestor_id, child.id, t.depth + 1
    FROM tree t JOIN bom_nodes child ON child.parent_id = t.descendant_id
    WHERE child.snapshot_id = p_snapshot_id
  ) SELECT p_snapshot_id, ancestor_id, descendant_id, depth FROM tree;
END;
$$;
