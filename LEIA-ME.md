# App de treino AV Team

O aluno abre o link dele, preenche as cargas e toca em **Finalizar treino**. As cargas vão sozinhas para o banco de dados e aparecem no **painel do treinador**.

## Arquivos

| Arquivo | Para que serve |
|---|---|
| `index.html` | Tela do aluno (abre pelo link com o código dele) |
| `treinador.html` | Painel do treinador (entra com e-mail e senha) |
| `config.js` | Onde você cola o endereço e a chave do Supabase (passo 4) |
| `supabase/schema.sql` | Monta o banco de dados (passo 2) |
| `estilo.css`, `comum.js`, `logo.png` | Visual e funções compartilhadas |

---

## Passo a passo para colocar no ar

São 6 passos, feitos uma única vez. Dá para fazer tudo pelo celular, mas no computador é mais confortável. Os sites estão em inglês; os nomes dos botões aparecem aqui **em negrito**, do jeito que estão na tela.

### 1. Criar a conta no Supabase (banco de dados, gratuito)

1. Entre em **supabase.com** e toque em **Start your project**.
2. Escolha **Continue with GitHub** (usa a mesma conta do GitHub, sem criar senha nova).
3. Toque em **New project** e preencha:
   - **Name:** `avteam`
   - **Database Password:** toque em **Generate a password** e guarde essa senha num lugar seguro. Você quase nunca vai precisar dela.
   - **Region:** escolha **South America (São Paulo)**.
4. Toque em **Create new project** e espere uns 2 minutos até terminar.

### 2. Montar o banco de dados

1. No menu da esquerda do Supabase, abra **SQL Editor**.
2. Aqui no GitHub, abra o arquivo `supabase/schema.sql`, toque no botão de copiar (dois quadradinhos, **Copy raw file**) e cole no SQL Editor.
3. Toque em **Run**. Se aparecer um aviso sobre "destructive operation", toque em **Run this query**: é esperado, o arquivo só substitui regras antigas.
4. Deve aparecer **Success. No rows returned**. Pronto.

### 3. Criar o seu login de treinador

1. No menu da esquerda, abra **Authentication** e depois **Users**.
2. Toque em **Add user** e depois em **Create new user**.
3. Coloque o seu e-mail e uma senha. Deixe marcada a opção **Auto Confirm User**. Toque em **Create user**.
4. **Importante:** impeça que estranhos criem conta. Ainda em **Authentication**, abra **Sign In / Providers** e **desligue** a opção **Allow new users to sign up**. Toque em **Save**.

### 4. Ligar o app ao banco (`config.js`)

1. No Supabase, toque em **Project Settings** (engrenagem, no fim do menu da esquerda).
2. Em **Data API**, copie o **Project URL** (algo como `https://abcdxyz.supabase.co`).
3. Em **API Keys**, copie a **Publishable key** (começa com `sb_publishable_`). Se só aparecer a versão antiga, use a **anon public**.
4. Aqui no GitHub, abra o arquivo `config.js` e toque no lápis (**Edit**). Cole cada valor entre as aspas:
   ```js
   SUPABASE_URL: "https://abcdxyz.supabase.co",
   SUPABASE_KEY: "sb_publishable_...",
   ```
   Confira também o seu número de WhatsApp na linha `WHATSAPP`.
5. Toque em **Commit changes** e confirme.

> Essas duas informações são públicas e podem ficar no código sem problema: a segurança está nas regras do banco.
> **Nunca** cole no `config.js` a chave **secret** nem a **service_role**. Elas dão acesso total ao banco.

### 5. Publicar o site (Netlify, gratuito)

1. Entre em **netlify.com**, toque em **Sign up** e escolha **GitHub**.
2. Toque em **Add new project** (ou **Add new site**) e depois em **Import an existing project**.
3. Escolha **GitHub**, autorize e selecione o repositório **AVTEAM-APP**.
4. Deixe tudo como está (não precisa de "build command") e toque em **Deploy**.
5. Em um minuto aparece o endereço do site, algo como `https://nome-aleatorio.netlify.app`. Para um nome melhor: **Project configuration** → **Change project name** (por exemplo `avteam-treinos`, que vira `https://avteam-treinos.netlify.app`).

Daqui em diante, toda mudança salva aqui no GitHub vai para o site sozinha.

### 6. Ajustar o "Esqueci minha senha"

1. No Supabase, abra **Authentication** e depois **URL Configuration**.
2. Em **Site URL**, coloque o endereço do seu site (ex.: `https://avteam-treinos.netlify.app`).
3. Em **Redirect URLs**, toque em **Add URL**, coloque `https://avteam-treinos.netlify.app/treinador.html` (com o seu endereço) e salve.

---

## Usando no dia a dia

- **Painel do treinador:** abra `https://SEU-SITE.netlify.app/treinador.html` e entre com o e-mail e a senha do passo 3. Vale salvar na tela inicial do celular (no Safari: compartilhar → **Adicionar à Tela de Início**).
- **Primeiro teste:** com o painel vazio, toque em **Criar aluno de exemplo (Fernando Martins)**. Depois toque em **Ver como aluno**, preencha algumas cargas e toque em **Finalizar treino**. Volte ao painel: o treino aparece no **Histórico**. Para apagar o exemplo depois: aba **Treino** → **Excluir aluno**.
- **Novo aluno:** **+ Novo aluno**, preencha nome, orientações e treinos e toque em **Salvar alterações**. Depois **Copiar link** e envie ao aluno pelo WhatsApp.
- **O que o painel mostra:** lista de alunos com a data do último treino; **Histórico** de cada sessão com as séries; **Evolução** da maior carga por exercício (gráfico e tabela); **Volume** (tonelagem) por semana, por grupo muscular e por treino.
- **Link vazou?** No aluno, toque em **Gerar novo link**. O link antigo para de funcionar na hora e o histórico continua.
- **Sem internet na academia:** o treino fica guardado no celular do aluno e é enviado sozinho quando a internet voltar.
- **"Enviar ao treinador" (WhatsApp)** continua funcionando como antes, se o aluno quiser usar.

## Sobre os dados

- O banco guarda só: nome do aluno, orientações, treinos e cargas/repetições com a data. Nada de telefone, e-mail ou senha de aluno.
- O aluno não tem conta. Ele só consegue ver e gravar os próprios treinos, usando o código do link (32 caracteres aleatórios, impossível de adivinhar).
- O público não acessa as tabelas diretamente. Só você, logado, vê os seus alunos.
- Editar ou remover um exercício não apaga o histórico: as séries antigas guardam o nome do exercício como era na época.
- O banco não deixa excluir o seu login enquanto houver alunos cadastrados, para nada ser apagado sem querer.

## Bom saber

- **Plano gratuito do Supabase:** se ninguém usar o app por 7 dias seguidos, o projeto "dorme". Basta entrar no supabase.com e tocar em **Restore project**. Com alunos treinando toda semana, isso não acontece.
- **Alunos do protótipo antigo:** as cargas antigas ficaram só no celular de cada aluno e não podem ser trazidas para o banco. Cadastre os alunos de novo pelo painel e envie os links novos.
