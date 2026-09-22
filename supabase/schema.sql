-- ============================================================
-- 오목 온라인 - Supabase 스키마 (v2: 재대국/랜덤 흑백/기권/무승부 포함)
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
-- 이미 예전 버전을 실행한 적이 있다면 supabase/migrations/ 안의 파일들을
-- 번호 순서대로 실행하는 편이 더 안전합니다 (README 참고).
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- rooms: 게임방
-- ---------------------------------------------------------------
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,                -- 6자리 초대 코드
  mode text not null default 'normal',      -- normal | mine | extreme
  status text not null default 'waiting',   -- waiting | playing | finished
  board_size int not null default 15,
  host_nickname text not null,
  guest_nickname text,
  current_turn text default 'black',        -- black | white
  phase text not null default 'move' check (phase in ('move', 'place_mine')),
                                             -- 지뢰 모드 전용: 'move'=착수 대기,
                                             -- 'place_mine'=방금 착수한 플레이어가
                                             -- 같은 턴에 지뢰 설치 칸을 골라야 함
  winner text,                              -- black | white | draw | null
  board jsonb not null default '[]'::jsonb, -- 15x15 돌 배치 (공개 정보만)
  last_move jsonb,                          -- {type,x,y,color}
  turn_number int not null default 0,
  draw_offered_by text check (draw_offered_by in ('host', 'guest')),
  rematch_host_requested boolean not null default false,
  rematch_guest_requested boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- players: 방에 접속한 플레이어
-- seat(host/guest)는 방을 만들었는지/참가했는지를 나타내는 "고정 신분"이고,
-- color(black/white)는 판마다 랜덤으로 재배정되는 "이번 판의 색"이다.
-- ---------------------------------------------------------------
create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  seat text not null check (seat in ('host', 'guest')),
  color text not null check (color in ('black', 'white')),
  nickname text not null,
  session_token uuid not null default gen_random_uuid(), -- 클라이언트가 보관, 본인 인증용
  created_at timestamptz not null default now(),
  unique (room_id, seat)
);

-- ---------------------------------------------------------------
-- mines: 지뢰 모드 전용, 절대 클라이언트에서 직접 조회 불가 (RLS로 차단)
-- 서버(API route, service role)만 읽고 씀
-- ---------------------------------------------------------------
create table if not exists mines (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  owner_color text not null check (owner_color in ('black', 'white')),
  x int not null,
  y int not null,
  placed_at_turn int not null,   -- 설치된 turn_number
  expires_at_turn int not null,  -- 이 turn_number가 되면 소멸 (상대 턴 종료 시점)
  consumed boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- chat_messages
-- ---------------------------------------------------------------
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  nickname text not null,
  color text,
  message text not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- RLS 활성화
-- ---------------------------------------------------------------
alter table rooms enable row level security;
alter table players enable row level security;
alter table mines enable row level security;
alter table chat_messages enable row level security;

-- rooms: 누구나 읽기 가능(보드는 공개 정보만 들어있음), 쓰기는 API(service role)만
create policy "rooms_select_all" on rooms for select using (true);

-- players: session_token이 들어있는 민감한 테이블이므로 클라이언트(anon key)에는
-- 어떤 select 정책도 주지 않는다. 필요한 공개 정보(닉네임/색상)는 rooms 테이블의
-- host_nickname/guest_nickname 과, 클라이언트가 이미 들고 있는 자기 세션으로 충분하고,
-- "내 색상 갱신"은 /api/rooms/[code]/me 서버 API(service role)를 통해서만 조회한다.

-- chat_messages: 누구나 읽기/쓰기 가능 (방 코드 기반 공개 채팅)
create policy "chat_select_all" on chat_messages for select using (true);
create policy "chat_insert_all" on chat_messages for insert with check (true);

-- mines: 어떤 정책도 만들지 않음 -> 클라이언트(anon key)는 절대 조회 불가.
-- service role key(API route)는 RLS를 우회하므로 서버에서만 접근 가능.

-- ---------------------------------------------------------------
-- Realtime 활성화
-- ---------------------------------------------------------------
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table chat_messages;

-- rooms.updated_at 자동 갱신 트리거
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_rooms_updated_at on rooms;
create trigger trg_rooms_updated_at
before update on rooms
for each row execute function set_updated_at();
