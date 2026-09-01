/*
 * ============================================================================
 * 文件名：entrybackupability/EntryBackupAbility.ets
 * ============================================================================
 * 【用途】备份恢复能力（系统模板保留）：声明应用数据的备份/恢复行为。
 * 【前置条件 / 假设】
 *   - 模板默认实现；本轮无数据持久化，实际不产生备份文件。
 * 【输入 / 输出（后置条件）】
 *   - 输入：系统备份恢复回调；
 *   - 输出：模板默认上下文（空实现）。
 * 【关键类 / 算法】
 *   - 无。
 * 【参考源】
 *   - DevEco 工程模板
 * ============================================================================
 */
/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, 'testTag', 'onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'testTag', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}