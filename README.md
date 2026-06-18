# MedExplain Frontend

## 1. Project Description

MedExplain은 환자와 보호자의 의료 이해도 향상을 위한 진료 대화 자동 요약 및 의학 용어 설명 앱입니다.

진료 중 의사와 환자의 대화를 녹음하면, 앱은 음성을 텍스트로 변환하고, 의료 용어와 수치 표현을 교정한 뒤, 환자가 이해하기 쉬운 요약 리포트를 제공합니다. 또한 어려운 의학 용어를 쉬운 말로 설명하고, 사용자가 진료 내용에 대해 추가 질문을 할 수 있도록 Q&A 기능을 제공합니다.

본 저장소는 MedExplain의 Flutter 기반 Frontend source code를 포함합니다.

---

## 2. Source Code Description

Frontend는 사용자가 직접 사용하는 모바일 앱 화면과 서버 통신 기능을 담당합니다.

주요 기능은 다음과 같습니다.

* 회원가입 및 로그인 화면
* 진료 음성 녹음
* WebSocket 기반 오디오 데이터 전송
* STT 중간 결과 및 최종 결과 표시
* AI 요약 결과 표시
* 의료 용어 설명 결과 표시
* 진료 기록 저장 및 조회
* 진료 내용 기반 Q&A
* 다음 진료 때 물어볼 질문 메모 관리

주요 모듈은 다음과 같습니다.

| Module              | Description                                |
| ------------------- | ------------------------------------------ |
| RecordingController | 녹음 시작, 종료, 오디오 청크 누적 및 서버 전송을 담당           |
| WsTransport         | WebSocket 연결, 세션 시작, 오디오 전송, 서버 이벤트 수신을 담당 |
| TranscriptStore     | STT 중간 결과와 최종 결과를 관리하고 UI에 반영              |
| ApiService          | Backend REST API 요청 및 응답 처리를 담당            |
| AppConfig           | 서버 IP 설정 및 저장을 담당                          |
| ResultScreen        | AI 요약 결과와 의료 용어 설명 결과를 표시                  |
| QuestionTab         | 진료 내용 기반 Q&A 기능을 제공                        |

---

## 3. Tech Stack

* Flutter
* Dart
* record
* web_socket_channel
* http
* shared_preferences

---

## 4. How to Install

Flutter 개발 환경이 설치되어 있어야 합니다.

```bash
flutter --version
```

필요한 패키지를 설치합니다.

```bash
flutter pub get
```

---

## 5. How to Build

Android APK 빌드:

```bash
flutter build apk
```

iOS 빌드:

```bash
flutter build ios
```

단, iOS 빌드는 macOS 및 Xcode 환경이 필요합니다.

---

## 6. How to Run

개발 환경에서 앱을 실행합니다.

```bash
flutter run
```

실행 전 Backend 서버가 먼저 실행되어 있어야 하며, 앱 내부 설정에서 Backend 서버 주소를 올바르게 입력해야 합니다.

---

## 7. How to Test

기본 실행 테스트는 다음 순서로 진행합니다.

1. Backend 서버 실행 여부 확인
2. Flutter 앱 실행
3. 회원가입 또는 로그인 진행
4. 녹음 버튼 선택
5. 음성 입력 후 녹음 종료
6. STT 결과가 화면에 표시되는지 확인
7. AI 분석 결과 보기 선택
8. 요약 결과와 의료 용어 설명이 표시되는지 확인
9. Q&A 탭에서 질문 입력 후 응답 확인
10. 진료과와 날짜 선택 후 기록 저장 확인

Flutter 정적 분석은 다음 명령어로 수행할 수 있습니다.

```bash
flutter analyze
```

테스트 코드가 포함된 경우 다음 명령어를 사용할 수 있습니다.

```bash
flutter test
```

---

## 8. Sample Data

Frontend 자체에는 별도의 대규모 데이터셋이 포함되어 있지 않습니다.

테스트 시에는 사용자가 직접 녹음한 음성 또는 Backend에서 제공하는 sample/proto data를 사용합니다. 진료 예시 문장은 다음과 같습니다.

```text
CRP 수치가 조금 올라서 염증 상태를 더 지켜봐야 합니다.
내일 CBC 검사를 다시 진행하고, 약은 5mg으로 조절하겠습니다.
```

---

## 9. Open Source / External Libraries

본 Frontend는 다음 오픈소스 패키지를 사용합니다.

| Library            | Purpose          |
| ------------------ | ---------------- |
| record             | 모바일 기기 음성 녹음     |
| web_socket_channel | WebSocket 통신     |
| http               | REST API 통신      |
| shared_preferences | 서버 IP 등 로컬 설정 저장 |

---

## 10. Notes

MedExplain은 환자와 보호자가 진료 내용을 쉽게 이해하도록 돕는 보조 도구입니다.

AI가 제공하는 요약과 답변은 참고용이며, 약물 변경, 수술 여부, 치료 결정 등 중요한 의료 판단은 반드시 담당 의료진과 상의해야 합니다.
