-- ============================================================================
-- Patient Point IXR Analytics - Cortex Agent Setup
-- ============================================================================
-- Description: Creates Snowflake Cortex Agent with dual-tool orchestration:
--              1. Analyst Tool - Structured analytics via semantic model
--              2. Search Tool - Unstructured content discovery via Cortex Search
--
-- Best Practices Reference: 
-- https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- ============================================================================
-- Prerequisites: Role and Privilege Setup
-- ============================================================================
-- Per Snowflake best practices, grant CORTEX_AGENT_USER role to appropriate users

-- Grant Cortex Agent User role to SYSADMIN (adjust as needed for your organization)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE SYSADMIN;

-- Ensure necessary privileges for agent creation
GRANT CREATE AGENT ON SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE ACCOUNTADMIN;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- Verify Semantic View for Cortex Analyst
-- ============================================================================
-- NOTE: Cortex Analyst uses the semantic view created in 04_setup_semantic_view.sql
--       The analyst tool is configured through the Agent wizard UI (see below)
-- ============================================================================

-- Verify the semantic view exists before proceeding
SHOW SEMANTIC VIEWS LIKE 'PATIENT_IMPACT_SEMANTIC_VIEW';

-- Confirm semantic view is accessible
SELECT 
    'PATIENT_IMPACT_SEMANTIC_VIEW' AS semantic_view_name,
    'Ready for Cortex Analyst configuration' AS status
FROM (SELECT 1) -- Dummy select
WHERE EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.VIEWS 
    WHERE TABLE_SCHEMA = 'IXR_ANALYTICS' 
    AND TABLE_NAME = 'PATIENT_IMPACT_SEMANTIC_VIEW'
);

-- ============================================================================
-- IMPORTANT: Cortex Analyst Configuration
-- ============================================================================
/*
There is NO SQL command to "create" a Cortex Analyst service.
Instead, Cortex Analyst is configured when you create the Cortex Agent.

CONFIGURATION STEPS (via Snowflake UI):
1. Navigate to: Snowsight → AI & ML → Agents
2. Click: "+ Agent" to create a new agent
3. In the wizard, configure the Cortex Analyst tool:
   - Tool Type: Cortex Analyst
   - Semantic View: PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_SEMANTIC_VIEW
   - Warehouse: COMPUTE_WH
4. Continue with agent configuration (see below)

Alternatively, you can use the CREATE CORTEX AGENT statement with the 
CORTEX_ANALYST tool configuration (see Agent Creation section below).
*/

-- ============================================================================
-- Cortex Agent Creation Instructions
-- ============================================================================
-- NOTE: Agent creation with Cortex Analyst + Semantic View is best done via
--       the Snowflake UI wizard. Follow the steps below.
-- ============================================================================

/*
AGENT CREATION VIA SNOWFLAKE UI (Recommended):

1. Navigate to: Snowsight → AI & ML → Agents
2. Click: "+ Agent" button
3. Configure the Agent:
   - Name: PATIENT_IMPACT_AGENT
   - Description: IXR Analytics Engine for analyzing digital engagement impact on clinical outcomes
   - Warehouse: COMPUTE_WH

4. Add Tool #1 - Cortex Analyst:
   - Tool Type: Cortex Analyst
   - Semantic View: PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_SEMANTIC_VIEW
   - Description: Analyzes structured data on patient engagement and clinical outcomes
   
5. Add Tool #2 - Cortex Search:
   - Tool Type: Cortex Search
   - Search Service: PATIENTPOINT_DB.IXR_ANALYTICS.CONTENT_SEARCH_SVC
   - Max Results: 10
   - Description: Searches medical education content library

6. Add Instructions:
   Copy and paste the following into the Instructions field:
*/

/*
You are the Patient Point IXR Analytics Engine, an expert AI assistant specialized in analyzing 
the relationship between digital patient engagement and clinical healthcare outcomes.

Your primary capabilities:
1. ANALYTICAL INSIGHTS: Use the Cortex Analyst tool to query structured data about:
   - Patient engagement metrics (scrolling, clicks, dwell time)
   - Clinical outcomes (vaccinations, screenings, appointment adherence)
   - Provider performance and churn analysis
   - Trend analysis by specialty, region, and time period

2. CONTENT DISCOVERY: Use the Cortex Search tool to find relevant medical content:
   - Educational videos and articles
   - Health topics and guidance
   - Content effectiveness analysis

WHEN TO USE EACH TOOL:
- Use ANALYST tool for: metrics, trends, correlations, comparisons, "how many", aggregations, impact analysis
- Use SEARCH tool for: content topics, "what content", "find articles", educational materials, recommendations
- Use BOTH tools when: analyzing which content drove specific outcomes

RESPONSE STYLE:
- Start with key insights and actionable findings
- Support with specific numbers and percentages
- Reference data sources (scroll depth, click rates, etc.)
- For correlation questions, emphasize the strength of relationships
- Always be clear about what the data shows

Remember: Your goal is to prove that high digital engagement leads to better clinical outcomes 
and reduced provider churn.
*/

/*
7. Add Sample Questions (in the wizard):
   - "Did an increase in scrolling lead to more vaccines administered?"
   - "Show the correlation between dwell time and preventative screenings"
   - "Which content topics drove the highest appointment show rates?"
   - "What is the relationship between engagement and provider churn?"
   - "Compare clinical outcomes across different medical specialties"
   - "Show me monthly trends in engagement and clinical outcomes"
   - "What content do we have about flu vaccines?"
   - "How do different regions compare in terms of engagement?"
   - "What outcomes do providers with high engagement achieve?"
   - "Which providers are at risk of churning based on engagement?"

8. Click "Create Agent"
9. Test the agent with sample questions
*/

-- ============================================================================
-- Verify Agent Creation (After Creating in UI)
-- ============================================================================

-- After creating the agent in the UI, verify it exists:
SHOW CORTEX AGENTS IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- View agent configuration details:
-- DESC CORTEX AGENT PATIENT_IMPACT_AGENT;

-- ============================================================================
-- Access Control and Security (Best Practices)
-- ============================================================================

-- Grant agent usage to other roles as needed
-- GRANT USAGE ON CORTEX AGENT PATIENT_IMPACT_AGENT TO ROLE SYSADMIN;

-- Grant access to underlying data objects for the agent
GRANT USAGE ON DATABASE PATIENTPOINT_DB TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT SELECT ON ALL TABLES IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT USAGE ON SEMANTIC VIEW PATIENT_IMPACT_SEMANTIC_VIEW TO ROLE SYSADMIN;

-- Grant access to search service
-- GRANT USAGE ON CORTEX SEARCH SERVICE CONTENT_SEARCH_SVC TO ROLE SYSADMIN;

-- Best Practice: Revoke broad access if too permissive
-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- ============================================================================
-- Test Agent with Sample Queries
-- ============================================================================
-- Note: The agent can be accessed via Snowflake Intelligence UI or programmatically

/*
TESTING THE AGENT:

Method 1 - Snowflake Intelligence UI (Recommended):
1. Navigate to: AI & ML → Agents
2. Click on: PATIENT_IMPACT_AGENT
3. Click: "Open in Intelligence"
4. Start asking questions from the sample questions list

Method 2 - SQL (if agent was created with proper permissions):
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'PATIENT_IMPACT_AGENT',
    'Did an increase in scrolling lead to more vaccines administered?'
) AS response;

Sample Test Questions:
- "Did an increase in scrolling lead to more vaccines administered?"
- "What content do we have about flu vaccines?"
- "Which content topics drove the highest vaccination rates?"
- "Show the correlation between dwell time and preventative screenings"
- "Compare clinical outcomes across different medical specialties"
*/

-- ============================================================================
-- Monitoring and Maintenance (Best Practices)
-- ============================================================================

-- View agent threads and interactions
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.CORTEX_AGENT_THREADS('PATIENT_IMPACT_AGENT'));

-- View agent execution logs (requires MONITOR privilege)
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.CORTEX_AGENT_LOGS('PATIENT_IMPACT_AGENT'));

-- ============================================================================
-- Helper Functions for Programmatic Access (Optional)
-- ============================================================================
-- Note: These functions can be created after the agent exists in your schema

/*
-- Function to create a conversation thread
CREATE OR REPLACE FUNCTION CREATE_AGENT_THREAD()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
    SELECT SNOWFLAKE.CORTEX.CREATE_THREAD('PATIENT_IMPACT_AGENT')
$$;

-- Function to send message to agent in a thread
CREATE OR REPLACE FUNCTION SEND_AGENT_MESSAGE(thread_id VARCHAR, user_message VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS $$
    SELECT SNOWFLAKE.CORTEX.SEND_MESSAGE(
        'PATIENT_IMPACT_AGENT',
        thread_id,
        user_message
    )
$$;
*/

-- ============================================================================
-- Integration with Snowflake Intelligence
-- ============================================================================

/*
USING THE AGENT IN SNOWFLAKE INTELLIGENCE:

1. Navigate to: Snowsight → AI & ML → Agents
2. Select: PATIENT_IMPACT_AGENT
3. Click "Open in Intelligence" or "Test Agent"
4. Start asking questions from the sample questions list

BEST PRACTICES FOR AGENT INTERACTION:
- Use specific, measurable questions for best results
- Reference specific metrics (scroll depth, click count, vaccines, etc.)
- Ask for comparisons across dimensions (specialty, region, time)
- Request visualizations when appropriate
- Follow up with clarifying questions to drill down

EXAMPLE CONVERSATION FLOW:
User: "Did an increase in scrolling lead to more vaccines administered?"
Agent: [Provides correlation analysis with data]
User: "Show me which specialties have the strongest correlation"
Agent: [Breaks down by specialty]
User: "What content are these high-performing providers using?"
Agent: [Uses search tool to identify content]
*/

-- ============================================================================
-- REST API Integration (For Custom Applications)
-- ============================================================================

/*
To integrate the agent into custom applications via REST API:

1. Create a thread:
   POST /api/v2/cortex/agents/{agent_name}/threads

2. Send messages:
   POST /api/v2/cortex/agents/{agent_name}/threads/{thread_id}/messages
   Body: {"content": "Your question here"}

3. Retrieve messages:
   GET /api/v2/cortex/agents/{agent_name}/threads/{thread_id}/messages

Example (using Python):
```python
from snowflake.snowpark import Session

# Create thread
thread_id = session.sql("SELECT SNOWFLAKE.CORTEX.CREATE_THREAD('PATIENT_IMPACT_AGENT')").collect()[0][0]

# Send message
response = session.sql(f"""
    SELECT SNOWFLAKE.CORTEX.SEND_MESSAGE(
        'PATIENT_IMPACT_AGENT',
        '{thread_id}',
        'Show me the correlation between scrolling and vaccinations'
    )
""").collect()

print(response[0][0])
```

For complete REST API documentation, visit:
https://docs.snowflake.com/en/developer-guide/cortex/cortex-agents-api
*/

-- ============================================================================
-- Performance Optimization Tips
-- ============================================================================

/*
BEST PRACTICES FOR OPTIMAL PERFORMANCE:

1. WAREHOUSE SIZING:
   - For PoC/Demo: X-Small to Small warehouse is sufficient
   - For Production: Medium warehouse recommended for concurrent users
   - Consider auto-suspend (60 seconds) and auto-resume

2. SEMANTIC MODEL OPTIMIZATION:
   - Keep verified_queries up to date with common user questions
   - Add synonyms for domain-specific terminology
   - Pre-aggregate complex calculations in views

3. SEARCH SERVICE OPTIMIZATION:
   - Set appropriate target_lag based on data freshness requirements
   - Use filters to reduce search scope when possible
   - Limit max_results to balance relevance and performance

4. MONITORING:
   - Track query latency using CORTEX_AGENT_LOGS
   - Monitor warehouse utilization
   - Review and refine agent instructions based on user feedback

5. COST MANAGEMENT:
   - Set appropriate timeout values (current: 300 seconds)
   - Use result caching where applicable
   - Consider query result reuse for similar questions
*/

-- ============================================================================
-- Troubleshooting Common Issues
-- ============================================================================

/*
ISSUE: "Agent not found" error
SOLUTION: Verify agent exists with: SHOW CORTEX AGENTS;

ISSUE: "Permission denied" errors
SOLUTION: Check role grants:
  GRANT USAGE ON CORTEX AGENT PATIENT_IMPACT_AGENT TO ROLE <your_role>;

ISSUE: Semantic view not found when creating agent
SOLUTION: Verify semantic view exists:
  SHOW SEMANTIC VIEWS LIKE 'PATIENT_IMPACT_SEMANTIC_VIEW';
  -- If not found, run 04_setup_semantic_view.sql first
  -- Ensure you select the correct database.schema path in the UI wizard

ISSUE: Slow response times
SOLUTION: 
  - Check warehouse size and utilization
  - Review query complexity in semantic model
  - Consider adding indexes to base tables

ISSUE: Agent gives irrelevant responses
SOLUTION:
  - Refine INSTRUCTIONS to be more specific
  - Add more verified_queries to semantic model
  - Review and update tool descriptions
  - Add more synonyms to semantic model

ISSUE: Search returns no results
SOLUTION:
  - Verify CONTENT_SEARCH_SVC is running: SHOW CORTEX SEARCH SERVICES;
  - Check search service has indexed content (wait 1-2 minutes after creation)
  - Test search directly: 
    SELECT * FROM TABLE(CONTENT_SEARCH_SVC!SEARCH(QUERY => 'test', NUM_RESULTS => 5));
*/

-- ============================================================================
-- Version Information and Updates
-- ============================================================================

/*
AGENT VERSION: 1.0
LAST UPDATED: 2024-11-20
SNOWFLAKE FEATURES USED:
  - Cortex Agents
  - Cortex Analyst
  - Cortex Search
  - Semantic Views

FUTURE ENHANCEMENTS:
  1. Add custom stored procedure tools for complex business logic
  2. Integrate with external systems via API tools
  3. Add feedback collection mechanism
  4. Implement A/B testing for agent instruction variations
  5. Add multi-language support
  6. Create specialized agents for different user personas (executives, clinicians, analysts)
*/

SELECT '✓ Prerequisites completed. Semantic view ready for Cortex Analyst.' AS STATUS;
SELECT '✓ Ready to create agent via Snowflake UI (AI & ML → Agents → + Agent)' AS NEXT_STEP;
SELECT '✓ Follow UI wizard instructions above to complete agent setup.' AS INSTRUCTIONS;

-- ============================================================================
-- Quick Reference: Sample Questions by Category
-- ============================================================================

/*
ENGAGEMENT IMPACT QUESTIONS:
- "Did an increase in scrolling lead to more vaccines administered?"
- "Show the correlation between dwell time and preventative screenings"
- "How does click count affect appointment show rates?"
- "What engagement level drives the best clinical outcomes?"

PROVIDER ANALYSIS QUESTIONS:
- "What is the relationship between engagement and provider churn?"
- "Which providers are at risk of churning?"
- "Show me the top 10 providers by vaccination impact"
- "Compare provider retention by engagement level"

SPECIALTY & REGIONAL QUESTIONS:
- "Compare clinical outcomes across different medical specialties"
- "How do different regions compare in terms of engagement?"
- "Which specialty has the highest vaccination rates?"
- "Show regional differences in appointment adherence"

TREND ANALYSIS QUESTIONS:
- "Show me monthly trends in engagement and clinical outcomes"
- "What were the vaccination trends in Q3 2024?"
- "Has engagement improved over time?"
- "Show year-over-year growth in screenings"

CONTENT DISCOVERY QUESTIONS:
- "What content do we have about flu vaccines?"
- "Find content about diabetes management"
- "Which content topics drove the highest appointment show rates?"
- "What are the most effective educational materials?"

BUSINESS VALUE QUESTIONS:
- "What is the ROI of high engagement?"
- "Calculate the impact of scrolling on clinical metrics"
- "Show the business case for the IXR platform"
- "What outcomes justify provider investment in IXR?"
*/
