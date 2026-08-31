# 星图 · Astra

给成年人使用、完全本地保存的亲密关系记录工具。用代号管理对象，记下每次亲密见面、相处边界、防护状态和只属于自己的备忘；不定义关系，也不替用户做判断。iOS 原生 App，SwiftUI + MapKit，iOS 26 液态玻璃风格，Core Haptics 原生触感。

> 想换名字？只改一处：`project.yml` 里的 `CFBundleDisplayName`（工程名、bundle id 也随之改掉即可），图标在 `Scripts/generate_icon.py`。

## 功能

- **私密概览**：首屏直接显示当前对象、本月亲密次数、防护填写进度和最近记录，并提供「记录一次 / 添加对象」两个主入口
- **对象档案**：代号、相处状态（新认识 → 在聊天 → 暧昧升温 → 偶尔 / 固定见面 → 暂停 / 结束）、默契度、相处期待、边界与禁区、安全备忘、标签和可选背景信息
- **暧昧聊天**：单独记录进展、她明确接受的内容形式、聊过的期待 / 尺度 / 边界 / 防护 / 避孕责任 / 见面安排、线上隐私约定，以及转账要求、可疑链接或传播威胁等可观察的账号安全事实
- **亲密记录**：基础信息 30 秒内即可保存；需要时再补实际行为、边界回看、本人当时状态、屏障与其他健康措施、身体 / 情绪感受、是否再见和私密备注
- **事后跟进**：用户主动添加消息确认、检测、暴露咨询、妊娠相关或身体状况任务，可设日期并标记完成；记录页集中筛选，首页只展示尚未完成的事项
- **安全小结**：区分安全套 / 屏障、PrEP、避孕和润滑等不同事实；不合成「安全分」，不按对象身份推断风险，也不把未填写当作默认好评
- **联系节奏**：每个对象可设 7/14/30/60 天周期，到期只温和提示；暂停和结束的对象不会触发提醒
- **城市足迹**：地图降为辅助视图，只标记到城市级；内置全国地级市、省直辖县级市、部分百强县和港澳台主要城市（380+），并处理 WGS-84 → GCJ-02 偏移
- **对象与回顾**：按相处状态 / 城市分组，支持代号、标签、城市搜索，以及近 6 个月亲密频率与平均体验统计
- **液态玻璃**：iOS 26 真 Liquid Glass（glassEffect / GlassEffectContainer / .glass 按钮），iOS 18 自动降级为 Material + 高光描边
- **原生触感**：记录、切换状态、城市聚焦、升降面板和拨动开关各有定制 Core Haptics 波形，强度可调
- **数据**：对象与记录纯本地，不上传、不统计、不同步；支持 JSON 备份导出 / 合并导入 / 一键清空

## 隐私（刻意为之）

| 项 | 设计 |
| --- | --- |
| 网络 | 无账号、统计 SDK 或云同步；MapKit 仅显示底图，档案不上传 |
| 权限 | 不申请任何系统权限；唯一可选的是 Face ID / 触控 ID 解锁 |
| 位置 | 只到**市**级粒度，无精确坐标，无定位 |
| 防窥 | 可选 App 锁 + 后台毛玻璃遮罩 + 代号默认打码 |
| 备份 | 明文 JSON，导出到你选的位置，自己保管 |

## 使用边界

星图只面向成年人之间自愿、知情且可随时撤回的相处。App 中的边界和安全字段用于记录已经明确沟通的信息，不代表一次记录可以替代下一次确认，也不替代专业健康建议。

记录结构优先适配成年男性记录女性对象，同时行为字段仍不依赖性取向或身体结构。所有健康提示基于实际行为与用户主动选择，避免「高风险对象」「战绩」「表现排行」和靠回复速度计算“成功率”等会误导或物化的设计。

## 本地开发

```bash
brew install xcodegen        # 一次性
make gen                     # 生成图标 + 工程
open Astra.xcodeproj         # Xcode 里选模拟器运行
make test                    # 命令行跑单测
```

## CI：GitHub Actions 打 IPA

推送到 `main` 即自动：装 xcodegen → 生成工程 → 模拟器跑单测 → 免签名 Archive → 打包 `Astra-unsigned.ipa` → 上传 Actions 产物（保留 14 天）。

```bash
git push origin main
# 网页端 Actions → 最新一次运行 → Artifacts → Astra-ipa 下载
```

- 手动跑：Actions → **iOS** → Run workflow，可选 `signed = on`、`publish_release = true`
- **免签名 IPA 装不了普通 iPhone**。上真机有两条路：
  1. 自己用 Xcode 打开工程，用免费的 Apple ID 签名（7 天有效）；
  2. 付费开发者账号（$99/年），配置仓库 Secrets 让 CI 出正式签名 IPA：

| Secret | 内容 |
| --- | --- |
| `P12_BASE64` | 分发证书 .p12 的 base64 |
| `P12_PASSWORD` | p12 密码 |
| `PROVISION_BASE64` | 描述文件 .mobileprovision 的 base64 |
| `PROVISION_UUID` | 描述文件 UUID |
| `DEVELOPMENT_TEAM` | Team ID |
| `SIGNING_IDENTITY` | 证书名，如 `Apple Distribution: xxx` |
| `BUNDLE_ID` | 与描述文件一致的 bundle id（默认 `com.lluviose.astra`） |

## 工程结构

```
project.yml                        # XcodeGen 工程定义（真源）
App/Sources
  App/        AstraApp · RootView · AppState · AppLock
  Domain/     Models · City · ChinaRegion · CoordinateTransform · RosterFilter
  Data/       LocalStore · CityCatalog · BackupService
  Design/     LiquidGlass · Haptics · Palette · Components
  Support/    Formatters
  Features/   Home · Map · Roster · Companion · Timeline · Settings · City
App/Resources  cities.json · Assets.xcassets
Scripts/       generate_icon.py（纯标准库，无依赖）
Tests/AstraTests
.github/workflows/ios.yml
```

## 关于坐标系

公开数据集的坐标是 WGS-84，而中国大陆地图服务（含中国区 Apple Maps）渲染用 GCJ-02，直接标点会偏 300~600 米。星图把转换做在 `CoordinateTransform` 里（含反解与境外透传），单元测试有覆盖。
