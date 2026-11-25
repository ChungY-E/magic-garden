# 🌿 마법의 정원 (Magic Garden)

초등 3학년 2학기 사회 학습지 두 편을 기반으로 만든 1~3분 실시간 성장형 퀴즈 게임의 첫 구현본입니다. 교사 1명과 학생 최대 30명을 목표로 합니다.

## 1. 시작 전 준비

- Supabase 계정: https://supabase.com/dashboard
- GitHub 계정: https://github.com
- Vercel 계정: https://vercel.com
- PC에서 ZIP을 압축 해제합니다. `public`, `supabase`, `vercel.json`이 같은 프로젝트 폴더 안에 있어야 합니다.
- 정답이 포함된 SQL이 있는 **GitHub 저장소는 Private(비공개)** 으로 만드세요. 학생들에게 공유하는 것은 Vercel 웹 주소뿐입니다. 체험용 HTML 역시 정답이 포함되어 있어 실제 경쟁 수업에서 공유하지 마세요.

## 2. Supabase 연결 (먼저 진행)

1. Supabase 대시보드에서 New project를 선택합니다. 프로젝트 이름을 `magic-garden`으로 정하고 데이터베이스 비밀번호는 별도로 안전하게 보관합니다.
2. 새 프로젝트 준비가 끝나면 SQL Editor에서 New query를 열고 `supabase/schema.sql` 전체를 복사해 실행합니다. 새 프로젝트에서 한 번만 실행해야 합니다. 기존 데이터가 있는 프로젝트에 덮어쓰지 마세요.
3. 별도 SQL Editor 탭에서 `supabase/seed.sql` 전체를 복사해 실행합니다. 이 파일에 두 단원 60문제, 보기, 정답, 해설과 그림 경로가 있습니다. 문제는 선택지 배열의 첫 번째 값이 정답이며, 서버가 학생별로 보기를 섞습니다.
4. SQL Editor에서 다음 쿼리로 초기 데이터를 확인합니다.
   ```sql
   select topic, count(*) from public.questions group by topic order by topic;
   select count(*) from public.questions;
   ```
   전체 60문제, 주제별 4, 6, 6, 8, 6, 4, 4, 6, 4, 10, 2문제여야 합니다.
5. Project URL과 Publishable key(또는 legacy anon key)를 프로젝트 Connect/API Keys 설정에서 찾습니다. 메뉴 명칭은 대시보드 버전에 따라 다를 수 있습니다.
6. 메모장이나 VS Code로 `public/config.js`를 열어 다음처럼 자신의 값으로 저장합니다.
   ```js
   window.MG_CONFIG = {
     url: "https://YOUR_PROJECT_REF.supabase.co",
     key: "YOUR_PUBLISHABLE_OR_ANON_KEY"
   };
   ```
   `service_role`, `sb_secret_` 키나 DB 비밀번호는 절대로 이 파일이나 GitHub에 올리지 마세요. Publishable/anon 키는 브라우저에서 사용하도록 설계된 공개 키입니다.

## 3. GitHub에 업로드

1. GitHub에서 New repository를 선택합니다.
2. 이름을 `magic-garden`으로 지정하고 **Private**을 선택합니다.
3. 빈 저장소를 만든 다음 Add file → Upload files를 이용하거나 Git 명령으로 압축을 푼 프로젝트 내부 파일을 업로드합니다. 폴더 구조를 유지합니다.
4. `public/config.js`가 자신의 Supabase 연결 정보로 설정되어 있는지 확인하고 Commit changes를 누릅니다.

Git을 사용할 수 있다면 프로젝트 폴더에서 다음과 같이 진행할 수도 있습니다. 저장소 URL을 자신의 것으로 바꾸세요.
```bash
git init
git add .
git commit -m "Initial Magic Garden game"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/magic-garden.git
git push -u origin main
```

## 4. Vercel 배포

1. Vercel에서 Add New → Project를 선택합니다.
2. GitHub 계정을 연결하고 `magic-garden` 저장소를 Import합니다. 비공개 저장소를 선택할 수 있도록 GitHub 앱 접근 권한을 허용해야 할 수 있습니다.
3. Framework Preset은 Other, Root Directory는 프로젝트 루트, Output Directory는 `public`으로 설정합니다. 별도의 빌드 명령 또는 설치 명령은 필요하지 않습니다. 저장소의 `vercel.json`이 기본 설정을 제공합니다.
4. Deploy를 누릅니다.
5. 배포가 끝나면 생성된 HTTPS 주소로 접속합니다. 예: `https://your-project.vercel.app/`. 이것은 예시이며 실제 주소는 Vercel에서 확인하세요.
6. 선생님 시작하기 → 문제 선택 → 게임방 만들기. QR을 학생 휴대폰에서 열고 별명과 식물을 고릅니다.
7. 학생이 들어오면 게임을 시작합니다. 수업 후에는 반드시 학생 기록 지우기를 실행합니다.

**확인:** 배포 주소에서 `/supabase/seed.sql`, `/supabase/schema.sql`, `/build_data.py`가 404로 접근 불가능해야 합니다. 반드시 `public`만 공개 출력 디렉터리로 설정하세요.

## 5. 로컬 실행

Python이 설치되어 있으면 프로젝트 폴더에서 `python -m http.server 8000 --directory public`을 실행하고 브라우저에서 `http://localhost:8000`으로 접속할 수 있습니다. 실시간 버전은 로컬 실행 시에도 Supabase 설정이 필요합니다. 다른 기기에서 테스트하려면 Vercel 배포 주소를 이용하는 것이 편합니다.

서버 없는 3분 개인 체험판은 별도 배포한 `magic-garden-demo.html`을 Chrome 또는 Edge에서 직접 열면 됩니다. 파일 열기가 제한되는 환경에서는 로컬 HTTP 서버를 이용하세요. 개인 체험판은 실제 게임방과 연결되지 않습니다.

## 6. 게임 내용

- 1단원 「사회 변화로 달라진 생활 모습」 30문제: 사회 변화, 저출산, 고령화, 지능정보화, 세계화
- 2단원 「옛날과 오늘날의 풍습」 30문제: 풍습, 두레와 품앗이, 일생 동안의 풍습, 결혼, 명절과 세시 풍속
- 5개 유형: 개념 맞히기, 그림 보고 맞히기, OX, 상황 판단하기, 설명 보고 그림 고르기
- 8종 식물, 5단계 성장 (0, 5, 10, 20, 30 에너지)
- 정답 1 에너지, 황금 햇살 20초 동안 정답 2 에너지
- 순위별 정답 보너스 확률 10% / 20% / 30% (1명은 20%), 보너스 1~3 에너지
- 자동 블라인드 마지막 30초, 수동 블라인드, 결과/기록 삭제

## 7. 파일 구성

```
magic-garden/
  public/                 # Vercel에서 공개하는 폴더
    index.html            # 메인
    teacher.html          # 교사 화면
    student.html          # 학생 화면
    config.js             # 자신의 공개 연결 키 설정
    common.js             # 공통 API, UI, 식물 SVG
    teacher.js            # 방 설정/대기/진행/결과
    student.js            # 입장/채점/성장/결과
    style.css             # 공통 UI
    images/               # 문제용 자체 제작 SVG 24종
  supabase/
    schema.sql            # DB 표, RLS, RPC, 실시간 신호
    seed.sql              # 60개 문제 및 비공개 정답
    asset-map.json        # 그림과 난수 파일명 대응, 비공개
  build_data.py           # 문제 원본 및 seed 재생성 도구
  build_images.py         # 그림 재생성 도구
  vercel.json             # 정적 사이트 배포 설정
  README.md               # 이 문서
  TESTING.md              # 구현 검증 및 제한 사항
```

## 8. 기술 설계와 학습 포인트

- GitHub: 코드를 버전 관리합니다. Vercel: `public/`을 인터넷에 배포합니다. Supabase: 교사·학생 방과 게임 상태, 채점, 에너지, 토큰, 종료 시각을 관리합니다.
- DB 함수는 `magic_game(action,args)` 단일 RPC 진입점에서 처리합니다. PRD의 개별 함수 이름은 action 값으로 구현하였고 상태 조회는 `state`로 통합했습니다.
- 교사·학생 토큰은 추측하기 어려운 UUID 난수 2개를 합쳐 발급하며 서버는 SHA-256 해시를 저장합니다. 공개 웹에 정답 데이터는 포함하지 않았습니다. 보기의 순서와 현재 출제 건은 서버에 저장합니다.
- 방 행 잠금으로 방 내 동시 답안 처리의 순서를 정하며, 출제 건 UUID의 중복 제출을 방지합니다. 오답 1초 및 정답 0.2초의 잠금을 적용합니다.
- 실시간 신호는 `room_signals`(교사 점수 변경)와 `room_status_signals`(학생 게임 상태 변경)로 나눴습니다. 둘 다 점수·별명·정답을 담지 않고 UUID와 변경 카운터만 공개합니다. 실제 데이터 조회는 해당 방 토큰을 검증합니다. 완전히 비공개인 Realtime 채널을 구현한 것은 아닙니다.
- Realtime 라이브러리를 불러올 수 없거나 연결 실패 시 주기적인 REST 조회로 대체합니다. QR 라이브러리 로딩 실패 시 링크와 방 번호로 입장할 수 있습니다.
- 단원과 주제는 정적 화면 메타데이터로, 식물 외형과 성장 단계 SVG는 JS에서 그립니다. 핵심 점수·성장 계산은 SQL에서 수행합니다.
- 24시간 지난 방은 새 방 생성 시 정리합니다(정기 작업은 설정되지 않음). 수업 후 기록 삭제를 반드시 수행하고, 필요하면 관리자 SQL Editor에서 `delete from public.rooms where created_at < now()-interval '24 hours';`를 실행할 수 있습니다. 실제 백업/서비스 로그의 보존 정책은 별도로 확인해야 합니다.

## 9. 참고 및 검증 범위

문제는 제공된 i-Scream 알짜 정리 학습지 사회 3-2 1단원 (1) 교과서 6~33쪽, 2단원 (1) 교과서 66~93쪽의 핵심 개념을 기반으로 새로 작성했습니다. 그림은 학습지에서 복사하지 않고 단순 SVG로 제작했습니다. 수업 전에 그림 식별 가능성, 정답 및 해설, 문제 난이도를 교사가 검토해 주세요. 동지의 음력 날짜는 문제로 사용하지 않았습니다.

이 프로젝트는 초기 구현본입니다. 브라우저 화면과 개인 체험 일부를 테스트했지만 실제 Supabase DB에서 SQL 실행, 30명 동시 접속, Realtime, 보안 침투, Vercel 배포는 검증하지 않았습니다. `TESTING.md`의 확인 절차를 마친 뒤 수업에 사용하세요.
