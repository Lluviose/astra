# 星图 · Astra

给成年人用的猎艳 / 约炮笔记。记下她是谁、每次上床或没上床、地点足迹、艳照和成就；不传开发者服务器，可随设备 iCloud Backup 恢复。iOS 原生 App，SwiftUI + MapKit，墨色 / 暖白原生界面与 iOS 26 液态玻璃控件，Core Haptics 原生触感。

> 想换名字？只改一处：`project.yml` 里的 `CFBundleDisplayName`（工程名、bundle id 也随之改掉即可），图标在 `Scripts/generate_icon.py`。

## 原生界面与产品改版

新版主导航为 **后宫 / 战绩 / 殿堂**。以暖白、深墨、酒红与旧金建立收藏感，照片、身份与记录分别拥有清晰的位置。

- **后宫**：大封面今日回味、偏爱人物、收藏层级与欲望排序；有私藏时点封面直接翻照片，完整名册保留在次级入口。
- **战绩**：按时间阅读记录；搜索、人物、时间与结果组合筛选；跟进直接完成并可撤销。
- **殿堂**：封号与总战绩、个人巅峰、勋章、传奇后宫、领地、排行、时间分析与专属战绩卡；可定制封号、陈列风格和王都。
- **人物档案**：战绩 / 画像 / 私藏三段，支持偏爱、单独修改六维评分、相册与完整记录。
- **快速记录**：首次从人物代号开始，城市可稍后补充；只有一位活跃人物时直接打开记录，多人时可选择或当场新建。
- **渐进表单**：基础结果、时间、地点、保护情况与备注优先，其余细节按需展开，收起保留输入。
- **晋升反馈**：成就与领地计算保留，保存后显示轻提示，新的进展留在殿堂陈列。
- **原生体验**：深浅模式、大字体重排、44pt 选择控件、降低透明度与减弱动态效果适配；原生地图、相册、搜索和导航。
- **数据兼容**：既有持久化键、媒体引用、备份格式与成就计算保留；照片分仓、导入导出和 App 锁继续可用。

设计细节见 [原生设计体系](Docs/native-design.md) 与 [欲望、收藏与身份感](Docs/desire-achievement-loop.md)。

## 隐私（刻意为之）

| 项 | 设计 |
| --- | --- |
| 网络 | 无账号、统计 SDK、开发者服务器或应用内云同步；MapKit 仅显示底图 |
| 权限 | 拍照才要相机；相册用系统选择器，不必交出整本相册。不读通讯录，不定位置。面容 / 触控 ID 可选 |
| 照片 | 头像、人物照、档案照片和艳照只存在 Application Support/AstraMedia，不写入系统相册，允许进入设备 iCloud Backup |
| 位置 | 中国只到**市**级，境外只到**国家**级；无精确坐标，无定位 |
| 防窥 | 可选 App 锁 + 后台不透明隐私遮罩 + 代号默认打码（打码时头像和相册也会糊掉） |
| 备份 | 档案、设置和全部照片允许进入设备 iCloud Backup；另可导出含照片的明文 JSON 自行保管 |

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
  Domain/     Models · Achievement(含 RoyalRank) · Insights · City · ChinaRegion · CoordinateTransform · RosterFilter
  Data/       LocalStore · MediaStore · CityCatalog · BackupService
  Design/     LiquidGlass · Haptics · Palette · Components(DesignSystem · HeroPanel · SectionCard · EntryTile 等)
  Support/    Formatters
  Features/   Home · Insights · Record(RecordingFlow) · Map · Roster · Companion · Timeline · Settings · City · Media
App/Resources  cities.json · countries.json · Assets.xcassets
Scripts/       generate_icon.py（纯标准库，无依赖）
Tests/AstraTests
.github/workflows/ios.yml
```

产品体验循环与后续实验见 `Docs/desire-achievement-loop.md`。

## 关于坐标系

公开数据集的坐标是 WGS-84，而中国大陆地图服务（含中国区 Apple Maps）渲染用 GCJ-02，直接标点会偏 300~600 米。星图只对中国城市坐标转换，境外国家代表点始终保持 WGS-84，单元测试有覆盖。
