-- 이미 supabase/schema.sql을 한 번 실행해서 rooms 테이블이 이미 있다면,
-- Supabase SQL Editor에서 이 파일만 추가로 실행하세요.
-- (schema.sql을 처음부터 새로 실행하는 경우에는 필요 없습니다 - 이미 포함되어 있음)

alter table rooms
  add column if not exists phase text not null default 'move';

alter table rooms
  drop constraint if exists rooms_phase_check;

alter table rooms
  add constraint rooms_phase_check check (phase in ('move', 'place_mine'));
