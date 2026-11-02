# 架构与数据规格

第 3 步与任何架构变更前必读。目标：让样板代码可以长成正式版本，而不是先拼装再重写。

## 1. 分层与模块边界

```
App（可运行目标，只做装配）
├── FeatureUI        各功能界面与视图模型
├── Domain           实体、规则、用例（纯 Swift，无 UI 无网络）
├── Data             仓储实现、本地存储、同步、缓存
├── Service          远端能力协议 + 实现（AI/语音/支付/社区/内容）
├── DesignSystem     设计常量与通用组件
└── Core             工具、日志、指标、配置、密钥读取
```

依赖方向单向：`App → FeatureUI → Domain ← Data / Service`。Domain 不 import 任何框架（除 Foundation）。UI 不直接调 Service，必须经 Domain 用例。

| 模块 | 可以有 | 不可以有 |
| --- | --- | --- |
| FeatureUI | 视图、视图模型、导航 | SQL、URLSession、模型调用、Keychain |
| Domain | 实体、规则、协议定义、用例 | UIKit/SwiftUI/RealityKit、网络 |
| Data | 仓储实现、DB、缓存、同步队列 | 业务规则判断（放 Domain） |
| Service | 协议实现、DTO、错误映射 | 直接读写 DB |
| Core | 日志、指标、配置、Secrets | 业务逻辑 |

## 2. 核心实体

```swift
struct UserProfile: Codable, Identifiable { let id: String; var nickname: String; var avatarURL: URL?; var preferences: Preferences }
struct ExamProfile: Codable { var major: String; var targetSchool: String?; var schoolVerified: Bool; var examDate: Date?; var foundation: FoundationLevel }
struct StudyPlan: Codable { var dailyQuestionTarget: Int; var dailyMinutes: Int; var generatedAt: Date; var recalculationNeeded: Bool }
struct StreakState: Codable { var current: Int; var longest: Int; var lastActiveDay: String; var makeupUsed: Int }

struct Course: Codable, Identifiable { let id: String; var title: String; var chapters: [Chapter]; var isPremium: Bool; var updatedAt: Date }
struct CourseProgress: Codable { let courseID: String; var completedChapterIDs: [String]; var positionSeconds: Double; var updatedAt: Date }

struct Material: Codable, Identifiable { let id: String; var title: String; var isPremium: Bool; var readProgress: Double; var isFavorite: Bool }

struct Question: Codable, Identifiable {
    let id: String; var subject: String; var knowledgePoints: [String]
    var type: QuestionType; var difficulty: Int; var stem: String; var options: [Option]
    var answer: String; var explanation: String?
    var source: String; var reviewStatus: ReviewStatus; var updatedAt: Date
    var linkedQuestionIDs: [String]
}
struct PracticeRecord: Codable, Identifiable { let id: String; var questionID: String; var isCorrect: Bool; var answeredAt: Date; var durationMs: Int }

struct InterviewSession: Codable, Identifiable { let id: String; var mode: InterviewMode; var state: SessionState; var turns: [Turn]; var startedAt: Date; var finishedAt: Date?; var summary: SessionSummary? }
struct Turn: Codable { let id: String; var question: String; var transcript: String; var inputMode: InputMode; var evaluation: Evaluation? }

struct AvatarProfile: Codable { var avatarID: String; var displayName: String; var slots: [String: String]; var claimedAt: Date }
struct PetState: Codable { var level: Int; var growth: Int; var mood: PetMood; var lastEventAt: Date }
struct GrowthEvent: Codable, Identifiable { let id: String; var kind: GrowthKind; var amount: Int; var createdAt: Date; var idempotencyKey: String }

struct Entitlement: Codable { var tier: Tier; var expiresAt: Date?; var source: EntitlementSource }

struct CommunityPeer: Codable, Identifiable { let id: String; var nickname: String; var presence: Presence; var visibility: Visibility }
```

命名规则：实体一律 `struct` + `Codable`；ID 用 `String`（便于 mock 与远端统一）；时间用 `Date`，跨端序列化为 ISO8601 UTC；金额若出现用 `Decimal`，禁止 `Double`。

## 3. 服务协议

每个远端能力先定协议：

```swift
protocol AuthServicing {
    func signIn(credential: Credential) async throws -> Session
    func signInAsGuest() async throws -> Session
    func signOut() async
    func deleteAccount() async throws
}

protocol ContentServicing {
    func courses(cursor: String?) async throws -> Page<Course>
    func materials(cursor: String?) async throws -> Page<Material>
    func questions(filter: QuestionFilter) async throws -> Page<Question>
}

protocol InterviewModelProviding { /* 见 ai-interview.md */ }
protocol SpeechRecognitionProviding {
    func start() async throws -> AsyncStream<TranscriptionChunk>
    func stop() async
}

protocol EntitlementProviding {
    func current() async throws -> Entitlement
    func purchase(_ productID: String) async throws -> PurchaseResult
    func restore() async throws -> RestoreResult
}

protocol PresenceProviding { func subscribe(roomID: String) -> AsyncStream<PresenceEvent> }
protocol RoomServicing { func join(_ roomID: String) async throws; func leave(_ roomID: String) async }
protocol CommunityFeedProviding { func fetchFeed(cursor: String?) async throws -> FeedPage }
protocol GrowthSyncing { func push(_ events: [GrowthEvent]) async throws -> SyncReceipt }
```

统一错误类型，所有实现抛同一枚举：

```swift
enum ServiceError: Error, Equatable {
    case network, timeout, unauthorized, quotaExceeded
    case server(code: Int, message: String)
    case decoding, cancelled, unavailableInSample
}
```

## 4. 单一数据源

| 数据 | 唯一写入者 | 其他模块 |
| --- | --- | --- |
| 用户与备考档案 | `ProfileRepository` | 只读 |
| 学习记录与进度 | `LearningRepository` | 只读 |
| 练习与正确率 | `PracticeRepository` | 只读 |
| 成长值 | `GrowthService`（唯一计算与写入） | 订阅变更 |
| 权益 | `EntitlementStore` | 只读查询 |
| 面试记录 | `InterviewRepository` | 只读 |
| 形象与宠物 | `AvatarRepository` / `PetRepository` | 只读 |

UI 通过 `@Observable`（iOS 17+）或 `ObservableObject` 订阅，变更后相关页面自动刷新。禁止页面各自缓存一份并本地计算。

成长事件入口只有一处：

```swift
func record(_ kind: GrowthKind, idempotencyKey: String) async
```

任何页面不得自己加成长值。

## 5. 本地存储

- 结构化数据：SwiftData（iOS 17+）或 SQLite；样板若需兼容更低版本，统一走仓储协议，不把 SwiftData 类型泄漏到上层。
- 轻量偏好：`UserDefaults`，只存开关与标量。
- 敏感项（会话令牌）：Keychain。
- 3D 资产与缓存：`Caches` 目录，可被系统清理，清除后能重新下载。
- 数据库迁移：每个 schema 版本一个迁移函数，版本号入配置，禁止"删库重建"当迁移。

## 6. 数据同步

```
本地写入（标记 pending，带 idempotencyKey）
  → 事件队列持久化
  → 联网批量推送
  → 服务端回执（accepted / duplicated / conflict）
  → 更新本地状态，清理队列
```

要求：
- 幂等键 = 业务语义 + 本地事件 ID，重复推送不重复计分。
- 冲突以服务端 `updatedAt` 为准，本地保留快照。
- 队列失败重试有上限与退避，超限进"待同步"列表并可手动重试。
- 断网时所有写入仍成功（本地优先），UI 显示待同步标记。
- 注销账号：清队列 → 清本地库 → 清缓存 → 清 Keychain → 回游客态。顺序不可颠倒。

## 7. mock 策略

| 能力 | 样板实现 | 明确标注 |
| --- | --- | --- |
| 登录 | 本地假会话，固定测试账号 | 未接真实鉴权 |
| 内容 | 内置 JSON（课程/资料/题库样本） | 内容为样本，非真实课程 |
| AI 面试 | `MockInterviewModel`：规则模板 + 延迟模拟 | 未接真实模型 |
| 语音识别 | 可切换的模拟转写 + 真实 `Speech` 框架二选一 | 标注哪条路径已实测 |
| 支付 | `MockEntitlementProvider`，本地开关模拟购买/过期/恢复 | 未接 StoreKit，未做真实交易 |
| 社区 presence | 定时器模拟状态变化 | 未接实时服务 |
| 同步 | 本地队列 + 可选假远端 | 未接正式后端 |

规则：
- mock 与真实实现**同一协议、同一错误语义、同一状态流**。切换只改装配层一处。
- mock 必须能模拟失败：提供调试面板可注入 `timeout`、`network`、`decoding`、`quotaExceeded`。
- mock 不得绕过加载态与错误态，否则样板会隐藏真实问题。
- 调试面板只在不影响正式包的条件下启用（Debug 编译配置），Release 不编译。

## 8. 正式替换路径

| 替换项 | 改动点 | 不改动 |
| --- | --- | --- |
| 接真实模型 | `RemoteInterviewModel` 实现 + 配置密钥 | 状态机、反馈页、评分量表 |
| 接 ASR 云服务 | `SpeechRecognitionProviding` 实现 | 转写编辑、降级逻辑 |
| 接 StoreKit 2 | `StoreKitEntitlementProvider` | 权益判断、锁定态 UI |
| 接正式后端 | `Data` 层仓储实现 + DTO 映射 | Domain 实体与用例 |
| 接实时社区 | `PresenceProviding` / `RoomServicing` 实现 | 场景、热点、社交 UI |

替换后必须回归：核心流程 A–E、异常矩阵、门禁表。

## 9. 密钥与合规

- `Secrets.swift` 不进仓库；提供 `Secrets.sample.swift` 作为结构示例（无真实值）。
- 或读 `Config.plist`（已 gitignore）+ 环境变量注入 CI。
- 日志统一走 `Logger`，禁止 `print` 输出实体与原文。
- 埋点只上报枚举、计数、耗时；不上报回答文本、昵称、院校名。
- 隐私授权撤回后，相关采集立即停止并从本地清理已采集项。
