const fs = require('fs');
const http = require('http');
const path = require('path');

const listDir = '/home/node/workflows_to_import';
const apiKey = process.env.N8N_KEY;

if (!apiKey) { console.error("N8N_KEY env var missing"); process.exit(1); }

// 1. Fetch existing workflows to build Name->ID map
const req = http.request({
    hostname: 'localhost',
    port: 5678,
    path: '/api/v1/workflows',
    method: 'GET',
    headers: { 'X-N8N-API-KEY': apiKey }
}, res => {
    let data = '';
    res.on('data', c => data += c);
    res.on('end', () => {
        if (res.statusCode !== 200) {
            console.error(`Failed to fetch workflows: ${res.statusCode}`);
            process.exit(1);
        }

        const existing = JSON.parse(data).data || [];
        const nameToId = {};
        existing.forEach(w => nameToId[w.name] = w.id);

        console.log(`Found ${existing.length} existing workflows.`);

        processFiles(nameToId);
    });
});
req.on('error', e => console.error(e));
req.end();

function processFiles(nameToId) {
    fs.readdir(listDir, (err, files) => {
        if (err) throw err;
        files.filter(f => f.endsWith('.json')).forEach(file => {
            const filePath = path.join(listDir, file);
            const content = fs.readFileSync(filePath, 'utf8');
            try {
                const wf = JSON.parse(content);
                const name = wf.name;
                const id = nameToId[name];

                // wf.active = true; // Activate by default (Removed because read-only on update)
                delete wf.active;
                delete wf.id; // Also good practice to remove ID from body on update
                delete wf.createdAt;
                delete wf.updatedAt;

                if (id) {
                    console.log(`Updating '${name}' (${id})...`);
                    updateWorkflow(id, wf);
                } else {
                    console.log(`Creating '${name}'...`);
                    createWorkflow(wf);
                }

            } catch (e) { console.error(`Failed to parse ${file}: ${e.message}`); }
        });
    });
}

function updateWorkflow(id, wf) {
    const req = http.request({
        hostname: 'localhost',
        port: 5678,
        path: `/api/v1/workflows/${id}`,
        method: 'PUT',
        headers: {
            'X-N8N-API-KEY': apiKey,
            'Content-Type': 'application/json'
        }
    }, res => {
        // consumes response
        // res.resume(); // Removed as we need to read the body on failure
        if (res.statusCode === 200) {
            res.resume(); // Consume response body for success cases
            console.log(`✅ Updated ${wf.name}`);
            activateWorkflow(id);
        } else {
            let data = '';
            res.on('data', c => data += c);
            res.on('end', () => console.log(`❌ Update failed for ${wf.name}: ${res.statusCode} ${data.substring(0, 200)}`));
        }
    });
    req.write(JSON.stringify(wf));
    req.end();
}

function createWorkflow(wf) {
    const req = http.request({
        hostname: 'localhost',
        port: 5678,
        path: `/api/v1/workflows`,
        method: 'POST',
        headers: {
            'X-N8N-API-KEY': apiKey,
            'Content-Type': 'application/json'
        }
    }, res => {
        let data = '';
        res.on('data', c => data += c);
        res.on('end', () => {
            if (res.statusCode === 200) {
                const json = JSON.parse(data);
                console.log(`✅ Created ${json.name} (${json.id})`);
            } else {
                console.log(`❌ Create failed for ${wf.name}: ${res.statusCode} ${data.substring(0, 100)}`);
            }
        });
    });
    req.write(JSON.stringify(wf));
    req.end();
}

function activateWorkflow(id) {
    const req = http.request({
        hostname: 'localhost',
        port: 5678,
        path: `/api/v1/workflows/${id}/activate`,
        method: 'POST',
        headers: { 'X-N8N-API-KEY': apiKey }
    }, res => { res.resume(); });
    req.end();
}
