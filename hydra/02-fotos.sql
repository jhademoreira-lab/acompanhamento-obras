-- ════════════════════════════════════════════════════════════════
--  Fotos — tabela no schema do app (o Lab não permite policies no Storage
--  sem a T.I.). Rodar no Studio → SQL Editor DEPOIS de 01-schema.sql.
--  data = imagem JPEG em data URL (já reduzida para até 1200 px pelo app).
--  Sem update/delete pela API: fotos de registros excluídos ficam para auditoria.
-- ════════════════════════════════════════════════════════════════

create table if not exists app_cpo_acompanhamento_obras.fotos (
  id text primary key,
  registro_id text not null,
  data text not null,
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid()
);

create index if not exists fotos_registro_idx on app_cpo_acompanhamento_obras.fotos (registro_id);

alter table app_cpo_acompanhamento_obras.fotos enable row level security;
grant select, insert, update, delete on app_cpo_acompanhamento_obras.fotos to authenticated;

create policy "fotos_sel" on app_cpo_acompanhamento_obras.fotos
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_aprovado());
create policy "fotos_ins" on app_cpo_acompanhamento_obras.fotos
  for insert to authenticated with check (app_cpo_acompanhamento_obras.eh_aprovado());
create policy "fotos_r_sel" on app_cpo_acompanhamento_obras.fotos as restrictive
  for select to authenticated using (app_cpo_acompanhamento_obras.eh_aprovado());
create policy "fotos_r_ins" on app_cpo_acompanhamento_obras.fotos as restrictive
  for insert to authenticated with check (app_cpo_acompanhamento_obras.eh_aprovado());
create policy "fotos_r_upd" on app_cpo_acompanhamento_obras.fotos as restrictive
  for update to authenticated using (false);
create policy "fotos_r_del" on app_cpo_acompanhamento_obras.fotos as restrictive
  for delete to authenticated using (false);
