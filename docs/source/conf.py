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
# -- Oasis shared branding (logo, palette, home link) -----------------------
import os as _os_brand
if globals().get("html_theme") == "furo":
    if "_static" not in (globals().get("html_static_path") or []):
        html_static_path = list(globals().get("html_static_path") or []) + ["_static"]
    try:
        html_theme_options
    except NameError:
        html_theme_options = {}
    html_theme_options.setdefault("light_logo", "OASIS_LMF_COLOUR.png")
    html_theme_options.setdefault("dark_logo", "OASIS_LMF_WHITE.png")
    _lcv = html_theme_options.setdefault("light_css_variables", {})
    _lcv.setdefault("color-brand-primary", "#862633")
    _lcv.setdefault("color-brand-content", "#d22630")
    _lcv.setdefault("font-stack", "Raleway, sans-serif")
    _dcv = html_theme_options.setdefault("dark_css_variables", {})
    _dcv.setdefault("color-brand-primary", "#e2919b")
    _dcv.setdefault("color-brand-content", "#ef8b93")
    _home = _os_brand.environ.get("OASIS_DOCS_HOME", "https://oasislmf.github.io/index.html")
    html_theme_options.setdefault(
        "announcement",
        '<a href="' + _home + '" style="color:inherit;font-weight:600;text-decoration:none">'
        '&#8962; Oasis documentation home</a>')
    if "https://fonts.googleapis.com/css?family=Raleway" not in (globals().get("html_css_files") or []):
        html_css_files = list(globals().get("html_css_files") or []) + ["https://fonts.googleapis.com/css?family=Raleway"]
