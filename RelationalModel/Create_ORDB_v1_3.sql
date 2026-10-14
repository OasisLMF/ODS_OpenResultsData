/*
================================================================================
  Open Results Database (ORDB) v1.3 — Schema Creation Script
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
    - UPPERCASE abbreviations for results tables     (e.g. MELT, GALT, PSEPT)

  Columns:
    - snake_case for relational / metadata columns   (e.g. analysis_id, output_set_id)
      Mirrors the JSON metadata layer of the ORD file-based standard.
    - PascalCase for data / results columns  (e.g. MeanLoss, EventId, SDLoss)
      Mirrors the CSV/Parquet column headers of the ORD file-based standard.

  This deliberate split preserves look-across comparability between the
  relational schema and its file-based counterpart.

  Foreign Keys:
    - Explicitly named using the pattern FK_<ChildTable>_<ParentTable>_<column>

  Default Values (for nullable columns):
    - NVARCHAR / string types:  DEFAULT ''
    - INT / TINYINT types:      DEFAULT 0
    - FLOAT types:              DEFAULT 0.0
    - DATETIME types:           No default (NULL)

  CHANGE LOG
  ----------
  v1.3  – Added missing DEFAULT values to all nullable columns for consistency.
           Rule: '' for strings, 0 for ints, 0.0 for floats, no default for datetime.
           Affected tables: Group, GroupSet, EventOccurrenceSet, GroupSummaryInfo,
           GALT, GEPT, GELT.
		   Made group_set_id (FK) not null in GroupSummaryInfo 
		   Removed source_name and engine_name defaults 'nrmc' and 'oasis', respectively.

  v1.2  – Merged from Create_ORDB_v1_2.sql, Alter1 and Alter2 scripts.
           Added Group, GroupAnalysis, GroupGroup, GroupSet, GroupOutputSet,
           GroupEventSet, GroupSummaryInfo, GroupEventSetAnalysis,
           EventOccurrenceSet, EventOccurrence, GALT, GEPT, GELT, GPLT tables.
           Added SDLossCor/SDLossInd to MELT and MPLT.
           Removed EPCalc from PSEPT to align with ORD file-based version.
           Extended EventOccurrenceSet, ModelSettings, OutputSet with new columns.

  PREREQUISITES
  -------------
  This script must be run in SQLCMD mode.
    - SSMS: Query menu → SQLCMD Mode
    - Command line: sqlcmd -i Create_ORDB_v1_3.sql
  Change the database name below to deploy with a different name.

================================================================================
*/

-- ============================================================================
-- 1. CONFIGURATION — change the database name here
-- ============================================================================
:setvar DatabaseName "ORDB_BLANK_v1_3"

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
        number_of_samples    FLOAT          NULL DEFAULT 0.0,
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
        hazard_correlation_value  NVARCHAR(10)  NULL DEFAULT '0.0',
        damage_correlation_value  NVARCHAR(10)  NULL DEFAULT '0.0',
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
        exposure_summary_level_id       FLOAT          NULL DEFAULT 0.0,
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

IF OBJECT_ID('dbo.[Group]', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.[Group] (
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
        CONSTRAINT FK_GroupAnalysis_Group_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.[Group](id),
        CONSTRAINT FK_GroupAnalysis_Analysis_analysis_id
            FOREIGN KEY (analysis_id) REFERENCES dbo.Analysis(id)
    );
END
GO

IF OBJECT_ID('dbo.GroupGroup', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GroupGroup (
        parent_group_id   INT NOT NULL,
        child_group_id    INT NOT NULL,
        CONSTRAINT FK_GroupGroup_Group_parent_group_id
            FOREIGN KEY (parent_group_id) REFERENCES dbo.[Group](id),
        CONSTRAINT FK_GroupGroup_Group_child_group_id
            FOREIGN KEY (child_group_id) REFERENCES dbo.[Group](id)
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
        CONSTRAINT FK_GroupSet_Group_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.[Group](id)
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
        CONSTRAINT FK_GroupEventSet_Group_group_id
            FOREIGN KEY (group_id) REFERENCES dbo.[Group](id),
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

IF OBJECT_ID('dbo.MELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MELT (
        output_set_id          INT   NOT NULL,
        EventId                INT   NULL DEFAULT 0,
        SummaryId              INT   NULL DEFAULT 0,
        SampleType             INT   NULL DEFAULT 0,
        EventRate              FLOAT NULL DEFAULT 0.0,
        ChanceOfLoss           FLOAT NULL DEFAULT 0.0,
        MeanLoss               FLOAT NULL DEFAULT 0.0,
        SDLoss                 FLOAT NULL DEFAULT 0.0,
        MaxLoss                FLOAT NULL DEFAULT 0.0,
        FootprintExposure      FLOAT NULL DEFAULT 0.0,
        MeanImpactedExposure   FLOAT NULL DEFAULT 0.0,
        MaxImpactedExposure    FLOAT NULL DEFAULT 0.0,
        SDLossCor              FLOAT NULL DEFAULT 0.0,
        SDLossInd              FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_MELT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.ALT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ALT (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NULL DEFAULT 0,
        SampleType      INT   NULL DEFAULT 0,
        MeanLoss        FLOAT NULL DEFAULT 0.0,
        SDLoss          FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_ALT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.EPT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EPT (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NULL DEFAULT 0,
        EPCalc          INT   NULL DEFAULT 0,
        EPType          INT   NULL DEFAULT 0,
        ReturnPeriod    FLOAT NULL DEFAULT 0.0,
        Loss            FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_EPT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.MPLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MPLT (
        output_set_id          INT      NOT NULL,
        SummaryId              INT      NULL DEFAULT 0,
        Period                 INT      NULL DEFAULT 0,
        PeriodWeight           FLOAT    NULL DEFAULT 0.0,
        EventId                INT      NULL DEFAULT 0,
        Year                   INT      NULL DEFAULT 0,
        Month                  INT      NULL DEFAULT 0,
        Day                    INT      NULL DEFAULT 0,
        Hour                   INT      NULL DEFAULT 0,
        Minute                 INT      NULL DEFAULT 0,
        SampleType             INT      NULL DEFAULT 0,
        ChanceOfLoss           FLOAT    NULL DEFAULT 0.0,
        MeanLoss               FLOAT    NULL DEFAULT 0.0,
        SDLoss                 FLOAT    NULL DEFAULT 0.0,
        MaxLoss                FLOAT    NULL DEFAULT 0.0,
        FootprintExposure      FLOAT    NULL DEFAULT 0.0,
        MeanImpactedExposure   FLOAT    NULL DEFAULT 0.0,
        MaxImpactedExposure    FLOAT    NULL DEFAULT 0.0,
        SDLossCor              FLOAT    NULL DEFAULT 0.0,
        SDLossInd              FLOAT    NULL DEFAULT 0.0,
        CONSTRAINT FK_MPLT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.QELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.QELT (
        output_set_id   INT   NOT NULL,
        EventId         INT   NULL DEFAULT 0,
        SummaryId       INT   NULL DEFAULT 0,
        Quantile        FLOAT NULL DEFAULT 0.0,
        Loss            FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_QELT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.SELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SELT (
        output_set_id      INT   NOT NULL,
        EventId            INT   NULL DEFAULT 0,
        SummaryId          INT   NULL DEFAULT 0,
        SampleId           INT   NULL DEFAULT 0,
        Loss               FLOAT NULL DEFAULT 0.0,
        ImpactedExposure   FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_SELT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.PSEPT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PSEPT (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NULL DEFAULT 0,
        SampleId        INT   NULL DEFAULT 0,
        EPType          INT   NULL DEFAULT 0,
        ReturnPeriod    FLOAT NULL DEFAULT 0.0,
        Loss            FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_PSEPT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.QPLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.QPLT (
        output_set_id   INT   NOT NULL,
        SummaryId       INT   NULL DEFAULT 0,
        Period          INT   NULL DEFAULT 0,
        PeriodWeight    FLOAT NULL DEFAULT 0.0,
        EventId         INT   NULL DEFAULT 0,
        Year            INT   NULL DEFAULT 0,
        Month           INT   NULL DEFAULT 0,
        Day             INT   NULL DEFAULT 0,
        Hour            INT   NULL DEFAULT 0,
        Minute          INT   NULL DEFAULT 0,
        Quantile        FLOAT NULL DEFAULT 0.0,
        Loss            FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_QPLT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO

IF OBJECT_ID('dbo.SPLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SPLT (
        output_set_id      INT   NOT NULL,
        SummaryId          INT   NULL DEFAULT 0,
        Period             INT   NULL DEFAULT 0,
        PeriodWeight       FLOAT NULL DEFAULT 0.0,
        EventId            INT   NULL DEFAULT 0,
        Year               INT   NULL DEFAULT 0,
        Month              INT   NULL DEFAULT 0,
        Day                INT   NULL DEFAULT 0,
        Hour               INT   NULL DEFAULT 0,
        Minute             INT   NULL DEFAULT 0,
        SampleId           INT   NULL DEFAULT 0,
        Loss               FLOAT NULL DEFAULT 0.0,
        ImpactedExposure   FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_SPLT_OutputSet_output_set_id
            FOREIGN KEY (output_set_id) REFERENCES dbo.OutputSet(id)
    );
END
GO


-- ============================================================================
-- 8. GROUP RESULTS TABLES
-- ============================================================================

IF OBJECT_ID('dbo.GALT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GALT (
        group_set_id   INT   NOT NULL,
        SummaryId      INT   NULL DEFAULT 0,
        LossType       INT   NULL DEFAULT 0,
        MeanLoss       FLOAT NULL DEFAULT 0.0,
        SDLoss         FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_GALT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GEPT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GEPT (
        group_set_id   INT   NOT NULL,
        SummaryId      INT   NULL DEFAULT 0,
        EPCalc         INT   NULL DEFAULT 0,
        EPType         INT   NULL DEFAULT 0,
        ReturnPeriod   FLOAT NULL DEFAULT 0.0,
        Loss           FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_GEPT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GELT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GELT (
        group_set_id           INT   NOT NULL,
        SummaryId              INT   NULL DEFAULT 0,
        EventId                INT   NULL DEFAULT 0,
        SampleType             INT   NULL DEFAULT 0,
        EventRate              FLOAT NULL DEFAULT 0.0,
        ChanceOfLoss           FLOAT NULL DEFAULT 0.0,
        MeanLoss               FLOAT NULL DEFAULT 0.0,
        SDLoss                 FLOAT NULL DEFAULT 0.0,
        MaxLoss                FLOAT NULL DEFAULT 0.0,
        FootprintExposure      FLOAT NULL DEFAULT 0.0,
        MeanImpactedExposure   FLOAT NULL DEFAULT 0.0,
        MaxImpactedExposure    FLOAT NULL DEFAULT 0.0,
        SDLossCor              FLOAT NULL DEFAULT 0.0,
        SDLossInd              FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_GELT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id)
    );
END
GO

IF OBJECT_ID('dbo.GPLT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GPLT (
        group_set_id         INT   NOT NULL,
        group_event_set_id   INT   NOT NULL,
        SummaryId            INT   NULL DEFAULT 0,
        Period               INT   NULL DEFAULT 0,
        EventId              INT   NULL DEFAULT 0,
        LossType             INT   NULL DEFAULT 0,
        Loss                 FLOAT NULL DEFAULT 0.0,
        CONSTRAINT FK_GPLT_GroupSet_group_set_id
            FOREIGN KEY (group_set_id) REFERENCES dbo.GroupSet(id),
        CONSTRAINT FK_GPLT_GroupEventSet_group_event_set_id
            FOREIGN KEY (group_event_set_id) REFERENCES dbo.GroupEventSet(id)
    );
END
GO


-- ============================================================================
-- 9. SEED DATA
-- ============================================================================

TRUNCATE TABLE dbo.DbAttribute;
INSERT INTO dbo.DbAttribute (Attribute, Value)
VALUES
    ('DBTYPE',     'ordb'),
    ('DBVERSION',  '1.0.0'),
    ('ODSVERSION', '2.0.0');
GO


-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
DECLARE @dbVersion NVARCHAR(100);
SELECT @dbVersion = Value FROM dbo.DbAttribute WHERE Attribute = 'DBVERSION';
PRINT 'ORDB v' + @dbVersion + ' schema created successfully: [$(DatabaseName)]';
GO