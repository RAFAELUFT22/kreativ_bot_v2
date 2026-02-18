# Guia de Persistência e Fluxo de Trabalho do Projeto

Este guia define como garantir que o progresso deste projeto seja mantido sem perdas, facilitando a retomada em novos dias ou sessões.

## 1. Camadas de Memória

### Camada 1: Artefatos do Agente (Curto Prazo)
O agente utiliza arquivos especiais para controle de estado:
- `task.md`: O checklist vivo de tudo que está sendo feito.
- `implementation_plan.md`: O desenho técnico antes de qualquer mudança grande.
- `walkthrough.md`: O resumo do que foi entregue e testado.

### Camada 2: Knowledge Items (Longo Prazo)
Ao finalizar marcos importantes do projeto (ex: "Configuração da Meta API concluída"), peça ao agente:
> *"Consolide o conhecimento desta tarefa em um Knowledge Item (KI)."*
Isso cria uma memória persistente que o agente lerá automaticamente no futuro.

### Camada 3: Versionamento Git (Segurança Externa)
O código é o nosso "ponto de verdade". Siga a rotina abaixo.

## 2. Rotinas Diárias Sugeridas

### 🌅 Início do Dia (Day Start)
Ao iniciar uma nova conversa, forneça o contexto:
> *"Olá! Resuma o progresso atual baseado no `task.md` e nos KIs recentes. O que falta fazer?"*

### 🌇 Final do Dia (Day End)
Antes de encerrar a sessão:
1. Verifique se o `task.md` está atualizado.
2. Comite as mudanças:
   ```bash
   git add .
   git commit -m "feat/fix: progresso do dia [descrição rápida]"
   git push origin [sua-branch]
   ```
3. Se algo complexo foi aprendido, solicite a criação de um KI.

## 3. Comandos Úteis para o Usuário
- `/ask qual o status atual?`: Faz o agente ler os artefatos e dar um resumo.
- `/ask crie uma nova tarefa para [objetivo]`: Inicia um novo ciclo de planejamento.
