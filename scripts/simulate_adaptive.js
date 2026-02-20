const http = require('http');

console.log('SCRIPT_START');

const data = JSON.stringify({
    phone: '556399374165',
    body: 'Olá! Teste de isolamento v30.'
});

const options = {
    hostname: 'localhost',
    port: 5678,
    path: '/webhook/fresh-test',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
    }
};

console.log('SENDING_REQUEST to ' + options.path);

const req = http.request(options, (res) => {
    console.log('STATUS:', res.statusCode);
    res.on('data', (d) => {
        process.stdout.write('DATA:' + d);
    });
    res.on('end', () => {
        console.log('\nRESPONSE_END');
    });
});

req.on('error', (error) => {
    console.error('ERROR:', error);
});

req.write(data);
req.end();
console.log('REQUEST_SENT');
