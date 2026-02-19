const fs = require('fs');

const apiKey = process.env.N8N_API_KEY;
const workflows = {
    'tULwBOlfOnCuk586': '/tmp/wf_p0/18.json',
    'oDg2TF7C0ne12fFg': '/tmp/wf_p0/02.json',
    'yKcjMnH87VsO5n9V': '/tmp/wf_p0/12.json',
    'cj1N7ZPVoDxlI7Sk': '/tmp/wf_p1/11.json',
};

async function apiCall(method, path, body = null) {
    const url = `http://localhost:5678${path}`;
    const options = {
        method,
        headers: {
            'X-N8N-API-KEY': apiKey,
            'Content-Type': 'application/json'
        }
    };
    if (body) options.body = JSON.stringify(body);

    try {
        const resp = await fetch(url, options);
        if (!resp.ok) {
            const text = await resp.text();
            return { error: `HTTP ${resp.status}: ${text}` };
        }
        return await resp.json();
    } catch (e) {
        return { error: e.message };
    }
}

async function run() {
    for (const [id, path] of Object.entries(workflows)) {
        console.log(`Deploying workflow ${id} from ${path}...`);
        try {
            if (!fs.existsSync(path)) {
                console.error(`  File not found: ${path}`);
                continue;
            }
            const data = JSON.parse(fs.readFileSync(path, 'utf8'));
            const payload = {};
            for (const key of Object.keys(data)) {
                if (key !== 'id' && key !== 'active') payload[key] = data[key];
            }

            console.log(`  Deactivating...`);
            await apiCall('POST', `/api/v1/workflows/${id}/deactivate`);

            console.log(`  Updating...`);
            const updateRes = await apiCall('PUT', `/api/v1/workflows/${id}`, payload);
            if (updateRes.error) {
                console.error(`  Update failed: ${updateRes.error}`);
            } else {
                console.log(`  Update success: ${updateRes.name}`);
            }

            console.log(`  Activating...`);
            const activateRes = await apiCall('POST', `/api/v1/workflows/${id}/activate`);
            if (activateRes.error) {
                console.error(`  Activation failed: ${activateRes.error}`);
            } else {
                console.log(`  Activation result: ${activateRes.active ? 'Active' : 'Inactive'}`);
            }

        } catch (e) {
            console.error(`  Process failed: ${e.message}`);
        }
    }
}

run();
