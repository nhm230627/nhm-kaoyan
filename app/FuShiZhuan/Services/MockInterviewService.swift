//  MockInterviewService.swift —— 假实现                                // 文件说明
//  用途：没启动 BFF、或做 UI 开发时也能把流程走通                       // 使用场景
//  铁律：返回结构与真实接口完全一致，且 evidence 必须真出自回答原文      // 一致性约束

import Foundation                                                     // 基础库

struct MockInterviewService: InterviewService {                       // 假实现
    var delayMilliseconds: Int = 600                                  // 模拟网络延迟
    var failure: AppError? = nil                                      // 注入失败，便于测异常分支

    func nextQuestion(_ request: TurnRequest) async throws -> TurnResponse { // 出题
        try await wait()                                              // 模拟延迟或抛错
        let offline = OfflineQuestions.question(phase: request.phase, index: request.turnIndex) // 与离线兜底同一份题
        return TurnResponse(                                          // 组装返回
            requestId: UUID().uuidString,                             // 随机请求 id
            question: offline.question,                               // 问题
            knowledgePoints: offline.points                           // 知识点
        )                                                             // 组装结束
    }                                                                 // 方法结束

    func evaluate(_ request: EvaluateRequest) async throws -> EvaluateResponse { // 评分
        try await wait()                                              // 模拟延迟或抛错
        let answer = request.answer                                   // 考生回答
        let evidence = Self.firstSentence(answer)                     // 取原文首句当证据
        let hasEvidence = !evidence.isEmpty                           // 有原话才算可判

        var evaluation: [String: DimensionPayload] = [:]              // 结果容器
        for (key, score) in Self.baseScores {                         // 遍历五个维度
            evaluation[key] = DimensionPayload(                       // 组装单维
                score: hasEvidence ? score : 0,                       // 没证据给 0
                evidence: hasEvidence ? evidence : "",                 // 没证据留空
                comment: hasEvidence ? "模拟点评：表述基本到位" : ""     // 没证据不给点评
            )                                                         // 组装结束
        }                                                             // 遍历结束

        let uncertainty = hasEvidence ? nil : "回答太短，各维度缺少可判断依据" // 无证据说明
        return EvaluateResponse(                                      // 组装返回
            requestId: UUID().uuidString,                             // 随机 id
            evaluation: evaluation,                                   // 五维
            improvements: [                                           // 一条改进建议
                ImprovementPayload(                                   // 建议
                    issue: "缺少具体政策依据",                          // 问题
                    example: evidence,                                // 考生原话
                    rewrite: "先给结论，再补一条政策原文，最后说影响"     // 改写示例
                )                                                     // 建议结束
            ],                                                        // 建议数组结束
            confidence: hasEvidence ? "medium" : "low",               // 置信度
            uncertainty: uncertainty                                  // 说明
        )                                                             // 组装结束
    }                                                                 // 方法结束

    func summarize(_ request: SummaryRequest) async throws -> SummaryResponse { // 总结
        try await wait()                                              // 模拟延迟或抛错
        return SummaryResponse(                                       // 组装返回
            requestId: UUID().uuidString,                             // 随机 id
            headline: "模拟总结：结构清楚，但缺政策依据",                  // 结论
            perQuestion: request.turns.map { turn in                  // 逐题生成
                PerQuestionPayload(                                   // 单题
                    question: turn.question,                          // 问题
                    yourPoints: ["提到了基本概念"],                     // 答到的
                    missingPoints: ["没引用条文", "没说影响"],           // 漏掉的
                    followUpExposed: "追问时停顿较长"                   // 追问暴露
                )                                                     // 单题结束
            },                                                        // 映射结束
            topActions: [                                             // 动作列表
                TopActionPayload(action: "每道题补一句政策原文", why: "评分看重依据", howToCheck: "能背出条文号"), // 动作一
                TopActionPayload(action: "用总分总结构回答", why: "逻辑分偏低", howToCheck: "录音回放能听出三段") // 动作二
            ],                                                        // 动作结束
            confidence: "medium",                                     // 置信度
            uncertainty: ["模拟数据，不代表真实评估"],                    // 不确定项
            disclaimer: "训练量表，非院校官方评分；不预测录取结果"          // 强制声明
        )                                                             // 组装结束
    }                                                                 // 方法结束

    // MARK: - 内部工具                                                  // 分节：工具

    /// 模拟延迟；若注入了错误则直接抛
    private func wait() async throws {                                // 延迟函数
        if let failure { throw failure }                              // 有注入错误先抛
        try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000) // 睡一会
    }                                                                 // 方法结束

    /// 取回答的第一句（用句号/问号/感叹号切），保证是原文子串
    private static func firstSentence(_ text: String) -> String {      // 取首句
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines) // 去空白
        guard !trimmed.isEmpty else { return "" }                      // 空回答返回空
        let separators = CharacterSet(charactersIn: "。！？.!?\n")      // 断句符
        if let range = trimmed.rangeOfCharacter(from: separators) {     // 找到第一个断句符
            let head = String(trimmed[..<range.lowerBound])            // 截取前半
            return head.isEmpty ? trimmed : head                       // 太短就用整段
        }                                                             // 分支结束
        return trimmed                                                // 没有断句符就用整段
    }                                                                 // 方法结束

    /// 五个维度的基准分
    private static let baseScores: [(String, Int)] = [                 // 维度与分数
        ("completeness", 62),                                         // 内容完整性
        ("logic", 70),                                                // 逻辑结构
        ("professionalExpression", 55),                                // 专业表达
        ("languageOrganization", 66),                                  // 语言组织
        ("manner", 72)                                                 // 综合素养
    ]                                                                 // 数组结束
}                                                                     // MockInterviewService 结束
