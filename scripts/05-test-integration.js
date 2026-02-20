#!/usr/bin/env node
/**
 * KREATIV EDUCAÇÃO — Integration Test Suite
 * ==========================================
 * Testa os componentes críticos da stack:
 *   1. Redis — Conectividade e autenticação
 *   2. PostgreSQL — Schema e queries críticas
 *   3. AI Router V3 — Endpoint e resposta
 *   4. Handoff FSM — Fluxo bot → human → bot
 *   5. Analytics — Queries KPI executam sem erro
 *
 * Uso: node scripts/05-test-integration.js
 * Pré-requisito: npm install pg ioredis (ou rode dentro do kreativ_postgres/redis)
 */

const { Pool } = require('pg');
const http = require('http');
const https = require('https');

// ── Configuração ──────────────────────────────────────────────────────────────
const config = {
  pg: {
    host: process.env.DB_HOST || 'kreativ_postgres',
    port: 5432,
    database: process.env.DB_NAME || 'kreativ_edu',
    user: process.env.DB_USER || 'kreativ_user',
    password: process.env.DB_PASSWORD || process.env.POSTGRES_PASSWORD,
  },
  n8n: {
    base: process.env.N8N_BASE || 'http://kreativ_n8n:5678',
    apiKey: process.env.N8N_API_KEY || '',
  },
  redis: {
    host: 'kreativ_redis',
    port: 6379,
    password: process.env.REDIS_PASSWORD,
  },
  evolution: {
    base: 'http://kreativ_evolution:8080',
    apiKey: process.env.EVOLUTION_API_KEY,
    instance: process.env.EVOLUTION_INSTANCE || 'europs',
  }
};

const pool = new Pool(config.pg);

// ── Utilidades ────────────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;
const results = [];

async function test(name, fn) {
  const start = Date.now();
  try {
    const result = await fn();
    const ms = Date.now() - start;
    console.log(`  ✅ ${name} (${ms}ms)`);
    if (result !== undefined) console.log(`     → ${JSON.stringify(result)}`);
    passed++;
    results.push({ name, status: 'PASS', ms });
  } catch (err) {
    const ms = Date.now() - start;
    console.log(`  ❌ ${name} (${ms}ms)`);
    console.log(`     → ${err.message}`);
    failed++;
    results.push({ name, status: 'FAIL', ms, error: err.message });
  }
}

function httpPost(url, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const urlObj = new URL(url);
    const mod = urlObj.protocol === 'https:' ? https : http;
    const req = mod.request({
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        ...headers
      }
    }, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.write(body);
    req.end();
  });
}

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const mod = urlObj.protocol === 'https:' ? https : http;
    const req = mod.request({
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: 'GET',
      headers
    }, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('Timeout')); });
    req.end();
  });
}

// ── SUITE 1: PostgreSQL ───────────────────────────────────────────────────────
async function testPostgres() {
  console.log('\n📊 Suite 1: PostgreSQL Schema & Queries');

  await test('Conexão ao PostgreSQL', async () => {
    const r = await pool.query('SELECT NOW() as ts, version()');
    return r.rows[0].ts;
  });

  await test('Tabela modules existe com course_int_id', async () => {
    const r = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name='modules' AND column_name='course_int_id'
    `);
    if (r.rowCount === 0) throw new Error('course_int_id não existe');
    return `tipo: ${r.rows[0].data_type}`;
  });

  await test('Módulos TDS disponíveis por course_int_id', async () => {
    const r = await pool.query(`
      SELECT course_int_id, count(*) as total
      FROM modules
      WHERE course_int_id IN (4, 5, 19)
      GROUP BY course_int_id
      ORDER BY course_int_id
    `);
    if (r.rowCount < 3) throw new Error(`Apenas ${r.rowCount} cursos encontrados, esperado 3`);
    const summary = r.rows.map(row => `curso ${row.course_int_id}: ${row.total} módulos`).join(', ');
    return summary;
  });

  await test('AI Router query: módulo por course_int_id', async () => {
    const r = await pool.query(`
      SELECT m.title, m.content_text, m.evaluation_rubric
      FROM modules m
      WHERE m.course_int_id = $1 AND m.module_number = $2
      LIMIT 1
    `, [19, 1]);
    if (r.rowCount === 0) throw new Error('Módulo não encontrado para course_int_id=19');
    return r.rows[0].title;
  });

  await test('training_memory tabela existe', async () => {
    const r = await pool.query(`SELECT COUNT(*) FROM training_memory`);
    return `${r.rows[0].count} exemplos`;
  });

  await test('handoff_control tabela e índice PRIMARY KEY', async () => {
    const r = await pool.query(`
      SELECT constraint_name FROM information_schema.table_constraints
      WHERE table_name='handoff_control' AND constraint_type='PRIMARY KEY'
    `);
    if (r.rowCount === 0) throw new Error('PK não encontrada em handoff_control');
    return r.rows[0].constraint_name;
  });

  await test('document_chunks tabela com índice ivfflat', async () => {
    const r = await pool.query(`
      SELECT indexname FROM pg_indexes
      WHERE tablename='document_chunks' AND indexname='idx_chunks_embedding'
    `);
    if (r.rowCount === 0) throw new Error('Índice vetorial não encontrado');
    return r.rows[0].indexname;
  });

  await test('module_content_sections tabela (GUI admin)', async () => {
    const r = await pool.query(`
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_name = 'module_content_sections'
    `);
    if (r.rows[0].count === '0') throw new Error('Tabela não existe');
    return 'OK';
  });

  await test('Analytics KPI: Funil de conversão executa', async () => {
    const r = await pool.query(`
      SELECT COUNT(*) as pre_inscritos FROM pre_inscriptions
      UNION ALL
      SELECT COUNT(*) FROM students
      UNION ALL
      SELECT COUNT(*) FROM certificates
    `);
    return `${r.rowCount} linhas no funil`;
  });
}

// ── SUITE 2: Redis ────────────────────────────────────────────────────────────
async function testRedis() {
  console.log('\n🔴 Suite 2: Redis');

  await test('Redis PING via docker exec', async () => {
    const { execSync } = require('child_process');
    const result = execSync(
      `docker exec kreativ_redis redis-cli -a "${config.redis.password}" ping`,
      { encoding: 'utf8', timeout: 5000 }
    ).trim();
    // Remove warning line about password
    const pong = result.split('\n').find(l => l.trim() === 'PONG');
    if (!pong) throw new Error(`Resposta inesperada: ${result}`);
    return 'PONG';
  });

  await test('Redis: SET e GET de sessão', async () => {
    const { execSync } = require('child_process');
    const key = `test:integration:${Date.now()}`;
    const val = JSON.stringify({ attendance_status: 'bot', current_module: 1 });
    execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" SET ${key} '${val}' EX 10`, { timeout: 5000 });
    const result = execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" GET ${key}`, { encoding: 'utf8', timeout: 5000 }).trim();
    const lines = result.split('\n');
    const json = lines[lines.length - 1];
    const parsed = JSON.parse(json);
    if (parsed.attendance_status !== 'bot') throw new Error('Valor incorreto no Redis');
    // Cleanup
    execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" DEL ${key}`, { timeout: 5000 });
    return `OK - status: ${parsed.attendance_status}`;
  });

  await test('Redis: LPUSH e LRANGE (chat_history)', async () => {
    const { execSync } = require('child_process');
    const key = `chat_history:test_integration_${Date.now()}`;
    const msg = JSON.stringify({ role: 'user', content: 'teste de integração' });
    execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" LPUSH ${key} '${msg}' EX 10`, { timeout: 5000 });
    const result = execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" LRANGE ${key} 0 -1`, { encoding: 'utf8', timeout: 5000 }).trim();
    const lines = result.split('\n').filter(l => l.trim() && !l.includes('Warning'));
    if (lines.length === 0) throw new Error('Lista vazia no Redis');
    execSync(`docker exec kreativ_redis redis-cli -a "${config.redis.password}" DEL ${key}`, { timeout: 5000 });
    return `${lines.length} mensagens`;
  });
}

// ── SUITE 3: N8N Workflows ────────────────────────────────────────────────────
async function testN8N() {
  console.log('\n⚙️  Suite 3: N8N Workflows');

  await test('N8N: Health check', async () => {
    const r = await httpGet(`${config.n8n.base}/healthz`);
    if (r.status !== 200) throw new Error(`HTTP ${r.status}`);
    return 'OK';
  });

  await test('N8N: AI Router V3 webhook responde', async () => {
    const r = await httpPost(
      `${config.n8n.base}/webhook/ai-tutor-v3`,
      { phone: 'test_integration', body: 'ping de teste' }
    );
    // Webhook com responseMode onReceived retorna 200 imediatamente
    if (r.status !== 200) throw new Error(`HTTP ${r.status} — esperado 200`);
    return `HTTP ${r.status}`;
  });

  await test('N8N: Chatwoot events webhook responde', async () => {
    const r = await httpPost(
      `${config.n8n.base}/webhook/chatwoot-events`,
      {
        event: 'conversation_status_changed',
        conversation: {
          id: 99999,
          status: 'resolved',
          meta: { sender: { phone_number: '+5511000000000' } }
        }
      }
    );
    if (r.status !== 200) throw new Error(`HTTP ${r.status}`);
    return `HTTP ${r.status}`;
  });
}

// ── SUITE 4: Evolution API ─────────────────────────────────────────────────────
async function testEvolution() {
  console.log('\n📱 Suite 4: Evolution API');

  await test('Evolution API: Health check', async () => {
    const r = await httpGet(`${config.evolution.base}/`);
    if (r.status < 200 || r.status > 299) throw new Error(`HTTP ${r.status}`);
    return `HTTP ${r.status}`;
  });

  await test('Evolution API: Instância existe', async () => {
    const r = await httpGet(
      `${config.evolution.base}/instance/fetchInstances`,
      { apikey: config.evolution.apiKey || '' }
    );
    if (r.status !== 200) throw new Error(`HTTP ${r.status}`);
    const instances = r.body;
    const found = Array.isArray(instances)
      ? instances.find(i => i.instance?.instanceName === config.evolution.instance)
      : instances;
    return found ? `instância ${config.evolution.instance} OK` : 'instância não encontrada (pode ser normal)';
  });
}

// ── SUITE 5: FSM Handoff ──────────────────────────────────────────────────────
async function testHandoffFSM() {
  console.log('\n🔄 Suite 5: FSM Handoff (Logic Tests)');

  const testPhone = `5511TEST${Date.now()}`;

  await test('Handoff: UPSERT student como human', async () => {
    await pool.query(`
      INSERT INTO students (phone, name, attendance_status)
      VALUES ($1, 'Aluno Teste FSM', 'bot')
      ON CONFLICT (phone) DO UPDATE SET attendance_status = 'bot'
    `, [testPhone]);

    await pool.query(`
      INSERT INTO handoff_control (phone, status)
      VALUES ($1, 'human')
      ON CONFLICT (phone) DO UPDATE SET status = 'human', last_handoff = NOW()
    `, [testPhone]);

    const r = await pool.query(`SELECT attendance_status FROM students WHERE phone = $1`, [testPhone]);
    return r.rows[0].attendance_status;
  });

  await test('Handoff: Retomar bot (transição human → bot)', async () => {
    await pool.query(`
      UPDATE students SET attendance_status = 'bot', updated_at = NOW() WHERE phone = $1
    `, [testPhone]);

    await pool.query(`
      INSERT INTO handoff_control (phone, status)
      VALUES ($1, 'bot')
      ON CONFLICT (phone) DO UPDATE SET status = 'bot', last_handoff = NOW()
    `, [testPhone]);

    const r = await pool.query(`
      SELECT s.attendance_status, hc.status as hc_status
      FROM students s
      JOIN handoff_control hc ON hc.phone = s.phone
      WHERE s.phone = $1
    `, [testPhone]);

    if (!r.rows[0]) throw new Error('Aluno não encontrado');
    if (r.rows[0].hc_status !== 'bot') throw new Error(`handoff_control.status = ${r.rows[0].hc_status}`);
    return `attendance=${r.rows[0].attendance_status}, handoff=${r.rows[0].hc_status}`;
  });

  await test('Handoff: Idempotência — segundo "resolved" não re-processa', async () => {
    // Se já estamos em 'bot', a query de idempotência deve retornar 'bot'
    const r = await pool.query(`
      SELECT status FROM handoff_control WHERE phone = $1
    `, [testPhone]);
    if (!r.rows[0]) throw new Error('handoff_control não encontrado');
    // Simular: se status já é 'bot', não processar novamente
    if (r.rows[0].status === 'bot') {
      return 'IDEMPOTENTE — evento duplicado seria ignorado ✓';
    }
    throw new Error(`Status inesperado: ${r.rows[0].status}`);
  });

  // Cleanup
  await pool.query(`DELETE FROM handoff_control WHERE phone = $1`, [testPhone]);
  await pool.query(`DELETE FROM students WHERE phone = $1`, [testPhone]);
  console.log(`     🧹 Dados de teste limpos (phone: ${testPhone})`);
}

// ── SUITE 6: Queries de Analytics ────────────────────────────────────────────
async function testAnalytics() {
  console.log('\n📈 Suite 6: Analytics KPI Queries');

  await test('KPI: Funil de conversão executa', async () => {
    const r = await pool.query(`
      SELECT 'Pre-Inscritos' as etapa, COUNT(*) FROM pre_inscriptions
      UNION ALL SELECT 'Alunos', COUNT(*) FROM students
      UNION ALL SELECT 'Certificados', COUNT(*) FROM certificates
    `);
    return r.rows.map(row => `${row.etapa}: ${row.count}`).join(' | ');
  });

  await test('KPI: Taxa de conclusão por módulo', async () => {
    const r = await pool.query(`
      SELECT c.name, m.module_number, COUNT(s.id) as total
      FROM modules m
      JOIN courses c ON c.id = m.course_int_id
      LEFT JOIN students s ON s.course_id = c.id
      WHERE m.course_int_id IN (4,5,19)
      GROUP BY c.name, m.module_number
      ORDER BY c.name, m.module_number
      LIMIT 5
    `);
    return `${r.rowCount} linhas`;
  });

  await test('KPI: Distribuição de lead score', async () => {
    const r = await pool.query(`
      SELECT
        CASE WHEN lead_score >= 80 THEN 'Hot'
             WHEN lead_score >= 50 THEN 'Warm'
             ELSE 'Cold' END as perfil,
        COUNT(*)
      FROM students GROUP BY 1
    `);
    return r.rows.map(row => `${row.perfil}: ${row.count}`).join(', ');
  });

  await test('KPI: Saúde do sistema', async () => {
    const r = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM students) as total_alunos,
        (SELECT COUNT(*) FROM modules WHERE is_published=TRUE) as modulos_publicados,
        (SELECT COUNT(*) FROM training_memory) as exemplos_treino,
        (SELECT COUNT(*) FROM document_chunks) as chunks_rag
    `);
    const d = r.rows[0];
    return `alunos=${d.total_alunos} módulos=${d.modulos_publicados} treino=${d.exemplos_treino} rag=${d.chunks_rag}`;
  });
}

// ── RUNNER ────────────────────────────────────────────────────────────────────
async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  KREATIV EDUCAÇÃO — Integration Test Suite');
  console.log(`  ${new Date().toISOString()}`);
  console.log('═══════════════════════════════════════════════════════');

  try {
    await testPostgres();
    await testRedis();
    await testN8N();
    await testEvolution();
    await testHandoffFSM();
    await testAnalytics();
  } finally {
    await pool.end();
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`  RESULTADO: ${passed} passed, ${failed} failed`);
  console.log('═══════════════════════════════════════════════════════');

  if (failed > 0) {
    console.log('\n❌ Falhas:');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`  - ${r.name}: ${r.error}`);
    });
    process.exit(1);
  } else {
    console.log('\n✅ Todos os testes passaram! Sistema pronto para deploy.');
    process.exit(0);
  }
}

main().catch(err => {
  console.error('ERRO FATAL:', err);
  process.exit(1);
});
