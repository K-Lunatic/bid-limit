# Native play screen review

References: MapleStory M (https://apps.apple.com/kr/app/id1133463693), Zombie High School (https://apps.apple.com/kr/app/id898986747).

Use the reference games to compare character readability, environment depth, compact edge controls and speech bubbles. Keep BID's own artwork. Existing hall PNG is the art source; this pass changes its presentation and camera, not the source painting.

Capture with Godot's actual OpenGL renderer:

`Godot --path . --script res://tools/capture_play_ui.gd`

Outputs: `/private/tmp/bid-native-lobby.png`, `/private/tmp/bid-native-play.png`, `/private/tmp/bid-native-auction.png`.

Verified locally: room opens with one human; AI is added on host Start when enabled; four seats fit in the auction camera; all seated transitions into auction; default HUD collapses hints; chat composer opens on demand and sends speech bubbles; 25 seconds per human turn; no floating weapons, customization weapon selector or free-roam attack. Old physical attack RPC is inert for compatibility. Card attack/defense remains.

The background and actor now share a source-texel projection of 0.5 logical pixels (2 output pixels at 1280×720), room-light tint and corrected texture multiplication. Bot names are 보풀왕 (AI), 단추부인 (AI), 실밥도둑 (AI). Accessory positions follow measured button centers per frame; `tools/capture_accessory_frames.gd` captures 32 frame/accessory/direction combinations at `/private/tmp/bid-accessories-32.png`.

Open issues: hat/badge remain temporary code-drawn art; hair customization needs a genuinely separate base mask; arbitrary output sizes and moving-camera pixel projection need further checks. Native shutdown still logs resource-cleanup warnings. Four remote devices and audio need another real-network session; local smoke tests do not prove that scenario. Web export is deferred until final delivery.

## 2026-11-04 — 분실물 극장과 행동표

인형은 둥근 단추 눈·치아 없는 펠트 입·실머리로 교체했다. 팔과 다리는 없다. 기다리거나 걸을 때는 입을 다물고, 말풍선이 있을 때만 말하기 프레임을 사용하며 입찰 등 행동이 먼저 끝난다. 배경과 진행자는 수선실 극장과 천 장갑으로 통일했다.

머리는 v3 몸통과 별도 파츠로 구성한다. 세 머리 모양 × 네 장식 미리보기에서 잘림이 없고, 여덟 프레임의 머리 접합·모자 눈 가림·몸통 기준선 검사를 통과했다. GPU 색상 검사에서 머리 6650픽셀 변화, 몸통/얼굴 30223픽셀 불변을 확인했다. 실제 비교 이미지는 `assets/art-direction/cozy-v2/review/`에 보관한다.

행동표는 크림색 천과 박음질 틀, 고정된 실밥 코스트, 종류 글자, 한 줄 효과로 구성했다. 11종이 서로 다른 그림을 쓰며 그림의 팔도 제거했다. 그림은 내장 imagegen의 4×3 원본, UI 틀은 공통 코드 렌더러다. 손패·상점·덱·제출·머리 위에 같은 앞/뒷면 규칙을 쓴다. 회전된 손패 모서리도 논리 화면 320×180 안에 들어온다.

첫 경매 전 60초 준비, 이후 45초 준비, 모두 직접 착석하면 조기 시작. 첫 60초가 만료돼도 강제 착석하지 않는다. 단추상점은 70보풀 선결제 후 세 장 공개/한 장 선택 규칙을 유지한다.

검증: 카드/터치/숫자키/다중 제출/상점 결제/편성/준비/씬 재사용/정리/픽셀/대사 동작 검사, 자동 4인 30판 종료, 로컬 네 실제 WebRTC 프로세스의 구매·개인 정보·덱·채팅·착석·감정 판매·방장 연결 종료를 통과했다. 이는 인터넷 NAT·모바일 실기기·실제 음성 품질의 검증은 아니다. 웹 빌드는 생성하지 않았다. 배경 반복 패널 연결과 전 장면의 카메라 픽셀 비율은 후속 점검이 필요하다.
