
import http from 'k6/http';
import { check, sleep } from 'k6';

const supabaseUrl = __ENV.SUPABASE_URL;
const anonKey = __ENV.SUPABASE_ANON_KEY;
const accessToken = __ENV.SUPABASE_ACCESS_TOKEN;

if (!supabaseUrl || !anonKey || !accessToken) {
    throw new Error(
        'Configura SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_ACCESS_TOKEN'
    );
}

export const options = {
    scenarios: {
        lectura_tickets: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '10s', target: 1 },
                { duration: '20s', target: 5 },
                { duration: '20s', target: 10 },
                { duration: '20s', target: 20 },
                { duration: '10s', target: 0 },
            ],
            gracefulRampDown: '10s',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.05'],
        http_req_duration: ['p(95)<2000'],
    },
};

export default function () {
    const url =
        `${supabaseUrl.replace(/\/$/, '')}/rest/v1/support_tickets` +
        '?select=id,title,status,created_at' +
        '&order=created_at.desc' +
        '&limit=20';

    const response = http.get(url, {
        headers: {
            apikey: anonKey,
            Authorization: `Bearer ${accessToken}`,
            Accept: 'application/json',
        },
        timeout: '10s',
        tags: {
            endpoint: 'lectura_tickets',
        },
    });

    check(response, {
        'HTTP 200': (r) => r.status === 200,
        'respuesta JSON': (r) => {
            if (r.status !== 200) return false;
            try {
                return Array.isArray(JSON.parse(r.body));
            } catch (_) {
                return false;
            }
        },
    });

    sleep(1);
}
