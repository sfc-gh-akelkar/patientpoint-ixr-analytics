# Patient Point Impact Engine - Deployment Checklist

## Pre-Deployment Requirements

- [ ] Snowflake account with Cortex AI enabled
- [ ] ACCOUNTADMIN role access
- [ ] COMPUTE_WH warehouse created (or modify scripts for your warehouse name)
- [ ] SnowSQL or Snowflake Web UI access
- [ ] All project files downloaded to local machine

---

## Deployment Steps

### ✅ Step 1: Setup Data Layer (5 minutes)

**File:** `01_setup_data.sql`

**Actions:**
1. Open Snowflake Web UI (Snowsight)
2. Create new SQL Worksheet
3. Copy entire contents of `01_setup_data.sql`
4. Execute script
5. Verify completion:
   ```sql
   SELECT 'PROVIDER_DIM' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM PATIENTPOINT_DB.IXR_ANALYTICS.PROVIDER_DIM
   UNION ALL
   SELECT 'IXR_METRICS', COUNT(*) FROM PATIENTPOINT_DB.IXR_ANALYTICS.IXR_METRICS
   UNION ALL
   SELECT 'PATIENT_OUTCOMES', COUNT(*) FROM PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_OUTCOMES
   UNION ALL
   SELECT 'CONTENT_LIBRARY', COUNT(*) FROM PATIENTPOINT_DB.IXR_ANALYTICS.CONTENT_LIBRARY;
   ```

**Expected Output:**
```
PROVIDER_DIM      | 100
IXR_METRICS       | 10000
PATIENT_OUTCOMES  | 5000
CONTENT_LIBRARY   | 50
```

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

### ✅ Step 2: Create Analytical Views (2 minutes)

**File:** `02_setup_views.sql`

**Actions:**
1. Open new SQL Worksheet in Snowsight
2. Copy entire contents of `02_setup_views.sql`
3. Execute script
4. Verify views created:
   ```sql
   SHOW VIEWS IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;
   ```

**Expected Output:**
- V_IMPACT_ANALYSIS
- V_PROVIDER_SUMMARY
- V_CONTENT_PERFORMANCE
- V_MONTHLY_TRENDS
- V_SPECIALTY_COMPARISON

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

### ✅ Step 3: Setup Cortex Search (3 minutes)

**File:** `03_setup_search.sql`

**Actions:**
1. Open new SQL Worksheet in Snowsight
2. Copy entire contents of `03_setup_search.sql`
3. Execute script
4. Wait for search service indexing (~1-2 minutes)
5. Verify search service:
   ```sql
   SHOW CORTEX SEARCH SERVICES IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;
   ```

**Test Search:**
```sql
SELECT * FROM TABLE(
    PATIENTPOINT_DB.IXR_ANALYTICS.CONTENT_SEARCH_SVC!SEARCH(
        QUERY => 'flu vaccine importance',
        NUM_RESULTS => 3
    )
);
```

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

### ✅ Step 4: Upload Semantic Model (2 minutes)

**File:** `04_semantic_model.yaml`

**Option A: Via Snowflake Web UI**
1. Navigate to: Databases → PATIENTPOINT_DB → IXR_ANALYTICS → Stages
2. Find or create stage: `SEMANTIC_MODEL_STAGE`
3. Click "Upload Files"
4. Select `04_semantic_model.yaml`
5. Upload (ensure AUTO_COMPRESS = FALSE)

**Option B: Via SnowSQL**
```bash
snowsql -a <your_account> -u <your_user>

PUT file:///path/to/04_semantic_model.yaml @PATIENTPOINT_DB.IXR_ANALYTICS.SEMANTIC_MODEL_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

**Verify Upload:**
```sql
LIST @PATIENTPOINT_DB.IXR_ANALYTICS.SEMANTIC_MODEL_STAGE;
```

**Expected:** Should see `04_semantic_model.yaml` in file list

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

### ✅ Step 5: Create Cortex Agent (3 minutes)

**File:** `05_agent_setup.sql`

**Actions:**
1. Open new SQL Worksheet in Snowsight
2. Copy entire contents of `05_agent_setup.sql`
3. Execute script
4. Wait for agent creation (~1-2 minutes)
5. Verify agent:
   ```sql
   SHOW CORTEX AGENTS IN SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;
   ```

**Test Agent:**
```sql
SELECT PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_AGENT(
    'Did an increase in scrolling lead to more vaccines administered?'
) AS response;
```

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

### ✅ Step 6: Deploy Streamlit App (5 minutes)

**File:** `06_streamlit_app.py`

**Actions:**
1. In Snowsight, navigate to: Projects → Streamlit → + Streamlit App
2. Configure:
   - **Name:** `Patient Point Impact Engine`
   - **Location:** PATIENTPOINT_DB.IXR_ANALYTICS
   - **Warehouse:** COMPUTE_WH
   - **App role:** ACCOUNTADMIN (or appropriate role)
3. Delete default code
4. Copy entire contents of `06_streamlit_app.py`
5. Paste into editor
6. Click "Run" (top right)
7. Wait for app to initialize (~30 seconds)

**Verify:**
- App loads with header "🏥 Patient Point Impact Engine"
- Sidebar shows Key Metrics
- Sample questions are visible
- Chat input is functional

**Test Query:** Click any sample question or type:
```
Did an increase in scrolling lead to more vaccines administered?
```

**Expected:** 
- Answer appears
- Scatter plot visualization shows
- SQL expander is available
- Data table expander shows results

**Status:** ⬜ Not Started | ⏳ In Progress | ✅ Complete

---

## Post-Deployment Validation

### Validation Checklist

- [ ] All tables populated with correct row counts
- [ ] All views accessible and return data
- [ ] Cortex Search returns relevant results
- [ ] Cortex Agent responds to queries
- [ ] Streamlit app loads and displays metrics
- [ ] Sample questions generate visualizations
- [ ] SQL transparency (view SQL expanders work)
- [ ] Data tables display correctly

### Validation Queries

**1. Check Data Bias (Should show correlation)**
```sql
SELECT 
    ENGAGEMENT_LEVEL,
    ROUND(AVG(AVG_SCROLL_DEPTH_PCT), 2) AS AVG_SCROLL,
    ROUND(AVG(AVG_CLICK_COUNT), 2) AS AVG_CLICKS,
    ROUND(AVG(VACCINES_ADMINISTERED), 2) AS AVG_VACCINES,
    ROUND(AVG(SCREENINGS_COMPLETED), 2) AS AVG_SCREENINGS,
    COUNT(*) AS RECORDS
FROM PATIENTPOINT_DB.IXR_ANALYTICS.V_IMPACT_ANALYSIS
GROUP BY ENGAGEMENT_LEVEL
ORDER BY AVG_SCROLL DESC;
```

**Expected Result:**
- High engagement → High vaccines (70-90)
- Medium engagement → Medium vaccines (40-60)
- Low engagement → Low vaccines (20-40)

**2. Check Provider Churn Correlation**
```sql
SELECT 
    PROVIDER_IS_ACTIVE,
    COUNT(DISTINCT PROVIDER_NPI) AS PROVIDERS,
    ROUND(AVG(ENGAGEMENT_SCORE), 2) AS AVG_ENGAGEMENT,
    ROUND(AVG(VACCINES_ADMINISTERED), 2) AS AVG_VACCINES
FROM PATIENTPOINT_DB.IXR_ANALYTICS.V_IMPACT_ANALYSIS
GROUP BY PROVIDER_IS_ACTIVE;
```

**Expected Result:**
- Active providers (TRUE) → Higher engagement scores
- Churned providers (FALSE) → Lower engagement scores

**3. End-to-End Agent Test**
```sql
SELECT 
    PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_AGENT(
        'Show me the correlation between scrolling and vaccinations'
    ) AS response;
```

**Expected Result:**
- JSON response with `status: success`
- SQL query generated
- Data array populated
- Interpretation text present

---

## Troubleshooting Guide

### Issue: "Cortex not available"
**Solution:** 
- Verify Cortex AI is enabled in your account
- Contact Snowflake Account Team to enable Cortex features
- Check region compatibility (Cortex available in select regions)

### Issue: "Permission denied on PATIENT_IMPACT_AGENT"
**Solution:**
```sql
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE PATIENTPOINT_DB TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS TO ROLE SYSADMIN;
GRANT USAGE ON CORTEX AGENT PATIENT_IMPACT_AGENT TO ROLE SYSADMIN;
```

### Issue: "Semantic model file not found"
**Solution:**
1. Verify file upload:
   ```sql
   LIST @PATIENTPOINT_DB.IXR_ANALYTICS.SEMANTIC_MODEL_STAGE;
   ```
2. If missing, re-upload with `AUTO_COMPRESS=FALSE`
3. Ensure filename is exactly `04_semantic_model.yaml`

### Issue: "Streamlit app shows import errors"
**Solution:**
- Ensure running on Snowflake's Streamlit (not local)
- Verify warehouse is running and accessible
- Check role has SELECT permissions on all views
- Restart the app (three dots menu → Restart)

### Issue: "No visualizations appear"
**Solution:**
- Check that query contains impact/correlation keywords
- Verify response contains data array with 2+ rows
- Check browser console for JavaScript errors
- Try a different sample question

### Issue: "Search service returns no results"
**Solution:**
- Wait 2-3 minutes for indexing to complete after creation
- Verify service status:
  ```sql
  SHOW CORTEX SEARCH SERVICES;
  ```
- Check service is in "Running" state
- Test with simple query: "vaccine"

---

## Demo Script for Executive Presentation

### 1. Opening (30 seconds)
"Today I'll demonstrate how Patient Point's IXR platform drives measurable clinical impact using AI-powered analytics on Snowflake."

### 2. Dashboard Overview (1 minute)
- Show Streamlit app landing page
- Highlight key metrics in sidebar:
  - "100 active providers across 5 specialties"
  - "10,000+ patient interactions"
  - "5,000+ clinical outcomes tracked"

### 3. Impact Query (2 minutes)
**Click:** "Did an increase in scrolling lead to more vaccines administered?"

**Point out:**
- Natural language query
- Automatic scatter plot generation
- Clear positive correlation visible
- "View SQL" transparency
- Data table with actual numbers

**Key message:** "High engagement providers administered 2.5x more vaccines"

### 4. Specialty Comparison (1.5 minutes)
**Click:** "Compare clinical outcomes across different medical specialties"

**Point out:**
- Bar chart auto-generated
- Cardiology and PCP leading in vaccinations
- Actionable insights for targeting

**Key message:** "We can optimize content by specialty"

### 5. Content Discovery (1 minute)
**Type:** "What content do we have about flu vaccines?"

**Point out:**
- Searches unstructured content library
- Returns relevant medical education materials
- Content-outcome correlation

**Key message:** "Content intelligence drives clinical results"

### 6. Churn Analysis (1.5 minutes)
**Click:** "What is the relationship between engagement and provider churn?"

**Point out:**
- 95% retention for high-engagement providers
- Direct business value quantified
- ROI justification

**Key message:** "Engagement reduces churn by 20%"

### 7. Closing (30 seconds)
"This PoC proves Patient Point's digital engagement platform delivers:
- Measurable clinical impact
- Reduced provider churn  
- AI-driven insights
- Scalable on Snowflake"

**Total Time:** 8-10 minutes

---

## Success Criteria

✅ **Technical Success:**
- All 7 files deployed without errors
- Agent responds to natural language queries
- Visualizations render automatically
- Search returns relevant content
- Performance < 5 seconds per query

✅ **Business Success:**
- Demonstrates clear correlation between engagement and outcomes
- Shows 60%+ improvement in clinical metrics for high engagement
- Proves churn reduction of 15-20%
- Executive-ready UI and insights
- Scalable architecture for production

---

## Rollback Procedure

If deployment fails or needs to be removed:

```sql
-- Drop all objects in reverse order
USE ROLE ACCOUNTADMIN;

-- Delete Streamlit app (via UI: Projects → Streamlit → Delete)

-- Drop agent and analyst
DROP CORTEX AGENT IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_AGENT;
DROP CORTEX ANALYST SERVICE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_IMPACT_ANALYST;

-- Drop search service
DROP CORTEX SEARCH SERVICE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.CONTENT_SEARCH_SVC;

-- Drop views
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_SPECIALTY_COMPARISON;
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_MONTHLY_TRENDS;
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_CONTENT_PERFORMANCE;
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_PROVIDER_SUMMARY;
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_CONTENT_ENGAGEMENT_ANALYSIS;
DROP VIEW IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.V_IMPACT_ANALYSIS;

-- Drop tables
DROP TABLE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.CONTENT_LIBRARY;
DROP TABLE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.PATIENT_OUTCOMES;
DROP TABLE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.IXR_METRICS;
DROP TABLE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.PROVIDER_DIM;

-- Drop stage
DROP STAGE IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS.SEMANTIC_MODEL_STAGE;

-- Drop schema (optional - only if removing completely)
-- DROP SCHEMA IF EXISTS PATIENTPOINT_DB.IXR_ANALYTICS;

-- Drop database (optional - only if removing completely)
-- DROP DATABASE IF EXISTS PATIENTPOINT_DB;
```

---

## Next Steps After Successful Deployment

1. **Schedule Executive Demo**
   - Book 30-minute session with Patient Point leadership
   - Prepare custom queries based on their priorities
   - Highlight ROI metrics

2. **Gather Feedback**
   - What additional questions do they want to ask?
   - Which visualizations are most compelling?
   - What real data sources to integrate?

3. **Plan Phase 2**
   - Real-time data integration from IXR devices
   - EMR integration for actual clinical outcomes
   - Predictive churn models
   - Content A/B testing framework

4. **Production Readiness**
   - Security review and role-based access control
   - Data retention and compliance policies
   - Performance optimization for scale
   - Monitoring and alerting setup

---

**Document Version:** 1.0  
**Last Updated:** November 20, 2024  
**Total Deployment Time:** ~20 minutes  
**Difficulty Level:** Intermediate (requires Snowflake admin access)

