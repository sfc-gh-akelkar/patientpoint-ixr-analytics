"""
============================================================================
Patient Point IXR Analytics - Streamlit Application
============================================================================
Description: Interactive chat interface for exploring the relationship 
             between digital engagement and clinical outcomes using 
             Snowflake Cortex Agent.

Features:
- Natural language chat interface
- Automatic visualization generation for impact/correlation queries
- SQL transparency with expandable query viewer
- Real-time analytics powered by Cortex Agent
============================================================================
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col

# ============================================================================
# Page Configuration
# ============================================================================

st.set_page_config(
    page_title="Patient Point Impact Engine",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# Custom CSS for Professional UI
# ============================================================================

st.markdown("""
<style>
    /* Main title styling */
    .main-title {
        font-size: 2.5rem;
        font-weight: 700;
        color: #1f77b4;
        margin-bottom: 0.5rem;
    }
    
    .subtitle {
        font-size: 1.2rem;
        color: #666;
        margin-bottom: 2rem;
    }
    
    /* Chat message styling */
    .user-message {
        background-color: #e3f2fd;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        border-left: 4px solid #1f77b4;
    }
    
    .agent-message {
        background-color: #f5f5f5;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        border-left: 4px solid #4caf50;
    }
    
    /* Metric cards */
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1.5rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin: 0.5rem;
    }
    
    .metric-value {
        font-size: 2rem;
        font-weight: 700;
    }
    
    .metric-label {
        font-size: 0.9rem;
        opacity: 0.9;
    }
    
    /* SQL code styling */
    .sql-container {
        background-color: #282c34;
        color: #abb2bf;
        padding: 1rem;
        border-radius: 5px;
        font-family: 'Courier New', monospace;
        font-size: 0.9rem;
        overflow-x: auto;
    }
    
    /* Button styling */
    .stButton>button {
        background-color: #1f77b4;
        color: white;
        border-radius: 5px;
        padding: 0.5rem 2rem;
        font-weight: 600;
        border: none;
        transition: all 0.3s;
    }
    
    .stButton>button:hover {
        background-color: #1565c0;
        box-shadow: 0 4px 8px rgba(0,0,0,0.2);
    }
    
    /* Sample questions styling */
    .sample-question {
        background-color: #fff3e0;
        padding: 0.8rem;
        border-radius: 5px;
        margin: 0.5rem 0;
        cursor: pointer;
        border: 1px solid #ffb74d;
        transition: all 0.2s;
    }
    
    .sample-question:hover {
        background-color: #ffe0b2;
        border-color: #ff9800;
    }
</style>
""", unsafe_allow_html=True)

# ============================================================================
# Session State Initialization
# ============================================================================

if 'messages' not in st.session_state:
    st.session_state.messages = []

if 'current_data' not in st.session_state:
    st.session_state.current_data = None

if 'current_sql' not in st.session_state:
    st.session_state.current_sql = None

# ============================================================================
# Helper Functions
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

def query_agent(user_query: str) -> dict:
    """
    Query the Cortex Agent with a natural language question.
    
    Args:
        user_query: Natural language question
        
    Returns:
        dict: Parsed response from agent
    """
    session = get_session()
    
    try:
        # Call the Cortex Agent
        result = session.sql(f"""
            SELECT PATIENT_IMPACT_AGENT('{user_query.replace("'", "''")}') AS response
        """).collect()
        
        # Parse JSON response
        response_str = result[0]['RESPONSE']
        response_dict = json.loads(response_str) if isinstance(response_str, str) else response_str
        
        return {
            'status': 'success',
            'response': response_dict
        }
        
    except Exception as e:
        return {
            'status': 'error',
            'error': str(e)
        }

def needs_visualization(query: str, response: dict) -> bool:
    """
    Determine if the query/response should trigger a visualization.
    
    Args:
        query: User's question
        response: Agent response
        
    Returns:
        bool: True if visualization should be shown
    """
    query_lower = query.lower()
    
    # Keywords that suggest visualization would be helpful
    viz_keywords = [
        'impact', 'correlation', 'trend', 'compare', 'comparison',
        'increase', 'decrease', 'lead to', 'relationship',
        'show', 'visualize', 'plot', 'chart'
    ]
    
    # Check if query contains visualization keywords
    has_viz_keyword = any(keyword in query_lower for keyword in viz_keywords)
    
    # Check if response has data suitable for visualization
    has_data = (
        response.get('data') and 
        len(response.get('data', [])) > 0 and
        len(response.get('data', [])) > 1  # Need at least 2 rows for meaningful viz
    )
    
    return has_viz_keyword and has_data

def create_visualization(query: str, data: list) -> go.Figure:
    """
    Create appropriate visualization based on query and data.
    
    Args:
        query: User's question
        data: List of dictionaries containing query results
        
    Returns:
        Plotly figure object
    """
    df = pd.DataFrame(data)
    query_lower = query.lower()
    
    # Determine visualization type based on query and data structure
    
    # Scatter plot for correlation/impact queries
    if any(keyword in query_lower for keyword in ['correlation', 'impact', 'lead to', 'relationship']):
        # Try to identify x and y axes
        engagement_cols = [col for col in df.columns if any(
            term in col.lower() for term in ['scroll', 'click', 'dwell', 'engagement']
        )]
        outcome_cols = [col for col in df.columns if any(
            term in col.lower() for term in ['vaccine', 'screening', 'show_rate', 'appointment']
        )]
        
        if engagement_cols and outcome_cols:
            x_col = engagement_cols[0]
            y_col = outcome_cols[0]
            
            # Check for categorical color column
            color_col = None
            for col in df.columns:
                if any(term in col.lower() for term in ['specialty', 'region', 'level', 'category']):
                    color_col = col
                    break
            
            fig = px.scatter(
                df,
                x=x_col,
                y=y_col,
                color=color_col,
                size=y_col if df[y_col].dtype in ['int64', 'float64'] else None,
                hover_data=df.columns.tolist(),
                title=f"Impact of {x_col} on {y_col}",
                labels={x_col: x_col.replace('_', ' ').title(), 
                       y_col: y_col.replace('_', ' ').title()},
                template="plotly_white"
            )
            
            # Add trendline
            if df[x_col].dtype in ['int64', 'float64'] and df[y_col].dtype in ['int64', 'float64']:
                fig.update_traces(marker=dict(size=12, line=dict(width=1, color='white')))
                
                # Calculate and add regression line
                import numpy as np
                z = np.polyfit(df[x_col], df[y_col], 1)
                p = np.poly1d(z)
                fig.add_trace(go.Scatter(
                    x=df[x_col].sort_values(),
                    y=p(df[x_col].sort_values()),
                    mode='lines',
                    name='Trend',
                    line=dict(color='red', dash='dash', width=2)
                ))
            
            return fig
    
    # Bar chart for comparisons
    if any(keyword in query_lower for keyword in ['compare', 'comparison', 'across', 'by']):
        # Find categorical and numeric columns
        cat_cols = df.select_dtypes(include=['object']).columns.tolist()
        num_cols = df.select_dtypes(include=['int64', 'float64']).columns.tolist()
        
        if cat_cols and num_cols:
            x_col = cat_cols[0]
            # Choose the most relevant numeric column
            y_col = num_cols[0]
            for col in num_cols:
                if any(term in col.lower() for term in ['vaccine', 'screening', 'total', 'count']):
                    y_col = col
                    break
            
            fig = px.bar(
                df,
                x=x_col,
                y=y_col,
                color=x_col,
                title=f"{y_col.replace('_', ' ').title()} by {x_col.replace('_', ' ').title()}",
                labels={x_col: x_col.replace('_', ' ').title(),
                       y_col: y_col.replace('_', ' ').title()},
                template="plotly_white"
            )
            fig.update_layout(showlegend=False)
            return fig
    
    # Line chart for trends over time
    if any(keyword in query_lower for keyword in ['trend', 'over time', 'monthly', 'quarterly']):
        time_cols = [col for col in df.columns if any(
            term in col.lower() for term in ['month', 'quarter', 'year', 'date', 'time']
        )]
        
        if time_cols:
            x_col = time_cols[0]
            num_cols = df.select_dtypes(include=['int64', 'float64']).columns.tolist()
            
            # Create multi-line chart for key metrics
            fig = go.Figure()
            
            for col in num_cols[:3]:  # Limit to 3 metrics for readability
                fig.add_trace(go.Scatter(
                    x=df[x_col],
                    y=df[col],
                    mode='lines+markers',
                    name=col.replace('_', ' ').title(),
                    line=dict(width=3),
                    marker=dict(size=8)
                ))
            
            fig.update_layout(
                title="Trends Over Time",
                xaxis_title=x_col.replace('_', ' ').title(),
                yaxis_title="Value",
                template="plotly_white",
                hovermode='x unified'
            )
            
            return fig
    
    # Default: Create a simple bar chart with first categorical and numeric columns
    cat_cols = df.select_dtypes(include=['object']).columns.tolist()
    num_cols = df.select_dtypes(include=['int64', 'float64']).columns.tolist()
    
    if cat_cols and num_cols:
        fig = px.bar(
            df,
            x=cat_cols[0],
            y=num_cols[0],
            title=f"Analysis Results",
            template="plotly_white"
        )
        return fig
    
    # If all else fails, create a simple table visualization
    return None

def get_summary_metrics() -> dict:
    """Get high-level summary metrics for dashboard"""
    session = get_session()
    
    try:
        # Get key metrics
        metrics = session.sql("""
            SELECT 
                COUNT(DISTINCT PROVIDER_NPI) AS total_providers,
                SUM(TOTAL_INTERACTIONS) AS total_interactions,
                ROUND(AVG(AVG_SCROLL_DEPTH_PCT), 1) AS avg_scroll_depth,
                SUM(VACCINES_ADMINISTERED) AS total_vaccines,
                SUM(SCREENINGS_COMPLETED) AS total_screenings,
                ROUND(AVG(APPOINTMENT_SHOW_RATE) * 100, 1) AS avg_show_rate
            FROM V_IMPACT_ANALYSIS
        """).collect()[0]
        
        return {
            'total_providers': metrics['TOTAL_PROVIDERS'],
            'total_interactions': metrics['TOTAL_INTERACTIONS'],
            'avg_scroll_depth': metrics['AVG_SCROLL_DEPTH'],
            'total_vaccines': metrics['TOTAL_VACCINES'],
            'total_screenings': metrics['TOTAL_SCREENINGS'],
            'avg_show_rate': metrics['AVG_SHOW_RATE']
        }
    except:
        return None

# ============================================================================
# Main Application UI
# ============================================================================

# Header
col1, col2 = st.columns([3, 1])
with col1:
    st.markdown('<p class="main-title">🏥 Patient Point Impact Engine</p>', unsafe_allow_html=True)
    st.markdown('<p class="subtitle">Proving Digital Engagement Drives Clinical Value</p>', unsafe_allow_html=True)

with col2:
    st.image("https://via.placeholder.com/150x80/1f77b4/ffffff?text=Patient+Point", use_column_width=True)

# ============================================================================
# Sidebar - Summary Metrics & Sample Questions
# ============================================================================

with st.sidebar:
    st.header("📊 Key Metrics")
    
    metrics = get_summary_metrics()
    if metrics:
        st.metric("Active Providers", f"{metrics['total_providers']:,}")
        st.metric("Total Interactions", f"{metrics['total_interactions']:,}")
        st.metric("Avg Scroll Depth", f"{metrics['avg_scroll_depth']}%")
        st.metric("Total Vaccines", f"{metrics['total_vaccines']:,}")
        st.metric("Total Screenings", f"{metrics['total_screenings']:,}")
        st.metric("Avg Show Rate", f"{metrics['avg_show_rate']}%")
    
    st.markdown("---")
    
    st.header("💡 Sample Questions")
    
    sample_questions = [
        "Did an increase in scrolling lead to more vaccines administered?",
        "Show the correlation between dwell time and preventative screenings",
        "Which content topics drove the highest appointment show rates?",
        "What is the relationship between engagement and provider churn?",
        "Compare clinical outcomes across different medical specialties",
        "Show me monthly trends in engagement and clinical outcomes",
        "What outcomes do providers with high engagement achieve?",
        "How do different regions compare in terms of engagement?",
        "What content do we have about flu vaccines?",
        "Find content about diabetes management"
    ]
    
    for question in sample_questions:
        if st.button(question, key=question, use_container_width=True):
            st.session_state.selected_question = question

# ============================================================================
# Main Chat Interface
# ============================================================================

st.header("💬 Ask Questions About Your Data")

# Display chat history
for message in st.session_state.messages:
    if message['role'] == 'user':
        with st.chat_message("user"):
            st.write(message['content'])
    else:
        with st.chat_message("assistant"):
            st.write(message['content'])
            
            # Show visualization if available
            if 'visualization' in message and message['visualization']:
                st.plotly_chart(message['visualization'], use_container_width=True)
            
            # Show SQL in expander
            if 'sql' in message and message['sql']:
                with st.expander("📝 View Generated SQL"):
                    st.code(message['sql'], language='sql')
            
            # Show data table if available
            if 'data' in message and message['data'] and len(message['data']) > 0:
                with st.expander("📊 View Data Table"):
                    st.dataframe(pd.DataFrame(message['data']), use_container_width=True)

# Chat input
user_query = st.chat_input("Ask a question about engagement impact...")

# Handle selected sample question
if 'selected_question' in st.session_state:
    user_query = st.session_state.selected_question
    del st.session_state.selected_question

# Process user input
if user_query:
    # Add user message to chat
    st.session_state.messages.append({
        'role': 'user',
        'content': user_query
    })
    
    # Display user message
    with st.chat_message("user"):
        st.write(user_query)
    
    # Query the agent
    with st.chat_message("assistant"):
        with st.spinner("Analyzing your question..."):
            result = query_agent(user_query)
        
        if result['status'] == 'success':
            response = result['response']
            answer = response.get('answer', 'Analysis completed.')
            sql = response.get('sql', '')
            data = response.get('data', [])
            
            # Display answer
            st.write(answer)
            
            # Create visualization if appropriate
            viz = None
            if needs_visualization(user_query, response) and data:
                try:
                    viz = create_visualization(user_query, data)
                    if viz:
                        st.plotly_chart(viz, use_container_width=True)
                except Exception as e:
                    st.warning(f"Could not create visualization: {str(e)}")
            
            # Show SQL
            if sql:
                with st.expander("📝 View Generated SQL"):
                    st.code(sql, language='sql')
            
            # Show data table
            if data and len(data) > 0:
                with st.expander("📊 View Data Table"):
                    st.dataframe(pd.DataFrame(data), use_container_width=True)
            
            # Add assistant message to chat
            st.session_state.messages.append({
                'role': 'assistant',
                'content': answer,
                'sql': sql,
                'data': data,
                'visualization': viz
            })
            
        else:
            error_msg = f"Error: {result.get('error', 'Unknown error occurred')}"
            st.error(error_msg)
            st.session_state.messages.append({
                'role': 'assistant',
                'content': error_msg
            })

# ============================================================================
# Footer
# ============================================================================

st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #666; padding: 1rem;'>
    <p><strong>Patient Point IXR Analytics Platform</strong></p>
    <p>Powered by Snowflake Cortex AI | Built with Streamlit</p>
    <p style='font-size: 0.8rem;'>© 2024 Patient Point. Confidential & Proprietary.</p>
</div>
""", unsafe_allow_html=True)

# Clear chat button in sidebar
with st.sidebar:
    st.markdown("---")
    if st.button("🗑️ Clear Chat History", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

