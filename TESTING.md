# 随心记 · 测试说明（功能测试 + 性能测试 + 覆盖率）

> 说明：Xcode 工程无法在本仓库的 Linux 容器里编译，测试代码已随工程附上，
> 请在 **Xcode 16** 里运行（`⌘U`）。若有失败用例，把报错发来即可迭代修复。

## 关于「100% 覆盖率」的现实口径

对一个 SwiftUI App 追求**整个工程 100% 行覆盖**并不是一个有意义的目标——
SwiftUI 的 `body`、`#Preview`、纯样式代码会把分母撑大却不带来真实保障。
本测试方案的目标是工程界惯例：

- **逻辑层 ~100% 覆盖**（模型、服务、文件存储、日期/时长格式化、时间轴分组、
  增删改 + 文件级联删除）——用单元测试全覆盖；
- **P0 用户流程全覆盖**——用 UI 测试（XCUITest）真机/模拟器驱动；
- **关键路径性能基线**——用 `measure {}` 性能测试。

为此把核心逻辑从视图中**抽离成可注入的独立单元**（`DiaryService`、`DiaryTimeline`、
`FileStoreImpl(root:)`、`DiaryDraft`），使其可脱离 UI 精确断言。

## 目录

```
SuixinJiTests/        单元测试 + 性能测试（unit-test bundle）
  DiaryEntryTests           模型规则：hasContent / hasAudio / 默认值
  DiaryDraftTests           草稿值类型：EditorImage / DraftAudio / hasContent
  DiaryDateFormatTests      日期与时长格式化（zh_CN，含四舍五入/补零）
  FileStoreTests            沙盒读写：压缩≤2048、.jpg/.m4a、adopt、级联删除
  DiaryTimelineTests        年-月分组：单月/跨月/跨年/补记不连续
  DiaryServiceTests         增删改闭环 + 文件级联（in-memory SwiftData + 临时 FileStore）
  MetadataTests             搜索(F8) / 提醒解析(F10) / 心情天气目录 / 元数据持久化(F7/F14)
  ExportWeatherTests        WeatherKit 天气映射(F14) / PDF+长图导出产物(F13)
  DictationTests            听写在光标处插入(F2)
  MemoriesTests             这一天/去年今天 + 里程碑(回顾)
  DiaryStatisticsTests      连续天数/累计/月度活跃/心情分布/媒体计数(统计)
  BackupServiceTests        全量导出→导入往返（含媒体 base64）
  MediaSyncServiceTests     媒体 iCloud 同步：上传/下载/孤儿清理/不复活(F11 媒体)
  PersistenceTests          容器工厂内存路径(F11)
  ThemeManagerTests         强调色/字号持久化（主题皮肤）
  WidgetSnapshotTests       小组件快照编解码 + App Group 键
  ── 演进引擎（本轮）──
  MapFootprintsTests        地图足迹：网格聚合/质心/地名/窗口
  SpotlightIndexerTests     Spotlight 条目构建（标题/关键词/占位）
  WritingPromptsTests       每日灵感确定性轮换 + 本周写作
  MoodTrendsTests           情绪趋势：valence 映射 + 按月平均/窗口
  YearReviewTests           年度报告：年度聚合 + 年内最长连记
  TagFilterTests            组合筛选(DiaryFilter) + 标签管理(TagManager 合并/删除)
  MarkdownParserTests       Markdown 行式块解析 + 去标记预览
  PerformanceTests          分组 1000 条 / 批量插入 500 条 / 8000×6000 图压缩
  EvolutionPerformanceTests 3000 条数据集上：统计/情绪趋势/年度报告/组合筛选/
                            标签计数/搜索/地图聚合/Markdown 预览/Spotlight 构建/这一天

SuixinJiUITests/      端到端 UI 测试（ui-testing bundle）
  SuixinJiUITests           空状态 / 保存禁用 / 新建-入列 / 取消放弃 / 详情-删除 / 设置 footer
  SuixinJiLaunchTests        启动性能 + 启动截图
```

## 功能测试覆盖（对照 PRD/Brief 验收点）

| 用例 | 覆盖点 | 位置 |
|---|---|---|
| 新建文本日记出现在时间轴 | F1 / §4.4 插入 | UITests.testCreateTextEntryAppearsInTimeline |
| 空内容「保存」置灰 | F1 / §5 保存禁用态 | UITests.testSaveDisabledWhenEmpty |
| 取消有改动弹「放弃本次修改」 | §4.4 | UITests.testCancelWithChangesAsksToDiscard |
| 详情 → 删除 → 二次确认 | F6 / §6 | UITests.testOpenDetailAndDeleteEntry |
| 空状态引导文案 | §5 | UITests.testEmptyStateShown |
| 设置页强制 footer | §4④ | UITests.testSettingsShowsDataFooter |
| 图片压缩到长边 ≤2048 | F4 / §9 | FileStoreTests.testSaveImageCompressesLongEdgeTo2048 |
| 删除日记级联删文件（先文件后记录） | §5.3 / §9 | DiaryServiceTests.testDeleteRemovesRecordAndAllFiles |
| 换录音删旧文件 / 删录音清字段 | F3 | DiaryServiceTests.testReplacingAudioDeletesOldFile 等 |
| 编辑不新增行 | F1/F6 | DiaryServiceTests.testEditUpdatesTextWithoutDuplicating |
| 年-月分组（含补记不连续） | F5 | DiaryTimelineTests.* |
| 媒体 iCloud 同步不复活删除/清孤儿 | F11 媒体 | MediaSyncServiceTests.testReconcileDoesNotResurrectDeletedBlob 等 |
| 地图足迹按网格聚合 + 质心 | 演进 | MapFootprintsTests.* |
| Spotlight 条目标题/关键词构建 | 演进 | SpotlightIndexerTests.* |
| 每日灵感当天稳定/跨天轮换 | 演进 | WritingPromptsTests.* |
| 情绪趋势按月平均 + 窗口边界 | 演进 | MoodTrendsTests.* |
| 年度报告聚合 + 年内最长连记 | 演进 | YearReviewTests.* |
| 组合筛选 AND/OR 语义 | 演进 | TagFilterTests.testFilter* |
| 标签重命名即合并去重 / 删除 | 演进 | TagFilterTests.testRename*/testDelete* |
| Markdown 块解析 + 去标记预览不丢字 | 演进 | MarkdownParserTests.* |

> 说明：录音/语音转文字/相机依赖真机硬件与系统权限，无法在纯逻辑单元测试里断言，
> 已通过 `AudioRecorder`/`SpeechTranscriber`/`AudioPlaybackManager` 的接口隔离；
> 其真机行为请按 PRD 第 8 节在设备上手测（飞行模式转文字、拒绝权限去设置、
> 录音中切后台不丢内容）。

## 运行方式

**Xcode：** 选中 `SuixinJi` scheme → `⌘U` 跑全部测试。
Test 导航器里可单独跑某个用例；scheme 已开启 **Code Coverage**。

**命令行（模拟器）：**
```bash
xcodebuild test \
  -project SuixinJi.xcodeproj \
  -scheme SuixinJi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

**查看覆盖率报告：**
```bash
# 摘要
xcrun xccov view --report TestResults.xcresult
# 只看某个文件
xcrun xccov view --report --files-for-target SuixinJi TestResults.xcresult
```
或在 Xcode：Report navigator → 最近一次 Test → Coverage 标签，逐文件查看行覆盖。

## 备注

- UI 测试通过启动参数 `-uitest` 让 App 使用**内存态 SwiftData**（每次全新、互不干扰），
  见 `SuixinJiApp.swift`。
- 单元测试用 `FileStoreImpl(root:)` 注入临时目录，绝不触碰真实 Documents。
