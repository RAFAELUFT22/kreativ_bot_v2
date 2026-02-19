import OpenAI from 'openai'

// DeepSeek é compatível com a SDK OpenAI — só muda o baseURL e o modelo
const client = new OpenAI({
    apiKey: process.env.DEEPSEEK_API_KEY || '',
    baseURL: process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com',
})

const MODEL = process.env.DEEPSEEK_MODEL || 'deepseek-chat'

const SYSTEM_PROMPT = `Você é o assistente virtual da Kreativ Educação, um programa de educação profissional e social para comunidades do Tocantins e região Norte do Brasil.

Seu papel:
- Apoiar estudantes durante a trilha de aprendizagem via WhatsApp
- Responder dúvidas sobre os conteúdos dos cursos
- Motivar e engajar os estudantes
- Quando não souber algo específico, direcionar para um tutor humano

Cursos disponíveis:
- Gestão Financeira para Empreendimentos
- Boas Práticas na Produção e Manipulação de Alimentos
- Organização da Produção para o Mercado
- Inteligência Artificial e Inclusão Digital
- Produção Audiovisual
- Saúde e Bem-estar
- Administração e Gestão
- Agronegócio e Produção Rural
- (e outros)

Diretrizes:
- Seja amigável, claro e objetivo
- Use linguagem simples e acessível
- Mensagens curtas (máx. 300 caracteres quando possível)
- Em caso de dúvida técnica complexa, sugira: "Gostaria de falar com um tutor? Responda TUTOR"
- Nunca invente informações sobre módulos ou quizzes — consulte o sistema para isso
- Não discuta temas fora do escopo educacional`

/**
 * Gera resposta de IA para mensagem livre do estudante.
 */
export async function askDeepSeek(
    userMessage: string,
    courseContext?: { courseName?: string; moduleTitle?: string }
): Promise<string> {
    const contextMsg = courseContext?.courseName
        ? `\n[Contexto: estudante inscrito em "${courseContext.courseName}"${courseContext.moduleTitle ? `, módulo "${courseContext.moduleTitle}"` : ''}]`
        : ''

    try {
        const completion = await client.chat.completions.create({
            model: MODEL,
            messages: [
                { role: 'system', content: SYSTEM_PROMPT + contextMsg },
                { role: 'user', content: userMessage },
            ],
            max_tokens: 300,
            temperature: 0.7,
        })

        return completion.choices[0]?.message?.content?.trim()
            || 'Desculpe, não consegui processar sua mensagem. Tente novamente ou responda TUTOR para falar com um atendente.'
    } catch (err) {
        console.error('[DeepSeek] Erro na chamada à API:', err)
        throw err
    }
}

/**
 * Avalia a resposta de um estudante baseando-se no conteúdo e na rubrica.
 */
export async function evaluateStudentResponse(
    studentMessage: string,
    moduleContext: {
        moduleTitle: string;
        contentText: string;
        evaluationRubric: string;
        phone: string;
        moduleId: number;
    }
): Promise<{
    message: string;
    approved: boolean;
    score?: number;
    feedback?: string;
}> {
    const systemPrompt = `Você é um Tutor especializado do Projeto TDS. 
Seu objetivo é avaliar se o aluno compreendeu o módulo atual através de uma conversa natural.

[CONTEXTO DO MÓDULO]
Módulo: ${moduleContext.moduleTitle}
Conteúdo estudado pelo aluno: ${moduleContext.contentText}

[RUBRICA DE AVALIAÇÃO]
Critério para aprovação: ${moduleContext.evaluationRubric}

[SUA TAREFA]
1. Analise a resposta do aluno em relação à rubrica.
2. Se a resposta for insuficiente ou errada, explique o conceito de forma gentil e peça para ele tentar responder novamente (ou faça uma pergunta de acompanhamento).
3. Se a resposta demonstrar entendimento (mesmo que com palavras simples ou erros ortográficos), parabenize-o calorosamente.
4. APENAS QUANDO O ALUNO ACERTAR (ATINGIR A RUBRICA): Você DEVE invocar a ferramenta 'aprovar_aluno_modulo' informando uma nota de 70 a 100 com base na qualidade da resposta.

Regras de Tom: Seja encorajador, use emojis moderadamente, e nunca aja como um robô punitivo. O tom deve ser de um mentor paciente.`;

    try {
        const completion = await client.chat.completions.create({
            model: MODEL,
            messages: [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: studentMessage },
            ],
            tools: [
                {
                    type: 'function',
                    function: {
                        name: 'aprovar_aluno_modulo',
                        description: 'Aprova o aluno no módulo atual após ele demonstrar entendimento conforme a rubrica.',
                        parameters: {
                            type: 'object',
                            properties: {
                                score: { type: 'number', minimum: 70, maximum: 100 },
                                feedback: { type: 'string' }
                            },
                            required: ['score', 'feedback']
                        }
                    }
                }
            ],
            tool_choice: 'auto',
        });

        const choice = completion.choices[0];
        const message = choice.message;

        if (message.tool_calls && message.tool_calls.length > 0) {
            const toolCall = message.tool_calls[0];
            const args = JSON.parse(toolCall.function.arguments);
            return {
                message: message.content || 'Parabéns pela resposta!',
                approved: true,
                score: args.score,
                feedback: args.feedback
            };
        }

        return {
            message: message.content || 'Não entendi sua resposta. Pode explicar melhor?',
            approved: false
        };
    } catch (err) {
        console.error('[evaluateStudentResponse] Erro:', err);
        return {
            message: 'Tivemos um problema técnico na avaliação. Tente responder novamente em instantes.',
            approved: false
        };
    }
}
