# 양말 인형 파츠 폴더

이 폴더의 파츠는 모두 96×128 기준 캔버스와 고정 anchor를 사용한다.

첫 원본은 `parts/v1/manifest.json`과 `sock-puppet-parts-sheet-v1.png`다. v1의 개별 PNG에서 검은 배경을 제거한 픽셀 알파 결과가 `parts/v2/`에 있다. 현재 런타임은 얼굴·머리카락·입이 포함된 `body_only/frames/` 시트를 사용하므로 중복 오버레이하지 않는다.

권장 파일명:

- `mouth_*.png`
- `eyes_*.png`
- `hair_*.png`
- `accessory_*.png`
- No external hand part: the hand is only the hidden mechanism inside the mouth of a real sock puppet.

각 파츠는 `ART_SCALE_AND_PARTS.md`의 소켓과 z 순서를 따른다. 색상 변형은 같은 픽셀 실루엣을 복제하지 않고 마스크·셰이더 팔레트로 만든다. 캐릭터 본체는 `../body_only/frames/00.png`부터 `07.png`까지를 사용하며, 돋보기·팔·손을 포함하지 않는다. 기존 `frames/` 시트는 덮어쓰지 않은 fallback 참고본이다.
