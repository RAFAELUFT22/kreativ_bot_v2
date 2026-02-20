import { createBot, createProvider, createFlow } from '@builderbot/bot'
import { PostgreSQLAdapter as Database } from '@builderbot/database-postgres'
import { EvolutionProvider as Provider } from '@builderbot/provider-evolution-api'
import { Pool } from 'pg'

import { entryFlow } from './flows/entry.flow'

const pool = new Pool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: Number(process.env.DB_PORT),
})

const PORT = process.env.PORT ?? 3008

const main = async () => {
    // Phase 19: Only entryFlow is used. All logic delegated to N8N.
    const adapterFlow = createFlow([entryFlow])

    console.log('DEBUG ENV:', {
        apikey: process.env.EVOLUTION_API_KEY,
        url: process.env.EVOLUTION_API_URL,
        instance: process.env.EVOLUTION_INSTANCE
    });

    const adapterProvider = createProvider(Provider, {
        instanceName: 'europs',
        baseURL: 'http://kreativ_evolution:8080',
        apiKey: 'EXr5OuEE2sBMbRo94LtWQfofvEF1gHUM',
    })

    const adapterDB = new Database({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        database: process.env.DB_NAME,
        password: process.env.DB_PASSWORD,
        port: Number(process.env.DB_PORT),
    })

    const { handleCtx, httpServer } = await createBot({
        flow: adapterFlow,
        provider: adapterProvider,
        database: adapterDB,
    })

    // DB Proxy
    adapterProvider.server.post('/api/query', async (req, res) => {
        const { query, values } = req.body
        console.log(`[DB QUERY] Executing: ${query} with values: ${values}`)
        try {
            const result = await pool.query(query, values)
            console.log(`[DB QUERY] Success: ${result.rowCount} rows returned`)
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ rows: result.rows }))
        } catch (e) {
            console.error('DB Query Error:', e)
            res.statusCode = 500
            res.end(JSON.stringify({ error: e.message }))
        }
    })

    httpServer(+PORT)

    // Webhook endpoint for N8N or other services to send messages voluntarily
    adapterProvider.server.post('/api/send', async (req, res) => {
        const { phone, message } = req.body
        console.log(`[API SEND] To: ${phone} | Msg: ${message?.substring(0, 30)}...`)
        if (phone && message) {
            try {
                await adapterProvider.sendText(phone, message)
                console.log(`[API SEND] Success for ${phone}`)
                res.writeHead(200, { 'Content-Type': 'application/json' })
                res.end(JSON.stringify({ success: true }))
            } catch (err) {
                console.error('Error sending message:', err)
                res.statusCode = 500
                res.end(JSON.stringify({ error: 'Failed' }))
            }
        } else {
            res.statusCode = 400
            res.end(JSON.stringify({ error: 'Missing phone or message' }))
        }
    })
}

main()
