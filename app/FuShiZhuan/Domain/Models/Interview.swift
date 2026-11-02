//  Interview.swift —— 模拟面试领域模型                              // 文件说明
//  依据 1：教育部招生工作管理规定第五十二条（小组不少于 5 人、每生不少于 20 分钟） // 依据
//  依据 2：技能 references/ai-interview.md 的导师分工、状态机、反馈结构   // 依据
//  铁律：状态转移只在这里定义，视图层不许写 if 拼流程                     // 约束

import Foundation  // 基础库

// MARK: - 导师                                                        // 分节：导师

enum MentorRole: String, Codable, CaseIterable, Identifiable {  // 面试小组成员
    case lead  // 组长，主问控场
    case majorA  // 专业导师 A，税收理论
    case majorB  // 专业导师 B，实务与政策
    case foreign  // 外语导师
    case comprehensive  // 综合导师
    case secretary  // 秘书，只记录不提问

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 角色名
        switch self {  // 按角色分支
        case .lead: "组长"  // 组长
        case .majorA: "专业导师 A"  // 专业 A
        case .majorB: "专业导师 B"  // 专业 B
        case .foreign: "外语导师"  // 外语
        case .comprehensive: "综合导师"  // 综合
        case .secretary: "秘书"  // 秘书
        }  // 分支结束
    }  // title 结束

    var focus: String {  // 提问方向
        switch self {  // 按角色分支
        case .lead: "开场、控场、核心专业题与追问节奏"  // 组长
        case .majorA: "税制原理、税收学基础、概念辨析"  // 专业 A
        case .majorB: "涉税案例、政策热点、税收筹划"  // 专业 B
        case .foreign: "财税英语，英文自我介绍与专业问答"  // 外语
        case .comprehensive: "学习经历、职业规划、报考动机、综合素养"  // 综合
        case .secretary: "记录与计时，不提问、不参与评分"  // 秘书
        }  // 分支结束
    }  // focus 结束

    var scores: Bool { self != .secretary }  // 是否参与打分

    var voicePitch: Float {  // 播报音高（0.5–2.0，1.0 为原始）
        switch self {  // 按角色分支
        case .lead: 0.92  // 组长：低沉，压得住场
        case .majorA: 1.04  // 专业 A：清亮
        case .majorB: 0.88  // 专业 B：更低沉，显年长
        case .foreign: 1.10  // 外语导师：偏高
        case .comprehensive: 1.00  // 综合导师：中性
        case .secretary: 1.00  // 秘书：中性
        }  // 分支结束
    }  // voicePitch 结束

    var voiceRate: Float {  // 播报语速（系统默认 0.5，越低越慢）
        switch self {  // 按角色分支
        case .lead: 0.48  // 组长：稳
        case .majorA: 0.50  // 专业 A：正常
        case .majorB: 0.46  // 专业 B：慢一点，像在斟酌
        case .foreign: 0.44  // 外语导师：更慢，方便听清
        case .comprehensive: 0.50  // 综合导师：正常
        case .secretary: 0.50  // 秘书：正常
        }  // 分支结束
    }  // voiceRate 结束

    static var seated: [MentorRole] {  // 导师席 5 人
        [.lead, .majorA, .majorB, .foreign, .comprehensive]  // 固定顺序
    }  // 属性结束
}  // MentorRole 结束

// MARK: - 环节与时间                                                   // 分节：环节

enum InterviewPhase: String, Codable, CaseIterable, Identifiable {  // 五个环节
    case opening  // 组长开场
    case foreign  // 外语环节
    case major  // 专业抽题与追问
    case comprehensive  // 综合提问
    case closing  // 组长收尾

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 环节名
        switch self {  // 按环节分支
        case .opening: "开场"  // 开场
        case .foreign: "外语环节"  // 外语
        case .major: "专业问答"  // 专业
        case .comprehensive: "综合提问"  // 综合
        case .closing: "收尾"  // 收尾
        }  // 分支结束
    }  // title 结束

    var seconds: Int {  // 该环节秒数
        switch self {  // 按环节分支
        case .opening: 60  // 1 分钟
        case .foreign: 300  // 5 分钟
        case .major: 540  // 9 分钟
        case .comprehensive: 240  // 4 分钟
        case .closing: 60  // 1 分钟
        }  // 合计 1200 秒
    }  // seconds 结束

    var speakers: [MentorRole] {  // 该环节提问人
        switch self {  // 按环节分支
        case .opening, .closing: [.lead]  // 只有组长
        case .foreign: [.foreign]  // 只有外语导师
        case .major: [.majorA, .majorB, .lead]  // 两位专业导师加组长
        case .comprehensive: [.comprehensive, .lead]  // 综合导师与组长交替
        }  // 分支结束
    }  // speakers 结束
}  // InterviewPhase 结束

// MARK: - 状态机                                                       // 分节：状态

enum InterviewState: String, Codable {  // 会话状态
    case idle  // 未开始
    case preparing  // 设置参数
    case connecting  // 建立连接
    case greeting  // 组长开场
    case asking  // 导师提问
    case listening  // 录音中
    case transcribing  // 识别中
    case reviewing  // 确认转写
    case evaluating  // 评分中
    case followingUp  // 追问中
    case switching  // 切换导师
    case paused  // 已暂停
    case finishing  // 收尾
    case feedback  // 出结果
    case archived  // 已归档
    case error  // 出错
    case abandoned  // 未完成

    var title: String {  // 状态文案
        switch self {  // 按状态分支
        case .idle: "未开始"  // 未开始
        case .preparing: "设置中"  // 设置
        case .connecting: "连接中"  // 连接
        case .greeting: "开场"  // 开场
        case .asking: "提问中"  // 提问
        case .listening: "录音中"  // 录音
        case .transcribing: "识别中"  // 识别
        case .reviewing: "确认作答"  // 确认
        case .evaluating: "评分中"  // 评分
        case .followingUp: "追问中"  // 追问
        case .switching: "切换导师"  // 切换
        case .paused: "已暂停"  // 暂停
        case .finishing: "收尾中"  // 收尾
        case .feedback: "已出结果"  // 结果
        case .archived: "已归档"  // 归档
        case .error: "出错"  // 错误
        case .abandoned: "未完成"  // 放弃
        }  // 分支结束
    }  // title 结束

    var timerRunning: Bool {  // 计时是否继续
        switch self {  // 按状态分支
        case .greeting, .asking, .listening, .transcribing, .reviewing,  // 进行中的状态（上半）
             .evaluating, .followingUp, .switching, .finishing:  // 进行中的状态（下半）
            true  // 计时走
        default: false  // 其它冻结
        }  // 分支结束
    }  // timerRunning 结束

    var isTerminal: Bool {  // 是否终态
        switch self {  // 按状态分支
        case .archived, .abandoned: true  // 归档与放弃是终态
        default: false  // 其它不是
        }  // 分支结束
    }  // isTerminal 结束
}  // InterviewState 结束

enum InterviewErrorKind: String, Codable, CaseIterable {  // 失败类型
    case network  // 网络
    case timeout  // 超时
    case asrFailed  // 语音识别失败
    case modelFailed  // 模型异常
    case quotaExceeded  // 额度用完
    case permissionDenied  // 权限被拒
    case sceneLoadFailed  // 场景加载失败

    var title: String {  // 错误标题
        switch self {  // 按类型分支
        case .network: "网络连接失败"  // 网络
        case .timeout: "响应超时"  // 超时
        case .asrFailed: "语音识别失败"  // 识别
        case .modelFailed: "AI 服务异常"  // 模型
        case .quotaExceeded: "今日次数已用完"  // 额度
        case .permissionDenied: "麦克风权限未开启"  // 权限
        case .sceneLoadFailed: "3D 场景加载失败"  // 场景
        }  // 分支结束
    }  // title 结束

    var recoveryAction: String {  // 恢复动作
        switch self {  // 按类型分支
        case .network: "检查网络后点「重试」"  // 网络
        case .timeout: "点「重试」，或切到文字作答继续"  // 超时
        case .asrFailed: "改用键盘输入，不影响本场面试"  // 识别
        case .modelFailed: "点「重试」；连续两次失败请稍后再来"  // 模型
        case .quotaExceeded: "明天再来，或开通会员增加次数"  // 额度
        case .permissionDenied: "去「设置 → 复试专 → 麦克风」打开权限"  // 权限
        case .sceneLoadFailed: "已自动切到静态背景，面试可继续"  // 场景
        }  // 分支结束
    }  // recoveryAction 结束

    var isRecoverable: Bool {  // 能否降级继续
        switch self {  // 按类型分支
        case .sceneLoadFailed, .asrFailed: true  // 场景与语音可降级
        default: false  // 其它不可
        }  // 分支结束
    }  // isRecoverable 结束
}  // InterviewErrorKind 结束

// MARK: - 准备参数                                                     // 分节：参数

enum InterviewMode: String, Codable, CaseIterable, Identifiable {  // 面试类型
    case professional  // 专业面试
    case general  // 综合面试
    case experience  // 经历追问

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 类型名
        switch self {  // 按类型分支
        case .professional: "专业面试"  // 专业
        case .general: "综合面试"  // 综合
        case .experience: "经历追问"  // 经历
        }  // 分支结束
    }  // title 结束
}  // InterviewMode 结束

enum MentorStyle: String, Codable, CaseIterable, Identifiable {  // 导师风格
    case gentle  // 温和
    case standard  // 标准
    case strict  // 严格

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 风格名
        switch self {  // 按风格分支
        case .gentle: "温和"  // 温和
        case .standard: "标准"  // 标准
        case .strict: "严格"  // 严格
        }  // 分支结束
    }  // title 结束
}  // MentorStyle 结束

enum RenderTier: String, Codable {  // 渲染档位
    case high  // 3D 场景加 3D 导师
    case medium  // 3D 场景加 2D 立绘
    case light  // 静态背景加头像条
}  // RenderTier 结束

// MARK: - 一轮问答                                                     // 分节：问答

struct InterviewTurn: Codable, Identifiable, Equatable {  // 单轮问答
    let id: UUID  // 唯一 id
    let index: Int  // 第几轮
    let phase: InterviewPhase  // 所属环节
    let speaker: MentorRole  // 谁提问
    let question: String  // 问题原文
    var answer: String  // 考生回答
    var followUp: String?  // 追问内容
    let askedAt: Date  // 提问时间
    var answeredAt: Date?  // 作答时间

    init(  // 构造器
        id: UUID = UUID(),  // 默认新 id
        index: Int,  // 轮次
        phase: InterviewPhase,  // 环节
        speaker: MentorRole,  // 提问人
        question: String,  // 问题
        answer: String = "",  // 默认空回答
        followUp: String? = nil,  // 默认无追问
        askedAt: Date = .now,  // 默认现在
        answeredAt: Date? = nil  // 默认未答
    ) {  // 构造体开始
        self.id = id  // 赋值 id
        self.index = index  // 赋值轮次
        self.phase = phase  // 赋值环节
        self.speaker = speaker  // 赋值提问人
        self.question = question  // 赋值问题
        self.answer = answer  // 赋值回答
        self.followUp = followUp  // 赋值追问
        self.askedAt = askedAt  // 赋值提问时间
        self.answeredAt = answeredAt  // 赋值作答时间
    }  // 构造结束

    var isAnswered: Bool {  // 是否已作答
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 去空白后非空
    }  // 属性结束
}  // InterviewTurn 结束

// MARK: - 评分                                                         // 分节：评分

enum ScoreDimension: String, Codable, CaseIterable, Identifiable {  // 五个评分维度
    case completeness  // 内容完整性
    case logic  // 逻辑结构
    case professionalExpression  // 专业表达
    case languageOrganization  // 语言组织
    case manner  // 综合素养

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 维度名
        switch self {  // 按维度分支
        case .completeness: "内容完整性"  // 完整性
        case .logic: "逻辑结构"  // 逻辑
        case .professionalExpression: "专业表达"  // 专业表达
        case .languageOrganization: "语言组织"  // 语言
        case .manner: "综合素养"  // 素养
        }  // 分支结束
    }  // title 结束

    var hint: String {  // 维度说明
        switch self {  // 按维度分支
        case .completeness: "是否答到了该题的核心要点"  // 完整性
        case .logic: "回答是否有层次、有条理"  // 逻辑
        case .professionalExpression: "术语是否准确、表述是否专业"  // 专业表达
        case .languageOrganization: "表达是否连贯，外语环节看语法与词汇"  // 语言
        case .manner: "态度、报考动机与表达是否得体"  // 素养
        }  // 分支结束
    }  // hint 结束

    static let scaleNote = "0-100 为训练量表分数，非院校官方评分，不预测录取结果。"  // 量表声明
}  // ScoreDimension 结束

struct DimensionScore: Codable, Identifiable, Equatable {  // 单维评分
    var id: String { dimension.rawValue }  // 可识别 id
    let dimension: ScoreDimension  // 哪个维度
    var score: Int  // 0-100 分
    var evidence: String  // 必须引用原文
    var comment: String  // 点评

    var isJudged: Bool {  // 是否可判
        !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 证据为空即不可判
    }  // 属性结束
}  // DimensionScore 结束

struct Improvement: Codable, Identifiable, Equatable {  // 一条改进建议
    var id: UUID = UUID()  // 唯一 id
    let issue: String  // 问题是什么
    let example: String  // 考生原话示例
    let rewrite: String  // 改写示例
}  // Improvement 结束

// MARK: - 会话                                                         // 分节：会话

struct InterviewSession: Codable, Identifiable, Equatable {  // 一场面试
    let id: UUID  // 场次 id
    var mode: InterviewMode  // 面试类型
    var style: MentorStyle  // 导师风格
    var tier: RenderTier  // 渲染档位
    var state: InterviewState  // 当前状态
    var phase: InterviewPhase  // 当前环节
    var turns: [InterviewTurn]  // 全部轮次
    var startedAt: Date  // 开始时间
    var endedAt: Date?  // 结束时间
    var limitSeconds: Int  // 限时秒数
    var elapsedSeconds: Int  // 已用秒数
    var scores: [DimensionScore]  // 各维评分
    var improvements: [Improvement]  // 改进建议
    var headline: String  // 一句话结论
    var summaryGenerated: Bool  // 总结是否已生成
    var uncertainty: [String]  // 低置信项

    init(  // 构造器
        id: UUID = UUID(),  // 默认新 id
        mode: InterviewMode = .professional,  // 默认专业面
        style: MentorStyle = .standard,  // 默认标准风格
        tier: RenderTier = .medium,  // 默认中配
        state: InterviewState = .preparing,  // 默认设置态
        phase: InterviewPhase = .opening,  // 默认开场
        turns: [InterviewTurn] = [],  // 默认无轮次
        startedAt: Date = .now,  // 默认现在
        endedAt: Date? = nil,  // 默认未结束
        limitSeconds: Int = 1200,  // 默认 20 分钟
        elapsedSeconds: Int = 0,  // 默认 0 秒
        scores: [DimensionScore] = [],  // 默认无评分
        improvements: [Improvement] = [],  // 默认无建议
        headline: String = "",  // 默认空结论
        summaryGenerated: Bool = false,  // 默认未生成
        uncertainty: [String] = []  // 默认无低置信项
    ) {  // 构造体开始
        self.id = id  // 赋值 id
        self.mode = mode  // 赋值类型
        self.style = style  // 赋值风格
        self.tier = tier  // 赋值档位
        self.state = state  // 赋值状态
        self.phase = phase  // 赋值环节
        self.turns = turns  // 赋值轮次
        self.startedAt = startedAt  // 赋值开始时间
        self.endedAt = endedAt  // 赋值结束时间
        self.limitSeconds = limitSeconds  // 赋值限时
        self.elapsedSeconds = elapsedSeconds  // 赋值已用时间
        self.scores = scores  // 赋值评分
        self.improvements = improvements  // 赋值建议
        self.headline = headline  // 赋值结论
        self.summaryGenerated = summaryGenerated  // 赋值标记
        self.uncertainty = uncertainty  // 赋值低置信项
    }  // 构造结束

    var remainingSeconds: Int { max(0, limitSeconds - elapsedSeconds) }  // 剩余秒数不为负

    var answeredCount: Int { turns.filter(\.isAnswered).count }  // 已作答题数

    var overallScore: Int? {  // 综合分
        let judged = scores.filter(\.isJudged).map(\.score)  // 只取可判维度
        guard !judged.isEmpty else { return nil }  // 全不可判返回 nil
        return judged.reduce(0, +) / judged.count  // 取平均
    }  // 属性结束

    var isOffline: Bool {  // 本场是否用过离线粗评
        uncertainty.contains { $0.hasPrefix(InterviewNotes.offlineTag) }  // 靠标记识别，不给存档加字段
    }  // 属性结束
}  // InterviewSession 结束

/// 固定说明标记。放 Domain 里，避免 Domain 反过来依赖 Services
enum InterviewNotes {  // 说明标记
    static let offlineTag = "离线粗评"  // 离线算分的统一前缀
}  // InterviewNotes 结束
