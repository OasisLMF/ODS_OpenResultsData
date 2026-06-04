/*
================================================================================
  Open Results Database (ORDB) v1.4 — Schema Creation Script
  SQL Server (tested with compatibility level 100 / SQL Server 2008+)
================================================================================

  PURPOSE
  -------
  Creates a blank ORDB database and its full table schema. This relational
  schema is the SQL Server equivalent of the Open Results Data (ORD) file-based
  standard (CSV/Parquet data files + JSON metadata) plus new group and event tables
  for grouped analyses.

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
    - Command line: sqlcmd -i Create_ORDB_v1_4.sql
  Change the database name below to deploy with a different name.

================================================================================
*/

-- ============================================================================
-- 1. CONFIGURATION — change the database name here
-- ============================================================================
:setvar DatabaseName "ORDB_BLANK_v1_4"

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
        currency                 NVARCHAR(3)    NULL DEFAULT '',
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
        number_of_samples    INT            NULL DEFAULT 0,
        gul_output           BIT            NULL DEFAULT 0,
        full_correlation     BIT            NULL DEFAULT 0,
        do_disaggregation    BIT            NULL DEFAULT 0,
        model_supplier_id    NVARCHAR(100)  NULL DEFAULT '',
        ri_output            BIT            NULL DEFAULT 0,
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
        event_occurrence_id             NVARCHAR(50)   NULL DEFAULT '',
        event_occurrence_description    NVARCHAR(255)  NULL DEFAULT '',
        event_occurrence_max_periods    INT            NULL DEFAULT 0,
        event_set_description           NVARCHAR(255)  NULL DEFAULT '',
        event_set_id                    NVARCHAR(50)   NULL DEFAULT '',
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
        EPCalc          INT   NOT NULL DEFAULT 0,
        EPType          INT   NOT NULL DEFAULT 0,
        ReturnPeriod    NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_EP PRIMARY KEY CLUSTERED (output_set_id, SummaryId, EPCalc, EPType, ReturnPeriod),
        CONSTRAINT FK_EP_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
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
        EPType          INT   NOT NULL DEFAULT 0,
        ReturnPeriod    NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss            FLOAT NULL,
        CONSTRAINT PK_EP_Samples PRIMARY KEY CLUSTERED (output_set_id, SummaryId, SampleId, EPType, ReturnPeriod),
        CONSTRAINT FK_EP_Samples_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
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
        group_set_id   INT   NOT NULL,
        SummaryId      INT   NOT NULL DEFAULT 0,
        LossType       INT   NOT NULL DEFAULT 0,
        MeanLoss       FLOAT NULL,
        SDLoss         FLOAT NULL,
        CONSTRAINT PK_GAAL PRIMARY KEY CLUSTERED (group_set_id, SummaryId, LossType),
        CONSTRAINT FK_GAAL_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );

    CREATE NONCLUSTERED INDEX IX_GAAL_SummaryId
        ON dbo.GAAL (SummaryId);
END
GO

-- GEP — Group Exceedance Probability Table
IF OBJECT_ID('dbo.GEP', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GEP (
        group_set_id   INT   NOT NULL,
        SummaryId      INT   NOT NULL DEFAULT 0,
        EPCalc         INT   NOT NULL DEFAULT 0,
        EPType         INT   NOT NULL DEFAULT 0,
        ReturnPeriod   NUMERIC(9,2) NOT NULL DEFAULT 0.0,
        Loss           FLOAT NULL,
        CONSTRAINT PK_GEP PRIMARY KEY CLUSTERED (group_set_id, SummaryId, EPCalc, EPType, ReturnPeriod),
        CONSTRAINT FK_GEP_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
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
        LossType             INT   NOT NULL DEFAULT 0,
        Loss                 FLOAT NULL,
        CONSTRAINT PK_GPLT PRIMARY KEY CLUSTERED (group_set_id, group_event_set_id, SummaryId, Period, EventId, LossType),
        CONSTRAINT FK_GPLT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GPLT_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id)
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
    ('DBVERSION',  '1.4.0'),
    ('ODSVERSION', '2.0.0');
GO


-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
DECLARE @dbVersion NVARCHAR(100);
SELECT @dbVersion = Value FROM dbo.DbAttribute WHERE Attribute = 'DBVERSION';
PRINT 'ORDB v' + @dbVersion + ' schema created successfully: [$(DatabaseName)]';
GO
