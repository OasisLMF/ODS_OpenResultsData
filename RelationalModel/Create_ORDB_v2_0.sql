/*
================================================================================
  Open Results Database (ORDB) v2.0 — Schema Creation Script
  SQL Server (tested with compatibility level 100 / SQL Server 2008+)
================================================================================

  PURPOSE
  -------
  Creates a blank ORDB database and its full table schema. This relational
  schema is the SQL Server equivalent of the Open Results Data (ORD) file-based
  standard (CSV/Parquet data files + JSON metadata) plus new group and event tables
  for grouped analyses.

  ORD v2 is a breaking change to column names and coded values versus ORD v1
  (see CHANGE LOG below). Oasis LMF v2.6.0 supports v1 and v2 in parallel until
  January 2028 — this script is additive (Create_ORDB_v1_3.sql / v1_4.sql are
  untouched) so a v1 database can still be stood up from this repo alongside v2.

  OPEN QUESTIONS (raised in the ORD working group, not yet resolved — flagged
  here rather than implemented; do not treat any of the below as decided):
    1. group_number_of_periods placement (Joh Carter): should this live in a
       dedicated "grouping params" table rather than a metadata/settings table?
       If so, what is its PK/FK structure? Not added to this schema pending
       resolution.
    2. Backward-compatibility mechanism for v1/v2 coexistence until Jan 2028:
       version flag on the analysis record vs. separate table sets vs. a
       conversion view? Not implemented here.
    3. Should SummaryInfo / GroupSummaryInfo gain explicit boolean output-type
       flag columns (qelt, qplt, and the rest of ord_output from the v2 results
       metadata schema), mirroring the JSON schema, or should that stay
       file/JSON-only? Not added to this schema pending resolution.

  NAMING CONVENTIONS
  ------------------
  Tables:
    - PascalCase for structural / metadata tables   (e.g. Analysis, GroupSet)
    - UPPERCASE abbreviations for results tables     (e.g. ELT, GAAL, EP_Samples)

  Columns:
    - snake_case for relational / metadata columns   (e.g. analysis_id, output_set_id)
      Mirrors the JSON metadata layer of the ORD file-based standard.
    - PascalCase for data / results columns  (e.g. MeanLoss, EventId, SDLoss)
      Mirrors the CSV/Parquet column headers of the ORD file-based standard.

  This deliberate split preserves look-across comparability between the
  relational schema and its file-based counterpart.

  Foreign Keys:
    - Explicitly named using the pattern FK_<ChildTable>_<ParentTable>_<column>

  Primary Keys (results tables):
    - Explicitly named using the pattern PK_<Table>
    - Composite clustered PKs covering the natural key of each results table
    - Key columns are NOT NULL (required by SQL Server for PK membership)

  Non-Clustered Indexes:
    - Named using the pattern IX_<Table>_<columns>
    - Added on the most frequently filtered columns: EventId, SummaryId,
      ReturnPeriod, and Period

  Default Values (for nullable columns):
    - NVARCHAR / string types:  DEFAULT ''
    - INT / TINYINT types:      DEFAULT 0
    - FLOAT types:              DEFAULT 0.0
    - DATETIME types:           No default (NULL)

  CHANGE LOG
  ----------
  v2.0  – ORD v2: legacy integer codes replaced with human-readable string codes,
           normalised into lookup tables per the pattern agreed with Jeremy
           Zechar — string `Code` appears in ORD output files as-is; the
           relational model stores an INT surrogate key for FK efficiency, with
           a `LegacyCode`/`LegacyInt` column retained for v1 traceability, and a
           `vw_*` view per affected results table to reconstruct the string
           codes for consumers.
           Added lookup tables: LossMethod (STOC, CONV, MEAN — renamed from
           ANLM), EPMethod (A_MEAN, S_FULL, S_PSMN, S_MEAN, C_MEAN, C_PARA),
           EPType (OEP, AEP, TVAR_OEP, TVAR_AEP — replaces legacy 1-4 ints),
           GroupMethod (MEAN, RSAM, RSSD — new, for grouped analyses; MEAN here
           is the LossMethod's analytical mean and is excluded from GroupMethod).
           EP: EPCalc (INT) → EPMethodId (FK → EPMethod); EPType (INT) →
           EPTypeId (FK → EPType). EP_Samples: EPType (INT) → EPTypeId (FK →
           EPType).
           Grouped tables use GroupMethod in place of LossMethod/EPMethod —
           GroupMethod replaces LossType on GAAL and GPLT, and replaces
           EPCalc+EPType on GEP (GEP's ReturnPeriod is now relative-frequency-
           derived, not EP-curve-constructed, since grouped analyses don't
           construct EP curves). Added group_event_set_id (FK → GroupEventSet)
           to GAAL and GEP, which were missing it (GPLT already had it).
           EventOccurrenceSet: event_set_id, event_set_description,
           event_occurrence_id, event_occurrence_description, and
           event_occurrence_max_periods changed from `NULL DEFAULT '' / 0` to
           plain nullable with no default, so an unpopulated field is true NULL
           rather than an empty string/zero — these five fields are the ones a
           GroupEventSetId can be generated from any subset of, so NULL must
           mean "not one of the fields used" rather than a default placeholder.
           Settings.number_of_samples: removed stale DEFAULT 0 (meaningful only
           for STOC LossMethod; NULL now means not applicable rather than 0).
           Added Settings.c_para_distribution_type, Settings.oed_version,
           Settings.join_summary_info to cover new results-metadata-schema-v2
           fields. Added Analysis.exposure_standard. Added child tables
           AnalysisCurrency (multi-currency support for grouped analyses,
           replacing single-value Analysis.currency for v2) and VendorExtension
           (open-ended platform-specific key/value metadata).
           Updated DBVERSION seed data to 2.0.0 (ODSVERSION was already seeded
           2.0.0 in v1.4).

  v1.4  – Renamed results tables to align with the ORD file-based naming standard:
           MELT → ELT, ALT → AAL, EPT → EP, MPLT → PLT,
           SELT → ELT_Samples, QELT → ELT_Quantile,
           PSEPT → EP_Samples, SPLT → PLT_Samples, QPLT → PLT_Quantile.
           Group results tables renamed on the same convention: GALT → GAAL,
           GEPT → GEP. GELT and GPLT are already G+ELT and G+PLT respectively.
           Added composite PRIMARY KEY constraints to all results tables (ELT,
           AAL, EP, PLT, ELT_Quantile, ELT_Samples, EP_Samples, PLT_Quantile, PLT_Samples, GAAL, GEP, GELT,
           GPLT). Key columns that participate in PKs are now NOT NULL.
           Added non-clustered indexes on EventId/SummaryId, Period/SummaryId,
           and SummaryId/ReturnPeriod across the relevant results tables to
           support performant filtering at the volumes these tables are expected
           to hold.
           Note: ReturnPeriod (EP, EP_Samples, GEP) and Quantile (ELT_Quantile, PLT_Quantile) are
           NUMERIC PK columns (NUMERIC(9,2) and NUMERIC(5,2) respectively). FLOAT is avoided in
           primary keys because floating-point representation is inexact: two values that are
           mathematically equal may differ in their binary encoding depending on how they were
           computed, causing equality joins and uniqueness checks to behave incorrectly.
           NUMERIC stores values as exact decimal fractions, so 100.0, 250.0, 0.1 etc. round-trip
           without precision loss and compare reliably.
           Removed DEFAULT 0 / DEFAULT 0.0 from all nullable data columns in
           results tables (sections 7–8). NULL is now the implicit default,
           avoiding ambiguity with 0 as a legitimate result value. NOT NULL key
           columns (composite PK members) are unaffected.
           Renamed [Group] → ResultsGroup and GroupGroup → ResultsGroupGroup to
           eliminate square-bracket escaping at every call site. All REFERENCES,
           OBJECT_ID checks, and FK/PK constraint names updated accordingly.
           Added composite PKs to junction tables GroupAnalysis (group_id,
           analysis_id) and ResultsGroupGroup (parent_group_id, child_group_id) to
           prevent duplicate relationship rows.
           Corrected column types: number_of_samples in Settings FLOAT → INT
           (sample counts are always whole numbers); exposure_summary_level
           in OutputSet FLOAT → INT (identifier with no fractional meaning);
           hazard_correlation_value and damage_correlation_value in
           CorrelationSettings NVARCHAR(10) → FLOAT (numeric values stored as
           strings prevented arithmetic and range validation).
           Updated DBVERSION seed data to 1.4.0.

  v1.3  – Added missing DEFAULT values to all nullable columns for consistency.
           Rule: '' for strings, 0 for ints, 0.0 for floats, no default for datetime.
           Affected tables: Group, GroupSet, EventOccurrenceSet, GroupSummaryInfo,
           GAAL, GEP, GELT.
		   Made group_set_id (FK) not null in GroupSummaryInfo
		   Removed source_name and engine_name defaults 'nrmc' and 'oasis', respectively.

  v1.2  – Merged from Create_ORDB_v1_2.sql, Alter1 and Alter2 scripts.
           Added ResultsGroup, GroupAnalysis, ResultsGroupGroup, GroupSet, GroupOutputSet,
           GroupEventSet, GroupSummaryInfo, GroupEventSetAnalysis,
           EventOccurrenceSet, EventOccurrence, GAAL, GEP, GELT, GPLT tables.
           Added SDLossCor/SDLossInd to ELT and PLT.
           Removed EPCalc from EP_Samples to align with ORD file-based version.
           Extended EventOccurrenceSet, ModelSettings, OutputSet with new columns.

  PREREQUISITES
  -------------
  This script must be run in SQLCMD mode.
    - SSMS: Query menu → SQLCMD Mode
    - Command line: sqlcmd -i Create_ORDB_v2_0.sql
  Change the database name below to deploy with a different name.

================================================================================
*/

-- ============================================================================
-- 1. CONFIGURATION — change the database name here
-- ============================================================================
:setvar DatabaseName "ORDB_BLANK_v2_0"

-- ============================================================================
-- 2. DATABASE CREATION
-- ============================================================================
USE [master];
GO

DECLARE @dbFilename    NVARCHAR(1000) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500)) + N'$(DatabaseName).mdf';
DECLARE @dbLogFilename NVARCHAR(1000) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(500)) + N'$(DatabaseName)_log.ldf';

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'$(DatabaseName)')
BEGIN
    EXECUTE (
        'CREATE DATABASE [$(DatabaseName)]
         CONTAINMENT = NONE
         ON PRIMARY (
             NAME = N''$(DatabaseName)'',
             FILENAME = N''' + @dbFilename + '''
         )
         LOG ON (
             NAME = N''$(DatabaseName)_log'',
             FILENAME = N''' + @dbLogFilename + '''
         )'
    );
END
GO

USE [$(DatabaseName)];
GO


-- ============================================================================
-- 3. METADATA TABLE
-- ============================================================================

IF OBJECT_ID('dbo.DbAttribute', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DbAttribute (
        Attribute   NVARCHAR(30)  NOT NULL,
        Value       NVARCHAR(100) NOT NULL
    );
END
GO


-- ============================================================================
-- 3a. LOOKUP TABLES (new in v2.0)
-- ============================================================================
-- String `Code` is what appears in ORD output files. The relational model
-- normalises to an INT surrogate key for FK efficiency in the results tables;
-- `vw_*` views (section 10) join back to Code for consumers that want the
-- human-readable value. LegacyCode/LegacyInt is retained for v1 traceability
-- only and is not a live foreign key.
-- ============================================================================

IF OBJECT_ID('dbo.LossMethod', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LossMethod (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        Code          NVARCHAR(10)  NOT NULL UNIQUE,
        LegacyCode    NVARCHAR(10)  NULL,
        Description   NVARCHAR(500) NOT NULL
    );
END
GO

IF OBJECT_ID('dbo.EPMethod', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EPMethod (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        Code          NVARCHAR(10)  NOT NULL UNIQUE,
        LossMethodCode NVARCHAR(10) NULL, -- LossMethod indicated by the code prefix (A_/S_/C_); not a live FK
        Description   NVARCHAR(500) NOT NULL
    );
END
GO

IF OBJECT_ID('dbo.EPType', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EPType (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        Code          NVARCHAR(10)  NOT NULL UNIQUE,
        LegacyInt     INT           NULL,
        Description   NVARCHAR(500) NOT NULL
    );
END
GO

IF OBJECT_ID('dbo.GroupMethod', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupMethod (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        Code          NVARCHAR(10)  NOT NULL UNIQUE,
        LegacyInt     INT           NULL,
        Description   NVARCHAR(500) NOT NULL
    );
END
GO

TRUNCATE TABLE dbo.LossMethod;
INSERT INTO dbo.LossMethod (Code, LegacyCode, Description)
VALUES
    ('MEAN', 'ANLM', 'Analytical mean'),
    ('STOC', NULL,   'Stochastic sampling'),
    ('CONV', NULL,   'Numerical convolution');
GO

TRUNCATE TABLE dbo.EPMethod;
INSERT INTO dbo.EPMethod (Code, LossMethodCode, Description)
VALUES
    ('A_MEAN', 'MEAN', 'Analytical mean EP'),
    ('S_FULL', 'STOC', 'Stochastic full uncertainty'),
    ('S_PSMN', 'STOC', 'Stochastic per-sample mean'),
    ('S_MEAN', 'STOC', 'Stochastic mean'),
    ('C_MEAN', 'CONV', 'Convolution mean'),
    ('C_PARA', 'CONV', 'Convolution with parametric uncertainty');
GO

TRUNCATE TABLE dbo.EPType;
INSERT INTO dbo.EPType (Code, LegacyInt, Description)
VALUES
    ('OEP',      1, 'Occurrence Exceedance Probability'),
    ('AEP',      2, 'Aggregate Exceedance Probability'),
    ('TVAR_OEP', NULL, 'Tail Value at Risk — OEP'),
    ('TVAR_AEP', NULL, 'Tail Value at Risk — AEP');
GO

TRUNCATE TABLE dbo.GroupMethod;
INSERT INTO dbo.GroupMethod (Code, LegacyInt, Description)
VALUES
    ('MEAN', 1, 'Grouped Means — group losses derive from summed/maximum event mean of underlying analyses'),
    ('RSAM', 2, 'Resampled secondary uncertainty — group event losses from summed/maximum of resampled losses from underlying event severity distributions; inter-GroupEventSet correlation is zero or imposed by alpha factors'),
    ('RSSD', 3, 'Resampled secondary uncertainty using sum of decomposed event standard deviations — group event losses from resampled losses; group event standard deviations from summing of decomposed correlated and independent standard deviations capturing internally derived correlation by event; requires decomposed event standard deviations in input ELTs');
GO


-- ============================================================================
-- 4. ANALYSIS & SETTINGS TABLES
-- ============================================================================

IF OBJECT_ID('dbo.Analysis', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Analysis (
        id                       INT IDENTITY(1,1) PRIMARY KEY,
        run_id                   INT            NULL DEFAULT 0,
        name                     NVARCHAR(255)  NULL DEFAULT '',
        description              NVARCHAR(255)  NULL DEFAULT '',
        exposure_database_name   NVARCHAR(255)  NULL DEFAULT '',
        exposure_set_id          INT            NULL DEFAULT 0,
        exposure_standard        NVARCHAR(20)   NULL, -- e.g. 'OED', 'CEDE', 'EDM'; NULL if unknown
        source_name              NVARCHAR(255)  NULL DEFAULT '', -- e.g. platform name
        engine_name              NVARCHAR(255)  NULL DEFAULT '', -- calc engine provider e.g. oasis
        portfolio_name           NVARCHAR(255)  NULL DEFAULT '',
        status                   NVARCHAR(50)   NULL DEFAULT '',
        created_by_username      NVARCHAR(255)  NULL DEFAULT '',
        run_by_username          NVARCHAR(255)  NULL DEFAULT '',
        run_submitted            DATETIME       NULL,
        input_generation_start   DATETIME       NULL,
        input_generation_end     DATETIME       NULL,
        execution_queue_start    DATETIME       NULL,
        execution_start          DATETIME       NULL,
        execution_end            DATETIME       NULL
    );
END
GO

-- AnalysisCurrency — v2.0: replaces the single-value Analysis.currency column.
-- Expressed as a child table (one row per currency) rather than a delimited
-- string, consistent with how other one-to-many metadata is modelled
-- (ExposureFiles, Versions) — supports multi-currency grouped analyses.
IF OBJECT_ID('dbo.AnalysisCurrency', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AnalysisCurrency (
        analysis_id   INT          NOT NULL,
        currency      NVARCHAR(3)  NOT NULL, -- ISO 4217, e.g. 'USD', 'GBP', 'EUR'
        CONSTRAINT PK_AnalysisCurrency PRIMARY KEY (analysis_id, currency),
        CONSTRAINT FK_AnalysisCurrency_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

-- VendorExtension — v2.0: open-ended platform-specific metadata that isn't
-- covered by the platform-neutral core or the Oasis-specific Settings columns.
-- Deliberately not normalised further — vendor_extensions in the results
-- metadata schema is free-form per vendor.
IF OBJECT_ID('dbo.VendorExtension', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VendorExtension (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        analysis_id   INT            NOT NULL,
        vendor        NVARCHAR(50)   NOT NULL, -- e.g. 'verisk', 'moodys'
        [key]         NVARCHAR(100)  NOT NULL,
        value         NVARCHAR(MAX)  NULL,
        CONSTRAINT FK_VendorExtension_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.ExposureFiles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExposureFiles (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        analysis_id   INT           NOT NULL,
        file_type     NVARCHAR(50)  NULL DEFAULT '',
        file_name     NVARCHAR(255) NULL DEFAULT '',
        CONSTRAINT FK_ExposureFiles_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.Settings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Settings (
        id                   INT IDENTITY(1,1) PRIMARY KEY,
        analysis_id          INT            NOT NULL,
        pla                  BIT            NULL DEFAULT 0,
        model_name_id        NVARCHAR(50)   NULL DEFAULT '',
        model_description    NVARCHAR(255)  NULL DEFAULT '',
        gul_threshold        FLOAT          NULL DEFAULT 0.0,
        il_output            BIT            NULL DEFAULT 0,
        number_of_samples    INT            NULL, -- meaningful for STOC LossMethod only; NULL = not applicable (v2.0: dropped DEFAULT 0)
        gul_output           BIT            NULL DEFAULT 0,
        full_correlation     BIT            NULL DEFAULT 0,
        do_disaggregation    BIT            NULL DEFAULT 0,
        model_supplier_id    NVARCHAR(100)  NULL DEFAULT '',
        ri_output            BIT            NULL DEFAULT 0,
        c_para_distribution_type   NVARCHAR(50)  NULL, -- required (by convention) when EPMethod C_PARA is present; free-form, e.g. 'Beta', 'Gamma'
        oed_version                NVARCHAR(20)  NULL, -- OED schema version of the input exposure, e.g. '2.0.0'; applicable only when exposure_standard = 'OED'
        join_summary_info          BIT           NULL DEFAULT 0,
        CONSTRAINT FK_Settings_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.ModelSettings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ModelSettings (
        id                              INT IDENTITY(1,1) PRIMARY KEY,
        settings_id                     INT            NOT NULL,
        event_occurrence_id             NVARCHAR(50)   NULL DEFAULT '',
        event_occurrence_description    NVARCHAR(255)  NULL DEFAULT '',
        event_occurrence_max_periods    INT            NULL DEFAULT 0,
        event_set_id                    NVARCHAR(50)   NULL DEFAULT '',
        event_set_description           NVARCHAR(255)  NULL DEFAULT '',
        footprint_set_id                NVARCHAR(50)   NULL DEFAULT '',
        footprint_set_description       NVARCHAR(255)  NULL DEFAULT '',
        vulnerability_set_id            NVARCHAR(50)   NULL DEFAULT '',
        vulnerability_set_description   NVARCHAR(255)  NULL DEFAULT '',
        CONSTRAINT FK_ModelSettings_Settings_settings_id
            FOREIGN KEY (settings_id) REFERENCES dbo.Settings(id)
    );
END
GO

IF OBJECT_ID('dbo.CorrelationSettings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CorrelationSettings (
        id                        INT IDENTITY(1,1) PRIMARY KEY,
        model_settings_id         INT           NOT NULL,
        peril_correlation_group   INT           NULL DEFAULT 0,
        hazard_correlation_value  FLOAT         NULL DEFAULT 0.0,
        damage_correlation_value  FLOAT         NULL DEFAULT 0.0,
        CONSTRAINT FK_CorrelationSettings_ModelSettings_model_settings_id
            FOREIGN KEY (model_settings_id) REFERENCES dbo.ModelSettings(id)
    );
END
GO

IF OBJECT_ID('dbo.Versions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Versions (
        id               INT IDENTITY(1,1) PRIMARY KEY,
        analysis_id      INT            NOT NULL,
        source_server    NVARCHAR(50)   NULL DEFAULT '',
        engine_server    NVARCHAR(50)   NULL DEFAULT '',
        worker_version   NVARCHAR(100)  NULL DEFAULT '',
        model_version    NVARCHAR(50)   NULL DEFAULT '',
        data_version     NVARCHAR(50)   NULL DEFAULT '',
        key_version      NVARCHAR(50)   NULL DEFAULT '',
        CONSTRAINT FK_Versions_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO


-- ============================================================================
-- 5. OUTPUT & EXPOSURE TABLES
-- ============================================================================

IF OBJECT_ID('dbo.OutputSet', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.OutputSet (
        id                              INT IDENTITY(1,1) PRIMARY KEY,
        settings_id                     INT            NOT NULL,
        perspective_code                NVARCHAR(10)   NULL DEFAULT '',
        exposure_summary_level       INT            NULL DEFAULT 0,
        exposure_summary_level_fields   NVARCHAR(255)  NULL DEFAULT '',
        output_set_description          NVARCHAR(255)  NULL DEFAULT '',
        CONSTRAINT FK_OutputSet_Settings_settings_id
            FOREIGN KEY (settings_id) REFERENCES dbo.Settings(id)
    );
END
GO

IF OBJECT_ID('dbo.SummaryInfo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SummaryInfo (
        id                INT IDENTITY(1,1) PRIMARY KEY,
        output_set_id     INT            NOT NULL,
        SummaryId         INT            NULL DEFAULT 1,
        SummaryDescription NVARCHAR(255) NULL DEFAULT '',
        SummaryField      NVARCHAR(50)   NULL DEFAULT '',
        TIV               FLOAT          NULL DEFAULT 0.0,
        CONSTRAINT FK_SummaryInfo_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.ExposureSummary', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExposureSummary (
        id                       INT IDENTITY(1,1) PRIMARY KEY,
        analysis_id              INT    NOT NULL,
        modelled_tiv             FLOAT  NULL DEFAULT 0.0,
        modelled_locations       INT    NULL DEFAULT 0,
        not_modelled_tiv         FLOAT  NULL DEFAULT 0.0,
        not_modelled_locations   INT    NULL DEFAULT 0,
        portfolio_tiv            FLOAT  NULL DEFAULT 0.0,
        portfolio_locations      INT    NULL DEFAULT 0,
        CONSTRAINT FK_ExposureSummary_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.ExposureCoverage', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExposureCoverage (
        id                    INT IDENTITY(1,1) PRIMARY KEY,
        exposure_summary_id   INT           NOT NULL,
        peril_code            NVARCHAR(50)  NULL DEFAULT '',
        category              NVARCHAR(50)  NULL DEFAULT '',
        tiv                   FLOAT         NULL DEFAULT 0.0,
        locations             INT           NULL DEFAULT 0,
        buildings_tiv         FLOAT         NULL DEFAULT 0.0,
        other_tiv             FLOAT         NULL DEFAULT 0.0,
        contents_tiv          FLOAT         NULL DEFAULT 0.0,
        bi_tiv                FLOAT         NULL DEFAULT 0.0,
        buildings_locations   INT           NULL DEFAULT 0,
        other_locations       INT           NULL DEFAULT 0,
        contents_locations    INT           NULL DEFAULT 0,
        bi_locations          INT           NULL DEFAULT 0,
        CONSTRAINT FK_ExposureCoverage_ExposureSummary_exposure_summary_id
            FOREIGN KEY (exposure_summary_id) REFERENCES dbo.ExposureSummary(id)
    );
END
GO


-- ============================================================================
-- 6. GROUP & EVENT TABLES
-- ============================================================================

IF OBJECT_ID('dbo.ResultsGroup', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ResultsGroup (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        description   NVARCHAR(255) NULL DEFAULT ''
    );
END
GO

IF OBJECT_ID('dbo.GroupAnalysis', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupAnalysis (
        group_id      INT NOT NULL,
        analysis_id   INT NOT NULL,
        CONSTRAINT PK_GroupAnalysis PRIMARY KEY (group_id, analysis_id),
        CONSTRAINT FK_GroupAnalysis_ResultsGroup_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.ResultsGroup(id),
        CONSTRAINT FK_GroupAnalysis_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.ResultsGroupGroup', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ResultsGroupGroup (
        parent_group_id   INT NOT NULL,
        child_group_id    INT NOT NULL,
        CONSTRAINT PK_ResultsGroupGroup PRIMARY KEY (parent_group_id, child_group_id),
        CONSTRAINT FK_ResultsGroupGroup_ResultsGroup_parent_group_id
            FOREIGN KEY (parent_group_id) REFERENCES dbo.ResultsGroup(id),
        CONSTRAINT FK_ResultsGroupGroup_ResultsGroup_child_group_id
            FOREIGN KEY (child_group_id) REFERENCES dbo.ResultsGroup(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupSet', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupSet (
        id                              INT IDENTITY(1,1) PRIMARY KEY,
        group_id                        INT            NOT NULL,
        perspective_code                NVARCHAR(10)   NULL DEFAULT '',
        exposure_summary_level_fields   NVARCHAR(255)  NULL DEFAULT '',
        group_set_description           NVARCHAR(255)  NULL DEFAULT '',
        CONSTRAINT FK_GroupSet_ResultsGroup_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.ResultsGroup(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupOutputSet', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupOutputSet (
        group_set_id    INT NOT NULL,
        output_set_id   INT NOT NULL,
        CONSTRAINT FK_GroupOutputSet_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GroupOutputSet_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.EventOccurrenceSet', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventOccurrenceSet (
        id                              INT IDENTITY(1,1) PRIMARY KEY,
        -- v2.0: the five columns below are the GroupEventSetId contributing
        -- fields (ORD Combining Results §7.2) — a GroupEventSetId may be
        -- generated from any subset of them, controlled by
        -- group_event_set_fields, so NULL must mean "not populated" rather
        -- than a default placeholder. DEFAULT '' / DEFAULT 0 removed.
        event_occurrence_id             NVARCHAR(50)   NULL,
        event_occurrence_description    NVARCHAR(255)  NULL,
        event_occurrence_max_periods    INT            NULL,
        event_set_description           NVARCHAR(255)  NULL,
        event_set_id                    NVARCHAR(50)   NULL,
        model_description               NVARCHAR(255)  NULL DEFAULT '',
        model_name_id                   NVARCHAR(50)   NULL DEFAULT '',
        model_supplier_id               NVARCHAR(100)  NULL DEFAULT '',
        model_version                   NVARCHAR(50)   NULL DEFAULT ''
    );
END
GO

IF OBJECT_ID('dbo.EventOccurrence', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventOccurrence (
        event_occurrence_set_id   INT      NOT NULL,
        EventId                   INT      NOT NULL,
        Period                    INT      NOT NULL,
        Year                      INT      NULL DEFAULT 0,
        Month                     TINYINT  NULL DEFAULT 0,
        Day                       TINYINT  NULL DEFAULT 0,
        CONSTRAINT FK_EventOccurrence_EventOccurrenceSet_event_occurrence_set_id
            FOREIGN KEY (event_occurrence_set_id) REFERENCES dbo.EventOccurrenceSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupEventSet', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupEventSet (
        id                        INT IDENTITY(1,1) PRIMARY KEY,
        group_id                  INT NOT NULL,
        event_occurrence_set_id   INT NOT NULL,
        CONSTRAINT FK_GroupEventSet_ResultsGroup_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.ResultsGroup(id),
        CONSTRAINT FK_GroupEventSet_EventOccurrenceSet_event_occurrence_set_id
            FOREIGN KEY (event_occurrence_set_id) REFERENCES dbo.EventOccurrenceSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupSummaryInfo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupSummaryInfo (
        id                    INT IDENTITY(1,1) PRIMARY KEY,
        group_set_id          INT			 NOT NULL,
        SummaryId             INT            NULL DEFAULT 0,
        SummaryDescription    NVARCHAR(255)  NULL DEFAULT '',
        SummaryField          NVARCHAR(50)   NULL DEFAULT '',
        TIV                   FLOAT          NULL DEFAULT 0.0,
        CONSTRAINT FK_GroupSummaryInfo_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupEventSetAnalysis', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupEventSetAnalysis (
        group_event_set_id   INT NOT NULL,
        analysis_id          INT NOT NULL,
        CONSTRAINT FK_GroupEventSetAnalysis_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id),
        CONSTRAINT FK_GroupEventSetAnalysis_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO


-- ============================================================================
-- 7. ANALYSIS RESULTS TABLES
-- ============================================================================
-- All results tables have composite clustered PRIMARY KEYs covering their
-- natural key. Columns participating in a PK are NOT NULL (SQL Server
-- requirement). Non-clustered indexes are added for the most common filter
-- patterns: EventId/SummaryId, Period/SummaryId, and SummaryId/ReturnPeriod.
-- Nullable data columns carry no DEFAULT so that NULL is stored when no value
-- is provided, avoiding ambiguity with 0 as a legitimate result.
-- ============================================================================

-- ELT — Mean Event Loss Table
IF OBJECT_ID('dbo.ELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ELT (
        output_set_id          INT   NOT NULL,
        EventId                INT   NOT NULL DEFAULT 0,
        SummaryId              INT   NOT NULL DEFAULT 0,
        SampleType             INT   NOT NULL DEFAULT 0,
        EventRate              FLOAT NULL,
        ChanceOfLoss           FLOAT NULL,
        MeanLoss               FLOAT NULL,
        SDLoss                 FLOAT NULL,
        MaxLoss                FLOAT NULL,
        FootprintExposure      FLOAT NULL,
        MeanImpactedExposure   FLOAT NULL,
        MaxImpactedExposure    FLOAT NULL,
        SDLossCor              FLOAT NULL,
        SDLossInd              FLOAT NULL,
        CONSTRAINT PK_ELT PRIMARY KEY CLUSTERED (output_set_id, EventId, SummaryId, SampleType),
        CONSTRAINT FK_ELT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_ELT_EventId_SummaryId
        ON dbo.ELT (EventId, SummaryId);

    CREATE NONCLUSTERED INDEX IX_ELT_SummaryId
        ON dbo.ELT (SummaryId);
END
GO

-- AAL — Aggregate Loss Table
IF OBJECT_ID('dbo.AAL', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AAL (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NOT NULL DEFAULT 0,
        SampleType      INT   NOT NULL DEFAULT 0,
        MeanLoss        FLOAT NULL,
        SDLoss          FLOAT NULL,
        CONSTRAINT PK_AAL PRIMARY KEY CLUSTERED (output_set_id, SummaryId, SampleType),
        CONSTRAINT FK_AAL_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_AAL_SummaryId
        ON dbo.AAL (SummaryId);
END
GO

-- EP — Exceedance Probability Table
IF OBJECT_ID('dbo.EP', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EP (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NOT NULL DEFAULT 0,
        EPMethodId      INT   NOT NULL, -- v2.0: replaces EPCalc (INT code) — FK to EPMethod lookup
        EPTypeId        INT   NOT NULL, -- v2.0: replaces EPType (INT code) — FK to EPType lookup
        ReturnPeriod    NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_EP PRIMARY KEY CLUSTERED (output_set_id, SummaryId, EPMethodId, EPTypeId, ReturnPeriod),
        CONSTRAINT FK_EP_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id),
        CONSTRAINT FK_EP_EPMethod_EPMethodId
            FOREIGN KEY (EPMethodId) REFERENCES dbo.EPMethod(id),
        CONSTRAINT FK_EP_EPType_EPTypeId
            FOREIGN KEY (EPTypeId) REFERENCES dbo.EPType(id)
    );

    CREATE NONCLUSTERED INDEX IX_EP_SummaryId_ReturnPeriod
        ON dbo.EP (SummaryId, ReturnPeriod);
END
GO

-- PLT — Mean Period Loss Table
IF OBJECT_ID('dbo.PLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PLT (
        output_set_id          INT      NOT NULL,
        SummaryId              INT      NOT NULL DEFAULT 0,
        Period                 INT      NOT NULL DEFAULT 0,
        PeriodWeight           FLOAT    NULL,
        EventId                INT      NOT NULL DEFAULT 0,
        Year                   INT      NULL,
        Month                  INT      NULL,
        Day                    INT      NULL,
        Hour                   INT      NULL,
        Minute                 INT      NULL,
        SampleType             INT      NOT NULL DEFAULT 0,
        ChanceOfLoss           FLOAT    NULL,
        MeanLoss               FLOAT    NULL,
        SDLoss                 FLOAT    NULL,
        MaxLoss                FLOAT    NULL,
        FootprintExposure      FLOAT    NULL,
        MeanImpactedExposure   FLOAT    NULL,
        MaxImpactedExposure    FLOAT    NULL,
        SDLossCor              FLOAT    NULL,
        SDLossInd              FLOAT    NULL,
        CONSTRAINT PK_PLT PRIMARY KEY CLUSTERED (output_set_id, SummaryId, Period, EventId, SampleType),
        CONSTRAINT FK_PLT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_PLT_Period_SummaryId
        ON dbo.PLT (Period, SummaryId);

    CREATE NONCLUSTERED INDEX IX_PLT_EventId_SummaryId
        ON dbo.PLT (EventId, SummaryId);
END
GO

-- ELT_Quantile — Quantile Event Loss Table
IF OBJECT_ID('dbo.ELT_Quantile', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ELT_Quantile (
        output_set_id   INT   NOT NULL,
        EventId         INT   NOT NULL DEFAULT 0,
        SummaryId       INT   NOT NULL DEFAULT 0,
        Quantile        NUMERIC(5,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_ELT_Quantile PRIMARY KEY CLUSTERED (output_set_id, EventId, SummaryId, Quantile),
        CONSTRAINT FK_ELT_Quantile_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_ELT_Quantile_EventId_SummaryId
        ON dbo.ELT_Quantile (EventId, SummaryId);
END
GO

-- ELT_Samples — Sample Event Loss Table
IF OBJECT_ID('dbo.ELT_Samples', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ELT_Samples (
        output_set_id      INT   NOT NULL,
        EventId            INT   NOT NULL DEFAULT 0,
        SummaryId          INT   NOT NULL DEFAULT 0,
        SampleId           INT   NOT NULL DEFAULT 0,
        Loss               FLOAT NULL,
        ImpactedExposure   FLOAT NULL,
        CONSTRAINT PK_ELT_Samples PRIMARY KEY CLUSTERED (output_set_id, EventId, SummaryId, SampleId),
        CONSTRAINT FK_ELT_Samples_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_ELT_Samples_EventId_SummaryId
        ON dbo.ELT_Samples (EventId, SummaryId);
END
GO

-- EP_Samples — Per-Sample Exceedance Probability Table
IF OBJECT_ID('dbo.EP_Samples', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EP_Samples (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NOT NULL DEFAULT 0,
        SampleId        INT   NOT NULL DEFAULT 0,
        EPTypeId        INT   NOT NULL, -- v2.0: replaces EPType (INT code) — FK to EPType lookup. No EPMethod here (removed in v1.2, unchanged in v2).
        ReturnPeriod    NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_EP_Samples PRIMARY KEY CLUSTERED (output_set_id, SummaryId, SampleId, EPTypeId, ReturnPeriod),
        CONSTRAINT FK_EP_Samples_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id),
        CONSTRAINT FK_EP_Samples_EPType_EPTypeId
            FOREIGN KEY (EPTypeId) REFERENCES dbo.EPType(id)
    );

    CREATE NONCLUSTERED INDEX IX_EP_Samples_SummaryId_ReturnPeriod
        ON dbo.EP_Samples (SummaryId, ReturnPeriod);
END
GO

-- PLT_Quantile — Quantile Period Loss Table
IF OBJECT_ID('dbo.PLT_Quantile', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PLT_Quantile (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NOT NULL DEFAULT 0,
        Period          INT   NOT NULL DEFAULT 0,
        PeriodWeight    FLOAT NULL,
        EventId         INT   NOT NULL DEFAULT 0,
        Year            INT   NULL,
        Month           INT   NULL,
        Day             INT   NULL,
        Hour            INT   NULL,
        Minute          INT   NULL,
        Quantile        NUMERIC(5,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_PLT_Quantile PRIMARY KEY CLUSTERED (output_set_id, SummaryId, Period, EventId, Quantile),
        CONSTRAINT FK_PLT_Quantile_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_PLT_Quantile_Period_SummaryId
        ON dbo.PLT_Quantile (Period, SummaryId);

    CREATE NONCLUSTERED INDEX IX_PLT_Quantile_EventId
        ON dbo.PLT_Quantile (EventId);
END
GO

-- PLT_Samples — Sample Period Loss Table
IF OBJECT_ID('dbo.PLT_Samples', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PLT_Samples (
        output_set_id      INT   NOT NULL,
        SummaryId          INT   NOT NULL DEFAULT 0,
        Period             INT   NOT NULL DEFAULT 0,
        PeriodWeight       FLOAT NULL,
        EventId            INT   NOT NULL DEFAULT 0,
        Year               INT   NULL,
        Month              INT   NULL,
        Day                INT   NULL,
        Hour               INT   NULL,
        Minute             INT   NULL,
        SampleId           INT   NOT NULL DEFAULT 0,
        Loss               FLOAT NULL,
        ImpactedExposure   FLOAT NULL,
        CONSTRAINT PK_PLT_Samples PRIMARY KEY CLUSTERED (output_set_id, SummaryId, Period, EventId, SampleId),
        CONSTRAINT FK_PLT_Samples_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_PLT_Samples_Period_SummaryId
        ON dbo.PLT_Samples (Period, SummaryId);

    CREATE NONCLUSTERED INDEX IX_PLT_Samples_EventId_SummaryId
        ON dbo.PLT_Samples (EventId, SummaryId);
END
GO


-- ============================================================================
-- 8. GROUP RESULTS TABLES
-- ============================================================================

-- GAAL — Group Aggregate Loss Table
IF OBJECT_ID('dbo.GAAL', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GAAL (
        group_set_id         INT   NOT NULL,
        group_event_set_id   INT   NOT NULL, -- v2.0: added, was missing (GPLT already had it)
        SummaryId            INT   NOT NULL DEFAULT 0,
        GroupMethodId        INT   NOT NULL, -- v2.0: replaces LossType (INT code) — FK to GroupMethod lookup
        MeanLoss             FLOAT NULL,
        SDLoss               FLOAT NULL,
        CONSTRAINT PK_GAAL PRIMARY KEY CLUSTERED (group_set_id, group_event_set_id, SummaryId, GroupMethodId),
        CONSTRAINT FK_GAAL_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GAAL_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id),
        CONSTRAINT FK_GAAL_GroupMethod_GroupMethodId
            FOREIGN KEY (GroupMethodId) REFERENCES dbo.GroupMethod(id)
    );

    CREATE NONCLUSTERED INDEX IX_GAAL_SummaryId
        ON dbo.GAAL (SummaryId);
END
GO

-- GEP — Group Exceedance Probability Table
-- v2.0: EPCalc+EPType dropped — grouped analyses don't construct EP curves per
-- LossMethod/EPMethod; GroupMethod replaces both. ReturnPeriod is now derived
-- from relative frequency of group events rather than EP-curve construction.
IF OBJECT_ID('dbo.GEP', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GEP (
        group_set_id         INT   NOT NULL,
        group_event_set_id   INT   NOT NULL, -- v2.0: added, was missing (GPLT already had it)
        SummaryId            INT   NOT NULL DEFAULT 0,
        GroupMethodId        INT   NOT NULL, -- v2.0: replaces EPCalc+EPType — FK to GroupMethod lookup
        ReturnPeriod         NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss                 FLOAT NULL,
        CONSTRAINT PK_GEP PRIMARY KEY CLUSTERED (group_set_id, group_event_set_id, SummaryId, GroupMethodId, ReturnPeriod),
        CONSTRAINT FK_GEP_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GEP_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id),
        CONSTRAINT FK_GEP_GroupMethod_GroupMethodId
            FOREIGN KEY (GroupMethodId) REFERENCES dbo.GroupMethod(id)
    );

    CREATE NONCLUSTERED INDEX IX_GEP_SummaryId_ReturnPeriod
        ON dbo.GEP (SummaryId, ReturnPeriod);
END
GO

-- GELT — Group Event Loss Table
IF OBJECT_ID('dbo.GELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GELT (
        group_set_id           INT   NOT NULL,
        SummaryId              INT   NOT NULL DEFAULT 0,
        EventId                INT   NOT NULL DEFAULT 0,
        SampleType             INT   NOT NULL DEFAULT 0,
        EventRate              FLOAT NULL,
        ChanceOfLoss           FLOAT NULL,
        MeanLoss               FLOAT NULL,
        SDLoss                 FLOAT NULL,
        MaxLoss                FLOAT NULL,
        FootprintExposure      FLOAT NULL,
        MeanImpactedExposure   FLOAT NULL,
        MaxImpactedExposure    FLOAT NULL,
        SDLossCor              FLOAT NULL,
        SDLossInd              FLOAT NULL,
        CONSTRAINT PK_GELT PRIMARY KEY CLUSTERED (group_set_id, EventId, SummaryId, SampleType),
        CONSTRAINT FK_GELT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_GELT_EventId_SummaryId
        ON dbo.GELT (EventId, SummaryId);

    CREATE NONCLUSTERED INDEX IX_GELT_SummaryId
        ON dbo.GELT (SummaryId);
END
GO

-- GPLT — Group Period Loss Table
IF OBJECT_ID('dbo.GPLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GPLT (
        group_set_id         INT   NOT NULL,
        group_event_set_id   INT   NOT NULL,
        SummaryId            INT   NOT NULL DEFAULT 0,
        Period               INT   NOT NULL DEFAULT 0,
        EventId              INT   NOT NULL DEFAULT 0,
        GroupMethodId        INT   NOT NULL, -- v2.0: replaces LossType (INT code) — FK to GroupMethod lookup
        Loss                 FLOAT NULL,
        CONSTRAINT PK_GPLT PRIMARY KEY CLUSTERED (group_set_id, group_event_set_id, SummaryId, Period, EventId, GroupMethodId),
        CONSTRAINT FK_GPLT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GPLT_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id),
        CONSTRAINT FK_GPLT_GroupMethod_GroupMethodId
            FOREIGN KEY (GroupMethodId) REFERENCES dbo.GroupMethod(id)
    );

    CREATE NONCLUSTERED INDEX IX_GPLT_Period_SummaryId
        ON dbo.GPLT (Period, SummaryId);

    CREATE NONCLUSTERED INDEX IX_GPLT_EventId_SummaryId
        ON dbo.GPLT (EventId, SummaryId);
END
GO


-- ============================================================================
-- 9. SEED DATA
-- ============================================================================

TRUNCATE TABLE dbo.DbAttribute;
INSERT INTO dbo.DbAttribute (Attribute, Value)
VALUES
    ('DBTYPE',     'ordb'),
    ('DBVERSION',  '2.0.0'),
    ('ODSVERSION', '2.0.0');
GO


-- ============================================================================
-- 10. VIEWS — reconstruct human-readable lookup codes for consumers
-- ============================================================================

IF OBJECT_ID('dbo.vw_EP', 'V') IS NOT NULL DROP VIEW dbo.vw_EP;
GO
CREATE VIEW dbo.vw_EP AS
SELECT e.output_set_id, e.SummaryId, em.Code AS EPMethod, et.Code AS EPType, e.ReturnPeriod, e.Loss
FROM dbo.EP e
JOIN dbo.EPMethod em ON em.id = e.EPMethodId
JOIN dbo.EPType et ON et.id = e.EPTypeId;
GO

IF OBJECT_ID('dbo.vw_EP_Samples', 'V') IS NOT NULL DROP VIEW dbo.vw_EP_Samples;
GO
CREATE VIEW dbo.vw_EP_Samples AS
SELECT s.output_set_id, s.SummaryId, s.SampleId, et.Code AS EPType, s.ReturnPeriod, s.Loss
FROM dbo.EP_Samples s
JOIN dbo.EPType et ON et.id = s.EPTypeId;
GO

IF OBJECT_ID('dbo.vw_GAAL', 'V') IS NOT NULL DROP VIEW dbo.vw_GAAL;
GO
CREATE VIEW dbo.vw_GAAL AS
SELECT a.group_set_id, a.group_event_set_id, a.SummaryId, gm.Code AS GroupMethod, a.MeanLoss, a.SDLoss
FROM dbo.GAAL a
JOIN dbo.GroupMethod gm ON gm.id = a.GroupMethodId;
GO

IF OBJECT_ID('dbo.vw_GEP', 'V') IS NOT NULL DROP VIEW dbo.vw_GEP;
GO
CREATE VIEW dbo.vw_GEP AS
SELECT e.group_set_id, e.group_event_set_id, e.SummaryId, gm.Code AS GroupMethod, e.ReturnPeriod, e.Loss
FROM dbo.GEP e
JOIN dbo.GroupMethod gm ON gm.id = e.GroupMethodId;
GO

IF OBJECT_ID('dbo.vw_GPLT', 'V') IS NOT NULL DROP VIEW dbo.vw_GPLT;
GO
CREATE VIEW dbo.vw_GPLT AS
SELECT p.group_set_id, p.group_event_set_id, p.SummaryId, p.Period, p.EventId, gm.Code AS GroupMethod, p.Loss
FROM dbo.GPLT p
JOIN dbo.GroupMethod gm ON gm.id = p.GroupMethodId;
GO


-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
DECLARE @dbVersion NVARCHAR(100);
SELECT @dbVersion = Value FROM dbo.DbAttribute WHERE Attribute = 'DBVERSION';
PRINT 'ORDB v' + @dbVersion + ' schema created successfully: [$(DatabaseName)]';
GO
