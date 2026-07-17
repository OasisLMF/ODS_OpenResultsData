# ORD concepts

ORD covers a suite of model outputs across multiple perspectives and calculations. The most
widely used are the **exceedance-probability (EP) curves**. This page explains the concepts
that the {doc}`result tables <../reference/tables>` and {doc}`fields <../reference/fields>`
encode.

## Perspectives

Results are produced at one or more financial **perspectives**:

- **GUL** — ground-up loss (before insurance terms).
- **IL** — insured loss (after applying policy terms).
- **RI** — reinsurance / net-of-reinsurance loss.

The same table schemas apply at every perspective; the perspective is a property of the
output file, not of the schema.

## Table families

The result tables come in families distinguished by *what* they summarise and *how* the
loss distribution is represented:

- **Event loss tables** (`SELT`, `MELT`, `QELT`) — loss per event.
- **Period loss tables** (`SPLT`, `MPLT`, `QPLT`) — loss per event within each period/year.
- **Exceedance-probability tables** (`EPT`, `PSEPT`) — loss by return period.
- **Average loss table** (`ALT`) — expected (annual average) loss.

Within event and period families the prefix denotes the representation: **S**ample (raw
samples), **M**oment (mean/SD statistics), **Q**uantile (user-specified quantiles). See the
{doc}`tables reference <../reference/tables>` for the full catalogue.

## EP curves: `EPType` and `EPCalc`

The EPT is a set of user-specified percentiles of (typically annual) loss. Each row is keyed
by two coded dimensions.

**`EPType`** — which exceedance metric:

| EPType | Meaning |
| --- | --- |
| 1 | **OEP** — Occurrence EP: the largest single event loss in a year. |
| 2 | **OEP TVaR** — tail value-at-risk of the OEP (mean of losses beyond the return-period threshold). |
| 3 | **AEP** — Aggregate EP: the sum of all event losses in a year. |
| 4 | **AEP TVaR** — tail value-at-risk of the AEP. |

**`EPCalc`** — how the loss for a year is calculated:

| EPCalc | Meaning |
| --- | --- |
| 1 | **Mean damage** — loss from the event mean damage (numerical integration of the damage distributions). |
| 2 | **Full uncertainty** — computed across all samples (samples treated as repeat years); the most accurate single EP curve. |
| 3 | **Per-sample mean** — the average, at each return period, of the per-sample EP curves (see `PSEPT`). |
| 4 | **Sample mean** — loss from the statistical sample event mean. |

`ReturnPeriod` is the reciprocal of the exceedance percentile; `Loss` is the modelled loss.

The **PSEPT** (per-sample EPT) computes the same percentiles *separately for each sample*,
giving one curve per sample — the distribution behind the single `EPCalc` curves above.

## Special sample indices

Sample-level tables use reserved negative `SampleId` (sidx) values for summary statistics:

| sidx | Meaning |
| --- | --- |
| -1 | mean |
| -2 | standard deviation |
| -3 | impacted exposure |
| -4 | chance of loss |
| -5 | maximum loss |

## Summary levels

Results can be output at a variety of **summary levels** — single-way (e.g. by
`OccupancyCode`) or multi-way (e.g. `CountryCode` × `AreaCode` × `LOB`). Each summary is
represented by two files:

- a **link file** mapping each `SummaryId` to the grouping key(s), and
- a **results file** carrying the loss values keyed by `SummaryId`.

This keeps the result tables narrow and uniform regardless of how many dimensions the user
summarised by. For example, a multi-way summary by `CountryCode × AreaCode × LOB` has a link
file with those three columns against `SummaryId`, and result tables that reference only
`SummaryId`.
