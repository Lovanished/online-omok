# 오목 온라인 (Gomoku Online)

친구와 실시간으로 즐기는 온라인 오목. Next.js + Supabase + Vercel 기반.

## 기능
- 방 생성 / 초대 코드로 참가 (흑돌·백돌은 방 생성 시 **랜덤**으로 배정)
- 실시간 채팅, 실시간 이모지 반응
- 🏳️ 기권, 🤝 무승부 제안(양쪽 동의 시 성립), 🔁 재대국(양쪽 동의 시 새 판 시작 +
  흑백 다시 랜덤 배정)
- 게임 모드
  - **일반 모드**: 표준 오목 규칙 + 흑돌 금수(장목, 33, 44)
  - **지뢰 모드**: 일반 모드 + 상대에게 보이지 않는 지뢰
  - **익스트림 모드**: 아직 규칙 미정 (스텁)

## 턴 구조
- 일반/익스트림 모드: 착수 한 번 = 한 턴
- 지뢰 모드: **① 돌 착수 → ② 지뢰 설치 칸 선택** 두 단계가 모두 끝나야 턴이
  상대에게 넘어갑니다. (`rooms.phase` 컬럼: `move` / `place_mine`)
  - 착수한 자리가 상대의 활성 지뢰였다면 → 착수 무효화 + 지뢰 설치 단계 없이 즉시 턴 종료
  - 지뢰는 `mines` 테이블에만 저장되고 RLS 정책이 아예 없어 브라우저(anon key)로는
    절대 조회 불가 → 서버 API(service role key)만 접근 가능
  - 설치 턴 T 기준 상대 턴(T+1)까지 유효, T+2에 자동 소멸
  - 직전에 자신이 설치한 지뢰와 같은 칸에는 곧바로 재설치 불가

## 흑백 랜덤 배정 / 재대국 / 기권 / 무승부
- **랜덤 배정**: 방 생성 시 호스트의 색이 50:50으로 랜덤 결정되고, 참가자는 나머지 색을
  받습니다. 재대국이 성사될 때마다 다시 랜덤으로 재배정됩니다.
- 이를 위해 `players` 테이블은 "고정 신분"인 `seat`(host/guest)과 "이번 판의 색"인
  `color`(black/white)를 분리해서 저장합니다. 색이 바뀔 수 있으므로, 새 판이
  시작되면(최초 입장 포함) 클라이언트가 `/api/rooms/[code]/me`를 호출해 자신의
  현재 색을 서버에서 다시 확인합니다.
- **기권**: 클릭 즉시 상대 승리로 게임 종료.
- **무승부**: 한쪽이 제안 → 상대가 수락해야 성립. 제안자는 응답 전까지 취소 가능,
  상대는 거절 가능.
- **재대국**: 게임 종료 후 양쪽이 모두 "재대국 신청"을 눌러야 새 판이 시작됩니다.
  새 판은 보드/턴/지뢰를 전부 초기화하고 흑백을 다시 랜덤 배정합니다.

> 참고: 렌주 금수(33/44) 판정 로직(`src/lib/game/gomoku.ts`)은 실전에서 흔히 쓰이는
> 패턴 매칭 방식의 간이 구현입니다. 대부분의 상황에서 정확하지만, 아주 드문 복합
> 패턴 엣지 케이스까지 100% 커버하진 않을 수 있어 실제 사용 전 테스트를 권장합니다.

## 로컬 개발 준비 (또는 Codespaces에서 그대로)

### 1. 패키지 설치
```bash
npm install
```

### 2. Supabase 프로젝트 준비
- **새로 시작하는 경우**: SQL Editor에서 `supabase/schema.sql` 전체 실행
- **이전 버전을 이미 쓰고 있던 경우**: `supabase/migrations/` 안의 파일을
  번호 순서대로(002, 003) 실행 (이미 적용한 파일은 다시 실행해도 안전하게
  설계되어 있습니다)
- Project Settings > API 에서 URL / anon key / service role key 확인

### 3. 환경변수
```bash
cp .env.example .env.local
```
값 채워넣기.

### 4. 개발 서버
```bash
npm run dev
```

## GitHub / Vercel
이전과 동일합니다.
```bash
git add -A
git commit -m "feat: 재대국/랜덤 흑백/기권/무승부 추가"
git push
```
Vercel 프로젝트의 Environment Variables는 이미 등록되어 있다면 추가 작업 없이
다음 배포에 자동 반영됩니다.

## 프로젝트 구조 (요약)
```
src/app/api/rooms/route.ts              방 생성 (흑백 랜덤)
src/app/api/rooms/[code]/join           참가 (남은 색 자동 배정)
src/app/api/rooms/[code]/me             내 현재 색/좌석 조회
src/app/api/rooms/[code]/move           착수 (금수/지뢰 판정)
src/app/api/rooms/[code]/mine           지뢰 설치 (착수 다음 단계)
src/app/api/rooms/[code]/resign         기권
src/app/api/rooms/[code]/draw           무승부 제안/수락/거절/취소
src/app/api/rooms/[code]/rematch        재대국 요청/성사(흑백 재배정)
src/lib/game/                           보드 로직, 타입
src/lib/supabase/                       브라우저/서버 클라이언트
src/app/room/[code]/RoomClient.tsx      실제 게임 화면
supabase/schema.sql                     최신 전체 스키마
supabase/migrations/                    기존 DB에 증분 적용할 SQL
```

## 알려진 제한사항
- 가벼운 `session_token` 기반 식별이라 로컬스토리지를 지우면 새 플레이어로 인식됩니다.
- 관전자(spectator) 기능 없음 (2인 전용)
- 재접속 시 타이머/오프라인 처리 없음
- 익스트림 모드는 스텁 상태
