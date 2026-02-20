const http = require('http');
const headers = {
    'X-N8N-API-KEY': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkN2U2ZWNjOC03MjU5LTQxMjQtODdjNy0yOWE1ZjJkMjMzYmEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiMjQwM2JjOGEtMDRhMy00NzU4LTkyZGUtNzhmYjEyMjI5MDczIiwiaWF0IjoxNzcxNDM5MDgyfQ.BeT4UyvODJXOo-NliIQMgF9cuR-8yVP7mtdBVVdcUms'
};

const callApi = (path, method = 'POST') => new Promise((resolve) => {
    http.request({ hostname: 'localhost', port: 5678, path, method, headers }, (res) => {
        console.log(`Called ${path} | Status: ${res.statusCode}`);
        resolve();
    }).on('error', console.error).end();
});

// Deactivate Code Only Router
callApi('/api/v1/workflows/zQeRrQr4g5GDyx2m/deactivate');

// Ensure Host is active
callApi('/api/v1/workflows/oeM02qpKdIGFbGQX/activate');
