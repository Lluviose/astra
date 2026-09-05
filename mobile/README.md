# Astra · React Native modern edition

Expo SDK 55 / React Native / TypeScript。iOS 优先的全新设计版本，位于 `mobile/`，与仓库现有 SwiftUI 应用独立运行。开发阶段不做旧数据迁移或备份功能。

## 运行

需要 Node.js 24。iOS 本地构建需要 macOS、兼容的 Xcode 与 CocoaPods。

```bash
cd mobile
npm install
npm run ios
```

正常启动为空白档案。设置中可主动载入虚构示例。开发用展示构建：

```bash
EXPO_PUBLIC_DEMO_MODE=1 npm run ios
EXPO_PUBLIC_DEMO_MODE=1 npm run web
```

展示模式使用独立数据库。修改展示环境变量后需重新生成 JavaScript bundle。正式发布构建不设置此变量。

## 本版功能

- 后宫画册、偏爱、搜索、完整名册、人物建档与归档。
- 人物战绩、画像、六维评分、封面选择、本地私藏、照片缩放翻阅。
- 新增和编辑记录、当场新建人物、可选细节、组合搜索、月份与人物筛选、跟进完成与撤销。
- 殿堂统计、六个月相处节奏、里程碑、评分排行、城市足迹与 iOS 原生地图。
- 隐藏私人内容、启动隐藏偏好、设备认证、原生后台模糊保护和前台遮罩、触感反馈。
- SQLite 持久化；所有数据写入串行化，在事务成功后更新界面。网页预览使用独立 localStorage 适配器。

记录保存前校验人物关系、标题和有效日期。直接新建人物并记录时一次提交，取消不会产生空人物。地图只使用内置城市中心，不读取设备定位；自由输入但未匹配的城市仍显示在足迹列表中。

## 验证

```bash
npm run typecheck
npm test
npx expo install --check
npm run export:web
npm run export:ios
```

`React Native review` 工作流执行检查、Expo 两平台导出、iOS 模拟器 Release 构建及原生页面截图。`public/review.html` 用固定手机宽度展示同一套 React Native Web 页面，方便视觉检查。

## 代码边界

| 目录 | 职责 |
| --- | --- |
| src/app | Expo Router 路由、记录与编辑流程 |
| src/features | 收藏、时间线、殿堂、人物档案 |
| src/design | 设计变量、基础控件、照片与布局 |
| src/domain | 数据模型、校验、派生统计、虚构样例 |
| src/data | SQLite / 网页适配器、串行写入、Zustand 状态 |
| src/platform | 照片与地图的平台实现 |

这是一套新业务模型，没有声称兼容旧版全部勋章和评级规则。当前六维评分 0 表示未评分，综合值为六维算术平均。

## 展示素材

`assets/editorial-portrait.png` 由内置图像生成工具创建，为虚构的成年人物。生成提示：自然杂志摄影风格，28 岁左右的虚构东亚女性，白色棉质上衣，混凝土墙边与柔和树影，午后光线，4:5 竖幅，无文字或标记。图片仅供示例模式展示。

当前照片选择器保存其返回源文件的字节。是否能取得特定系统照片格式的原始资源，仍受系统选择器行为影响；不宣称完整支持 Live Photo 或跨格式原始资源导出。
