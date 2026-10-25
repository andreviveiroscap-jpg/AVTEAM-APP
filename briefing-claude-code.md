# Briefing para o Claude Code: app de treino AV Team

## Objetivo
Transformar o protótipo atual (um único arquivo HTML, `index.html`) em um app com banco de dados. Hoje as cargas ficam só no aparelho do aluno. O objetivo é que, ao finalizar o treino, as cargas apareçam sozinhas num painel do treinador, sem o aluno precisar enviar nada.

## O que o protótipo já faz (manter)
- Identidade visual AV Team (logo, roxo, fonte condensada), em português do Brasil, pensado para celular.
- O aluno abre um link com o código dele, vê o treino do dia, preenche carga e repetições por série, marca a série como concluída.
- Mostra "Última vez" por série, volume total em tonelagem (carga × repetições), volume por exercício e por grupo muscular.
- Orientações do treino (texto editável por aluno) e abas por dia de treino (A, B, C, D).
- Modo treinador para criar aluno, treinos, exercícios (nome, grupo muscular, séries, faixa de repetições).

## O que precisa existir
1. **Aluno sem conta e sem senha.** Acessa por link com código impossível de adivinhar. Cada aluno só enxerga e grava os próprios dados.
2. **Gravação automática.** Ao tocar em "Finalizar treino", as séries (carga, repetições, data) são gravadas no banco. "Última vez" passa a vir do banco, não do aparelho, então funciona também se o aluno trocar de celular.
3. **Painel do treinador, com login por e-mail.** Lista de alunos com data do último treino; histórico de cada aluno por sessão; evolução de carga por exercício; tonelagem por sessão, por semana e por grupo muscular; edição de treinos e orientações.
4. **Link de cada aluno** copiável pelo painel. O botão "Enviar ao treinador" por WhatsApp pode continuar como opção.

## Sugestão técnica (pode propor alternativa)
- Banco e login do treinador: Supabase (Postgres, regras de acesso por linha).
- Acesso do aluno por código: funções no banco que recebem o código e só devolvem/gravam dados daquele aluno. Nunca expor as tabelas diretamente ao público.
- Hospedagem do front-end estático: Netlify, Vercel ou Cloudflare Pages (plano gratuito).
- Tabelas sugeridas: alunos (id, nome, codigo, orientacoes), treinos (aluno, dia, nome), exercicios (treino, nome, grupo, series, repeticoes, ordem), sessoes (aluno, treino, data), series (sessao, exercicio, numero, carga, repeticoes).

## Cuidados
- Dados de alunos são pessoais: não registrar nada além de nome, treino e cargas; nada de chaves secretas no código do front-end.
- Explicar cada passo que exigir minha ação (criar conta, copiar chave, etc.) em linguagem simples: trabalho com treino de musculação e não sou programador(a).
- Antes de apagar ou migrar dados, perguntar.

## Ponto de partida
O arquivo `index.html` anexo é o protótipo atual. O aluno de exemplo ("Fernando Martins", treino de peito, ombro e tríceps) pode ser usado para testar.
