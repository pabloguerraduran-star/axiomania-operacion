-- Rol 'despacho' (17-nov-2026, pedido de Pablo): Marisol y Andrés Rodríguez solo escriben los envíos
-- de Bendito y Exponor (colección 'despacho'). El resto de la app es de solo lectura para ellos.
-- El límite vive aquí (RLS), no solo en la página.
alter table public.perfiles drop constraint perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check check (rol in ('editor','lector','despacho'));

create function public.puede_escribir(p_col text) returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.perfiles where id = auth.uid()
     and (rol = 'editor' or (rol = 'despacho' and p_col = 'despacho'))) $$;

drop policy docs_insertar on public.docs;
drop policy docs_actualizar on public.docs;
drop policy docs_borrar on public.docs;
create policy docs_insertar on public.docs for insert to authenticated with check (public.puede_escribir(coleccion));
create policy docs_actualizar on public.docs for update to authenticated using (public.puede_escribir(coleccion)) with check (public.puede_escribir(coleccion));
create policy docs_borrar on public.docs for delete to authenticated using (public.puede_escribir(coleccion));
