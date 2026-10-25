-- AV Team: banco de dados do app de treino.
-- Cole este arquivo inteiro no "SQL Editor" do Supabase e clique em "Run".
-- Pode rodar de novo sem perder dados: só cria o que ainda não existe e
-- atualiza as funções.

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------

create table if not exists public.alunos (
  id            uuid primary key default gen_random_uuid(),
  -- "restrict": excluir o login do treinador não apaga os alunos sem querer.
  treinador_id  uuid not null default auth.uid() references auth.users (id) on delete restrict,
  nome          text not null check (length(nome) between 1 and 120),
  -- Código do link do aluno: 32 caracteres aleatórios, impossível de adivinhar.
  codigo        text not null unique default replace(gen_random_uuid()::text, '-', ''),
  orientacoes   text not null default '',
  criado_em     timestamptz not null default now()
);

create table if not exists public.treinos (
  id        uuid primary key default gen_random_uuid(),
  aluno_id  uuid not null references public.alunos (id) on delete cascade,
  dia       text not null default '',
  nome      text not null default '',
  ordem     int  not null default 0
);

create table if not exists public.exercicios (
  id          uuid primary key default gen_random_uuid(),
  treino_id   uuid not null references public.treinos (id) on delete cascade,
  nome        text not null default '',
  grupo       text not null default '',
  series      int  not null default 3 check (series between 1 and 10),
  repeticoes  text not null default '',
  ordem       int  not null default 0,
  -- Tipo e repetições de cada série: [{"tipo": "aquecimento", "reps": "12"}, ...]
  -- tipo: aquecimento, reconhecimento ou trabalho.
  series_cfg  jsonb
);

-- Uma sessão é um treino finalizado pelo aluno.
-- treino_nome guarda uma cópia do nome para o histórico continuar legível
-- mesmo se o treinador apagar ou renomear o treino depois.
create table if not exists public.sessoes (
  id           uuid primary key default gen_random_uuid(),
  aluno_id     uuid not null references public.alunos (id) on delete cascade,
  treino_id    uuid references public.treinos (id) on delete set null,
  treino_nome  text not null default '',
  data         timestamptz not null default now()
);

-- Cada série feita. Nome e grupo do exercício também são copiados, pelo
-- mesmo motivo de treino_nome.
create table if not exists public.series (
  id              uuid primary key default gen_random_uuid(),
  sessao_id       uuid not null references public.sessoes (id) on delete cascade,
  exercicio_id    uuid references public.exercicios (id) on delete set null,
  exercicio_nome  text not null default '',
  grupo           text not null default '',
  numero          int  not null check (numero between 1 and 10),
  carga           numeric(6,2) check (carga between 0 and 1000),
  repeticoes      int  check (repeticoes between 0 and 200),
  -- Posição da série no treino, para o histórico sair na mesma ordem.
  posicao         int  not null default 0,
  tipo            text not null default 'trabalho'
);

-- Colunas acrescentadas depois da primeira versão (para bancos já criados).
alter table public.exercicios add column if not exists series_cfg jsonb;
alter table public.series     add column if not exists tipo text not null default 'trabalho';

create index if not exists alunos_treinador_idx    on public.alunos (treinador_id);
create index if not exists treinos_aluno_idx       on public.treinos (aluno_id);
create index if not exists exercicios_treino_idx   on public.exercicios (treino_id);
create index if not exists sessoes_aluno_data_idx  on public.sessoes (aluno_id, data desc);
create index if not exists series_sessao_idx       on public.series (sessao_id);
create index if not exists series_exercicio_idx    on public.series (exercicio_id);

-- ---------------------------------------------------------------------------
-- Regras de acesso (RLS)
-- O público (aluno, sem login) não acessa nenhuma tabela diretamente.
-- O treinador logado só enxerga os próprios alunos e tudo que é deles.
-- ---------------------------------------------------------------------------

alter table public.alunos     enable row level security;
alter table public.treinos    enable row level security;
alter table public.exercicios enable row level security;
alter table public.sessoes    enable row level security;
alter table public.series     enable row level security;

revoke all on public.alunos, public.treinos, public.exercicios, public.sessoes, public.series from anon;
grant select, insert, update, delete on public.alunos, public.treinos, public.exercicios, public.sessoes, public.series to authenticated;

drop policy if exists treinador_alunos on public.alunos;
create policy treinador_alunos on public.alunos for all to authenticated
  using (treinador_id = auth.uid())
  with check (treinador_id = auth.uid());

drop policy if exists treinador_treinos on public.treinos;
create policy treinador_treinos on public.treinos for all to authenticated
  using (exists (select 1 from public.alunos a where a.id = aluno_id and a.treinador_id = auth.uid()))
  with check (exists (select 1 from public.alunos a where a.id = aluno_id and a.treinador_id = auth.uid()));

drop policy if exists treinador_exercicios on public.exercicios;
create policy treinador_exercicios on public.exercicios for all to authenticated
  using (exists (select 1 from public.treinos t join public.alunos a on a.id = t.aluno_id
                 where t.id = treino_id and a.treinador_id = auth.uid()))
  with check (exists (select 1 from public.treinos t join public.alunos a on a.id = t.aluno_id
                      where t.id = treino_id and a.treinador_id = auth.uid()));

drop policy if exists treinador_sessoes on public.sessoes;
create policy treinador_sessoes on public.sessoes for all to authenticated
  using (exists (select 1 from public.alunos a where a.id = aluno_id and a.treinador_id = auth.uid()))
  with check (exists (select 1 from public.alunos a where a.id = aluno_id and a.treinador_id = auth.uid()));

drop policy if exists treinador_series on public.series;
create policy treinador_series on public.series for all to authenticated
  using (exists (select 1 from public.sessoes s join public.alunos a on a.id = s.aluno_id
                 where s.id = sessao_id and a.treinador_id = auth.uid()))
  with check (exists (select 1 from public.sessoes s join public.alunos a on a.id = s.aluno_id
                      where s.id = sessao_id and a.treinador_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- Funções do aluno (acesso pelo código do link)
-- Rodam com permissão do banco, mas só leem e gravam dados do aluno dono do
-- código recebido.
-- ---------------------------------------------------------------------------

-- Tudo que a tela do aluno precisa: nome, orientações, treinos com exercícios,
-- a última vez de cada exercício e a tonelagem da última sessão de cada treino.
create or replace function public.aluno_dados(p_codigo text)
returns json
language sql
stable
security definer
set search_path = public
as $$
  with a as (
    select id, nome, orientacoes from alunos where codigo = p_codigo
  ),
  ult as (
    -- Para cada exercício, a sessão mais recente em que ele foi feito.
    select distinct on (se.exercicio_id) se.exercicio_id, se.sessao_id
    from series se
    join sessoes s on s.id = se.sessao_id
    join a on a.id = s.aluno_id
    where se.exercicio_id is not null
    order by se.exercicio_id, s.data desc
  ),
  ant as (
    select distinct on (s.treino_id) s.treino_id, s.data,
      (select coalesce(sum(se.carga * se.repeticoes), 0) from series se where se.sessao_id = s.id) as tonelagem
    from sessoes s
    join a on a.id = s.aluno_id
    where s.treino_id is not null
    order by s.treino_id, s.data desc
  )
  select json_build_object(
    'nome', a.nome,
    'orientacoes', a.orientacoes,
    'treinos', coalesce((
      select json_agg(json_build_object(
        'id', t.id, 'dia', t.dia, 'nome', t.nome,
        'ex', coalesce((
          select json_agg(json_build_object(
            'id', e.id, 'nome', e.nome, 'grupo', e.grupo,
            'series', e.series, 'repeticoes', e.repeticoes, 'series_cfg', e.series_cfg
          ) order by e.ordem, e.nome)
          from exercicios e where e.treino_id = t.id
        ), '[]'::json)
      ) order by t.ordem, t.dia)
      from treinos t where t.aluno_id = a.id
    ), '[]'::json),
    'ultima', coalesce((
      select json_object_agg(u.exercicio_id, (
        select json_agg(json_build_object('numero', se.numero, 'carga', se.carga, 'repeticoes', se.repeticoes) order by se.posicao, se.numero)
        from series se where se.sessao_id = u.sessao_id and se.exercicio_id = u.exercicio_id
      ))
      from ult u
    ), '{}'::json),
    'anterior', coalesce((
      select json_object_agg(x.treino_id, json_build_object('data', x.data, 'tonelagem', x.tonelagem))
      from ant x
    ), '{}'::json)
  )
  from a;
$$;

-- Grava um treino finalizado.
-- p_id é gerado pelo aparelho do aluno: se o envio for repetido (internet
-- caiu, toque duplo), a sessão não é gravada duas vezes.
-- p_series: [{"exercicio_id": "...", "numero": 1, "carga": 20, "repeticoes": 10}, ...]
create or replace function public.aluno_finalizar(p_codigo text, p_id uuid, p_treino uuid, p_data timestamptz, p_series json)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aluno uuid;
  v_treino_nome text;
begin
  select id into v_aluno from alunos where codigo = p_codigo;
  if v_aluno is null then
    raise exception 'codigo invalido' using errcode = '28000';
  end if;

  select nome into v_treino_nome from treinos where id = p_treino and aluno_id = v_aluno;
  if not found then
    raise exception 'treino invalido' using errcode = '22023';
  end if;

  if json_typeof(p_series) <> 'array' or json_array_length(p_series) > 120 then
    raise exception 'series invalidas' using errcode = '22023';
  end if;

  if exists (select 1 from sessoes where id = p_id) then
    return p_id;
  end if;

  insert into sessoes (id, aluno_id, treino_id, treino_nome, data)
  -- A data vem do aparelho (o treino pode ter sido salvo sem internet), mas
  -- não pode ficar no futuro nem muito no passado.
  values (p_id, v_aluno, p_treino, v_treino_nome,
          case when p_data between now() - interval '30 days' and now() + interval '5 minutes'
               then p_data else now() end);

  insert into series (sessao_id, exercicio_id, exercicio_nome, grupo, numero, carga, repeticoes, posicao, tipo)
  select p_id, e.id, e.nome, e.grupo, x.numero, x.carga, x.repeticoes, x.posicao,
         coalesce(e.series_cfg -> (x.numero - 1) ->> 'tipo', 'trabalho')
  from (
    -- Um valor fora da faixa (erro de digitação) é descartado sem perder o
    -- resto do treino.
    select exercicio_id, numero, (n - 1)::int as posicao,
      case when carga between 0 and 1000 then round(carga, 2) end as carga,
      case when repeticoes between 0 and 200 then repeticoes end as repeticoes
    from json_array_elements(p_series) with ordinality as j(v, n),
         json_to_record(j.v) as r(exercicio_id uuid, numero int, carga numeric, repeticoes int)
    where numero between 1 and 10
  ) x
  -- Só aceita exercícios que pertencem a este treino.
  join exercicios e on e.id = x.exercicio_id and e.treino_id = p_treino
  where x.carga is not null or x.repeticoes is not null;

  return p_id;
end;
$$;

revoke all on function public.aluno_dados(text) from public;
revoke all on function public.aluno_finalizar(text, uuid, uuid, timestamptz, json) from public;
grant execute on function public.aluno_dados(text) to anon, authenticated;
grant execute on function public.aluno_finalizar(text, uuid, uuid, timestamptz, json) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Funções do treinador
-- ---------------------------------------------------------------------------

-- Gera um código novo para o aluno (se o link vazar). O link antigo para de
-- funcionar; o histórico continua.
create or replace function public.novo_codigo(p_aluno uuid)
returns text
language sql
security invoker
set search_path = public
as $$
  update alunos set codigo = replace(gen_random_uuid()::text, '-', '')
  where id = p_aluno and treinador_id = auth.uid()
  returning codigo;
$$;

revoke all on function public.novo_codigo(uuid) from public;
grant execute on function public.novo_codigo(uuid) to authenticated;

-- Lista de alunos do treinador logado, com a data do último treino.
create or replace function public.treinador_alunos()
returns json
language sql
stable
set search_path = public
as $$
  select coalesce(json_agg(json_build_object(
    'id', a.id, 'nome', a.nome, 'codigo', a.codigo,
    'ultimo', (select max(s.data) from sessoes s where s.aluno_id = a.id),
    'sessoes', (select count(*) from sessoes s where s.aluno_id = a.id)
  ) order by lower(a.nome)), '[]'::json)
  from alunos a;
$$;

-- Um aluno completo: treinos com exercícios e o histórico de sessões com as
-- séries (as 400 sessões mais recentes).
create or replace function public.treinador_aluno(p_id uuid)
returns json
language sql
stable
set search_path = public
as $$
  select json_build_object(
    'id', a.id, 'nome', a.nome, 'codigo', a.codigo, 'orientacoes', a.orientacoes,
    'treinos', coalesce((
      select json_agg(json_build_object(
        'id', t.id, 'dia', t.dia, 'nome', t.nome,
        'ex', coalesce((
          select json_agg(json_build_object(
            'id', e.id, 'nome', e.nome, 'grupo', e.grupo,
            'series', e.series, 'repeticoes', e.repeticoes, 'series_cfg', e.series_cfg
          ) order by e.ordem, e.nome)
          from exercicios e where e.treino_id = t.id
        ), '[]'::json)
      ) order by t.ordem, t.dia)
      from treinos t where t.aluno_id = a.id
    ), '[]'::json),
    'sessoes', coalesce((
      select json_agg(json_build_object(
        'id', s.id, 'data', s.data, 'treino_id', s.treino_id, 'treino_nome', s.treino_nome,
        'series', coalesce((
          select json_agg(json_build_object(
            'exercicio_id', se.exercicio_id, 'exercicio', se.exercicio_nome, 'grupo', se.grupo,
            'numero', se.numero, 'tipo', se.tipo, 'carga', se.carga, 'repeticoes', se.repeticoes
          ) order by se.posicao, se.numero)
          from series se where se.sessao_id = s.id
        ), '[]'::json)
      ) order by s.data desc)
      from (select * from sessoes where aluno_id = a.id order by data desc limit 400) s
    ), '[]'::json)
  )
  from alunos a where a.id = p_id;
$$;

-- Limpa a lista de séries recebida do painel: no máximo 10, tipo válido.
create or replace function public.normaliza_series(c jsonb)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select case when jsonb_typeof(c) = 'array' and jsonb_array_length(c) > 0 then (
    select jsonb_agg(jsonb_build_object(
      'tipo', case when x->>'tipo' in ('aquecimento', 'reconhecimento', 'trabalho') then x->>'tipo' else 'trabalho' end,
      'reps', left(coalesce(x->>'reps', ''), 20)
    ) order by n)
    from jsonb_array_elements(c) with ordinality as t(x, n)
    where n <= 10
  ) end;
$$;

-- Salva aluno, treinos e exercícios de uma vez (tudo ou nada).
-- p: {"id", "nome", "orientacoes", "treinos": [{"id", "dia", "nome", "ex": [{"id", "nome", "grupo", "series_cfg"}]}]}
-- Treinos e exercícios que não vierem na lista são removidos. O histórico
-- de séries já feitas é mantido.
create or replace function public.treinador_salvar_aluno(p json)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  v_id uuid := coalesce(nullif(p->>'id', '')::uuid, gen_random_uuid());
  v_treinos uuid[];
  v_exercicios uuid[];
begin
  insert into alunos (id, nome, orientacoes)
  values (v_id, coalesce(nullif(trim(p->>'nome'), ''), 'Aluno'), coalesce(p->>'orientacoes', ''))
  on conflict (id) do update set nome = excluded.nome, orientacoes = excluded.orientacoes;

  -- Treinos e exercícios recebidos, já com a ordem da lista.
  with t as (
    select (v->>'id')::uuid as id, coalesce(v->>'dia', '') as dia, coalesce(v->>'nome', '') as nome, (n - 1)::int as ordem
    from json_array_elements(coalesce(p->'treinos', '[]'::json)) with ordinality as x(v, n)
  )
  select coalesce(array_agg(id), '{}') into v_treinos from t;

  select coalesce(array_agg((e.v->>'id')::uuid), '{}') into v_exercicios
  from json_array_elements(coalesce(p->'treinos', '[]'::json)) as t(v),
       json_array_elements(coalesce(t.v->'ex', '[]'::json)) as e(v);

  delete from treinos where aluno_id = v_id and id <> all (v_treinos);

  insert into treinos (id, aluno_id, dia, nome, ordem)
  select (v->>'id')::uuid, v_id, coalesce(v->>'dia', ''), coalesce(v->>'nome', ''), (n - 1)::int
  from json_array_elements(coalesce(p->'treinos', '[]'::json)) with ordinality as x(v, n)
  on conflict (id) do update set dia = excluded.dia, nome = excluded.nome, ordem = excluded.ordem
  where treinos.aluno_id = excluded.aluno_id;

  delete from exercicios where treino_id = any (v_treinos) and id <> all (v_exercicios);

  -- "series" e "repeticoes" ficam como resumo (número de séries e as
  -- repetições da primeira série de trabalho).
  insert into exercicios (id, treino_id, nome, grupo, series, repeticoes, ordem, series_cfg)
  select (e.v->>'id')::uuid, (t.v->>'id')::uuid, coalesce(e.v->>'nome', ''), coalesce(e.v->>'grupo', ''),
         coalesce(jsonb_array_length(c.cfg), greatest(1, least(10, coalesce(nullif(e.v->>'series', '')::numeric::int, 3)))),
         coalesce((select x->>'reps' from jsonb_array_elements(c.cfg) x where x->>'tipo' = 'trabalho' limit 1), e.v->>'repeticoes', ''),
         (e.n - 1)::int, c.cfg
  from json_array_elements(coalesce(p->'treinos', '[]'::json)) as t(v),
       json_array_elements(coalesce(t.v->'ex', '[]'::json)) with ordinality as e(v, n),
       lateral (select normaliza_series((e.v->'series_cfg')::jsonb) as cfg) c
  on conflict (id) do update set treino_id = excluded.treino_id, nome = excluded.nome, grupo = excluded.grupo,
    series = excluded.series, repeticoes = excluded.repeticoes, ordem = excluded.ordem, series_cfg = excluded.series_cfg;

  return v_id;
end;
$$;

revoke all on function public.treinador_alunos() from public;
revoke all on function public.treinador_aluno(uuid) from public;
revoke all on function public.treinador_salvar_aluno(json) from public;
grant execute on function public.treinador_alunos() to authenticated;
grant execute on function public.treinador_aluno(uuid) to authenticated;
grant execute on function public.treinador_salvar_aluno(json) to authenticated;

-- Exclui o aluno e todo o histórico dele.
create or replace function public.treinador_excluir_aluno(p_id uuid)
returns void
language sql
set search_path = public
as $$
  delete from alunos where id = p_id;
$$;

revoke all on function public.treinador_excluir_aluno(uuid) from public;
grant execute on function public.treinador_excluir_aluno(uuid) to authenticated;
