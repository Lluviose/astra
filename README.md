# 星图 · Astra

个人私密关系档案。把重要的人标注在中国地图上（只到**市**一级），记录每段关系的状态、相处时间线与花费。iOS 原生 App，SwiftUI + MapKit，iOS 26 液态玻璃风格，Core Haptics 原生触感。

> 想换名字？只改一处：`project.yml` 里的 `CFBundleDisplayName`（工程名、bundle id 也随之改掉即可），图标在 `Scripts/generate_icon.py`。

## 功能

- **中国地图**：MapKit 锁定中国范围（含港澳台），城市气泡用玻璃胶囊呈现，尺寸随人数、颜色随关系阶段；内置 66 座主要城市，坐标做 WGS-84 → GCJ-02 转换，没有国内底图的偏移问题
- **名单**：按关系阶段 / 城市分组，搜索（名字、标签、城市、拼音）、多条件筛选、置顶、归档、删除
- **档案**：名字、头像（emoji / 首字渐变）、城市、关系阶段（观察中 → 稳定 → 已结束）、心动指数、生日倒计时、年龄身高职业、认识渠道、联系方式备注、标签、自由备注
- **相处时间线**：见面 / 吃饭 / 出去玩 / 旅行 / 通话 / 聊天 / 送礼，每条可记地点、花费、感受、备注；一键「聊了 / 见了 / 送礼」
- **该联系了**：每人可设提醒间隔（7/14/30/60 天），超时没互动的人会置顶提醒，名单页带角标
- **统计**：进行中人数、城市数、本月见面次数与花费、近 6 个月见面频率图、平均感受
- **液态玻璃**：iOS 26 真 Liquid Glass（glassEffect / GlassEffectContainer / .glass 按钮），iOS 18 自动降级为 Material + 高光描边
- **原生触感**：落针、聚焦、升降面板、发出记录、拨动开关各有定制 Core Haptics 波形，强度可调
- **数据**：纯本地，无网络代码；JSON 备份导出 / 合并导入 / 一键清空

## 隐私（刻意为之）

| 项 | 设计 |
| --- | --- |
| 网络 | **零网络代码**，不请求、不统计、不同步 |
| 权限 | 不申请任何系统权限；唯一可选的是 Face ID / 触控 ID 解锁 |
| 位置 | 只到**市**级粒度，无精确坐标，无定位 |
| 防窥 | 可选 App 锁 + 后台毛玻璃遮罩 + 名字打码显示 |
| 备份 | 明文 JSON，导出到你选的位置，自己保管 |

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
  Features/   Map · Roster · Companion · Timeline · Settings · City
App/Resources  cities.json · Assets.xcassets
Scripts/       generate_icon.py（纯标准库，无依赖）
Tests/AstraTests
.github/workflows/ios.yml
```

## 关于坐标系

公开数据集的坐标是 WGS-84，而中国大陆地图服务（含中国区 Apple Maps）渲染用 GCJ-02，直接标点会偏 300~600 米。星图把转换做在 `CoordinateTransform` 里（含反解与境外透传），单元测试有覆盖。
