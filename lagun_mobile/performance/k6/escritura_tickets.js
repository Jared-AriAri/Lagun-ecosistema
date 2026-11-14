import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.SUPABASE_URL;
const anonKey = __ENV.SUPABASE_ANON_KEY;
const accessToken = __ENV.SUPABASE_ACCESS_TOKEN;
const runId = __ENV.TEST_RUN_ID;

if (!baseUrl || !anonKey || !accessToken || !runId) {
  throw new Error('Faltan variables de configuración');
}

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<2000'],
    checks: ['rate==1'],
  },
};

export default function () {
  const title = `P12-LOAD-${runId}-${__VU}-${__ITER}`;

  const payload = JSON.stringify({
    title,
    description: 'Ticket generado para prueba controlada de concurrencia LAGUN',
    category: 'app',
  });

  const response = http.post(
    `${baseUrl.replace(/\/$/, '')}/rest/v1/support_tickets`,
    payload,
    {
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      timeout: '10s',
      tags: {
        endpoint: 'escritura_tickets',
      },
    }
  );

  check(response, {
    'HTTP 201': (r) => r.status === 201,
    'ticket creado correctamente': (r) => {
      if (r.status !== 201) return false;

      try {
        const data = JSON.parse(r.body);
        return Array.isArray(data) &&
          data.length === 1 &&
          data[0].title === title &&
          Boolean(data[0].id);
      } catch (_) {
        return false;
      }
    },
  });

  sleep(1);
}
