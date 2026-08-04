-- ============================================================
-- 오목 온라인 - Supabase 스키마
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- rooms: 게임방
-- ---------------------------------------------------------------
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,               -- 6자리 초대 코드
  mode text not null default 'normal',      -- normal | mine | extreme
  status text not null default 'waiting',   -- waiting | playing | finished
  board_size int not null default 15,
  host_nickname text not null,
  guest_nickname text,
  current_turn text default 'black',        -- black | white
  phase text not null default 'move' check (phase in ('move', 'place_mine')),
                                             -- 지뢰 모드 전용: 'move'=착수 대기, 'place_mine'=방금 착수한
                                             -- 플레이어가 같은 턴에 지뢰 설치 칸을 골라야 함
  winner text,                              -- black | white | draw | null
  board jsonb not null default '[]'::jsonb, -- 15x15 돌 배치 (공개 정보만)
  last_move jsonb,                          -- {x,y,color,invalidatedByMine}
  turn_number int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- players: 방에 접속한 플레이어 (플레이어 식별용, 인증 없이 세션 토큰 기반)
-- ---------------------------------------------------------------
create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  color text not null check (color in ('black', 'white')),
  nickname text not null,
  session_token uuid not null default gen_random_uuid(), -- 클라이언트가 보관, 본인 인증용
  created_at timestamptz not null default now(),
  unique (room_id, color)
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

-- players: 자신의 row는 못 읽어도 되지만, 방 참가자 존재 확인을 위해 읽기 허용(닉네임/색상만 노출)
create policy "players_select_all" on players for select using (true);

-- chat_messages: 누구나 읽기/쓰기 가능 (방 코드 기반 공개 채팅)
create policy "chat_select_all" on chat_messages for select using (true);
create policy "chat_insert_all" on chat_messages for insert with check (true);

-- mines: 어떤 정책도 만들지 않음 -> 클라이언트(anon key)는 절대 조회 불가.
-- service role key(API route)는 RLS를 우회하므로 서버에서만 접근 가능.

-- ---------------------------------------------------------------
-- Realtime 활성화 (Supabase 대시보드 > Database > Replication 에서도 설정 가능)
-- ---------------------------------------------------------------
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table chat_messages;
alter publication supabase_realtime add table players;

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
