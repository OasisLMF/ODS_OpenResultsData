# ORD Results Metadata Schema v2 — Reference Guide

This is a human-readable companion to [`results_metadata_schema_v2.json`](results_metadata_schema_v2.json),
the machine-readable JSON Schema. If the two ever disagree, **the JSON file is
authoritative** — this document is for browsing and onboarding, not validation.

## What this schema is for

Every ORD analysis result set is accompanied by a metadata JSON document that
describes the analysis: who ran it, what model produced it, what event set and
perils were used, what output files/tables exist, and — for grouped analyses —
how the underlying analyses were combined.

The schema has a **platform-neutral core** (works for any modelling platform)
plus two optional extension blocks:

- **`oasis_platform`** — settings specific to the Oasis LMF platform (other
  vendors don't populate this)
- **`vendor_extensions`** — an open slot for any other vendor's own
  platform-specific fields

> Schema v2 incorporates ORD working-group feedback through September 2026:
> GroupMethod codes, nullable `event_set` fields, and platform-neutral
> `perspective_code` handling.

## Required fields

Only three fields are mandatory at the top level:

| Field | Why it's required |
|---|---|
| `model_supplier_id` | Identifies which vendor's model produced the results |
| `model_name_id` | Identifies which model was used |
| `output_sets` | The actual output — without at least one output set, there's nothing to describe |

Everything else is optional, filled in where applicable/known.

---

## Top-level fields

| Field | Type | Required | Description |
|---|---|---|---|
| `version` | string | | The results metadata schema version this document was written against. |
| `analysis_id` | integer or string | | Unique identifier for this analysis, in whatever format the originating platform uses natively. |
| `source_tag` | integer or string | | Labels the origin of the analysis (e.g. platform or portfolio name). |
| `analysis_tag` | integer or string | | Human-readable label for the analysis. |
| `model_supplier_id` | string | **yes** | Identifier for the model vendor/supplier. Used as a compatibility key when grouping analyses. |
| `model_name_id` | string | **yes** | Identifier for the model used. |
| `model_version` | string | | Version of the model used. |
| `model_description` | string | | Human-readable description of the model. |
| `created_at` | string (date-time) | | ISO 8601 timestamp the analysis was run, e.g. `2026-05-01T12:00:00Z`. |
| `currency` | array of string | | ISO 4217 currency code(s) of the output losses, e.g. `["USD"]`. An array (not a single value) so multi-currency grouped analyses can list every currency involved. At least one entry. |
| `number_of_samples` | integer | | Number of samples generated per event. Only meaningful for stochastic (`STOC`) analyses — may be absent or zero for analytical (`MEAN`) or convolution (`CONV`) methods. |
| `loss_methods` | array of string | | Which [LossMethod codes](#lossmethod-codes) appear in this analysis's output files, e.g. `["STOC"]`. Lets a consumer know what's in the files without reading them. |
| `ep_methods` | array of string | | Which [EPMethod codes](#epmethod-codes) appear in the output files, e.g. `["A_MEAN", "S_FULL", "S_PSMN"]`. |
| `c_para_distribution_type` | string | conditional | The parametric distribution used (e.g. `"Beta"`, `"Gamma"`) — **required if `"C_PARA"` appears in `ep_methods`**. Deliberately free-form, not a fixed list, so new distributions don't need a schema change. |
| `event_set` | object | | See [Event set](#event-set). |
| `peril_filter` | array of string | | Peril codes the analysis was filtered to (at least one). OED-based analyses use OED's three-letter peril codes (e.g. `"WSS"`, `"ORF"`); other exposure standards use their own. Omitted entirely if no filter was applied. |
| `exposure_standard` | string | | The exposure data standard for the input portfolio. Well-known values: `OED`, `CEDE` (Moody's/AIR), `EDM` (RMS/Verisk) — other values are allowed for proprietary standards. |
| `output_sets` | array of [Output set](#output-set-one-per-loss-perspective) | **yes** | One entry per loss perspective produced (e.g. GUL, IL, RI). |
| `exposure_summary` | object | | See [Exposure summary](#exposure-summary). |
| `grouping` | object | | See [Grouping settings](#grouping-settings-grouped-analyses-only). |
| `oasis_platform` | object | | See [Oasis platform settings](#oasis-platform-settings-oasis-only). |
| `vendor_extensions` | object | | See [Vendor extensions](#vendor-extensions). |

---

## Event set

`event_set` identifies which event/occurrence set produced the results. Its
fields also double as the raw material for a **GroupEventSetId** in grouped
analyses (see [Grouping settings](#grouping-settings-grouped-analyses-only)) —
which subset of these fields actually gets used to build that ID is controlled
by a separate `group_event_set_fields` parameter (see ORD Combining Results
§7.2).

**Every field here is nullable**, and that's deliberate: since the
GroupEventSetId can be built from *any subset* of these fields, a field that
isn't part of that subset — or just isn't known — must be explicit `null`,
never simply left out of the JSON.

| Field | Type | Description |
|---|---|---|
| `event_set_id` | string or null | Locally unique identifier of the event set file used. |
| `event_set_description` | string or null | Human-readable description of the event set. |
| `event_occurrence_id` | string or null | Locally unique identifier of the occurrence set file used. |
| `event_occurrence_description` | string or null | Human-readable description of the occurrence set. |
| `event_occurrence_max_periods` | integer or null | The occurrence set's timespan, in periods. This directly caps the minimum valid `grouping.group_number_of_periods` — a missing value here is a real functional gap for any grouping operation, not just a cosmetic omission. |

---

## Output set (one per loss perspective)

Each entry in the top-level `output_sets` array describes one loss
perspective's worth of output.

| Field | Type | Required | Description |
|---|---|---|---|
| `perspective_code` | string | **yes** | The loss perspective, e.g. `gul` (ground-up loss), `il` (insured loss), `ri` (reinsurance net), `rl` (reinsurance loss / ceded). These four are the well-known Oasis/OED values — **not a locked enum**; other platforms may use their own conventions. Used as a compatibility key when grouping analyses, and must be consistent within a grouping operation. |
| `exposure_summary_level_fields` | array of string | | The fields used to define exposure summary levels for this output set (OED field names, or the equivalent for other exposure standards). Also a grouping-compatibility key. |
| `summaries` | array of [Summary set](#summary-set) | | The summary sets produced under this output set. |

### Summary set

One entry per summary level (e.g. "Res", "Com", "Total").

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | integer (≥1) | **yes** | Matches `SummaryId` in the ORD output files. |
| `description` | string | | Human-readable label, e.g. `"Res"`, `"Com"`, `"Total"`. Matches `SummaryDescription` in ORDB. |
| `grouping_fields` | array of string | | Fields used to group losses at this summary level. Matches `SummaryField` in ORDB. |
| `oed_fields` | array of string | | **Deprecated** — old name for `grouping_fields`, kept only for backward compatibility. Use `grouping_fields` going forward. |
| `ord_output` | object | | Boolean flags for which ORD output files exist at this summary level — see below. |

#### `ord_output` flags

Every flag defaults to `false`.

| Flag | Output |
|---|---|
| `elt_moment` | Moment Event Loss Table |
| `elt_sample` | Sample Event Loss Table |
| `elt_quantile` | Quantile Event Loss Table |
| `plt_moment` | Moment Period Loss Table |
| `plt_sample` | Sample Period Loss Table |
| `plt_quantile` | Quantile Period Loss Table |
| `alt_period` | Period Average Annual Loss table |
| `alt_meanonly` | Average Annual Loss table (mean only, no SD) |
| `ept_full_uncertainty_aep` | Full-uncertainty aggregate EP curve |
| `ept_full_uncertainty_oep` | Full-uncertainty occurrence EP curve |
| `ept_mean_sample_aep` | Mean-sample aggregate EP curve |
| `ept_mean_sample_oep` | Mean-sample occurrence EP curve |
| `ept_per_sample_mean_aep` | Per-sample-mean aggregate EP curve |
| `ept_per_sample_mean_oep` | Per-sample-mean occurrence EP curve |
| `psept_aep` | Per Sample EP Table (aggregate) |
| `psept_oep` | Per Sample EP Table (occurrence) |
| `qelt` | Quantile Event Loss Table (quantile-based EP variant) |
| `qplt` | Quantile Period Loss Table (quantile-based EP variant) |

---

## Exposure summary

`exposure_summary` is a dictionary keyed by peril code (OED three-letter codes
like `WSS`, `ORF`, or the equivalent for other exposure standards). Each value
is an **exposure summary for a peril**:

| Field | Type | Description |
|---|---|---|
| `number_of_locations` | integer | Default `0`. |
| `number_of_buildings` | integer | Default `0`. |
| `number_of_risks` | integer | Default `0`. |
| `tiv_by_coverage` | object | TIV broken down by coverage type — see below. |

### TIV by coverage type

Standard OED types (`buildings`, `other`, `contents`, `bi`) are always
included; the extended types are zero-filled where not applicable. All
default to `0`.

`buildings` · `other` · `contents` · `bi` · `binp` (BI non-physical) ·
`cbi` (contingent BI) · `dias` · `ext` (extended coverage) ·
`fin` (fine arts / inland marine) · `inre` (inland/re) · `liab` (liability) ·
`reg` (regulatory) · `eno` (errors and omissions)

---

## Grouping settings (grouped analyses only)

The `grouping` block is populated when an analysis is part of, or a candidate
for, a **grouped** result — i.e. its results are (or could be) combined with
other compatible analyses into a GPLT/GALT/GEPT grouped output.

| Field | Type | Description |
|---|---|---|
| `group_methods` | array of string | Which [GroupMethod codes](#groupmethod-codes) appear in the grouped output files, e.g. `["RSAM", "RSSD"]`. |
| `group_event_set_id` | string | Opaque identifier shared by analyses with compatible event sets. **Treat as an opaque string** — never parse or assume a structure, it varies by platform. |
| `group_number_of_periods` | integer (≥1) | Number of periods used in the grouped analysis. Must be at least the largest `event_set.event_occurrence_max_periods` across every event set being grouped. |
| `group_elt_format_selection` | string, one of `moment` / `quantile` / `sample` | Which ELT format is used for loss severity sampling in the grouped analysis. |
| `group_fill_perspectives` | boolean (default `false`) | Whether a missing perspective is filled from an available one during grouping (e.g. deriving net from gross). |
| `was_filled` | boolean (default `false`) | Whether *this output set's* perspective was itself filled from another during grouping — lets a consumer detect a fill without having to infer it from the perspective code. |
| `source_perspective` | string | If `was_filled` is true, which perspective it was filled from. |
| `global_alpha` | number, 0–1 | Gaussian copula correlation parameter applied across every model in the group. Overridden per-model or per-summary below. |
| `alpha_by_model` | array of [Alpha by model](#alpha-overrides) | Per-model overrides of `global_alpha`. |
| `alpha_by_summary` | array of [Alpha by model + summary](#alpha-overrides) | Per-model-and-summary overrides — takes precedence over both `alpha_by_model` and `global_alpha`. |

### Alpha overrides

**Alpha by model** — `model_supplier_id`, `model_name_id`, `alpha` (0–1, all required).

**Alpha by model and summary** — `model_supplier_id`, `model_name_id`,
`perspective_code`, `summary_id`, `alpha` (0–1, all required).

### Why `GroupMethod` and not `EPMethod`/`LossMethod`?

Grouped output tables (GPLT, GALT, GEPT) use `GroupMethod` instead of
`EPMethod`/`LossMethod`. Return periods in grouped tables come from the
*relative frequency* of group events, not EP-curve construction, so there's
no EP-variant to track. See [GroupMethod codes](#groupmethod-codes) below for
why the analytical mean is excluded.

---

## Oasis platform settings (Oasis only)

`oasis_platform` consolidates the fields that only make sense on the Oasis
LMF platform — other vendors shouldn't populate this block. (This mirrors how
OED itself handles non-standard, platform-specific fields.)

| Field | Type | Description |
|---|---|---|
| `oed_version` | string | The input exposure file's OED schema version, `major.minor.patch` (e.g. `2.0.0`). Only meaningful when `exposure_standard` is `OED`. |
| `pla` | boolean (default `false`) | Whether Post Loss Amplification was applied. |
| `pla_settings` | object | PLA parameters, populated when `pla` is true — see below. |
| `do_disaggregation` | boolean (default `true`) | Whether OED disaggregation was applied to split terms/conditions for aggregate exposure. |
| `join_summary_info` | boolean (default `false`) | Whether summary info data was joined onto the output files. |
| `correlation_settings` | array of objects | Hazard/damage correlation settings actually used (see below). Oasis-specific — other vendors typically apply correlation inside the model, before output, and may not expose these parameters at all. |

### `pla_settings`

| Field | Type | Description |
|---|---|---|
| `pla_secondary_factor` | number, 0–1 (default `1`) | |
| `pla_uniform_factor` | number, ≥0 (default `0`) | |

### `correlation_settings` (per entry)

| Field | Type | Description |
|---|---|---|
| `peril_correlation_group` | integer (≥1) | |
| `hazard_correlation_value` | number, 0–1 | |
| `damage_correlation_value` | number, 0–1 | |

---

## Vendor extensions

`vendor_extensions` is an open slot for anything platform-specific that isn't
covered by the neutral core or by `oasis_platform`. Each key should identify
the vendor (e.g. `"verisk"`, `"moodys"`); the value's internal shape is
entirely up to that vendor. Fields that turn out to be broadly useful are
candidates for promotion into the core schema in a future version.

---

## Known code values

These are the string codes referenced by `loss_methods`, `ep_methods`, and
`grouping.group_methods`. All three are **open** string arrays in the schema
(not enums) — new codes can appear without a schema change — but these are
the values defined so far.

### LossMethod codes

| Code | Formerly (v1) | Meaning |
|---|---|---|
| `MEAN` | `ANLM` | Analytical mean |
| `STOC` | `STOC` | Stochastic sampling |
| `CONV` | `CONV` | Numerical convolution |

### EPMethod codes

The prefix tells you the LossMethod: `A_` = analytical (`MEAN`), `S_` =
stochastic (`STOC`), `C_` = convolution (`CONV`).

| Code | Meaning |
|---|---|
| `A_MEAN` | Analytical mean EP |
| `S_FULL` | Stochastic full uncertainty |
| `S_PSMN` | Stochastic per-sample mean |
| `S_MEAN` | Stochastic mean |
| `C_MEAN` | Convolution mean |
| `C_PARA` | Convolution with parametric uncertainty — requires `c_para_distribution_type` |

### GroupMethod codes

Used only in grouping — never mixed with `EPMethod`/`LossMethod` on the same
table. **`MEAN` (analytical mean) is not valid here**: it's not meaningful to
group analytical-mean analyses. All three GroupMethods can combine `STOC`
and/or `CONV` loss inputs.

| Code | Meaning |
|---|---|
| `MEAN` | Grouped Means — group losses derive from the summed/maximum event mean of the underlying analyses. |
| `RSAM` | Resampled secondary uncertainty — group event losses from the summed/maximum of resampled losses from the underlying event severity distributions; inter-GroupEventSet correlation is zero, or imposed by alpha factors. |
| `RSSD` | Resampled secondary uncertainty using summed decomposed event standard deviations — group event losses from resampled losses; group event standard deviations from summing decomposed correlated and independent standard deviations that capture internally-derived correlation by event. **Requires decomposed event standard deviations in the input ELTs.** |

### `perspective_code` well-known values

Not an enum — any string is valid — but these four are the well-known
Oasis/OED values:

| Code | Meaning |
|---|---|
| `gul` | Ground-up loss |
| `il` | Insured loss |
| `ri` | Reinsurance net — the cedant's loss retained after reinsurance recoveries |
| `rl` | Reinsurance loss — the ceded amount recovered from reinsurers (distinct from `ri`) |

### `exposure_standard` well-known values

| Code | Meaning |
|---|---|
| `OED` | Open Exposure Data |
| `CEDE` | Moody's/AIR |
| `EDM` | RMS/Verisk |
