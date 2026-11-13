-- Axiomania 2026: documentos por colección (misma forma que la base de la app anterior),
-- acceso solo para usuarios con sesión; escribir solo rol 'editor'.
create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  rol text not null default 'lector' check (rol in ('editor','lector'))
);
alter table public.perfiles enable row level security;
create policy perfiles_leer on public.perfiles for select to authenticated using (true);

create table public.docs (
  coleccion text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (coleccion, id)
);
alter table public.docs enable row level security;
alter table public.docs replica identity full;

create function public.es_editor() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.perfiles where id = auth.uid() and rol = 'editor') $$;

create policy docs_leer on public.docs for select to authenticated using (true);
create policy docs_insertar on public.docs for insert to authenticated with check (public.es_editor());
create policy docs_actualizar on public.docs for update to authenticated using (public.es_editor()) with check (public.es_editor());
create policy docs_borrar on public.docs for delete to authenticated using (public.es_editor());

-- mezcla profunda: lo que trae el parche gana; objetos se mezclan, el resto se reemplaza (null incluido)
create function public.mezclar(a jsonb, b jsonb) returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(k,
    case when jsonb_typeof(a->k)='object' and jsonb_typeof(b->k)='object' then public.mezclar(a->k, b->k)
         when b ? k then b->k else a->k end), '{}'::jsonb)
  from (select jsonb_object_keys(coalesce(a,'{}'::jsonb)) k union select jsonb_object_keys(coalesce(b,'{}'::jsonb))) t
$$;

create function public.doc_actualizar(p_col text, p_id text, p_parche jsonb) returns void
language plpgsql security invoker set search_path=public as $$
begin
  insert into public.docs(coleccion,id,data) values (p_col,p_id,p_parche)
  on conflict (coleccion,id) do update set data = public.mezclar(public.docs.data, p_parche), updated_at = now();
end $$;

alter publication supabase_realtime add table public.docs;
