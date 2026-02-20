-- =============================================================================
-- KREATIV EDUCAÇÃO — KPI Analytics Queries para Metabase
-- =============================================================================
-- Como usar: cole cada bloco como uma nova Question no Metabase
-- Banco: kreativ_edu (kreativ_postgres:5432)
-- =============================================================================


-- =============================================================================
-- BLOCO 1 — FUNIL DE CONVERSÃO (Pré-inscrição → Aluno → Módulos Concluídos)
-- Metabase: Funnel chart ou Bar chart
-- =============================================================================
SELECT
    'Pre-Inscritos'::text                      AS etapa,
    COUNT(*)                                   AS total,
    1                                          AS ordem
FROM pre_inscriptions
UNION ALL
SELECT
    'Alunos Ativos'::text,
    COUNT(*),
    2
FROM students
WHERE attendance_status != 'undefined'
UNION ALL
SELECT
    'Iniciaram Módulo 1'::text,
    COUNT(*),
    3
FROM students
WHERE current_module >= 1
UNION ALL
SELECT
    'Completaram ≥ 1 Módulo'::text,
    COUNT(*),
    4
FROM students
WHERE cardinality(completed_modules) > 0
UNION ALL
SELECT
    'Certificados Emitidos'::text,
    COUNT(*),
    5
FROM certificates
ORDER BY ordem;


-- =============================================================================
-- BLOCO 2 — TAXA DE CONCLUSÃO POR MÓDULO E CURSO
-- Metabase: Bar chart, agrupar por course_name + module_number
-- =============================================================================
SELECT
    c.name                                  AS curso,
    m.module_number                         AS modulo,
    m.title                                 AS titulo_modulo,
    COUNT(s.id)                             AS total_alunos_curso,
    -- Alunos que já passaram deste módulo
    COUNT(s.id) FILTER (
        WHERE m.module_number = ANY(s.completed_modules)
    )                                       AS concluiram,
    ROUND(
        100.0 * COUNT(s.id) FILTER (WHERE m.module_number = ANY(s.completed_modules))
        / NULLIF(COUNT(s.id), 0), 1
    )                                       AS taxa_conclusao_pct
FROM modules m
JOIN courses c ON c.id = m.course_int_id
LEFT JOIN students s ON s.course_id = c.id
GROUP BY c.name, m.module_number, m.title
ORDER BY c.name, m.module_number;


-- =============================================================================
-- BLOCO 3 — DISTRIBUIÇÃO DO LEAD SCORE (Engajamento)
-- Metabase: Pie chart ou Bar chart agrupado por perfil
-- =============================================================================
SELECT
    CASE
        WHEN lead_score >= 80 THEN '🔥 Hot (≥80)'
        WHEN lead_score >= 50 THEN '⚡ Warm (50-79)'
        WHEN lead_score >= 20 THEN '🌱 Warm-Cold (20-49)'
        ELSE '❄️ Cold (<20)'
    END                                     AS perfil_engajamento,
    COUNT(*)                                AS alunos,
    ROUND(AVG(lead_score), 1)               AS score_medio,
    MAX(lead_score)                         AS score_max
FROM students
GROUP BY 1
ORDER BY score_medio DESC;


-- =============================================================================
-- BLOCO 4 — ESCALAÇÃO DE SUPORTE (Handoff Bot → Humano)
-- Metabase: Single number + Table
-- =============================================================================
SELECT
    COUNT(*)                                AS total_sessoes,
    COUNT(*) FILTER (WHERE bot_resumed)     AS bot_retomado,
    COUNT(*) FILTER (WHERE NOT bot_resumed AND ended_at IS NOT NULL)
                                            AS encerrado_sem_retomar_bot,
    COUNT(*) FILTER (WHERE ended_at IS NULL)
                                            AS sessoes_em_aberto,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (ended_at - started_at)) / 60
    ) FILTER (WHERE ended_at IS NOT NULL), 1)
                                            AS tempo_medio_min,
    MAX(
        EXTRACT(EPOCH FROM (ended_at - started_at)) / 60
    ) FILTER (WHERE ended_at IS NOT NULL)   AS tempo_max_min
FROM support_sessions;


-- =============================================================================
-- BLOCO 5 — TOP RAZÕES DE ESCALAÇÃO PARA SUPORTE HUMANO
-- Metabase: Bar chart horizontal
-- =============================================================================
SELECT
    reason,
    COUNT(*)                                AS ocorrencias,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentual
FROM support_sessions
WHERE reason IS NOT NULL AND reason != ''
GROUP BY reason
ORDER BY ocorrencias DESC
LIMIT 15;


-- =============================================================================
-- BLOCO 6 — ATIVIDADE DIÁRIA (DAU - Daily Active Users)
-- Metabase: Line chart por data
-- =============================================================================
SELECT
    DATE(el.created_at)                     AS data,
    COUNT(DISTINCT el.student_id)           AS alunos_ativos,
    COUNT(*)                                AS total_eventos,
    COUNT(*) FILTER (WHERE el.event_type = 'module_completed')
                                            AS modulos_concluidos,
    COUNT(*) FILTER (WHERE el.event_type = 'quiz_passed')
                                            AS quizzes_passados,
    COUNT(*) FILTER (WHERE el.event_type = 'human_support_requested')
                                            AS suportes_solicitados
FROM events_log el
WHERE el.created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(el.created_at)
ORDER BY data;


-- =============================================================================
-- BLOCO 7 — ENGAJAMENTO POR ESTADO (Tocantins e outros)
-- Metabase: Map chart ou Bar chart
-- =============================================================================
SELECT
    COALESCE(pi.estado, 'Não informado')    AS estado,
    COALESCE(pi.cidade, 'Não informado')    AS cidade,
    COUNT(DISTINCT pi.id)                   AS pre_inscritos,
    COUNT(DISTINCT s.id)                    AS convertidos_alunos,
    ROUND(100.0 * COUNT(DISTINCT s.id) / NULLIF(COUNT(DISTINCT pi.id), 0), 1)
                                            AS taxa_conversao_pct
FROM pre_inscriptions pi
LEFT JOIN students s ON s.id = pi.student_id
GROUP BY pi.estado, pi.cidade
ORDER BY pre_inscritos DESC
LIMIT 30;


-- =============================================================================
-- BLOCO 8 — RETENÇÃO SEMANAL (Cohort Analysis simplificado)
-- Quantos alunos criados em cada semana retornaram na semana seguinte
-- Metabase: Table
-- =============================================================================
WITH weekly_cohorts AS (
    SELECT
        DATE_TRUNC('week', created_at)      AS cohort_week,
        id                                  AS student_id
    FROM students
    WHERE created_at >= NOW() - INTERVAL '8 weeks'
),
weekly_activity AS (
    SELECT
        DATE_TRUNC('week', el.created_at)   AS activity_week,
        el.student_id
    FROM events_log el
    WHERE el.created_at >= NOW() - INTERVAL '8 weeks'
    GROUP BY 1, 2
)
SELECT
    TO_CHAR(wc.cohort_week, 'YYYY-MM-DD')   AS semana_inscricao,
    COUNT(DISTINCT wc.student_id)           AS alunos_inscrito,
    COUNT(DISTINCT wa.student_id)           AS retornaram_semana_seguinte,
    ROUND(100.0 * COUNT(DISTINCT wa.student_id) / NULLIF(COUNT(DISTINCT wc.student_id), 0), 1)
                                            AS taxa_retencao_pct
FROM weekly_cohorts wc
LEFT JOIN weekly_activity wa
    ON wa.student_id = wc.student_id
    AND wa.activity_week = wc.cohort_week + INTERVAL '1 week'
GROUP BY wc.cohort_week
ORDER BY wc.cohort_week;


-- =============================================================================
-- BLOCO 9 — CURSOS MAIS POPULARES (por inscrição)
-- Metabase: Horizontal bar chart
-- =============================================================================
SELECT
    c.name                                  AS curso,
    c.area                                  AS area,
    COUNT(DISTINCT pic.pre_inscription_id)  AS pre_inscritos,
    COUNT(DISTINCT s.id)                    AS alunos_ativos,
    COUNT(DISTINCT cert.id)                 AS certificados_emitidos,
    ROUND(AVG(s.lead_score), 1)             AS lead_score_medio
FROM courses c
LEFT JOIN pre_inscription_courses pic ON pic.course_id = c.id
LEFT JOIN students s ON s.course_id = c.id
LEFT JOIN certificates cert ON cert.course_id = c.id
GROUP BY c.id, c.name, c.area
ORDER BY pre_inscritos DESC;


-- =============================================================================
-- BLOCO 10 — SAÚDE DO SISTEMA (Dashboard Técnico)
-- Metabase: Single number tiles
-- =============================================================================
SELECT
    -- Alunos
    (SELECT COUNT(*) FROM students)                             AS total_alunos,
    (SELECT COUNT(*) FROM students WHERE attendance_status='bot')   AS modo_bot,
    (SELECT COUNT(*) FROM students WHERE attendance_status='human') AS modo_humano,
    -- Módulos
    (SELECT COUNT(*) FROM modules WHERE is_published=TRUE)     AS modulos_publicados,
    (SELECT COUNT(*) FROM document_chunks)                     AS chunks_rag,
    -- Treinamento
    (SELECT COUNT(*) FROM training_memory)                     AS exemplos_treinamento,
    -- Certificados
    (SELECT COUNT(*) FROM certificates)                        AS certificados_emitidos,
    -- Suporte
    (SELECT COUNT(*) FROM support_sessions WHERE ended_at IS NULL) AS suportes_abertos,
    -- Eventos hoje
    (SELECT COUNT(*) FROM events_log WHERE DATE(created_at) = CURRENT_DATE) AS eventos_hoje;


-- =============================================================================
-- BLOCO 11 — PROGRESSÃO DO MÓDULO (heatmap de módulo atual)
-- Metabase: Bar chart ou Heatmap
-- =============================================================================
SELECT
    c.name                                  AS curso,
    s.current_module                        AS modulo_atual,
    COUNT(s.id)                             AS alunos
FROM students s
LEFT JOIN courses c ON c.id = s.course_id
WHERE s.current_module > 0
GROUP BY c.name, s.current_module
ORDER BY c.name, s.current_module;


-- =============================================================================
-- BLOCO 12 — MEMORIA DE TREINAMENTO POR CURSO (qualidade do few-shot)
-- Metabase: Table
-- =============================================================================
SELECT
    COALESCE(course_id, 'geral')            AS curso,
    COUNT(*)                                AS total_exemplos,
    MIN(created_at)                         AS primeiro_exemplo,
    MAX(created_at)                         AS ultimo_exemplo,
    COUNT(DISTINCT student_phone)           AS alunos_contribuiram
FROM training_memory
GROUP BY course_id
ORDER BY total_exemplos DESC;
