import { addKeyword } from '@builderbot/bot'
import type { BotContext, BotMethods } from '@builderbot/bot/dist/types'
import { mcpClient } from '../services/mcp-client'
import { evaluateStudentResponse } from '../services/ai'

// =============================================================================
// FLOW DE MÓDULO (GENERATIVO)
// Gerencia a progressão via avaliação baseada em IA e Rubricas.
// =============================================================================

const N8N_BASE = process.env.N8N_WEBHOOK_BASE || 'http://n8n:5678/webhook'

export const moduleFlow = addKeyword(['modulo', 'módulo', 'iniciar', 'continuar'])
    .addAnswer(
        '📚 Carregando o conteúdo do módulo...',
        { delay: 1000 },
        async (ctx: BotContext, { flowDynamic, state }: BotMethods) => {
            const phone = ctx.from

            try {
                const response = await fetch(`${N8N_BASE}/get-student-module`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ phone }),
                })

                if (!response.ok) throw new Error(`N8N retornou ${response.status}`)

                const data = await response.json() as {
                    moduleNumber: number
                    title: string
                    content: string
                    evaluationRubric: string
                }

                await state.update({
                    currentModule: data.moduleNumber,
                    moduleTitle: data.title,
                    moduleContent: data.content,
                    evaluationRubric: data.evaluationRubric,
                })

                await flowDynamic([
                    { body: `*Módulo ${data.moduleNumber}: ${data.title}*` },
                    { body: data.content, delay: 1500 },
                    { body: 'Quando terminar de ler, responda *AVALIAÇÃO* para iniciarmos um breve papo sobre o que você aprendeu.', delay: 800 }
                ])

            } catch (err) {
                console.error('[moduleFlow] Erro:', err)
                await flowDynamic([{ body: 'Tivemos um problema ao carregar o conteúdo. Tente novamente em instantes.' }])
            }
        }
    )

export const quizFlow = addKeyword(['quiz', 'QUIZ', 'avaliação', 'prova', 'avaliacao'])
    .addAnswer(
        'Excelente! Para concluirmos este módulo, quero te fazer uma pergunta sobre o conteúdo que acabamos de ver.',
        { delay: 800 },
        async (ctx: BotContext, { flowDynamic, state }: BotMethods) => {
            const title = await state.get('moduleTitle')
            await flowDynamic([{ body: `Baseado no módulo *${title}*, como você explicaria a importância do que aprendeu para o seu dia a dia?` }])
        }
    )
    .addAnswer(
        'Estou ouvindo... Pode escrever com suas palavras.',
        { capture: true },
        async (ctx: BotContext, { flowDynamic, state, fallBack }: BotMethods) => {
            const studentMessage = ctx.body
            const phone = ctx.from
            const moduleTitle = await state.get('moduleTitle') as string
            const contentText = await state.get('moduleContent') as string
            const evaluationRubric = await state.get('evaluationRubric') as string
            const moduleId = await state.get('currentModule') as number

            const evaluation = await evaluateStudentResponse(studentMessage, {
                moduleTitle,
                contentText,
                evaluationRubric,
                phone,
                moduleId
            })

            if (evaluation.approved) {
                await flowDynamic([{ body: evaluation.message }])

                // Registrar progresso via MCP
                await mcpClient.saveProgress(phone, moduleId, evaluation.score || 100, true)

                await flowDynamic([{
                    body: `🎉 Parabéns! Você concluiu o módulo ${moduleId}!\n\nNota: ${evaluation.score}%\nFeedback: ${evaluation.feedback}\n\nResponda *MÓDULO* para seguir para o próximo nível!`,
                    delay: 1000
                }])
            } else {
                // Se não aprovou, devolve a mensagem do tutor (que deve ser uma ajuda ou pergunta) 
                // e volta para a captura de resposta.
                await flowDynamic([{ body: evaluation.message }])
                return fallBack()
            }
        }
    )
