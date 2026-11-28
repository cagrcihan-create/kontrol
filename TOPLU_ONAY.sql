-- Eksik işler: yönetici de onaylayabilir + toplu onay.
-- Hiçbir kayıt silinmez. Tekrar çalıştırılırsa zarar vermez.

-- 1) Tek tek onay / tekrar yap: müdürün yanında yönetici (admin, yonetici) de yapabilir.
--    Fonksiyonun geri kalanı eskisiyle aynı.
create or replace function public.review_missing_task(task_id uuid, accept boolean, note text default null::text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  t public.checklist_missing_tasks%rowtype;
  actor public.profiles%rowtype;
begin
  select * into actor from public.profiles
  where id = auth.uid() and approved is true and role in ('mudur', 'yonetici', 'admin');
  if not found then raise exception 'Bu işlem için onaylı müdür ya da yönetici hesabı gerekir'; end if;

  select * into t from public.checklist_missing_tasks where id = task_id for update;
  if not found then raise exception 'Eksik iş bulunamadı'; end if;

  if t.business not in ('Carlo Burger', 'Bi Hatıra') then raise exception 'İşletme yetkisi bulunamadı'; end if;

  if t.status not in ('open', 'pending_approval', 'rejected') then
    raise exception '%', case when accept then 'Bu iş onaylanamaz' else 'Bu iş tekrar eksik olarak işaretlenemez' end;
  end if;

  if not accept and length(trim(coalesce(note, ''))) = 0 then
    raise exception 'Olmadı açıklaması zorunludur';
  end if;

  update public.checklist_missing_tasks set
    status = case when accept then 'approved' else 'rejected' end,
    approved_by = case when accept then auth.uid() else null end,
    approved_by_name = case when accept then actor.full_name else null end,
    approved_at = case when accept then now() else null end,
    reviewed_at = now(),
    manager_note = case when accept then null else left(trim(note), 1000) end
  where id = task_id;
end;
$function$;

-- 2) Toplu onay: yalnızca personelin "Tamamladım" dediği (pending_approval) işler onaylanır.
--    Onaylanan iş sayısını döndürür; diğer durumdaki işlere dokunmaz.
create or replace function public.approve_missing_tasks(task_ids uuid[])
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  actor public.profiles%rowtype;
  n integer;
begin
  select * into actor from public.profiles
  where id = auth.uid() and approved is true and role in ('mudur', 'yonetici', 'admin');
  if not found then raise exception 'Bu işlem için onaylı müdür ya da yönetici hesabı gerekir'; end if;

  if task_ids is null or cardinality(task_ids) = 0 then return 0; end if;

  update public.checklist_missing_tasks set
    status = 'approved',
    approved_by = auth.uid(),
    approved_by_name = actor.full_name,
    approved_at = now(),
    reviewed_at = now(),
    manager_note = null
  where id = any(task_ids)
    and status = 'pending_approval'
    and business in ('Carlo Burger', 'Bi Hatıra');
  get diagnostics n = row_count;
  return n;
end;
$function$;

revoke all on function public.approve_missing_tasks(uuid[]) from public, anon;
grant execute on function public.approve_missing_tasks(uuid[]) to authenticated;
