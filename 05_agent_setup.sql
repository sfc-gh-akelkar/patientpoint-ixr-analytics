-- ============================================================================
-- Patient Point IXR Analytics - Cortex Agent Setup
-- ============================================================================
-- Description: Creates Snowflake Cortex Agent with dual-tool orchestration:
--              1. Analyst Tool - Structured analytics via semantic model
--              2. Search Tool - Unstructured content discovery via Cortex Search
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- ============================================================================
-- Stage Setup for Semantic Model File
-- ============================================================================

-- Create internal stage for the semantic model YAML
CREATE STAGE IF NOT EXISTS SEMANTIC_MODEL_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Upload the semantic model YAML file to stage
-- Note: After running this script, upload 04_semantic_model.yaml to this stage using:
-- PUT file:///path/to/04_semantic_model.yaml @SEMANTIC_MODEL_STAGE AUTO_COMPRESS=FALSE;

-- Verify stage contents
LIST @SEMANTIC_MODEL_STAGE;

-- ============================================================================
-- Cortex Analyst Service Setup
-- ============================================================================

-- Create Cortex Analyst service using the semantic model
CREATE OR REPLACE CORTEX ANALYST SERVICE PATIENT_IMPACT_ANALYST
    SEMANTIC_MODEL_FILE = '@SEMANTIC_MODEL_STAGE/04_semantic_model.yaml'
    WAREHOUSE = COMPUTE_WH;

-- Test the analyst with a sample query
-- SELECT SNOWFLAKE.CORTEX.COMPLETE_ANALYST(
--     'PATIENT_IMPACT_ANALYST',
--     'Did an increase in scrolling lead to more vaccines administered?'
-- );

-- ============================================================================
-- Cortex Agent Creation with Dual Tools
-- ============================================================================

CREATE OR REPLACE CORTEX AGENT PATIENT_IMPACT_AGENT
AS $$
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
from snowflake.cortex import Complete, Analyst
import json

def agent_handler(session: snowpark.Session, user_query: str) -> dict:
    """
    Orchestrates between analytical queries and content search.
    
    Tools:
    1. analyst_tool: Uses Cortex Analyst for structured data queries
    2. search_tool: Uses Cortex Search for content discovery
    
    Args:
        session: Snowflake session
        user_query: Natural language question from user
        
    Returns:
        dict: Response containing answer, SQL (if applicable), and sources
    """
    
    # ========================================================================
    # Tool Definitions
    # ========================================================================
    
    def analyst_tool(query: str) -> dict:
        """
        Executes analytical queries using Cortex Analyst.
        Handles questions about metrics, trends, correlations, and impacts.
        """
        try:
            # Call Cortex Analyst
            result = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE_ANALYST(
                    'PATIENT_IMPACT_ANALYST',
                    '{query.replace("'", "''")}'
                ) AS response
            """).collect()
            
            response_json = json.loads(result[0]['RESPONSE'])
            
            # Extract SQL and execute to get results
            if 'sql' in response_json:
                sql_query = response_json['sql']
                data_results = session.sql(sql_query).collect()
                
                return {
                    'tool': 'analyst',
                    'status': 'success',
                    'sql': sql_query,
                    'data': [row.as_dict() for row in data_results],
                    'interpretation': response_json.get('interpretation', ''),
                    'row_count': len(data_results)
                }
            else:
                return {
                    'tool': 'analyst',
                    'status': 'success',
                    'interpretation': response_json.get('interpretation', ''),
                    'message': response_json.get('message', '')
                }
                
        except Exception as e:
            return {
                'tool': 'analyst',
                'status': 'error',
                'error': str(e)
            }
    
    def search_tool(query: str, num_results: int = 5) -> dict:
        """
        Searches medical content library using Cortex Search.
        Handles questions about content topics, recommendations, and guidance.
        """
        try:
            # Call Cortex Search
            search_results = session.sql(f"""
                SELECT * FROM TABLE(
                    CONTENT_SEARCH_SVC!SEARCH(
                        QUERY => '{query.replace("'", "''")}',
                        NUM_RESULTS => {num_results}
                    )
                )
            """).collect()
            
            return {
                'tool': 'search',
                'status': 'success',
                'results': [row.as_dict() for row in search_results],
                'count': len(search_results)
            }
            
        except Exception as e:
            return {
                'tool': 'search',
                'status': 'error',
                'error': str(e)
            }
    
    # ========================================================================
    # Intent Classification
    # ========================================================================
    
    def classify_intent(query: str) -> str:
        """
        Determines which tool to use based on query intent.
        
        Returns:
            'analyst' - for metrics, trends, correlations, comparisons
            'search' - for content topics, recommendations, educational material
            'both' - when both tools would be helpful
        """
        query_lower = query.lower()
        
        # Analytical keywords
        analytical_keywords = [
            'correlation', 'impact', 'trend', 'compare', 'comparison',
            'metric', 'rate', 'increase', 'decrease', 'lead to',
            'show rate', 'vaccine', 'screening', 'churn', 'retention',
            'scroll', 'click', 'dwell', 'engagement', 'outcome',
            'how many', 'what is the', 'average', 'total', 'sum',
            'by specialty', 'by region', 'monthly', 'quarterly'
        ]
        
        # Content search keywords
        search_keywords = [
            'content', 'topic', 'article', 'video', 'about',
            'information on', 'tell me about', 'what content',
            'which content', 'educational', 'material', 'guidance',
            'recommendation', 'advice'
        ]
        
        # Combination keywords (use both tools)
        both_keywords = [
            'content drove', 'content impact', 'which topics',
            'content and outcome', 'content performance'
        ]
        
        # Check for combination queries first
        if any(keyword in query_lower for keyword in both_keywords):
            return 'both'
        
        # Count analytical vs search keywords
        analytical_count = sum(1 for kw in analytical_keywords if kw in query_lower)
        search_count = sum(1 for kw in search_keywords if kw in query_lower)
        
        if analytical_count > search_count:
            return 'analyst'
        elif search_count > analytical_count:
            return 'search'
        elif analytical_count > 0:
            return 'analyst'
        else:
            return 'analyst'  # Default to analyst
    
    # ========================================================================
    # Main Agent Logic
    # ========================================================================
    
    intent = classify_intent(user_query)
    
    if intent == 'analyst':
        # Use only the analyst tool
        result = analyst_tool(user_query)
        
        # Format response
        if result['status'] == 'success':
            response = {
                'answer': result.get('interpretation', 'Analysis completed successfully.'),
                'tool_used': 'analyst',
                'sql': result.get('sql', ''),
                'data': result.get('data', []),
                'row_count': result.get('row_count', 0)
            }
        else:
            response = {
                'answer': f"Error in analysis: {result.get('error', 'Unknown error')}",
                'tool_used': 'analyst',
                'status': 'error'
            }
            
    elif intent == 'search':
        # Use only the search tool
        result = search_tool(user_query)
        
        if result['status'] == 'success':
            # Format search results into readable answer
            content_summaries = []
            for item in result['results'][:3]:  # Top 3 results
                content_summaries.append(
                    f"- {item.get('TITLE', 'Untitled')}: {item.get('TRANSCRIPT_TEXT', '')[:200]}..."
                )
            
            response = {
                'answer': f"Found {result['count']} relevant content pieces:\n\n" + "\n\n".join(content_summaries),
                'tool_used': 'search',
                'search_results': result['results'],
                'result_count': result['count']
            }
        else:
            response = {
                'answer': f"Error in content search: {result.get('error', 'Unknown error')}",
                'tool_used': 'search',
                'status': 'error'
            }
            
    else:  # intent == 'both'
        # Use both tools in sequence
        analyst_result = analyst_tool(user_query)
        search_result = search_tool(user_query, num_results=3)
        
        # Combine results
        answer_parts = []
        
        if analyst_result['status'] == 'success':
            answer_parts.append("**Analytical Insights:**")
            answer_parts.append(analyst_result.get('interpretation', ''))
            
        if search_result['status'] == 'success':
            answer_parts.append("\n**Related Content:**")
            for item in search_result['results'][:2]:
                answer_parts.append(f"- {item.get('TITLE', 'Untitled')}")
        
        response = {
            'answer': "\n".join(answer_parts),
            'tool_used': 'both',
            'analyst_data': analyst_result,
            'search_data': search_result
        }
    
    return response

# Register the handler
def main(session: snowpark.Session, user_query: str) -> dict:
    return agent_handler(session, user_query)
$$
HANDLER = 'main'
PACKAGES = ('snowflake-snowpark-python', 'snowflake-ml-python')
RUNTIME_NAME = 'python_runtime';

-- ============================================================================
-- Test Agent with Sample Queries
-- ============================================================================

-- Test 1: Analytical query
SELECT PATIENT_IMPACT_AGENT(
    'Did an increase in scrolling lead to more vaccines administered?'
) AS response;

-- Test 2: Content search query
SELECT PATIENT_IMPACT_AGENT(
    'What content do we have about flu vaccines?'
) AS response;

-- Test 3: Combined query
SELECT PATIENT_IMPACT_AGENT(
    'Which content topics drove the highest vaccination rates?'
) AS response;

-- Test 4: Churn analysis
SELECT PATIENT_IMPACT_AGENT(
    'What is the relationship between engagement and provider churn?'
) AS response;

-- Test 5: Specialty comparison
SELECT PATIENT_IMPACT_AGENT(
    'Compare clinical outcomes across different medical specialties'
) AS response;

-- ============================================================================
-- Helper Functions for Streamlit Integration
-- ============================================================================

-- Function to format agent response for UI
CREATE OR REPLACE FUNCTION FORMAT_AGENT_RESPONSE(response VARIANT)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS $$
    try {
        const resp = JSON.parse(RESPONSE);
        
        // Extract key components for UI rendering
        return {
            answer: resp.answer || 'No answer provided',
            sql: resp.sql || null,
            data: resp.data || [],
            tool_used: resp.tool_used || 'unknown',
            has_visualization_data: (resp.data && resp.data.length > 0),
            search_results: resp.search_results || []
        };
    } catch (e) {
        return {
            answer: 'Error parsing response',
            error: e.message
        };
    }
$$;

-- Function to determine if query needs visualization
CREATE OR REPLACE FUNCTION NEEDS_VISUALIZATION(query TEXT)
RETURNS BOOLEAN
LANGUAGE JAVASCRIPT
AS $$
    const query_lower = QUERY.toLowerCase();
    const viz_keywords = [
        'impact', 'correlation', 'trend', 'compare', 'comparison',
        'increase', 'decrease', 'lead to', 'relationship',
        'over time', 'by month', 'by specialty', 'by region'
    ];
    
    return viz_keywords.some(keyword => query_lower.includes(keyword));
$$;

-- ============================================================================
-- Permissions and Grants
-- ============================================================================

-- Grant usage to appropriate roles
GRANT USAGE ON CORTEX ANALYST SERVICE PATIENT_IMPACT_ANALYST TO ROLE SYSADMIN;
GRANT USAGE ON CORTEX AGENT PATIENT_IMPACT_AGENT TO ROLE SYSADMIN;

-- Grant access to underlying objects
GRANT USAGE ON DATABASE PATIENTPOINT_DB TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT SELECT ON ALL TABLES IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;

SELECT '✓ Cortex Agent created with dual-tool orchestration (Analyst + Search).' AS STATUS;

-- ============================================================================
-- Usage Instructions
-- ============================================================================

/*
To use the agent from SQL:

1. Simple query:
   SELECT PATIENT_IMPACT_AGENT('your question here') AS response;

2. Parse and format response:
   SELECT FORMAT_AGENT_RESPONSE(
       PATIENT_IMPACT_AGENT('your question here')
   ) AS formatted_response;

3. Check if visualization needed:
   SELECT NEEDS_VISUALIZATION('your question here') AS needs_viz;

Sample Questions to Ask:
- "Did an increase in scrolling lead to more vaccines administered?"
- "Show the correlation between dwell time and preventative screenings"
- "Which content topics drove the highest appointment show rates?"
- "What is the relationship between engagement levels and provider churn?"
- "Compare clinical outcomes across different medical specialties"
- "Show me monthly trends in engagement and clinical outcomes"
- "What content do we have about diabetes management?"
- "How do different regions compare in terms of engagement and outcomes?"
- "What outcomes do providers with high engagement achieve?"
- "Find content about cancer screening guidelines"
*/

