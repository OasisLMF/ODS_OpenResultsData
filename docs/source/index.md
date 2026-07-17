# Open Results Data (ORD)

**ORD** is the open standard for catastrophe-model **results** — a common set of loss
result tables (event loss tables, period loss tables, exceedance-probability tables,
average loss tables) with a consistent, well-defined schema. It is the results counterpart
to [OED](https://github.com/OasisLMF/ODS_OpenExposureData) (exposure data), together forming
the Open Data Standards (ODS) maintained by the ODS Steering Committee.

This site is the reference for the standard. The table and field definitions are generated
directly from the authoritative `Schema/` CSVs in this repository, so they always match the
released specification.

::::{grid} 1 1 2 2
:gutter: 3

:::{grid-item-card} 📖 Explanation
:link: explanation/index
:link-type: doc

What ORD is, its perspectives and summary levels, and the meaning of the key result
concepts (EP curves, TVaR, samples).
:::

:::{grid-item-card} 📋 Reference
:link: reference/index
:link-type: doc

The generated catalogue of ORD tables and the full field list, plus worked examples.
:::
::::

```{toctree}
:hidden:
:maxdepth: 2

explanation/index
reference/index
```
