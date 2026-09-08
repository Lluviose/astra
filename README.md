# 星图 · Astra

给成年人用的猎艳 / 约炮笔记。记下她是谁、每次上床或没上床、地点足迹、艳照和成就；不传开发者服务器，可随设备 iCloud Backup 恢复。iOS 原生 App，SwiftUI + MapKit，苹果风格的克制配色与原生 Liquid Glass，Core Haptics 原生触感。

> 想换名字？只改一处：`project.yml` 里的 `CFBundleDisplayName`（工程名、bundle id 也随之改掉即可），图标在 `Scripts/generate_icon.py`。

## 功能

- **猎场首页**：王者等级（每 10 枚成就升一级）+ 女人 / 上床 / 回头客 / 战绩地四格战绩；「点她，直接记」一条最近的人，点头像两步就能记下上床了 / 没上床；图鉴、成就册、战绩统计、版图四个入口并排
- **战绩统计**：上床率、近 12 个月双柱趋势、套的分布、最常做的玩法与收尾、清晨 / 白天 / 晚上 / 深夜与周几偏好、上得最多的人和地点、花费合计与平均、间隔与空窗、还想不想再约
- **后宫图鉴**：只有真正记录过「上床了」的人才能进入；每天固定回味一个她，支持按次数、最近、综合和照片排序，封面可直接翻阅照片
- **今夜焦点**：按置顶、相处阶段和已有结果选出一个值得回味或推进的人，可直接打开档案或记录结果
- **名册与私密排行**：每个人一张猎获档案；支持综合、欲望、床上默契、回味欲和上床次数榜单，只在本机显示
- **六维评分**：颜值、身材、床上默契、主动感、欲望值、回味欲均为 0–10，带快速预设、实时综合分、滑杆触感和旧五星数据迁移
- **时间线**：记录只分「上床了 / 没上床」，按天显示具体时间、地点和备注；可按代号、地点、备注、玩法搜索；近 6 个月双柱对比，一键进完整统计；左滑直达档案
- **成就册**：60 枚徽章分成猎获、上床、复盘、足迹、私藏、玩法六章，铜银金三档，含她主动、持久战、三连发、潮吹、过夜、出境战绩、连续三月、摸清她等新章目，并聚合成从「猎场开张」到「全册封神」的 6 级王者身份
- **人物照与艳照分仓**：头像封面、普通人物资料照、艳照私藏和单次约会照片分开保存、分开浏览、分开计数
- **猎获档案**：以她的头像色做封面，综合分环、「认识 X 天 · 第 Y 天上床」、上床 / 没上 / 私藏 / 上次上床四格加两个玻璃结果按钮；「见她之前看一眼」把她在床上喜欢什么、怎么约她最顺、说过的规矩和安全备忘放在最上面；「和她的战绩」小结第一次上床、上床率、平均间隔、平均多久、平均几轮、谁更主动、最常做、套、花费、常约时段和最爽的一次；联系方式点一下复制；艳照与人物照分档切换；六维评分、基本线索和她的时间线
- **结果记录**：原生三步表单「结果 → 细节 → 跟进」，两张结果大卡（未选的是玻璃）、刚刚 / 昨晚 / 今早快捷时间、场所芯片，对象、结果、时间和地点确认好就能存；没上床可选进展和原因；上床了先记节奏（谁主动、几轮、多久），再按接吻与手上动作 / 口 / 性交 / 姿势 / 节奏 / 场景 / 情趣与玩法七组勾行为，收尾含潮吹，防护分开选；只复用上次行为与收尾，不自动填写这次防护、地点或花费
- **人物建档**：直接新增人物，在档案里选地点；选人时也能新增并接着记。按「基本资料 → 偏好与约法 → 照片」填写，17 个认识渠道、18 条床上偏好与 16 条约她方式的快捷短语、7 组人物标签，照片页直接看到待保存的缩略图，保留自由备注和自定义标签
- **记录动效**：系统分段选择器、固定步骤栏和底部工具栏；方向性弹簧切页、淡入与轻模糊过渡、SF Symbols 替换、选项按压与勾选联动，适配减弱动态效果和辅助功能大字体
- **事后跟进**：回个消息、再约一次、去做检测、暴露咨询等，可设日期并勾完成
- **安全小结**：戴套、PrEP、避孕分开记，不算「安全分」，也不按人打标签
- **全球版图**：默认只看真正上过床的战绩地点，按时间连接路线并显示路线里程、城 / 国数量、头号猎场、地点排名和当地后宫；有两年以上战绩时可按年份翻版图，境外国家气泡用国旗，地点面板小结首战、最近、常去场所、平均多久、花费和照片；有境外记录时自动切换全球视角
- **苹果风格界面**：系统蓝、浅色 / 石墨色内容卡片与低饱和午夜封面，统一 SF Symbols 图标、留白和弹簧动效；导航、封面按钮和地图控件使用 iOS 26+ 原生 Liquid Glass，iOS 18 降级为 Material；适配减少透明度、增强对比度和减弱动态效果。设计说明与预览入口见 `Docs/apple-design.md`
- **原生触感**：记录、切换状态、地点聚焦、升降面板和拨动开关各有定制 Core Haptics 波形，强度可调
- **数据**：无账号、无统计、无应用内云同步；全部持久化用户数据允许进入设备 iCloud Backup，并支持明文 JSON 导出 / 合并导入 / 一键清空

## 隐私（刻意为之）

| 项 | 设计 |
| --- | --- |
| 网络 | 无账号、统计 SDK、开发者服务器或应用内云同步；MapKit 仅显示底图 |
| 权限 | 拍照才要相机；相册用系统选择器，不必交出整本相册。不读通讯录，不定位置。面容 / 触控 ID 可选 |
| 照片 | 头像、人物资料照和艳照只存在 Application Support/AstraMedia，不写入系统相册，允许进入设备 iCloud Backup |
| 位置 | 中国只到**市**级，境外只到**国家**级；无精确坐标，无定位 |
| 防窥 | 可选 App 锁 + 后台毛玻璃遮罩 + 代号默认打码（打码时头像和相册也会糊掉） |
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
  Design/     LiquidGlass · Haptics · Palette · Components(HeroPanel · SectionCard · EntryTile 等)
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

