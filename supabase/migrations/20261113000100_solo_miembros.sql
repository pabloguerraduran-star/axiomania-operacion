-- Un usuario que se registre solo (sin fila en perfiles) no ve nada.
create function public.es_miembro() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.perfiles where id = auth.uid()) $$;
drop policy docs_leer on public.docs;
create policy docs_leer on public.docs for select to authenticated using (public.es_miembro());
drop policy perfiles_leer on public.perfiles;
create policy perfiles_leer on public.perfiles for select to authenticated using (public.es_miembro());
