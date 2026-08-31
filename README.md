# 星图 · Astra

给成年人用的猎艳 / 约炮笔记。记下她是谁、约成几次、过夜、艳照和成就；全部只存在这台手机上，不上传。iOS 原生 App，SwiftUI + MapKit，iOS 26 液态玻璃风格，Core Haptics 原生触感。

> 想换名字？只改一处：`project.yml` 里的 `CFBundleDisplayName`（工程名、bundle id 也随之改掉即可），图标在 `Scripts/generate_icon.py`。

## 功能

- **猎场**：首页就是猎艳记录册封面。本月新人 / 约成 / 过夜 / 照片一眼能看到，记下就能翻页
- **名册**：每个人一张猎获档案，头像、约成次数、过夜、回头客都写在行上；可按约成次数排序
- **记录册**：约成、过夜、照片按月成册；近 6 个月约成柱状图
- **成就册**：50 枚徽章分成猎获、约成、留宿、足迹、私藏、玩法六章，铜银金三档。无套、内射、口爆、颜射、车震都能点亮。记下新猎获会翻页弹出，只给你自己看，不算排行榜
- **头像与艳照**：每人一张头像；档案里就能直接加私藏，每次约还能再留最多 8 张。只复制进 App 沙盒，不进系统相册，也不进 iCloud 备份
- **猎获档案**：代号 / 头像、相处状态（刚认识 → 聊上了 → 暧昧中 → 准炮友 → 炮友 / 固定炮友 → 先搁着 / 结束了）、约成 / 过夜 / 照片、怎么约、她说过不行的事
- **聊天记录**：进展、她对黄段子 / 照片 / 视频的回应、聊过的尺度和规矩、线上隐私约定，以及转账、可疑链接等需要停手的信号
- **约成记录**：对象、时间和类型填了就能存；姿势、口、无套、内射、口爆、颜射、爽不爽、还想不想再干、照片和私密备注都可以后补
- **事后跟进**：回个消息、再约一次、去做检测、暴露咨询等，可设日期并勾完成
- **安全小结**：戴套、PrEP、避孕分开记，不算「安全分」，也不按人打标签
- **猎场地图**：只标记到城市级；内置全国地级市、省直辖县级市、部分百强县和港澳台主要城市（380+），并处理 WGS-84 → GCJ-02 偏移
- **液态玻璃**：iOS 26 真 Liquid Glass（glassEffect / GlassEffectContainer / .glass 按钮），iOS 18 自动降级为 Material + 高光描边
- **原生触感**：记录、切换状态、城市聚焦、升降面板和拨动开关各有定制 Core Haptics 波形，强度可调
- **数据**：名册、记录册和照片纯本地，不上传、不统计、不同步；支持 JSON 备份导出（含照片）/ 合并导入 / 一键清空

## 隐私（刻意为之）

| 项 | 设计 |
| --- | --- |
| 网络 | 无账号、统计 SDK 或云同步；MapKit 仅显示底图，档案和照片不上传 |
| 权限 | 拍照才要相机；相册用系统选择器，不必交出整本相册。不读通讯录，不定位置。面容 / 触控 ID 可选 |
| 照片 | 头像和艳照只存在 Application Support/AstraMedia，排除 iCloud 备份，不写入系统相册 |
| 位置 | 只到**市**级粒度，无精确坐标，无定位 |
| 防窥 | 可选 App 锁 + 后台毛玻璃遮罩 + 代号默认打码（打码时头像和相册也会糊掉） |
| 备份 | 明文 JSON，照片一并打进去，导出到你选的位置，自己保管 |

## 使用边界

星图只面向成年人之间自愿、知情且可随时撤回的相处。App 中的边界和安全字段用于记录已经明确沟通的信息，不代表一次记录可以替代下一次确认，也不替代专业健康建议。

记录结构优先适配成年男性记录女性对象，同时行为字段仍不依赖性取向或身体结构。所有健康提示基于实际行为与用户主动选择。成就只是给你自己看的进度徽章，不是对外战绩榜。

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
  Domain/     Models · Achievement · City · ChinaRegion · CoordinateTransform · RosterFilter
  Data/       LocalStore · MediaStore · CityCatalog · BackupService
  Design/     LiquidGlass · Haptics · Palette · Components
  Support/    Formatters
  Features/   Home · Map · Roster · Companion · Timeline · Settings · City · Media
App/Resources  cities.json · Assets.xcassets
Scripts/       generate_icon.py（纯标准库，无依赖）
Tests/AstraTests
.github/workflows/ios.yml
```

## 关于坐标系

公开数据集的坐标是 WGS-84，而中国大陆地图服务（含中国区 Apple Maps）渲染用 GCJ-02，直接标点会偏 300~600 米。星图把转换做在 `CoordinateTransform` 里（含反解与境外透传），单元测试有覆盖。
