create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  responder_id uuid not null references public.users(id) on delete cascade,
  response_status text not null default 'on_the_way',
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create unique index if not exists responses_alert_responder_unique_idx
  on public.responses (alert_id, responder_id);

create index if not exists responses_alert_id_idx
  on public.responses (alert_id);

create index if not exists responses_responder_id_idx
  on public.responses (responder_id);

alter table public.responses replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.responses;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
