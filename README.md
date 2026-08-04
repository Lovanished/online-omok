# 오목 온라인 (Gomoku Online)

친구와 실시간으로 즐기는 온라인 오목. Next.js + Supabase + Vercel 기반.

## 기능
- 방 생성 / 초대 코드로 참가
- 실시간 채팅, 실시간 이모지 반응
- 게임 모드
  - **일반 모드**: 표준 오목 규칙 + 흑돌 금수(장목, 33, 44)
  - **지뢰 모드**: 일반 모드 + 상대에게 보이지 않는 지뢰
  - **익스트림 모드**: 아직 규칙 미정 (UI/구조만 준비된 스텁, 아이디어가 정해지면
    `src/lib/game/` 에 새 모듈을 추가하고 `move` API의 분기만 확장하면 됩니다)

## 지뢰 모드 규칙 구현
- 자신의 턴에 "돌 두기" 또는 "지뢰 설치" 중 하나를 선택 (지뢰 설치도 턴을 소모합니다)
- 지뢰는 `mines` 테이블에만 저장되고, 이 테이블은 RLS 정책이 전혀 없어
  브라우저(anon key)로는 절대 조회할 수 없습니다. 오직 서버 API 라우트
  (service role key)만 접근 가능 → 상대에게 위치가 노출되지 않습니다.
- 설치 턴을 T라 하면, 상대 턴(T+1)까지 유효하고 그 다음(T+2)에 자동 소멸합니다.
- 상대가 지뢰 칸에 착수하면 착수가 무효 처리되고 턴만 다시 넘어갑니다
  (이때는 위치가 공개됩니다 - 규칙상 당연히 드러나는 정보이므로).
- 직전에 자신이 설치한 지뢰와 같은 칸에는 곧바로 재설치할 수 없습니다.

> 참고: 렌주 금수(33/44) 판정 로직(`src/lib/game/gomoku.ts`)은 실전에서 흔히 쓰이는
> 패턴 매칭 방식의 간이 구현입니다. 대부분의 상황에서 정확하지만, 아주 드문 복합
> 패턴 엣지 케이스까지 100% 커버하진 않을 수 있어 실제 사용 전 테스트를 권장합니다.

## 로컬 개발 준비

### 1. 저장소 클론 & 패키지 설치
```bash
npm install
```

### 2. Supabase 프로젝트 생성
1. https://supabase.com 에서 새 프로젝트 생성
2. 프로젝트의 **SQL Editor** 에서 `supabase/schema.sql` 내용을 그대로 실행
3. **Project Settings > API** 에서 다음 값을 확인:
   - Project URL
   - `anon` `public` key
   - `service_role` key (⚠️ 절대 클라이언트에 노출 금지)
4. **Database > Replication** 에서 `rooms`, `chat_messages`, `players` 테이블의
   Realtime이 켜져 있는지 확인 (schema.sql이 이미 publication에 추가함)

### 3. 환경변수 설정
```bash
cp .env.example .env.local
```
`.env.local` 을 열어 위에서 확인한 값을 채워넣습니다.

### 4. 개발 서버 실행
```bash
npm run dev
```
http://localhost:3000 접속

## GitHub 저장소에 올리기
```bash
git init
git add .
git commit -m "chore: initial gomoku online scaffold"
git branch -M main
git remote add origin https://github.com/<your-username>/<repo-name>.git
git push -u origin main
```

## Vercel 배포
1. https://vercel.com 에서 "Add New Project" → 위 GitHub 저장소 선택
2. **Environment Variables** 에 `.env.local`과 동일한 3개 값 등록
   (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`)
3. Deploy 클릭 → 완료 후 발급된 URL을 친구와 공유하면 바로 플레이 가능

## 프로젝트 구조
```
src/
  app/
    page.tsx                 방 생성/참가 홈 화면
    room/[code]/page.tsx     방 입장 처리
    room/[code]/RoomClient.tsx  실제 게임 화면(보드/채팅/이모지)
    api/rooms/route.ts       방 생성 API
    api/rooms/[code]/join    방 참가 API
    api/rooms/[code]/move    착수 처리(금수/지뢰 판정 포함)
    api/rooms/[code]/mine    지뢰 설치 API
  lib/game/
    gomoku.ts                보드 로직, 승리/금수 판정
    mine.ts                  지뢰 유효기간 계산 등 순수 로직
    types.ts                 공용 타입
  lib/supabase/
    client.ts                브라우저용(anon key)
    server.ts                서버 전용(service role key, API route에서만 import)
  hooks/useRoomRealtime.ts   보드/채팅/이모지 실시간 구독
  components/                Board, Chat, EmojiBar
supabase/schema.sql          테이블, RLS 정책, Realtime 설정
```

## 알려진 제한사항 (다음 작업 후보)
- 인증이 없는 가벼운 `session_token` 기반 식별 방식이라, 같은 브라우저에서
  로컬스토리지를 지우면 재접속 시 새 플레이어로 인식됩니다. 필요하면 Supabase
  Auth(익명 로그인)로 교체하는 것을 권장합니다.
- 관전자(spectator) 기능 없음 (2인 전용)
- 재접속 시 타이머/오프라인 처리 없음
- 익스트림 모드는 스텁 상태
