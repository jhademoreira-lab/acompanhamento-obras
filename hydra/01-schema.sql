-- ════════════════════════════════════════════════════════════════
--  Acompanhamento de Obras — schema no Hydra (Lab)
--  Schema: app_cpo_acompanhamento_obras
--  Rodar no Studio → SQL Editor (uma vez).
--
--  Segurança: o Auth do Lab é compartilhado por todos os apps, então
--  "authenticated" = qualquer conta do Hydra. Por isso TODA tabela tem
--  policies RESTRICTIVE exigindo usuário aprovado NESTE app (elas valem
--  mesmo depois que a automação do Hydra criar o write-RLS permissivo).
-- ════════════════════════════════════════════════════════════════

create schema if not exists app_cpo_acompanhamento_obras;

-- ── Tabelas ─────────────────────────────────────────────────────
create table if not exists app_cpo_acompanhamento_obras.admins (
  uid uuid primary key,
  criado_em timestamptz not null default now()
);

create table if not exists app_cpo_acompanhamento_obras.usuarios (
  uid uuid primary key,
  nome text not null default '',
  email text not null default '',
  departamento text not null default '',
  status text not null default 'pendente' check (status in ('pendente', 'aprovado', 'revogado')),
  criado_em timestamptz not null default now(),
  aprovado_em timestamptz,
  aprovado_por text
);

-- Cadastro do sistema antigo (Firebase) — só para o admin consultar ao aprovar
create table if not exists app_cpo_acompanhamento_obras.usuarios_legado (
  email text primary key,
  nome text,
  departamento text,
  status text,
  criado_em text
);

-- Registro completo em JSON (mesmo formato do app); fotos = caminhos no bucket
create table if not exists app_cpo_acompanhamento_obras.registros (
  id text primary key,
  dados jsonb not null,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid()
);

create table if not exists app_cpo_acompanhamento_obras.pdf_log (
  id text primary key default gen_random_uuid()::text,
  uid text not null,
  dados jsonb not null,
  ts timestamptz not null default now()
);

-- meta = resumo (lista); dados = registro completo no momento da exclusão
create table if not exists app_cpo_acompanhamento_obras.exclusoes (
  id text primary key,
  uid text not null,
  meta jsonb not null,
  dados jsonb not null,
  excluido_em timestamptz not null default now()
);

alter table app_cpo_acompanhamento_obras.admins enable row level security;
alter table app_cpo_acompanhamento_obras.usuarios enable row level security;
alter table app_cpo_acompanhamento_obras.usuarios_legado enable row level security;
alter table app_cpo_acompanhamento_obras.registros enable row level security;
alter table app_cpo_acompanhamento_obras.pdf_log enable row level security;
alter table app_cpo_acompanhamento_obras.exclusoes enable row level security;

-- ── Funções de permissão ────────────────────────────────────────
create or replace function app_cpo_acompanhamento_obras.eh_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from app_cpo_acompanhamento_obras.admins a where a.uid = auth.uid());
$$;

create or replace function app_cpo_acompanhamento_obras.eh_aprovado()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from app_cpo_acompanhamento_obras.usuarios u
                 where u.uid = auth.uid() and u.status = 'aprovado');
$$;

grant usage on schema app_cpo_acompanhamento_obras to anon, authenticated;
grant execute on function app_cpo_acompanhamento_obras.eh_admin() to anon, authenticated;
grant execute on function app_cpo_acompanhamento_obras.eh_aprovado() to anon, authenticated;
grant select, insert, update, delete on all tables in schema app_cpo_acompanhamento_obras to authenticated;

-- ── admins: cada um só vê a própria linha; ninguém grava pela API ──
create policy "admins_sel" on app_cpo_acompanhamento_obras.admins
  for select to authenticated using (uid = auth.uid());
create policy "admins_r_sel" on app_cpo_acompanhamento_obras.admins as restrictive
  for select to authenticated using (uid = auth.uid());
create policy "admins_r_ins" on app_cpo_acompanhamento_obras.admins as restrictive
  for insert to authenticated with check (false);
create policy "admins_r_upd" on app_cpo_acompanhamento_obras.admins as restrictive
  for update to authenticated using (false);
create policy "admins_r_del" on app_cpo_acompanhamento_obras.admins as restrictive
  for delete to authenticated using (false);

-- ── usuarios: pessoa vê/cria só o próprio pedido (pendente); admin gerencia ──
create policy "usuarios_sel" on app_cpo_acompanhamento_obras.usuarios
  for select to authenticated using (uid = auth.uid() or app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_ins" on app_cpo_acompanhamento_obras.usuarios
  for insert to authenticated with check (
    (uid = auth.uid() and status = 'pendente' and aprovado_em is null)
    or app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_upd" on app_cpo_acompanhamento_obras.usuarios
  for update to authenticated using (app_cpo_acompanhamento_obras.eh_admin())
  with check (app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_r_sel" on app_cpo_acompanhamento_obras.usuarios as restrictive
  for select to authenticated using (uid = auth.uid() or app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_r_ins" on app_cpo_acompanhamento_obras.usuarios as restrictive
  for insert to authenticated with check (
    (uid = auth.uid() and status = 'pendente' and aprovado_em is null)
    or app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_r_upd" on app_cpo_acompanhamento_obras.usuarios as restrictive
  for update to authenticated using (app_cpo_acompanhamento_obras.eh_admin())
  with check (app_cpo_acompanhamento_obras.eh_admin());
create policy "usuarios_r_del" on app_cpo_acompanhamento_obras.usuarios as restrictive
  for delete to authenticated using (false);

-- ── usuarios_legado: só admin lê; ninguém grava pela API ──
create policy "legado_sel" on app_cpo_acompanhamento_obras.usuarios_legado
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "legado_r_sel" on app_cpo_acompanhamento_obras.usuarios_legado as restrictive
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "legado_r_ins" on app_cpo_acompanhamento_obras.usuarios_legado as restrictive
  for insert to authenticated with check (false);
create policy "legado_r_upd" on app_cpo_acompanhamento_obras.usuarios_legado as restrictive
  for update to authenticated using (false);
create policy "legado_r_del" on app_cpo_acompanhamento_obras.usuarios_legado as restrictive
  for delete to authenticated using (false);

-- ── registros: só aprovados leem e gravam ──
create policy "registros_all" on app_cpo_acompanhamento_obras.registros
  for all to authenticated
  using (app_cpo_acompanhamento_obras.eh_aprovado())
  with check (app_cpo_acompanhamento_obras.eh_aprovado());
create policy "registros_r_all" on app_cpo_acompanhamento_obras.registros as restrictive
  for all to authenticated
  using (app_cpo_acompanhamento_obras.eh_aprovado())
  with check (app_cpo_acompanhamento_obras.eh_aprovado());

-- ── pdf_log: aprovado registra o próprio; só admin lê ──
create policy "pdflog_ins" on app_cpo_acompanhamento_obras.pdf_log
  for insert to authenticated
  with check (uid = auth.uid()::text and app_cpo_acompanhamento_obras.eh_aprovado());
create policy "pdflog_sel" on app_cpo_acompanhamento_obras.pdf_log
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "pdflog_r_ins" on app_cpo_acompanhamento_obras.pdf_log as restrictive
  for insert to authenticated
  with check (uid = auth.uid()::text and app_cpo_acompanhamento_obras.eh_aprovado());
create policy "pdflog_r_sel" on app_cpo_acompanhamento_obras.pdf_log as restrictive
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "pdflog_r_upd" on app_cpo_acompanhamento_obras.pdf_log as restrictive
  for update to authenticated using (false);
create policy "pdflog_r_del" on app_cpo_acompanhamento_obras.pdf_log as restrictive
  for delete to authenticated using (false);

-- ── exclusoes: aprovado registra a própria exclusão; só admin lê ──
create policy "exclusoes_ins" on app_cpo_acompanhamento_obras.exclusoes
  for insert to authenticated
  with check (uid = auth.uid()::text and app_cpo_acompanhamento_obras.eh_aprovado());
create policy "exclusoes_sel" on app_cpo_acompanhamento_obras.exclusoes
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "exclusoes_r_ins" on app_cpo_acompanhamento_obras.exclusoes as restrictive
  for insert to authenticated
  with check (uid = auth.uid()::text and app_cpo_acompanhamento_obras.eh_aprovado());
create policy "exclusoes_r_sel" on app_cpo_acompanhamento_obras.exclusoes as restrictive
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_admin());
create policy "exclusoes_r_upd" on app_cpo_acompanhamento_obras.exclusoes as restrictive
  for update to authenticated using (false);
create policy "exclusoes_r_del" on app_cpo_acompanhamento_obras.exclusoes as restrictive
  for delete to authenticated using (false);
