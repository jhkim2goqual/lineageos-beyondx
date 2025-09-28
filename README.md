# LineageOS Build Environment for Samsung Galaxy S10 5G (beyondx)

NixOS 환경에서 도커를 활용한 LineageOS 빌드 시스템

## 📱 디바이스 정보

- **모델**: Samsung Galaxy S10 5G
- **코드명**: beyondx
- **지원 버전**: SM-G977B, SM-G977N
- **LineageOS 버전**: 22.2 (Android 15)
- **커널**: 4.14 (Exynos 9820)

## 🎯 프로젝트 특징

- **재현성**: 도커 기반으로 일관된 빌드 환경 보장
- **NixOS 호환**: Ubuntu 의존성을 도커로 격리
- **자동화**: 5단계 스크립트로 전체 프로세스 자동화
- **검증 가능**: 공식 빌드와 비교 기능 포함
- **CI/CD 준비**: GitHub Actions/GitLab CI 통합 가능

## 📋 시스템 요구사항

### 최소 사양
- CPU: 4코어 이상
- RAM: 16GB (32GB 권장)
- 스토리지: 300GB 이상 여유 공간
- 네트워크: 안정적인 인터넷 (50GB+ 다운로드)

### 소프트웨어
- Docker & Docker Compose
- Git
- 기본 Linux 도구

## 🚀 빠른 시작

### 1. 프로젝트 클론
```bash
cd ~/repos/work/lineageos-beyondx
```

### 2. 도커 이미지 빌드
```bash
cd docker
docker-compose build
```

### 3. 컨테이너 시작
```bash
docker-compose run --rm lineageos-builder /bin/bash
```

### 4. 빌드 프로세스 실행
컨테이너 내부에서:
```bash
# 단계 1: 환경 초기화
./scripts/01-setup-env.sh

# 단계 2: 소스 코드 동기화 (1-3시간 소요)
./scripts/02-sync-sources.sh

# 단계 3: Proprietary blobs 준비
./scripts/03-extract-blobs.sh

# 단계 4: 빌드 실행 (2-4시간 소요)
./scripts/04-build-lineage.sh

# 단계 5: 빌드 검증
./scripts/05-verify-build.sh
```

## 📁 프로젝트 구조

```
lineageos-beyondx/
├── docker/
│   ├── Dockerfile              # Ubuntu 20.04 기반 빌드 환경
│   ├── docker-compose.yml      # 컨테이너 설정
│   └── entrypoint.sh          # 컨테이너 진입점
├── scripts/
│   ├── 01-setup-env.sh        # 환경 초기화
│   ├── 02-sync-sources.sh     # 소스 동기화
│   ├── 03-extract-blobs.sh    # Proprietary 파일 추출
│   ├── 04-build-lineage.sh    # 빌드 실행
│   └── 05-verify-build.sh     # 빌드 검증
├── config/
│   └── build-config.env       # 빌드 환경 변수
├── volumes/
│   ├── lineage-source/         # LineageOS 소스 (영구)
│   ├── ccache/                 # 빌드 캐시
│   ├── downloads/              # 다운로드 파일
│   └── output/                 # 빌드 결과물
└── README.md
```

## ⚙️ 환경 설정

### build-config.env 주요 설정
```bash
DEVICE_CODENAME=beyondx        # 디바이스 코드명
DEVICE_BRANCH=lineage-22.2     # LineageOS 브랜치
BUILD_JOBS=16                   # 병렬 빌드 작업 수
CCACHE_SIZE=50G                # 캐시 크기
```

### Docker 리소스 제한
`docker-compose.yml`에서 조정:
```yaml
resources:
  limits:
    cpus: '16'
    memory: 32G
```

## 🛠️ 빌드 옵션

### 클린 빌드
```bash
# 컨테이너 내부에서
make clean
./scripts/04-build-lineage.sh
```

### 증분 빌드
이전 빌드 결과를 유지하여 빌드 시간 단축:
```bash
./scripts/04-build-lineage.sh
# 클린 여부 묻는 프롬프트에 'N' 선택
```

### ccache 최적화
첫 빌드 후 재빌드 시 시간을 크게 단축:
```bash
# ccache 통계 확인
ccache -s

# ccache 크기 조정
ccache -M 75G
```

## 📦 빌드 결과물

빌드 완료 후 `volumes/output/` 디렉토리에 생성:

- `lineage-22.2-YYYYMMDD-UNOFFICIAL-beyondx.zip` - ROM 패키지
- `recovery.img` - 리커버리 이미지
- `boot.img` - 부트 이미지
- `dtbo.img` - Device Tree Blob Overlay
- `vbmeta.img` - Verified Boot 메타데이터
- `SHA256SUMS` - 체크섬 파일

## ✅ 빌드 검증

### 공식 빌드와 비교
```bash
./scripts/05-verify-build.sh
```

검증 항목:
- 필수 파일 존재 여부
- 파일 크기 비교
- ZIP 구조 비교
- 이미지 헤더 검증

### 수동 검증
```bash
# 체크섬 확인
cd volumes/output/[날짜-시간]/
sha256sum -c SHA256SUMS

# ZIP 내용 확인
unzip -l lineage-*.zip
```

## 🚨 문제 해결

### 디스크 공간 부족
```bash
# 불필요한 파일 정리
docker system prune -a
rm -rf volumes/lineage-source/out/
```

### 빌드 실패
```bash
# 로그 확인
tail -n 100 volumes/output/*/build.log

# ccache 초기화
ccache -C

# 재시도
./scripts/04-build-lineage.sh
```

### 메모리 부족
Docker Desktop 설정에서 메모리 할당 증가 또는:
```bash
# swap 추가 (호스트에서)
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 🔄 CI/CD 통합

### GitHub Actions 예시
`.github/workflows/build.yml`:
```yaml
name: Build LineageOS
on:
  schedule:
    - cron: '0 0 * * 0'  # 매주 일요일
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build Docker Image
        run: docker-compose build
      - name: Run Build
        run: docker-compose run lineageos-builder
```

## 📱 디바이스에 설치

### 전제 조건
- 부트로더 언락
- TWRP 또는 LineageOS Recovery 설치

### 설치 단계
1. Recovery 모드 진입: `Volume Up + Bixby + Power`
2. Wipe Data/Factory Reset
3. Install from SD/OTG
4. `lineage-*.zip` 선택
5. 재부팅

## 🤝 기여

이슈나 PR은 언제든 환영합니다!

## 📄 라이선스

이 프로젝트는 LineageOS 프로젝트의 라이선스를 따릅니다.

## 🔗 참고 자료

- [LineageOS Wiki - beyondx](https://wiki.lineageos.org/devices/beyondx/)
- [LineageOS 빌드 가이드](https://wiki.lineageos.org/devices/beyondx/build/)
- [공식 다운로드](https://download.lineageos.org/devices/beyondx)
- [GitHub - Device Tree](https://github.com/LineageOS/android_device_samsung_beyondx)
- [GitHub - Kernel](https://github.com/LineageOS/android_kernel_samsung_exynos9820)

## 📝 노트

- 이것은 **비공식(UNOFFICIAL)** 빌드입니다
- LineageOS 공식 서명 키로 서명되지 않습니다
- 실제 디바이스에 설치하기 전 백업을 권장합니다
- 경동 프로젝트 AOSP 빌드에도 동일한 구조 적용 가능

---
작성: 2025-09-28 | NixOS 환경에서 재현 가능한 Android 빌드 시스템 구축