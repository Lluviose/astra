# Astra 3 · 山河

iOS 优先的私人记录应用与内嵌 3D 城市策略沙盘。开发入口为本目录；`App/` 下的 SwiftUI 工程不参与本次重写。不做旧数据迁移。

## 运行

需要 Node.js 24；原生构建需要 macOS、Xcode、CocoaPods。

```sh
npm ci
npm run ios
```

正常构建从空档案开始。设置中可主动载入虚构示例。展示构建使用独立数据库：

```sh
EXPO_PUBLIC_DEMO_MODE=1 npm run ios
EXPO_PUBLIC_DEMO_MODE=1 npm run web
```

## 功能

- **山河**：离线 3D 沙盘、城市搜索、角色等级、星尘钱包、攻占与四级建筑。
- **人物**：代号、档案、六维评分、私藏和编辑。
- **战绩**：新增、编辑、删除、搜索和跟进；私人细节支持地点、姿势/玩法、身体特征标签与主观身体评分。
- **成就**：城市建筑图鉴、海岸/高原成就、领地与累计里程碑。
- **积分规则**：0–1000 整数权重；无套、私人标签和身体评分可加分，设为 0 关闭，修改前预览结果。

记录与积分、建造消费和 3D 渲染分层。SQLite 提交成功后更新界面；修改或删除记录会重算积分和领地。角色经验不因建造消费减少。城市可直接点亮或从相邻领地扩张。

## 验证

```sh
npm run typecheck
npm test
npx expo install --check
npm run export:web
npm run export:ios -- --output-dir ios-export
```

本轮通过类型检查、25 项业务测试、Web 与 iOS JavaScript 导出、Expo 离线依赖检查。原生编译、iPhone 真机性能和截图验收尚未完成：当前环境无 Xcode，本地浏览器预览连接被环境拦截。JavaScript 导出不等于 iOS 应用编译成功。

`React Native review` workflow 仍然只手动运行，macOS 模拟器选项默认关闭。原生验收脚本已适配新导航。`public/review.html` 提供固定手机宽度的开发预览。

## 代码边界

| 目录 | 职责 |
| --- | --- |
| src/app | 路由、表单、规则设置 |
| src/features/atlas | 山河、图鉴、隐私和渲染生命周期 |
| src/game | 城市配置、纯函数计分、建造重放、成就、类型 |
| src/platform/atlas | 原生/Web Canvas、程序化 3D 场景 |
| src/data | SQLite、Web 适配器、串行提交 |
| src/domain | 人物、记录、输入校验、虚构样例 |

地图是原创简化游戏轮廓，不是精确行政地图。首批有 7 个建筑家族、18 个城市专属配置；其余大陆城市按地区与城市参数生成。所有城市都有独立解锁状态。没有实时部队战斗、在线对战或自动定位。

详细产品方案、默认积分、城市建筑清单、隐私说明与后续验收见 [架构说明](../Docs/atlas-game-architecture.md)。
