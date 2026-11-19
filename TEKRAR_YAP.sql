-- Müdür, onay bekleyen bir checklistte yalnızca seçtiği maddeleri tekrar yaptırır.
-- Seçilen her madde "tekrar yapılacak" eksik işi olur (status = 'rejected', müdür notu ile);
-- personel Eksik işler sekmesinden "Tamamladım" der, müdür onaylar.
-- Checklistin durumu "Düzeltme istendi" olur. Hiçbir kayıt silinmez.
-- Tekrar çalıştırılırsa zarar vermez.

create or replace function public.send_back_items(rec_id uuid, item_keys text[], note text)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  r public.checklist_records%rowtype;
  actor public.profiles%rowtype;
  k text;
  n integer := 0;
begin
  select * into actor from public.profiles
  where id = auth.uid() and approved is true and role in ('mudur', 'yonetici', 'admin');
  if not found then raise exception 'Onay yetkiniz yok'; end if;

  if item_keys is null or cardinality(item_keys) = 0 then
    raise exception 'Tekrar yapılacak en az bir madde seçin';
  end if;
  if length(trim(coalesce(note, ''))) = 0 then
    raise exception 'Personelin göreceği bir not yazın';
  end if;

  select * into r from public.checklist_records where id = rec_id for update;
  if not found then raise exception 'Kayıt bulunamadı'; end if;
  if r.status <> 'Onay bekliyor' then raise exception 'Kayıt onay beklemiyor'; end if;
  if r.person_id = auth.uid() then raise exception 'Kendi kaydınızı tekrar yaptıramazsınız'; end if;

  foreach k in array item_keys loop
    if not (coalesce(r.answers, '{}'::jsonb) ? k) then
      raise exception 'Geçersiz madde: %', k;
    end if;
    insert into public.checklist_missing_tasks
      (record_id, item_key, item_label, initial_note, business, checklist_title, reporter_name, status, manager_note, reviewed_at)
    values
      (r.id, k, coalesce(r.labels ->> k, k), coalesce(r.answers -> k ->> 'note', ''), r.business, r.title, r.person,
       'rejected', left(trim(note), 1000), now())
    on conflict (record_id, item_key) do update set
      status = 'rejected',
      manager_note = excluded.manager_note,
      reviewed_at = now(),
      completed_by = null, completed_by_name = null, completed_at = null,
      approved_by = null, approved_by_name = null, approved_at = null;
    n := n + 1;
  end loop;

  update public.checklist_records
  set status = 'Düzeltme istendi', approver = actor.full_name, approved_at = now()
  where id = rec_id;

  return n;
end $$;

revoke all on function public.send_back_items(uuid, text[], text) from public, anon;
grant execute on function public.send_back_items(uuid, text[], text) to authenticated;
