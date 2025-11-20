-- ============================================================================
-- Patient Point IXR Analytics - Data Setup
-- ============================================================================
-- Description: Creates tables and inserts mathematically biased dummy data
--              to demonstrate correlation between digital engagement and 
--              clinical outcomes.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Create Database and Schema
CREATE DATABASE IF NOT EXISTS PATIENTPOINT_DB;
CREATE SCHEMA IF NOT EXISTS PATIENTPOINT_DB.IXR_ANALYTICS;
USE SCHEMA PATIENTPOINT_DB.IXR_ANALYTICS;

-- ============================================================================
-- 1. PROVIDER_DIM - Provider Master Data (100 providers)
-- ============================================================================

CREATE OR REPLACE TABLE PROVIDER_DIM (
    NPI VARCHAR(10) PRIMARY KEY,
    SPECIALTY VARCHAR(50),
    REGION VARCHAR(50),
    IS_ACTIVE BOOLEAN,
    PROVIDER_NAME VARCHAR(100)
);

-- Insert 100 Providers with diverse specialties and regions
INSERT INTO PROVIDER_DIM
WITH specialty_options AS (
    SELECT column1 AS specialty FROM VALUES 
    ('Cardiology'),
    ('PCP'),
    ('Dermatology'),
    ('Orthopedics'),
    ('Pediatrics')
),
region_options AS (
    SELECT column1 AS region FROM VALUES
    ('Northeast'),
    ('Southeast'),
    ('Midwest'),
    ('West'),
    ('Southwest')
),
provider_seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS provider_id
    FROM TABLE(GENERATOR(ROWCOUNT => 100))
),
base_providers AS (
    SELECT 
        p.provider_id,
        LPAD(p.provider_id::VARCHAR, 10, '0') AS NPI,
        s.specialty,
        r.region,
        CONCAT('Dr. ', 
               CASE (p.provider_id % 10)
                   WHEN 0 THEN 'Smith'
                   WHEN 1 THEN 'Johnson'
                   WHEN 2 THEN 'Williams'
                   WHEN 3 THEN 'Brown'
                   WHEN 4 THEN 'Jones'
                   WHEN 5 THEN 'Garcia'
                   WHEN 6 THEN 'Miller'
                   WHEN 7 THEN 'Davis'
                   WHEN 8 THEN 'Rodriguez'
                   WHEN 9 THEN 'Martinez'
               END,
               ' ',
               CHR(65 + (p.provider_id % 26))
        ) AS provider_name,
        -- Create temp engagement score for churn logic (will compute later)
        UNIFORM(1, 100, RANDOM()) AS temp_engagement_score
    FROM provider_seq p
    CROSS JOIN specialty_options s
    CROSS JOIN region_options r
    WHERE p.provider_id <= 100
    QUALIFY ROW_NUMBER() OVER (PARTITION BY p.provider_id ORDER BY RANDOM()) = 1
)
SELECT 
    NPI,
    specialty,
    region,
    -- Bias Logic: 95% retention for high engagement (score > 50), ~75% for low
    CASE 
        WHEN temp_engagement_score > 50 THEN (UNIFORM(1, 100, RANDOM()) <= 95)
        ELSE (UNIFORM(1, 100, RANDOM()) <= 75)
    END AS IS_ACTIVE,
    provider_name
FROM base_providers;

-- ============================================================================
-- 2. IXR_METRICS - Digital Engagement Metrics (10,000 rows)
-- ============================================================================

CREATE OR REPLACE TABLE IXR_METRICS (
    DEVICE_ID VARCHAR(20),
    PROVIDER_NPI VARCHAR(10),
    ENGAGEMENT_DATE DATE,
    DWELL_TIME_SEC INT,
    CLICK_COUNT INT,
    SCROLL_DEPTH_PCT FLOAT,
    CONTENT_CATEGORY VARCHAR(50)
);

-- Insert 10,000 engagement records across 2024
INSERT INTO IXR_METRICS
WITH providers AS (
    SELECT NPI FROM PROVIDER_DIM
),
date_range AS (
    SELECT DATEADD(DAY, SEQ4(), '2024-01-01'::DATE) AS engagement_date
    FROM TABLE(GENERATOR(ROWCOUNT => 365))
    WHERE engagement_date <= '2024-12-31'
),
content_categories AS (
    SELECT column1 AS category FROM VALUES
    ('Vaccinations'),
    ('Cancer Screening'),
    ('Diabetes Management'),
    ('Heart Health'),
    ('Wellness Tips'),
    ('Appointment Reminders'),
    ('Nutrition Education')
),
engagement_records AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS record_id,
        p.NPI AS PROVIDER_NPI,
        d.engagement_date,
        c.category AS CONTENT_CATEGORY,
        -- Create engagement profiles: 40% high, 30% medium, 30% low
        CASE 
            WHEN UNIFORM(1, 100, RANDOM()) <= 40 THEN 'HIGH'
            WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS engagement_profile
    FROM providers p
    CROSS JOIN date_range d
    CROSS JOIN content_categories c
    WHERE UNIFORM(1, 100, RANDOM()) <= 35  -- ~35% sampling rate for realistic data volume
    QUALIFY ROW_NUMBER() OVER (ORDER BY RANDOM()) <= 10000
)
SELECT 
    CONCAT('DEVICE_', LPAD((record_id % 50)::VARCHAR, 5, '0')) AS DEVICE_ID,
    PROVIDER_NPI,
    engagement_date AS ENGAGEMENT_DATE,
    -- Dwell Time (0-300 seconds)
    CASE engagement_profile
        WHEN 'HIGH' THEN UNIFORM(180, 300, RANDOM())
        WHEN 'MEDIUM' THEN UNIFORM(90, 179, RANDOM())
        ELSE UNIFORM(0, 89, RANDOM())
    END AS DWELL_TIME_SEC,
    -- Click Count (0-50)
    CASE engagement_profile
        WHEN 'HIGH' THEN UNIFORM(11, 50, RANDOM())
        WHEN 'MEDIUM' THEN UNIFORM(5, 10, RANDOM())
        ELSE UNIFORM(0, 4, RANDOM())
    END AS CLICK_COUNT,
    -- Scroll Depth (0-100%)
    CASE engagement_profile
        WHEN 'HIGH' THEN UNIFORM(71, 100, RANDOM())
        WHEN 'MEDIUM' THEN UNIFORM(40, 70, RANDOM())
        ELSE UNIFORM(0, 39, RANDOM())
    END AS SCROLL_DEPTH_PCT,
    CONTENT_CATEGORY
FROM engagement_records;

-- ============================================================================
-- 3. PATIENT_OUTCOMES - Clinical Outcomes by Provider/Month (5,000 rows)
-- ============================================================================

CREATE OR REPLACE TABLE PATIENT_OUTCOMES (
    PROVIDER_NPI VARCHAR(10),
    OUTCOME_MONTH DATE,
    VACCINES_ADMINISTERED INT,
    SCREENINGS_COMPLETED INT,
    APPOINTMENT_SHOW_RATE FLOAT
);

-- Insert outcomes with strong correlation to engagement
INSERT INTO PATIENT_OUTCOMES
WITH monthly_engagement AS (
    SELECT 
        PROVIDER_NPI,
        DATE_TRUNC('MONTH', ENGAGEMENT_DATE) AS outcome_month,
        AVG(SCROLL_DEPTH_PCT) AS avg_scroll_depth,
        AVG(CLICK_COUNT) AS avg_click_count,
        AVG(DWELL_TIME_SEC) AS avg_dwell_time,
        COUNT(*) AS engagement_events
    FROM IXR_METRICS
    GROUP BY PROVIDER_NPI, outcome_month
),
providers_with_no_data AS (
    SELECT 
        p.NPI AS PROVIDER_NPI,
        d.month_date AS outcome_month,
        0 AS avg_scroll_depth,
        0 AS avg_click_count,
        0 AS avg_dwell_time,
        0 AS engagement_events
    FROM PROVIDER_DIM p
    CROSS JOIN (
        SELECT DATEADD(MONTH, SEQ4(), '2024-01-01'::DATE) AS month_date
        FROM TABLE(GENERATOR(ROWCOUNT => 12))
    ) d
    WHERE NOT EXISTS (
        SELECT 1 FROM IXR_METRICS m 
        WHERE m.PROVIDER_NPI = p.NPI 
        AND DATE_TRUNC('MONTH', m.ENGAGEMENT_DATE) = d.month_date
    )
),
all_provider_months AS (
    SELECT * FROM monthly_engagement
    UNION ALL
    SELECT * FROM providers_with_no_data
),
outcomes_with_bias AS (
    SELECT 
        PROVIDER_NPI,
        outcome_month,
        avg_scroll_depth,
        avg_click_count,
        avg_dwell_time,
        -- Bias Logic: Strong correlation between high engagement and outcomes
        -- HIGH ENGAGEMENT: Scroll > 70 AND Clicks > 10 -> High vaccines (50-100)
        -- LOW ENGAGEMENT: Low metrics -> 30-40% lower vaccines (20-50)
        CASE 
            WHEN avg_scroll_depth > 70 AND avg_click_count > 10 THEN
                ROUND(50 + (avg_scroll_depth * 0.5) + (avg_click_count * 1.2) + UNIFORM(-5, 10, RANDOM()))
            WHEN avg_scroll_depth > 40 AND avg_click_count > 5 THEN
                ROUND(35 + (avg_scroll_depth * 0.3) + (avg_click_count * 0.8) + UNIFORM(-5, 5, RANDOM()))
            ELSE
                ROUND(20 + (avg_scroll_depth * 0.15) + (avg_click_count * 0.4) + UNIFORM(-3, 5, RANDOM()))
        END AS vaccines_administered,
        CASE 
            WHEN avg_scroll_depth > 70 AND avg_click_count > 10 THEN
                ROUND(30 + (avg_scroll_depth * 0.3) + (avg_dwell_time * 0.05) + UNIFORM(-3, 8, RANDOM()))
            WHEN avg_scroll_depth > 40 AND avg_click_count > 5 THEN
                ROUND(20 + (avg_scroll_depth * 0.2) + (avg_dwell_time * 0.03) + UNIFORM(-3, 5, RANDOM()))
            ELSE
                ROUND(10 + (avg_scroll_depth * 0.1) + (avg_dwell_time * 0.02) + UNIFORM(-2, 3, RANDOM()))
        END AS screenings_completed,
        CASE 
            WHEN avg_scroll_depth > 70 AND avg_click_count > 10 THEN
                LEAST(0.95, 0.75 + (avg_scroll_depth * 0.002) + (avg_click_count * 0.005) + (UNIFORM(-2, 5, RANDOM()) * 0.01))
            WHEN avg_scroll_depth > 40 AND avg_click_count > 5 THEN
                LEAST(0.85, 0.65 + (avg_scroll_depth * 0.0015) + (avg_click_count * 0.003) + (UNIFORM(-2, 3, RANDOM()) * 0.01))
            ELSE
                LEAST(0.75, 0.50 + (avg_scroll_depth * 0.001) + (avg_click_count * 0.002) + (UNIFORM(-2, 2, RANDOM()) * 0.01))
        END AS appointment_show_rate
    FROM all_provider_months
)
SELECT 
    PROVIDER_NPI,
    outcome_month AS OUTCOME_MONTH,
    GREATEST(0, vaccines_administered)::INT AS VACCINES_ADMINISTERED,
    GREATEST(0, screenings_completed)::INT AS SCREENINGS_COMPLETED,
    ROUND(LEAST(1.0, GREATEST(0.0, appointment_show_rate)), 3) AS APPOINTMENT_SHOW_RATE
FROM outcomes_with_bias
WHERE outcome_month <= '2024-12-01';

-- ============================================================================
-- 4. CONTENT_LIBRARY - Unstructured Video/Article Content (50 rows)
-- ============================================================================

CREATE OR REPLACE TABLE CONTENT_LIBRARY (
    CONTENT_ID VARCHAR(20) PRIMARY KEY,
    TITLE VARCHAR(200),
    TRANSCRIPT_TEXT TEXT,
    CONTENT_TYPE VARCHAR(50),
    PUBLISH_DATE DATE
);

-- Insert 50 realistic medical content pieces
INSERT INTO CONTENT_LIBRARY
WITH content_data AS (
    SELECT column1 AS title, column2 AS content_type, column3 AS transcript FROM VALUES
    ('Importance of Flu Vaccines for Seniors', 'Video', 'Influenza vaccination is crucial for adults over 65. The flu vaccine reduces hospitalization risk by 40% and can prevent serious complications like pneumonia. Annual vaccination is recommended by the CDC every fall season.'),
    ('Colon Cancer Screening Guide', 'Article', 'Colon cancer screening saves lives through early detection. Starting at age 45, adults should undergo colonoscopy every 10 years or FIT testing annually. Risk factors include family history, inflammatory bowel disease, and lifestyle factors.'),
    ('Managing Type 2 Diabetes Effectively', 'Video', 'Type 2 diabetes management involves blood glucose monitoring, healthy diet, regular exercise, and medication adherence. Target HbA1c levels should be below 7% for most adults. Regular check-ups with your healthcare provider are essential.'),
    ('Heart Health: Know Your Numbers', 'Interactive', 'Understanding your heart health metrics is vital. Blood pressure should be below 120/80, LDL cholesterol under 100, and HDL above 60. Regular cardiovascular screening helps prevent heart disease and stroke.'),
    ('Breast Cancer Screening Recommendations', 'Article', 'Mammography screening guidelines recommend annual mammograms starting at age 40 for average-risk women. Women with family history should discuss earlier screening. Breast self-exams and clinical exams complement mammography.'),
    ('Childhood Vaccination Schedule Explained', 'Video', 'Protecting children through vaccination prevents serious diseases like measles, polio, and whooping cough. The CDC vaccination schedule covers birth through 18 years with vaccines proven safe and effective through rigorous testing.'),
    ('Understanding Blood Pressure Management', 'Article', 'Hypertension affects 1 in 3 American adults. Lifestyle modifications including reduced sodium intake, regular exercise, stress management, and medication when needed can effectively control blood pressure and reduce cardiovascular risk.'),
    ('Skin Cancer Prevention and Detection', 'Video', 'Melanoma and other skin cancers are highly treatable when caught early. Monthly self-exams using the ABCDE method, annual dermatology visits, and sun protection through SPF 30+ sunscreen and protective clothing are recommended.'),
    ('Asthma Action Plan for Better Control', 'Interactive', 'Asthma management requires understanding triggers, proper inhaler technique, and peak flow monitoring. Work with your provider to create a personalized action plan that includes daily controller medications and rescue inhaler use.'),
    ('Prostate Cancer Screening Decisions', 'Article', 'Men should discuss PSA testing with their doctor starting at age 50, or age 45 for high-risk groups. Shared decision-making weighs screening benefits against potential harms including overdiagnosis and treatment side effects.'),
    ('Nutrition for Healthy Aging', 'Video', 'Senior nutrition focuses on adequate protein intake, vitamin D and calcium for bone health, fiber for digestive health, and hydration. Mediterranean diet patterns show benefits for cognitive function and cardiovascular health.'),
    ('COVID-19 Vaccine Boosters: What You Need to Know', 'Article', 'Updated COVID-19 boosters provide enhanced protection against current variants. Annual vaccination similar to flu shots is recommended for most adults. Immunocompromised individuals may need additional doses.'),
    ('Exercise Guidelines for Chronic Disease Prevention', 'Video', 'Adults need 150 minutes of moderate aerobic activity weekly plus strength training twice per week. Regular physical activity reduces risk of heart disease, diabetes, certain cancers, and improves mental health.'),
    ('Cervical Cancer Screening Updates', 'Article', 'Cervical cancer screening includes Pap tests and HPV testing. Women ages 21-29 should have Pap tests every 3 years. Ages 30-65 can choose Pap plus HPV testing every 5 years or Pap alone every 3 years.'),
    ('Medication Adherence: Taking Pills as Prescribed', 'Interactive', 'Half of all medications are not taken as prescribed. Use pill organizers, smartphone reminders, and synchronize refills to improve adherence. Discuss concerns about side effects or costs with your healthcare team.'),
    ('Lung Cancer Screening for Smokers', 'Video', 'Annual low-dose CT screening is recommended for adults 50-80 with 20 pack-year smoking history. Early detection through screening increases survival rates significantly compared to symptom-based diagnosis.'),
    ('Healthy Sleep Habits for Adults', 'Article', 'Adults need 7-9 hours of quality sleep nightly. Good sleep hygiene includes consistent bedtimes, cool dark bedroom, limiting screen time before bed, and avoiding caffeine late in the day. Poor sleep increases chronic disease risk.'),
    ('Osteoporosis Prevention and Treatment', 'Video', 'Bone health requires adequate calcium and vitamin D intake, weight-bearing exercise, and fall prevention. DEXA scans assess bone density starting at age 65 for women. Medication may be needed for osteoporosis.'),
    ('Mental Health: Recognizing Depression and Anxiety', 'Article', 'Mental health is as important as physical health. Depression affects 1 in 15 adults annually. Symptoms lasting more than 2 weeks require professional evaluation. Treatment including therapy and medication is highly effective.'),
    ('Kidney Disease: Early Warning Signs', 'Video', 'Chronic kidney disease often has no early symptoms. Risk factors include diabetes, high blood pressure, and family history. Regular screening through blood and urine tests catches disease early when treatment is most effective.'),
    ('Hepatitis B and C Screening', 'Article', 'One-time hepatitis C screening is recommended for all adults. Hepatitis B screening is important for high-risk groups. Both infections can cause serious liver disease but are treatable when detected early.'),
    ('Arthritis Pain Management Strategies', 'Interactive', 'Osteoarthritis and rheumatoid arthritis require comprehensive management including medications, physical therapy, exercise, weight management, and sometimes surgery. Joint protection techniques and assistive devices help maintain function.'),
    ('Vision Care: Eye Exam Importance', 'Video', 'Regular comprehensive eye exams detect glaucoma, macular degeneration, and diabetic retinopathy before vision loss occurs. Adults should have exams every 1-2 years, more frequently if diabetic or over age 60.'),
    ('Stroke Prevention and Recognition', 'Article', 'Learn FAST: Face drooping, Arm weakness, Speech difficulty, Time to call 911. Stroke prevention includes blood pressure control, cholesterol management, not smoking, exercise, and sometimes anticoagulation therapy.'),
    ('HPV Vaccine: Cancer Prevention for Teens', 'Video', 'HPV vaccination prevents cancers of the cervix, vagina, vulva, penis, anus, and throat. Recommended at ages 11-12, the vaccine is most effective before HPV exposure. Catch-up vaccination available through age 26.'),
    ('COPD Management and Breathing Techniques', 'Article', 'Chronic obstructive pulmonary disease requires smoking cessation, inhaled medications, pulmonary rehabilitation, and oxygen therapy when needed. Breathing exercises and energy conservation improve quality of life.'),
    ('Prenatal Care: Healthy Pregnancy Tips', 'Video', 'Prenatal care starting in the first trimester ensures healthy pregnancy outcomes. Regular visits monitor mother and baby health. Prenatal vitamins, healthy diet, avoiding alcohol and tobacco are essential.'),
    ('Allergies: Triggers and Treatment Options', 'Interactive', 'Seasonal and perennial allergies affect millions. Treatment includes allergen avoidance, antihistamines, nasal corticosteroids, and immunotherapy for severe cases. Identify triggers through testing with an allergist.'),
    ('Hearing Loss: When to Get Tested', 'Article', 'Age-related hearing loss affects 1 in 3 adults over 65. Annual hearing screenings help detect loss early. Hearing aids and assistive devices significantly improve communication and quality of life.'),
    ('Shingles Vaccine: Protecting Against Pain', 'Video', 'Shingles vaccination is recommended for adults 50 and older. The vaccine prevents painful shingles rash and post-herpetic neuralgia. Two doses given 2-6 months apart provide over 90% protection.'),
    ('Thyroid Health: Understanding Your Thyroid Function', 'Article', 'Thyroid disorders affect metabolism, energy, weight, and mood. TSH testing screens for hypothyroidism and hyperthyroidism. Both conditions are treatable with medication and regular monitoring.'),
    ('Falls Prevention for Older Adults', 'Video', 'Falls are the leading cause of injury in adults over 65. Prevention includes strength and balance exercises, home safety modifications, vision and medication reviews, and vitamin D supplementation.'),
    ('Dental Health: Connection to Overall Health', 'Article', 'Oral health impacts overall health. Gum disease links to heart disease and diabetes. Brush twice daily, floss daily, and see your dentist every 6 months for cleanings and exams.'),
    ('Prediabetes: Reversing Course to Prevent Diabetes', 'Interactive', 'Prediabetes affects 96 million Americans. Lifestyle changes including 7% weight loss and 150 minutes weekly exercise can reduce diabetes risk by 58%. Regular screening catches prediabetes early.'),
    ('Immunotherapy for Cancer Treatment', 'Video', 'Cancer immunotherapy harnesses the immune system to fight cancer. Checkpoint inhibitors and CAR-T cell therapy show remarkable results for certain cancers. Discuss eligibility with your oncologist.'),
    ('Migraine Management: Beyond Pain Relief', 'Article', 'Migraine management includes trigger identification, preventive medications, acute treatments, and lifestyle modifications. Keep a headache diary and work with a neurologist for personalized treatment plans.'),
    ('Bone Marrow and Stem Cell Donation', 'Video', 'Becoming a bone marrow donor can save lives of blood cancer patients. Registration is simple with a cheek swab. Donation is safe and recovery is quick for most donors.'),
    ('Pneumonia Vaccine: Who Needs It and When', 'Article', 'Pneumococcal vaccines prevent serious pneumonia infections. Adults 65+ need PCV20 or PCV15 plus PPSV23. Younger adults with chronic conditions may also need vaccination.'),
    ('Atrial Fibrillation: Heart Rhythm Disorder Guide', 'Video', 'AFib increases stroke risk fivefold. Management includes rate or rhythm control medications, blood thinners, and sometimes ablation procedures. Regular monitoring and medication adherence are crucial.'),
    ('Irritable Bowel Syndrome Relief Strategies', 'Interactive', 'IBS affects quality of life through abdominal pain, bloating, and altered bowel habits. Management includes dietary modifications like the low-FODMAP diet, stress reduction, and medications for symptom control.'),
    ('Anemia: Causes and Treatment', 'Article', 'Anemia causes fatigue and weakness. Common causes include iron deficiency, vitamin B12 deficiency, and chronic disease. Blood tests identify the cause and guide treatment with supplements or addressing underlying conditions.'),
    ('Testicular Self-Exam for Early Detection', 'Video', 'Monthly testicular self-exams help detect testicular cancer early. Young men ages 15-35 are at highest risk. Any lumps, swelling, or pain should be evaluated promptly by a healthcare provider.'),
    ('Omega-3 Fatty Acids and Heart Health', 'Article', 'Omega-3s from fatty fish or supplements benefit heart health by reducing triglycerides and inflammation. The American Heart Association recommends eating fish twice weekly, especially salmon, mackerel, and sardines.'),
    ('Celiac Disease: Gluten-Free Living', 'Video', 'Celiac disease requires strict gluten avoidance to prevent intestinal damage. Read labels carefully, use dedicated cooking equipment, and work with a dietitian to ensure nutritional adequacy on a gluten-free diet.'),
    ('Urinary Tract Infection Prevention', 'Article', 'UTIs are common, especially in women. Prevention includes staying hydrated, urinating after intercourse, wiping front to back, and avoiding irritating feminine products. Recurrent UTIs may need preventive antibiotics.'),
    ('Vitamin D Deficiency: Silent Epidemic', 'Interactive', 'Vitamin D deficiency affects bone health, immune function, and mood. Screening through blood tests identifies deficiency. Supplementation with D3, sunlight exposure, and dietary sources like fatty fish help maintain levels.'),
    ('Pelvic Floor Health for Women', 'Video', 'Pelvic floor disorders including incontinence and prolapse affect many women, especially after childbirth. Kegel exercises, pelvic floor physical therapy, and lifestyle modifications improve symptoms and quality of life.'),
    ('Gout: Managing Painful Joint Inflammation', 'Article', 'Gout results from uric acid crystal deposition in joints. Management includes medications to lower uric acid, dietary modifications limiting purines, hydration, and avoiding alcohol. Untreated gout leads to joint damage.'),
    ('Travel Vaccines and Health Precautions', 'Video', 'International travel may require vaccines for hepatitis A and B, typhoid, yellow fever, and others depending on destination. Consult a travel medicine clinic 4-6 weeks before departure for personalized recommendations.'),
    ('Telehealth: Accessing Care from Home', 'Article', 'Telehealth expands access to healthcare through video visits. Suitable for many conditions including follow-ups, mental health, dermatology, and urgent care. Check with your insurance about coverage and providers.')
)
SELECT 
    CONCAT('CONTENT_', LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM())::VARCHAR, 4, '0')) AS CONTENT_ID,
    title AS TITLE,
    transcript AS TRANSCRIPT_TEXT,
    content_type AS CONTENT_TYPE,
    DATEADD(DAY, -UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) AS PUBLISH_DATE
FROM content_data;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Show table counts
SELECT 'PROVIDER_DIM' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM PROVIDER_DIM
UNION ALL
SELECT 'IXR_METRICS', COUNT(*) FROM IXR_METRICS
UNION ALL
SELECT 'PATIENT_OUTCOMES', COUNT(*) FROM PATIENT_OUTCOMES
UNION ALL
SELECT 'CONTENT_LIBRARY', COUNT(*) FROM CONTENT_LIBRARY;

-- Show engagement distribution
SELECT 
    CASE 
        WHEN SCROLL_DEPTH_PCT > 70 AND CLICK_COUNT > 10 THEN 'High Engagement'
        WHEN SCROLL_DEPTH_PCT > 40 AND CLICK_COUNT > 5 THEN 'Medium Engagement'
        ELSE 'Low Engagement'
    END AS engagement_level,
    COUNT(*) AS record_count,
    ROUND(AVG(SCROLL_DEPTH_PCT), 2) AS avg_scroll_depth,
    ROUND(AVG(CLICK_COUNT), 2) AS avg_clicks,
    ROUND(AVG(DWELL_TIME_SEC), 2) AS avg_dwell_time
FROM IXR_METRICS
GROUP BY engagement_level;

-- Show outcomes by engagement level
SELECT 
    CASE 
        WHEN m.avg_scroll_depth > 70 AND m.avg_click_count > 10 THEN 'High Engagement'
        WHEN m.avg_scroll_depth > 40 AND m.avg_click_count > 5 THEN 'Medium Engagement'
        ELSE 'Low Engagement'
    END AS engagement_level,
    COUNT(DISTINCT o.PROVIDER_NPI) AS provider_count,
    ROUND(AVG(o.VACCINES_ADMINISTERED), 2) AS avg_vaccines,
    ROUND(AVG(o.SCREENINGS_COMPLETED), 2) AS avg_screenings,
    ROUND(AVG(o.APPOINTMENT_SHOW_RATE), 3) AS avg_show_rate
FROM PATIENT_OUTCOMES o
JOIN (
    SELECT 
        PROVIDER_NPI,
        DATE_TRUNC('MONTH', ENGAGEMENT_DATE) AS outcome_month,
        AVG(SCROLL_DEPTH_PCT) AS avg_scroll_depth,
        AVG(CLICK_COUNT) AS avg_click_count
    FROM IXR_METRICS
    GROUP BY PROVIDER_NPI, outcome_month
) m ON o.PROVIDER_NPI = m.PROVIDER_NPI AND o.OUTCOME_MONTH = m.outcome_month
GROUP BY engagement_level;

-- Provider churn analysis
SELECT 
    IS_ACTIVE,
    COUNT(*) AS provider_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM PROVIDER_DIM
GROUP BY IS_ACTIVE;

SELECT '✓ Data setup complete. All tables created and populated with biased data.' AS STATUS;

