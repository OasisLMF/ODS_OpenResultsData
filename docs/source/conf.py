"""Sphinx configuration for the Open Results Data (ORD) standard reference site.

The field/table reference is generated at build time from the ``Schema/`` CSVs by
the local ``gen_ord_reference`` extension (single source of truth). Theme and MyST
setup mirror the other OasisLMF documentation sites for a consistent aggregated site.
"""
import datetime
import os
import sys

# make the local extension importable
sys.path.insert(0, os.path.abspath("_ext"))

# -- Project information -----------------------------------------------------
project = "Open Results Data (ORD)"
author = "Oasis LMF"
copyright = f"{datetime.date.today().year} Oasis LMF"

# -- General configuration ---------------------------------------------------
extensions = [
    "myst_parser",        # Markdown (MyST)
    "sphinx_design",      # grids / cards for the landing page
    "sphinx_copybutton",  # copy button on code blocks
    "gen_ord_reference",  # build-time reference generation from Schema/*.csv
]

source_suffix = {".rst": "restructuredtext", ".md": "markdown"}
master_doc = "index"
language = "en"
# _generated/*.md are include-only fragments, not standalone documents
exclude_patterns = ["reference/_generated/**"]

myst_enable_extensions = ["colon_fence", "deflist", "substitution", "tasklist"]
myst_heading_anchors = 6

# -- HTML output -------------------------------------------------------------
html_theme = "furo"
html_title = "Open Results Data (ORD)"
html_static_path = ["_static"] if os.path.isdir(os.path.join(os.path.dirname(__file__), "_static")) else []


# -- Cross-component links (intersphinx, aggregated site) --------------------
# The GenerateDocs orchestrator sets OASIS_INTERSPHINX_MAP (JSON) to point cross-references at
# the other components' built inventories; standalone builds add nothing. Use explicit roles,
# e.g. {external+ord:doc}`reference/tables` or :external+oed:ref:`some-label`.
import json as _ix_json, os as _ix_os
if "sphinx.ext.intersphinx" not in extensions:
    extensions = list(extensions) + ["sphinx.ext.intersphinx"]
try:
    intersphinx_mapping
except NameError:
    intersphinx_mapping = {}
intersphinx_mapping.update({
    _k: (_v[0], _v[1])
    for _k, _v in _ix_json.loads(_ix_os.environ.get("OASIS_INTERSPHINX_MAP", "{}")).items()
})
