#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVECO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app}"
SDK_ROOT="${DEVECO_SDK_HOME:-${DEVECO_HOME}/Contents/sdk}"
JAVA_ROOT="${JAVA_HOME:-${DEVECO_HOME}/Contents/jbr/Contents/Home}"
HVIGORW="${HVIGORW_PATH:-${DEVECO_HOME}/Contents/tools/hvigor/bin/hvigorw}"
HDC="${HDC_PATH:-${SDK_ROOT}/default/openharmony/toolchains/hdc}"
HAP_PATH="${PROJECT_ROOT}/entry/build/default/outputs/default/entry-default-signed.hap"
PACKAGE_NAME="com.example.momo"
ABILITY_NAME="EntryAbility"

fail() {
  printf '\n[失败] %s\n' "$1" >&2
  exit 1
}

[ -x "${JAVA_ROOT}/bin/java" ] || fail "找不到 DevEco Java：${JAVA_ROOT}/bin/java"
[ -x "${HVIGORW}" ] || fail "找不到 hvigorw：${HVIGORW}"
[ -x "${HDC}" ] || fail "找不到 hdc：${HDC}"

export JAVA_HOME="${JAVA_ROOT}"
export DEVECO_SDK_HOME="${SDK_ROOT}"
export PATH="${JAVA_ROOT}/bin:${PATH}"

printf '[1/4] 构建 HAP...\n'
cd "${PROJECT_ROOT}"
"${HVIGORW}" assembleHap --no-daemon

[ -f "${HAP_PATH}" ] || fail "构建完成但没有找到 HAP：${HAP_PATH}"

TARGETS="$(${HDC} list targets 2>&1 || true)"
if ! printf '%s\n' "${TARGETS}" | awk 'NF && $0 !~ /^\[Empty\]$/ { found = 1 } END { exit(found ? 0 : 1) }'; then
  printf '\n[2/4] 没有检测到模拟器。请先在 DevEco Studio -> Device Manager 启动 HarmonyOS 模拟器。\n'
  printf 'hdc 输出：%s\n' "${TARGETS}"
  exit 2
fi

printf '[2/4] 已连接目标：\n%s\n' "${TARGETS}"
printf '[3/4] 安装 HAP...\n'
"${HDC}" install -r "${HAP_PATH}"

printf '[4/4] 重启应用...\n'
"${HDC}" shell aa force-stop "${PACKAGE_NAME}" >/dev/null 2>&1 || true
"${HDC}" shell aa start -a "${ABILITY_NAME}" -b "${PACKAGE_NAME}"

printf '\n完成：已构建、安装并启动 %s\n' "${PACKAGE_NAME}"
