-- Checklistlere "son gönderim saati" alanı ekler.
-- Yalnızca yeni, boş bir sütun ekler; hiçbir kayıt silinmez veya değişmez.
-- Bir kez çalıştırmak yeterli; tekrar çalıştırılırsa zarar vermez.
alter table public.checklist_templates add column if not exists deadline text;
