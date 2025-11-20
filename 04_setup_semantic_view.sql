-- ============================================================================
-- Patient Point IXR Analytics - Semantic View Setup
-- ============================================================================
-- Description: Creates a Snowflake semantic view for natural language queries
--              Replaces the YAML-based semantic model approach
-- Reference: https://docs.snowflake.com/en/user-guide/views-semantic/example
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- ============================================================================
-- Create Semantic View for Patient Point Impact Analysis
-- ============================================================================
-- This semantic view enables Cortex Analyst to understand the relationship
-- between digital engagement metrics and clinical outcomes using natural language

CREATE OR REPLACE SEMANTIC VIEW PATIENT_IMPACT_SEMANTIC_VIEW
  COMMENT = 'Semantic view for analyzing digital engagement impact on clinical outcomes'
  
  -- Define base tables and their primary keys
  TABLES (
    provider_dim AS PATIENTPOINT_DB.IXR_ANALYTICS.PROVIDER_DIM 
      PRIMARY KEY (NPI),
    
    impact_analysis AS PATIENTPOINT_DB.IXR_ANALYTICS.V_IMPACT_ANALYSIS 
      PRIMARY KEY (PROVIDER_NPI, OUTCOME_MONTH)
  )
  
  -- Define relationships between tables
  RELATIONSHIPS (
    impact_analysis (PROVIDER_NPI) REFERENCES provider_dim (NPI)
  )
  
  -- Define facts (base columns and simple calculations)
  FACTS (
    -- Provider Identification
    provider_dim.NPI AS provider_npi,
    provider_dim.PROVIDER_NAME AS provider_name,
    
    -- Time dimensions from impact_analysis
    impact_analysis.OUTCOME_MONTH AS outcome_month,
    impact_analysis.OUTCOME_YEAR AS outcome_year,
    impact_analysis.OUTCOME_MONTH_NAME AS outcome_month_name,
    impact_analysis.OUTCOME_QUARTER AS outcome_quarter,
    
    -- Engagement metrics (raw values)
    impact_analysis.TOTAL_INTERACTIONS AS total_interactions,
    impact_analysis.UNIQUE_DEVICES AS unique_devices,
    impact_analysis.AVG_DWELL_TIME_SEC AS avg_dwell_time_sec,
    impact_analysis.AVG_CLICK_COUNT AS avg_click_count,
    impact_analysis.AVG_SCROLL_DEPTH_PCT AS avg_scroll_depth_pct,
    impact_analysis.MAX_SCROLL_DEPTH_PCT AS max_scroll_depth_pct,
    impact_analysis.TOTAL_DWELL_TIME_SEC AS total_dwell_time_sec,
    impact_analysis.TOTAL_CLICKS AS total_clicks,
    impact_analysis.ENGAGEMENT_SCORE AS engagement_score,
    
    -- Clinical outcomes (raw values)
    impact_analysis.VACCINES_ADMINISTERED AS vaccines_administered,
    impact_analysis.SCREENINGS_COMPLETED AS screenings_completed,
    impact_analysis.APPOINTMENT_SHOW_RATE AS appointment_show_rate,
    
    -- Derived efficiency metrics
    impact_analysis.VACCINES_PER_INTERACTION AS vaccines_per_interaction,
    impact_analysis.SCREENINGS_PER_INTERACTION AS screenings_per_interaction,
    
    -- Content flags
    impact_analysis.HAS_VACCINATION_CONTENT AS has_vaccination_content,
    impact_analysis.HAS_SCREENING_CONTENT AS has_screening_content,
    impact_analysis.HAS_APPOINTMENT_CONTENT AS has_appointment_content
  )
  
  -- Define dimensions (categorical and descriptive attributes)
  DIMENSIONS (
    -- Provider dimensions
    provider_dim.provider_specialty 
      SYNONYMS ('medical specialty', 'provider specialty', 'doctor specialty', 'practice type')
      AS provider_dim.SPECIALTY,
    
    provider_dim.provider_region 
      SYNONYMS ('geographic region', 'location', 'area')
      AS provider_dim.REGION,
    
    provider_dim.provider_active_status 
      SYNONYMS ('active status', 'active provider', 'provider status', 'churned', 'retained')
      AS provider_dim.IS_ACTIVE,
    
    -- Impact analysis dimensions
    impact_analysis.specialty 
      SYNONYMS ('medical specialty', 'provider type', 'specialty type')
      AS impact_analysis.SPECIALTY,
    
    impact_analysis.region 
      SYNONYMS ('geographic region', 'location')
      AS impact_analysis.REGION,
    
    impact_analysis.provider_is_active 
      SYNONYMS ('active', 'churned', 'retention status', 'provider churn')
      AS impact_analysis.PROVIDER_IS_ACTIVE,
    
    impact_analysis.engagement_level 
      SYNONYMS ('engagement category', 'interaction level', 'engagement tier')
      AS impact_analysis.ENGAGEMENT_LEVEL,
    
    -- Time dimension with synonyms
    impact_analysis.reporting_month 
      SYNONYMS ('month', 'time period', 'date', 'reporting month')
      AS impact_analysis.OUTCOME_MONTH
  )
  
  -- Define metrics (aggregated measures)
  METRICS (
    -- Provider counts
    provider_dim.provider_count 
      SYNONYMS ('number of providers', 'provider count', 'total providers', 'how many providers')
      DESCRIPTION 'Total number of unique providers'
      AS COUNT(DISTINCT provider_dim.NPI),
    
    provider_dim.active_provider_count 
      SYNONYMS ('active providers', 'retained providers')
      DESCRIPTION 'Number of active (non-churned) providers'
      AS COUNT(DISTINCT CASE WHEN provider_dim.IS_ACTIVE = TRUE THEN provider_dim.NPI END),
    
    -- Engagement metrics (aggregated)
    impact_analysis.total_engagement_events 
      SYNONYMS ('total interactions', 'interaction count', 'engagement events')
      DESCRIPTION 'Total number of patient interactions with digital screens'
      AS SUM(impact_analysis.TOTAL_INTERACTIONS),
    
    impact_analysis.avg_dwell_time 
      SYNONYMS ('dwell time', 'time spent', 'viewing time', 'engagement time', 'screen time')
      DESCRIPTION 'Average time patients spent viewing content in seconds'
      AS AVG(impact_analysis.AVG_DWELL_TIME_SEC),
    
    impact_analysis.avg_clicks 
      SYNONYMS ('clicks', 'click count', 'interactions', 'number of clicks', 'user clicks')
      DESCRIPTION 'Average number of clicks per interaction'
      AS AVG(impact_analysis.AVG_CLICK_COUNT),
    
    impact_analysis.avg_scroll_depth 
      SYNONYMS ('scrolling', 'scroll depth', 'scroll percentage', 'how far scrolled', 'content consumption', 'reading depth')
      DESCRIPTION 'Average percentage of content scrolled through (0-100%)'
      AS AVG(impact_analysis.AVG_SCROLL_DEPTH_PCT),
    
    impact_analysis.max_scroll 
      SYNONYMS ('maximum scroll', 'deepest scroll', 'max scroll depth')
      DESCRIPTION 'Maximum scroll depth achieved'
      AS MAX(impact_analysis.MAX_SCROLL_DEPTH_PCT),
    
    impact_analysis.total_dwell_time 
      SYNONYMS ('total time spent', 'cumulative time', 'total viewing time')
      DESCRIPTION 'Total cumulative dwell time across all interactions'
      AS SUM(impact_analysis.TOTAL_DWELL_TIME_SEC),
    
    impact_analysis.total_click_volume 
      SYNONYMS ('total clicks', 'click volume', 'cumulative clicks')
      DESCRIPTION 'Total number of clicks across all interactions'
      AS SUM(impact_analysis.TOTAL_CLICKS),
    
    impact_analysis.avg_engagement_score 
      SYNONYMS ('engagement score', 'engagement index', 'interaction score')
      DESCRIPTION 'Composite engagement score from scroll, clicks, and dwell time'
      AS AVG(impact_analysis.ENGAGEMENT_SCORE),
    
    -- Clinical outcome metrics (aggregated)
    impact_analysis.total_vaccines 
      SYNONYMS ('vaccines', 'vaccinations', 'shots', 'immunizations', 'vaccine count', 'shots given')
      DESCRIPTION 'Total number of vaccines administered to patients'
      AS SUM(impact_analysis.VACCINES_ADMINISTERED),
    
    impact_analysis.avg_vaccines_per_provider 
      SYNONYMS ('average vaccines', 'vaccines per provider', 'mean vaccinations')
      DESCRIPTION 'Average number of vaccines administered per provider per month'
      AS AVG(impact_analysis.VACCINES_ADMINISTERED),
    
    impact_analysis.total_screenings 
      SYNONYMS ('screenings', 'preventative screenings', 'health screenings', 'screening tests', 'preventive care')
      DESCRIPTION 'Total number of preventative health screenings completed'
      AS SUM(impact_analysis.SCREENINGS_COMPLETED),
    
    impact_analysis.avg_screenings_per_provider 
      SYNONYMS ('average screenings', 'screenings per provider', 'mean screenings')
      DESCRIPTION 'Average number of screenings completed per provider per month'
      AS AVG(impact_analysis.SCREENINGS_COMPLETED),
    
    impact_analysis.avg_show_rate 
      SYNONYMS ('show rate', 'appointment adherence', 'no-show rate', 'attendance rate', 'kept appointments')
      DESCRIPTION 'Average rate of patients showing up for scheduled appointments'
      AS AVG(impact_analysis.APPOINTMENT_SHOW_RATE),
    
    -- Efficiency metrics
    impact_analysis.avg_vaccine_efficiency 
      SYNONYMS ('vaccine efficiency', 'vaccines per engagement', 'vaccination rate')
      DESCRIPTION 'Average vaccines administered per patient interaction'
      AS AVG(impact_analysis.VACCINES_PER_INTERACTION),
    
    impact_analysis.avg_screening_efficiency 
      SYNONYMS ('screening efficiency', 'screenings per engagement', 'screening rate')
      DESCRIPTION 'Average screenings completed per patient interaction'
      AS AVG(impact_analysis.SCREENINGS_PER_INTERACTION),
    
    -- Retention metrics
    impact_analysis.retention_rate 
      SYNONYMS ('retention rate', 'churn rate', 'provider retention', 'active rate')
      DESCRIPTION 'Percentage of providers who remain active (not churned)'
      AS AVG(CASE WHEN impact_analysis.PROVIDER_IS_ACTIVE = TRUE THEN 100.0 ELSE 0.0 END)
  )
;

-- ============================================================================
-- Verify Semantic View Creation
-- ============================================================================

-- Show the semantic view
SHOW SEMANTIC VIEWS LIKE 'PATIENT_IMPACT_SEMANTIC_VIEW';

-- Describe the semantic view structure
DESC SEMANTIC VIEW PATIENT_IMPACT_SEMANTIC_VIEW;

-- ============================================================================
-- Test Queries Using the Semantic View
-- ============================================================================

-- Test 1: Simple aggregation query
SELECT 
    specialty,
    provider_count,
    total_vaccines,
    avg_scroll_depth
FROM PATIENT_IMPACT_SEMANTIC_VIEW
GROUP BY specialty
ORDER BY total_vaccines DESC;

-- Test 2: Time-based trend analysis
SELECT 
    outcome_month,
    total_vaccines,
    total_screenings,
    avg_show_rate
FROM PATIENT_IMPACT_SEMANTIC_VIEW
GROUP BY outcome_month
ORDER BY outcome_month;

-- Test 3: Engagement level comparison
SELECT 
    engagement_level,
    provider_count,
    avg_scroll_depth,
    total_vaccines,
    retention_rate
FROM PATIENT_IMPACT_SEMANTIC_VIEW
GROUP BY engagement_level
ORDER BY 
    CASE engagement_level 
        WHEN 'High' THEN 1 
        WHEN 'Medium' THEN 2 
        ELSE 3 
    END;

-- ============================================================================
-- Grant Access to the Semantic View
-- ============================================================================

-- Grant usage to SYSADMIN role
GRANT USAGE ON SEMANTIC VIEW PATIENT_IMPACT_SEMANTIC_VIEW TO ROLE SYSADMIN;

-- Grant access to underlying objects
GRANT SELECT ON VIEW V_IMPACT_ANALYSIS TO ROLE SYSADMIN;

SELECT '✓ Semantic view created successfully. Ready for Cortex Analyst integration.' AS STATUS;

-- ============================================================================
-- Integration Notes
-- ============================================================================
/*
USING THE SEMANTIC VIEW WITH CORTEX ANALYST:

The semantic view replaces the need for a YAML file. When creating the 
Cortex Analyst service, you can now reference this semantic view directly:

CREATE OR REPLACE CORTEX ANALYST SERVICE PATIENT_IMPACT_ANALYST
    SEMANTIC_VIEW = 'PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_SEMANTIC_VIEW'
    WAREHOUSE = COMPUTE_WH
    COMMENT = 'Cortex Analyst using native semantic view';

BENEFITS OF SEMANTIC VIEWS OVER YAML:
1. Native Snowflake object - no file upload required
2. Version controlled through SQL scripts
3. Can be managed with standard DDL commands
4. Integrated with Snowflake's metadata and governance
5. Easier to update and maintain
6. Better integration with Snowflake Intelligence

SAMPLE NATURAL LANGUAGE QUESTIONS:
- "Did an increase in scrolling lead to more vaccines administered?"
- "Show the correlation between dwell time and preventative screenings"
- "What is the relationship between engagement and provider churn?"
- "Compare clinical outcomes across different medical specialties"
- "Show me monthly trends in engagement and clinical outcomes"
*/

