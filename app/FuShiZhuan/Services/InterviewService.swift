//  InterviewService.swift —— 面试服务协议与数据结构                     // 文件说明
//  铁律：先定协议，Mock 与真实实现共用同一协议、同一异常语义           // 架构约束
//  字段名与 BFF 的 index.mjs 严格对齐，改一边必须同步另一边             // 契约提醒

import Foundation                                                     // 基础库

// MARK: - 请求 / 响应                                                  // 分节：数据结构

/// 出题请求
struct TurnRequest: Encodable {                                       // 请求体
    let sessionId: String                                             // 场次 id
    let turnIndex: Int                                                // 第几轮
    let phase: String                                                 // 环节 rawValue
    let speaker: String                                               // 提问人 rawValue
    let mode: String                                                  // 面试类型 rawValue
    let style: String                                                 // 导师风格 rawValue
    let history: [HistoryItem]                                        // 已有问答

    struct HistoryItem: Encodable {                                   // 单条历史
        let question: String                                          // 问题
        let answer: String                                            // 回答
        let speaker: String                                           // 谁问的
    }                                                                 // HistoryItem 结束
}                                                                     // TurnRequest 结束

/// 出题响应
struct TurnResponse: Decodable {                                      // 返回体
    let requestId: String                                             // 请求 id
    let question: String                                              // 问题
    let knowledgePoints: [String]                                      // 涉及知识点
}                                                                     // TurnResponse 结束

/// 评分请求
struct EvaluateRequest: Encodable {                                   // 请求体
    let sessionId: String                                             // 场次 id
    let turnIndex: Int                                                // 第几轮
    let speaker: String                                               // 提问人
    let question: String                                              // 问题
    let answer: String                                                // 考生回答
}                                                                     // EvaluateRequest 结束

/// 单维评分载荷
struct DimensionPayload: Decodable {                                  // 服务端返回的单维
    let score: Int                                                    // 0-100
    let evidence: String                                              // 原文引用，可能为空
    let comment: String                                               // 点评
}                                                                     // DimensionPayload 结束

/// 改进建议载荷
struct ImprovementPayload: Decodable {                                // 服务端返回的建议
    let issue: String                                                 // 问题
    let example: String                                               // 考生原话
    let rewrite: String                                               // 改写示例
}                                                                     // ImprovementPayload 结束

/// 评分响应
struct EvaluateResponse: Decodable {                                  // 返回体
    let requestId: String                                             // 请求 id
    let evaluation: [String: DimensionPayload]                         // 五维评分
    let improvements: [ImprovementPayload]                             // 改进建议
    let confidence: String                                            // high / medium / low
    let uncertainty: String?                                           // 低置信说明
}                                                                     // EvaluateResponse 结束

/// 总结请求
struct SummaryRequest: Encodable {                                    // 请求体
    let sessionId: String                                             // 场次 id
    let mode: String                                                  // 面试类型
    let turns: [SummaryTurn]                                          // 全部轮次

    struct SummaryTurn: Encodable {                                   // 单轮
        let index: Int                                                // 轮次
        let phase: String                                             // 环节
        let speaker: String                                           // 提问人
        let question: String                                          // 问题
        let answer: String                                            // 回答
    }                                                                 // SummaryTurn 结束
}                                                                     // SummaryRequest 结束

/// 逐题复盘
struct PerQuestionPayload: Decodable {                                // 返回体的逐题项
    let question: String?                                              // 问题
    let yourPoints: [String]?                                          // 你答到的要点
    let missingPoints: [String]?                                       // 你漏掉的要点
    let followUpExposed: String?                                       // 追问暴露的问题
}                                                                     // PerQuestionPayload 结束

/// 可执行动作
struct TopActionPayload: Decodable {                                  // 返回体的动作项
    let action: String?                                                // 做什么
    let why: String?                                                   // 为什么
    let howToCheck: String?                                            // 怎么自检
}                                                                     // TopActionPayload 结束

/// 总结响应
struct SummaryResponse: Decodable {                                   // 返回体
    let requestId: String?                                             // 请求 id
    let headline: String?                                              // 一句话结论
    let perQuestion: [PerQuestionPayload]?                             // 逐题复盘
    let topActions: [TopActionPayload]?                                // 可执行动作
    let confidence: String?                                            // 置信度
    let uncertainty: [String]?                                         // 不确定项
    let disclaimer: String?                                            // 强制声明
}                                                                     // SummaryResponse 结束

// MARK: - 协议                                                          // 分节：协议

/// 面试服务。Mock 与 Remote 必须实现同一套语义：
/// 同样的输入给同样的结构，同样的失败给同样的错误。
protocol InterviewService {  // 服务协议（不加 Sendable，避免 URLSession 并发检查带来的编译风险）
    func nextQuestion(_ request: TurnRequest) async throws -> TurnResponse  // 出题
    func evaluate(_ request: EvaluateRequest) async throws -> EvaluateResponse  // 评分
    func summarize(_ request: SummaryRequest) async throws -> SummaryResponse  // 总结
}  // 协议结束

// MARK: - 错误                                                          // 分节：错误

/// BFF 返回的错误体
struct BFFErrorBody: Decodable {                                      // 错误载荷
    let code: String?                                                  // 错误码
    let message: String?                                               // 错误描述
    let retriable: Bool?                                               // 能否重试
}                                                                     // BFFErrorBody 结束

/// 把 HTTP 状态码与错误码翻译成 AppError，保证 UI 只认一种错误
func mapBFFError(status: Int, body: BFFErrorBody?) -> AppError {       // 映射函数
    switch body?.code {                                                // 先看业务错误码
    case "quotaExceeded": return .quotaExceeded                        // 额度用完
    case "unauthorized", "missing_device": return .unauthorized        // 鉴权失败
    case "timeout": return .timeout                                    // 超时
    case "aiUnavailable": return .aiUnavailable(body?.message ?? "服务端异常") // AI 不可用
    default: break                                                     // 其它看状态码
    }                                                                  // 分支结束
    switch status {                                                    // 再看 HTTP 状态
    case 401: return .unauthorized                                     // 未授权
    case 429: return .quotaExceeded                                    // 限流
    case 504: return .timeout                                          // 网关超时
    case 502, 503: return .aiUnavailable(body?.message ?? "服务不可用")  // 服务异常
    default: return .network("HTTP \(status)")                         // 其它归为网络
    }                                                                  // 分支结束
}                                                                     // 映射结束
