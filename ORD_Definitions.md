# ORD Output Definitions

> **ORD v2 open questions** (raised in the ORD working group, not yet resolved —
> flagged here rather than implemented in the relational model):
> 1. `group_number_of_periods` placement (Joh Carter): should this live in a
>    dedicated "grouping params" table rather than a metadata/settings table?
>    If so, what is its PK/FK structure?
> 2. Backward-compatibility mechanism for v1/v2 coexistence: Oasis LMF v2.6.0
>    supports v1 and v2 in parallel until January 2028 — version flag on the
>    analysis record vs. separate table sets vs. a conversion view?
> 3. Should `SummaryInfo`/`GroupSummaryInfo` gain explicit boolean output-type
>    flag columns (`qelt`, `qplt`, and the rest of `ord_output`), mirroring the
>    results metadata schema, or should that stay file/JSON-only?

ORD covers an extensive suite of model outputs for multiple perspectives and calculations. The key ORD outputs and the ones most typically used in cat modelling are the exceedance probability (EP) curves.

The detailed ORD outputs are outlined in the data sepc doc:

https://github.com/OasisLMF/OpenDataStandards/tree/master/OpenResultsData/Docs

&nbsp;

## Probability Table (EPT) 

The calculation of EPTs depends on the mathematical methodology of calculating the underlying ground up and insured losses.
In the Oasis kernel the methodology is Monte Carlo Sampling from damage distributions, which results in several samples (realisations) of an event loss for every event in the model's catalogue. The event losses are assigned to a year timeline and the years are rank ordered by loss. The method of computing the percentiles is by taking the ratio of the frequency of years with a loss exceeding a given threshold over the total number of years.
The EPT in ORD is a set of user-specified percentiles of (typically) annual loss and contains the following data fields:
•	SummaryID: Summary level groupings from OED

> **ORD v2 note:** `EPCalc` (integer) is renamed **`EPMethod`** and `EPType`
> moves from an integer code to a string code, both as part of the wider ORD v2
> move from integer codes to human-readable string codes across output files.
> The legacy v1 integers are shown below for traceability only.

**LossMethod** (renamed from `LossType` in ORD v1) describes how a loss was
calculated, independent of any specific output table:

| Code | v1 code | Description |
|------|---------|-------------|
| `MEAN` | `ANLM` | Analytical mean |
| `STOC` | `STOC` | Stochastic sampling |
| `CONV` | `CONV` | Numerical convolution |

**EPMethod** (replaces the integer `EPCalc`):

| Code | v1 int (`EPCalc`) | Description |
|------|-------------------|-------------|
| `A_MEAN` | 1 (Mean Damage Ratio) | Analytical mean EP — the loss calculation for a year using the event mean damage loss computed by numerical integration of the effective damageability distributions. |
| `S_FULL` | 2 (Full Uncertainty) | Stochastic full uncertainty — the calculation across all samples (treating the samples effectively as repeat years) — this is the most accurate of all the single EP Curves. |
| `S_PSMN` | 3 (Per Sample Mean) | Stochastic per-sample mean — the average of the losses at each return period of the Per Sample EPT (see PSEPT below). |
| `S_MEAN` | 4 (Sample Mean) | Stochastic mean — the loss calculation for a year using the statistical sample event mean. |
| `C_MEAN` | (new) | Convolution mean. |
| `C_PARA` | (new) | Convolution with parametric uncertainty. When present, the distribution type used is recorded in results metadata as `c_para_distribution_type` (free-form string). |

The code prefix indicates the associated LossMethod: `A_` → `MEAN` (analytical),
`S_` → `STOC` (stochastic), `C_` → `CONV` (convolution).

&nbsp;

**EPType** (replaces the integer `EPType`):

| Code | v1 int | Description |
|------|--------|-------------|
| `OEP` | 1 | Occurrence Exceedance Probability — maximum of any one event's losses in a year. |
| `AEP` | 2 (was AEP) / 3 | Aggregate Exceedance Probability — sum of losses from all events in a year. |
| `TVAR_OEP` | (was OEP TVaR) | Tail Value at Risk / TCE (Tail Conditional Expectation) — computed by averaging the rank ordered losses exceeding a given return period loss from the respective OEP result. |
| `TVAR_AEP` | (was AEP TVaR) | Tail Value at Risk / TCE — computed by averaging the rank ordered losses exceeding a given return period loss from the respective AEP result. |

**ReturnPeriod:** Represents the reciprocal of the percentile

**Loss:** Modelled loss

&nbsp;

## Per Sample Exceedance Probability Table (PSEPT)

Similarly to the EPT, the PSEPT is a set of user specified percentiles calculated separately for each sample, resulting in many curves (one loss curve per sample) and contains the following data fields:

**• SummaryID:**	Summary level groupings from OED

**•	SampleID:** Refers to the sample number from the user defined set

**•	EPType:** Same as EPT

**•	ReturnPeriod:** Same as EPT

**•	Loss:** Same as EPT


&nbsp;

## Event Loss Tables (ELT)

There are multiple ELTs in ORD format that contain the losses by event at each summary level.

**• Event Loss Table (SELT):** Sample losses for each event at the appropriate summary level.

**•	Moment Event Loss Table (MELT):** Summary stats (mean and standard deviation) for each event at the appropriate summary level, along with the event’s annual rate of occurrence.

**• Quantile Event Loss Table (QELT):** Distribution of losses at user specified quantiles for each 
event at the appropriate summary level.

&nbsp;

## Period Loss Tables (PLT)

The detailed event losses of the ELT’s are organised into periods according to how events are assigned to those periods in the occurrence timeline. A period is typically a year, however in ORD loss can be represented over any period of time and referred to as a ‘period’. 
As for events, the same statistical variants are available for periods at each summary level as follows:

**•	Moment Period Loss Table (MPLT)** - Summary stats (mean, event rates, standard deviation, etc) for each event within each period at the appropriate summary level.

**•	Quantile Period Loss Table (QPLT)** - Distribution of losses at user specified quantiles for each event within each period at the appropriate summary level

**•	Sample Period Loss Table (SPLT)** - Sample losses for each event within each period at the appropriate summary level

&nbsp;

## Average Loss Table (PALT)

Commonly known as the Average Annual Loss ‘AAL’, the Period Average Loss Table (PALT) is the high level statistical summary of the mean and standard deviation of loss over all periods.

&nbsp;

## Grouped Analysis (ORD v2)

ORD v2 introduces grouped output tables — **GPLT** (Group Period Loss Table),
**GALT** (Group Annual Loss Table), and **GEPT** (Group Exceedance Probability
Table) — for combining results from multiple compatible analyses. Grouped
tables use **GroupMethod** in place of LossMethod/EPMethod; they don't carry an
EPMethod because return periods in grouped tables are determined by the
relative frequency of group events rather than EP curve construction.

**GroupMethod:**

| Code | Int | Description |
|------|-----|-------------|
| `MEAN` | 1 | Grouped Means — group losses derive from summed/maximum event mean of underlying analyses. |
| `RSAM` | 2 | Resampled secondary uncertainty — group event losses from summed/maximum of resampled losses from underlying event severity distributions; inter-GroupEventSet correlation is zero or imposed by alpha factors. |
| `RSSD` | 3 | Resampled secondary uncertainty using sum of decomposed event standard deviations — group event losses from resampled losses; group event standard deviations from summing of decomposed correlated and independent standard deviations capturing internally derived correlation by event; requires decomposed event standard deviations in input ELTs. |

The analytical mean LossMethod (`MEAN`, formerly `ANLM`) is **not** a valid
GroupMethod — it's not valid to group analytical mean analyses. All three
GroupMethods can combine `STOC` and `CONV` loss inputs; `RSSD` additionally
requires decomposed event standard deviations in the input ELTs.

**GroupEventSet:** identifies a set of analyses with compatible event sets that
can be combined in a grouped analysis. `GroupEventSetId` is an opaque
string — its internal structure is platform-specific and should be treated as
opaque for comparison, never parsed.

The `GroupEventSetId` is generated from a configurable subset of event set
fields, controlled by a `group_event_set_fields` parameter. Because the id may
be generated from any subset of the available fields, **all** contributing
fields must be nullable, with `null` meaning "not one of the fields used to
generate this id" rather than "unknown":

- `EventSetId`
- `EventSetDescription`
- `EventOccurrenceId`
- `EventOccurrenceDescription`
- `EventOccurrenceMaxPeriods`

In the relational model these fields live on `EventOccurrenceSet`, and
`GroupEventSet` references it via `event_occurrence_set_id`.
