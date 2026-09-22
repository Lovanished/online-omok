-- 재대국 / 랜덤 흑백 배정 / 기권 / 무승부 기능을 위한 마이그레이션.
-- schema.sql(v2)을 처음부터 새로 실행하는 경우에는 필요 없습니다.
-- 예전 DB(001, 002만 적용된 상태)에 적용할 때만 실행하세요.

-- ---- players: seat(고정 신분) 추가, color unique 제약을 seat unique로 교체 ----
alter table players
  add column if not exists seat text;

-- 기존 규칙(호스트=black, 게스트=white)을 그대로 백필
update players set seat = case when color = 'black' then 'host' else 'guest' end
where seat is null;

alter table players
  alter column seat set not null;

alter table players
  drop constraint if exists players_seat_check;
alter table players
  add constraint players_seat_check check (seat in ('host', 'guest'));

-- 판마다 색이 랜덤으로 재배정되므로 더 이상 "방 안에서 색은 유일하다"를
-- DB 제약으로 강제하지 않는다 (재대국 시 색 스왑 과정에서 일시적으로
-- 중복될 수 있음). 대신 seat는 방 안에서 유일해야 한다.
alter table players
  drop constraint if exists players_room_id_color_key;

alter table players
  drop constraint if exists players_room_id_seat_key;
alter table players
  add constraint players_room_id_seat_key unique (room_id, seat);

-- ---- rooms: 무승부 제안 / 재대국 요청 플래그 ----
alter table rooms
  add column if not exists draw_offered_by text;

alter table rooms
  drop constraint if exists rooms_draw_offered_by_check;
alter table rooms
  add constraint rooms_draw_offered_by_check check (draw_offered_by in ('host', 'guest'));

alter table rooms
  add column if not exists rematch_host_requested boolean not null default false;
alter table rooms
  add column if not exists rematch_guest_requested boolean not null default false;

-- ---- players 테이블에 대한 기존 공개 select 정책이 있었다면 제거 ----
-- (session_token이 그대로 노출되는 보안 문제가 있었음)
drop policy if exists "players_select_all" on players;
