-- ============================================================================
-- Patient Point IXR Analytics - Cortex Search Service Setup
-- ============================================================================
-- Description: Creates Cortex Search Service for semantic search over 
--              unstructured medical content (videos, articles, transcripts)
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- ============================================================================
-- Cortex Search Service Configuration
-- ============================================================================
-- Purpose: Enable semantic search on CONTENT_LIBRARY to allow the Cortex Agent
--          to retrieve relevant medical content based on natural language queries
-- ============================================================================

-- Create Cortex Search Service on Content Library
CREATE OR REPLACE CORTEX SEARCH SERVICE CONTENT_SEARCH_SVC
ON TRANSCRIPT_TEXT
ATTRIBUTES TITLE, CONTENT_TYPE, PUBLISH_DATE
WAREHOUSE = COMPUTE_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        CONTENT_ID,
        TRANSCRIPT_TEXT,
        TITLE,
        CONTENT_TYPE,
        PUBLISH_DATE
    FROM CONTENT_LIBRARY
);

-- ============================================================================
-- Test Search Service
-- ============================================================================

-- Wait a moment for the service to initialize
CALL SYSTEM$WAIT(5);

-- Test Query 1: Search for vaccination content
SELECT 
    'Vaccination Search Test' AS TEST_NAME,
    *
FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'flu vaccine importance for seniors',
        NUM_RESULTS => 5
    )
);

-- Test Query 2: Search for cancer screening content  
SELECT 
    'Cancer Screening Test' AS TEST_NAME,
    *
FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'cancer screening guidelines and recommendations',
        NUM_RESULTS => 5
    )
);

-- Test Query 3: Search for diabetes management
SELECT 
    'Diabetes Management Test' AS TEST_NAME,
    *
FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'how to manage type 2 diabetes effectively',
        NUM_RESULTS => 5
    )
);

-- Test Query 4: Search for preventative care
SELECT 
    'Preventative Care Test' AS TEST_NAME,
    *
FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'preventative health screenings and checkups',
        NUM_RESULTS => 5
    )
);

-- ============================================================================
-- Service Status and Metadata
-- ============================================================================

-- Show search service details
SHOW CORTEX SEARCH SERVICES LIKE 'CONTENT_SEARCH_SVC';

-- Describe the search service
DESC CORTEX SEARCH SERVICE CONTENT_SEARCH_SVC;

-- ============================================================================
-- Usage Examples for Cortex Agent Integration
-- ============================================================================

-- Example 1: Find content related to appointment adherence
-- The agent will use this pattern to retrieve contextual content
/*
SELECT * FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'appointment reminders and show rates',
        NUM_RESULTS => 3
    )
);
*/

-- Example 2: Find content that might influence screening rates
/*
SELECT * FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'preventative screening benefits early detection',
        NUM_RESULTS => 5
    )
);
*/

-- Example 3: Find content about patient engagement
/*
SELECT * FROM TABLE(
    CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'patient education digital health content',
        NUM_RESULTS => 5
    )
);
*/

-- ============================================================================
-- Performance View - Link Search Results to Engagement
-- ============================================================================

-- Create a helper view to analyze which content topics drive engagement
CREATE OR REPLACE VIEW V_CONTENT_ENGAGEMENT_ANALYSIS AS
WITH content_keywords AS (
    SELECT 
        CONTENT_ID,
        TITLE,
        CONTENT_TYPE,
        CASE 
            WHEN LOWER(TITLE) LIKE '%vaccine%' OR LOWER(TITLE) LIKE '%vaccination%' THEN 'Vaccination'
            WHEN LOWER(TITLE) LIKE '%screen%' OR LOWER(TITLE) LIKE '%cancer%' THEN 'Screening'
            WHEN LOWER(TITLE) LIKE '%diabetes%' THEN 'Diabetes'
            WHEN LOWER(TITLE) LIKE '%heart%' OR LOWER(TITLE) LIKE '%cardio%' THEN 'Cardiovascular'
            WHEN LOWER(TITLE) LIKE '%appointment%' THEN 'Appointment'
            ELSE 'General Health'
        END AS TOPIC_CATEGORY
    FROM CONTENT_LIBRARY
),
engagement_by_category AS (
    SELECT 
        m.CONTENT_CATEGORY,
        COUNT(*) AS VIEW_COUNT,
        ROUND(AVG(m.SCROLL_DEPTH_PCT), 2) AS AVG_SCROLL_DEPTH,
        ROUND(AVG(m.CLICK_COUNT), 2) AS AVG_CLICKS,
        ROUND(AVG(m.DWELL_TIME_SEC), 2) AS AVG_DWELL_TIME
    FROM IXR_METRICS m
    GROUP BY m.CONTENT_CATEGORY
)
SELECT 
    ck.TOPIC_CATEGORY,
    COUNT(DISTINCT ck.CONTENT_ID) AS CONTENT_PIECES,
    ec.VIEW_COUNT,
    ec.AVG_SCROLL_DEPTH,
    ec.AVG_CLICKS,
    ec.AVG_DWELL_TIME,
    -- Engagement score
    (ec.AVG_SCROLL_DEPTH * 0.4 + ec.AVG_CLICKS * 2.0 + ec.AVG_DWELL_TIME * 0.1) AS ENGAGEMENT_SCORE
FROM content_keywords ck
LEFT JOIN engagement_by_category ec 
    ON ck.TOPIC_CATEGORY = ec.CONTENT_CATEGORY
GROUP BY 
    ck.TOPIC_CATEGORY,
    ec.VIEW_COUNT,
    ec.AVG_SCROLL_DEPTH,
    ec.AVG_CLICKS,
    ec.AVG_DWELL_TIME
ORDER BY ENGAGEMENT_SCORE DESC NULLS LAST;

-- Show content engagement summary
SELECT * FROM V_CONTENT_ENGAGEMENT_ANALYSIS;

SELECT '✓ Cortex Search Service created and tested successfully.' AS STATUS;

