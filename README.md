# BID! LIMIT · Godot 4 Web MVP

횡스크롤 2D 경매장 게임이다. 픽셀 PNG 양말 인형, 경매장·감정소·암시장, 신성한 손 경매사, AI, 덱 편집, 카드 코스트, 재화, 카드 공격·방어와 4인 WebRTC P2P를 한 실행 경로에 묶었다. 그래픽과 배포 검수는 계속 진행 중이다.

프로젝트 소개와 팀 소식은 [roomcon.team](https://roomcon.team)에서 확인할 수 있다. 실행 가능한 웹 빌드는 [BID! LIMIT](https://bid-limit.vercel.app/)에서 제공한다.

## 실행

Godot 4에서 `project.godot`를 열고 실행한다. 방을 생성하면 본인만 대기실에 들어간다. 방장은 시작 시 빈자리를 AI로 채울지 선택한다. 오프라인 연습도 같은 대기실 흐름을 쓴다.

조작:

- 데스크톱: `A/D` 또는 방향키 이동, 스페이스 점프, 숫자키 1~5로 카드 선택, Enter로 한 장 제출(선택이 없으면 말하기). 차례 넘김 전까지 카드를 계속 낼 수 있다.
- 모바일: 바닥 터치로 이동, 빈 좌석 터치로 착석, 말하기 버튼으로 채팅 입력, 카드를 중앙으로 끌어 제출한다.
- 데스크톱: 경매 시작 전 월드의 1~4번 빈 좌석을 직접 클릭해 착석한다. 네 명이 모두 앉아야 경매가 시작된다.
- 암시장: 대출·상환·룰렛과 카드 구매를 이용할 수 있다. 담보 실밥은 이자를 갚아야 되돌아온다.
- 한 판의 목표: 5라운드 뒤 보유 보풀 + 감정품 가치 - 남은 빚이 가장 높은 플레이어가 승리한다.
- 채팅은 캐릭터 말풍선과 함께 브라우저 TTS로 높은 피치 재생된다. 웹에서는 `MIC` 버튼을 눌러 고음역 필터가 적용된 음성 채널에 참여한다.
- `음성` 패널에서 내 마이크 감도(자동 보정 기반)를 직접 조절하고, 참가자별 음소거·볼륨을 따로 조절할 수 있다.
- 오른쪽 아래 `덱`: 현재 판의 보유 카드로 8~15장 구성, 입찰 1장 필수. 빼 둔 카드는 보관함에 남는다. 대기·감정 때 편집하고 다음 경매 시작 시 섞는다. 경매 중에는 조회만 가능하다.

## 멀티플레이

게임 상태는 호스트 권한 WebRTC full-mesh로 전달한다. 신호 서버는 공개방 목록, 비밀번호 검증, SDP/ICE 교환만 담당하며 위치·경매·카드·전투·재화를 저장하지 않는다.

세부 실행 분리는 [ARCHITECTURE.md](ARCHITECTURE.md)를 따른다. Vercel은 Web 프론트엔드와 시그널링 요청만 처리하고, 경매·AI·전투 계산은 클라이언트에서 수행한다.

현재 게임 수치와 라운드별 규칙은 [GAME_SETTINGS.md](GAME_SETTINGS.md)에 정리되어 있다.
월드 크기, 캐릭터 표시 배율, 파츠 소켓 규칙은 [ART_SCALE_AND_PARTS.md](ART_SCALE_AND_PARTS.md)에 정리되어 있다.

```sh
node signaling/server.mjs
```

웹 배포와 TURN 설정은 [DEPLOYMENT.md](DEPLOYMENT.md)를 따른다. 포트포워딩이나 동일 Wi-Fi는 필요하지 않지만, 직접 연결이 막힌 NAT에서는 TURN relay가 필요하다.

## 검증

```sh
node ../work/check-godot-project.cjs
godot --headless --path . --script res://tests/auction_smoke.gd
godot --headless --path . --script res://tests/combat_smoke.gd
godot --headless --path . --script res://tests/network_2d_smoke.gd
node signaling/smoke.mjs
node tests/multiplayer_e2e.mjs
```

Web export는 Godot의 `Web` preset으로 생성한다. 배포물은 HTTPS에서 서비스해야 WebRTC가 동작한다.

`multiplayer_e2e.mjs`는 실제 신호 서버와 독립 Godot 프로세스 4개를 실행한다. 닉네임, 서로 3개 WebRTC 연결, 채팅 왕복, 개인 덱 편집, 전원 착석 후 경매 진입과 개인 손패를 검사한다. `GODOT_BIN`으로 실행 파일 위치를 지정한다. 포함한 네이티브 확장은 macOS 개발용이며 웹은 브라우저 WebRTC를 사용한다. 최종 웹 export는 모든 작업 뒤 진행한다.

## Godot 편집기에서 씬 편집

- `scenes/main_2d.tscn`: 메인 진입점. `World` 인스턴스가 포함되어 실행 전에도 맵이 보인다. F5로 전체 게임을 실행한다.
- `scenes/auction_world.tscn`: 월드 편집용 씬. 배경/좌석 표시/장식 레이어, 감정사, 암시장 상인, 경매사, CRT, 경매품, 카메라가 실제 노드다.
- `scenes/sock_puppet.tscn`: 공용 인형 씬. Body의 SpriteFrames 애니메이션과 Parts를 편집할 수 있으며, 플레이어도 이 씬을 인스턴스화한다.
- 월드가 화면 밖에 있으면 2D 모드에서 World 또는 원하는 노드를 선택하고 F로 화면을 맞춘다. 경매 무대 중심은 x=1450 부근이다.
- Seats/Seat1~Seat4 마커를 이동하면 좌석 클릭 판정과 실제 착석 위치도 그 좌표를 사용한다.
- NPC의 Sock Color, Hair Color, Chosen Accessory 값을 바꾸면 편집기 미리보기와 실행에 반영된다. 편집기에서는 네트워크·경매 로직을 실행하지 않는다.
- 타이틀의 배경·그림·닉네임·메뉴 버튼은 `scenes/title_ui.tscn`에 저장되어 편집기에서 수정한다. 방 목록·생성·커스터마이징의 하위 화면과 카드 UI는 아직 코드에서 구성된다.
- tools/build_editor_scenes.gd는 최초 이관용이며 기존 씬을 덮어쓰지 않는다. 이후 수정은 Godot 씬에서 한다.

타이틀 UI는 main_2d의 TitleUI 인스턴스다. 별도로 title_ui.tscn을 열면 Panel/TitleArt와 Panel/TitleMenu의 배치를 편집할 수 있다. 실행 시 해당 메뉴 노드를 재사용하며, 화면 전환 후에도 신호를 중복 연결하지 않는다.
