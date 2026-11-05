# BID! LIMIT Web 배포

## 연결 구조

- 게임 상태: 최대 4명 WebRTC full-mesh P2P
- 방 생성·비밀번호·SDP/ICE 교환: `signaling/server.mjs`
- 직접 연결: STUN
- 직접 연결이 막힌 NAT/방화벽: TURN relay
- 게임 서버가 플레이 상태를 중계하지 않으므로 포트포워딩이나 같은 Wi-Fi가 필요하지 않다.

## 운영 설정

1. Godot Web export를 HTTPS로 서비스한다. WebRTC는 안전한 브라우저 컨텍스트가 필요하다.
2. `signaling/server.mjs`를 공개 HTTPS origin에 연결한다. 기본 설정이 빈 문자열이면 브라우저의 현재 origin을 사용한다.
3. `project.godot`의 `bid_network/turn_url`, `turn_username`, `turn_credential`에 TURN 자격 정보를 넣는다. `turns:` TLS endpoint를 권장한다.
4. 신호 서버와 정적 Web 파일을 서로 다른 origin에 둘 경우 `bid_network/signaling_url`을 HTTPS 주소로 지정한다.
5. 프로필 이동 코드의 서버 재시작 후 복호화를 위해 `BID_PROFILE_SECRET` 환경 변수를 고정된 강한 비밀값으로 설정한다.

## 로컬 확인

```sh
node signaling/server.mjs
Godot --path . --editor
```

Web export 후 별도 터미널에서 `python3 tools/serve_web.py`를 실행하고 `http://127.0.0.1:8080`을 연다. 이 서버는 Godot 스레드 실행에 필요한 교차 출처 격리 헤더를 제공하며 `/rooms`, `/auth`, `/profiles` 요청을 로컬 8787번 신호 서버로 전달한다. 신호 서버를 실행하지 않으면 AI 솔로만 사용할 수 있다. 일반 정적 서버에 헤더가 없으면 시작 화면에서 멈출 수 있다.

신호 서버 회귀 테스트는 `node signaling/smoke.mjs`, 2D WebRTC 초기화는 `tests/network_2d_smoke.gd`로 확인한다.

## Vercel 정적 배포

Godot에서 `Web` preset을 `build/web/index.html`로 export한 뒤 `godot-bid` 폴더를 Vercel 프로젝트의 Root Directory로 지정한다. 정적 파일은 `build/web`에서 제공하고, 프로젝트 루트의 `api/[...path].js`가 `build/web/api/[...path].js`를 Vercel Function으로 연결한다. 방 목록·입장·SDP/ICE·계정·프로필 코드를 사용하려면 Vercel에 Redis 환경변수(`KV_REST_API_URL`, `KV_REST_API_TOKEN`)와 `BID_PROFILE_SECRET`을 설정한다. Vercel 환경에서는 별도의 상시 실행 신호 서버가 필요하지 않다. 교차 출처 격리 헤더는 `vercel.json`에 포함되어 있다. 다른 서버를 사용할 때도 `Cross-Origin-Opener-Policy: same-origin`과 `Cross-Origin-Embedder-Policy: require-corp`를 설정해야 한다.

## 제한

4명 full-mesh에서는 각 클라이언트가 다른 3명과 연결한다. 인원이 늘어날수록 서버가 자동으로 더 안정해지는 구조가 아니므로, 5명 이상은 SFU/authoritative relay로 전환해야 한다.
