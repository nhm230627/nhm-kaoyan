//  LocalEvaluatorTests.swift —— 离线粗评的规则测试                    // 文件说明
//  锁住三条诚实原则：短答不许拿高分、证据必须出自原话、判不出就说判不出     // 测试目标
//  这套规则在断网时替模型兜底，一旦放宽就等于向用户编分数                // 风险说明

import XCTest                       // 测试框架
@testable import FuShiZhuan         // 拿到被测模块的内部类型

final class LocalEvaluatorTests: XCTestCase {  // 离线评分测试

    /// 造一个中文环节的评分请求
    private func request(_ answer: String, speaker: MentorRole = .majorA) -> EvaluateRequest {  // 构造请求
        EvaluateRequest(                                          // 请求体
            sessionId: "test-session",                            // 固定场次
            turnIndex: 0,                                         // 第 0 轮
            speaker: speaker.rawValue,                            // 提问人
            question: "请谈谈你对税收中性的理解",                      // 固定问题
            answer: answer                                        // 待评回答
        )                                                         // 请求体结束
    }                                                             // 方法结束

    /// 取某一维的分
    private func score(_ response: EvaluateResponse, _ dimension: ScoreDimension) -> Int? {  // 读分
        response.evaluation[dimension.rawValue]?.score                // 从字典里取
    }                                                                 // 方法结束

    // MARK: - 短答不许拿高分                                            // 分节：封顶

    func testShortAnswerIsCappedAt50() {                                   // 不足 20 字的回答封顶 50
        let response = LocalEvaluator.evaluate(request("因为税负要公平"))       // 只有 7 个字
        for dimension in ScoreDimension.allCases where dimension != .manner {  // 逐维检查
            let value = score(response, dimension) ?? 0                     // 取分
            XCTAssertLessThanOrEqual(value, 50, "短答不该超过 50：\(dimension.title)")  // 断言封顶
        }                                                                   // 循环结束
    }                                                                       // 测试结束

    func testLongAnswerCanExceed50() {                                  // 超过 20 字放开到 92
        let long = "首先税收中性是指税收不应改变纳税人的经济选择。其次它要求税制尽量少干预市场配置。最后在我国增值税的抵扣链条就是为了减少重复征税。因此中性原则与效率原则高度一致。"  // 约 76 字的长答
        let response = LocalEvaluator.evaluate(request(long))            // 一百多字
        XCTAssertGreaterThan(score(response, .completeness) ?? 0, 50)     // 完整性应超过 50
    }                                                                    // 测试结束

    func testLongerAnswerScoresHigher() {                               // 同等条件下字数越多分越高
        let shortText = "税收中性要求税制不干预市场选择因为干扰会带来额外损失所以要保持克制"  // 33 字
        let longText = shortText + "首先税负要可预期其次征管成本要低最后纳税人要能自己判断"    // 更长的版本
        let a = LocalEvaluator.evaluate(request(shortText))               // 短文评分
        let b = LocalEvaluator.evaluate(request(longText))                // 长文评分
        XCTAssertGreaterThanOrEqual(score(b, .completeness) ?? 0, score(a, .completeness) ?? 0)  // 不应更差
    }                                                                     // 测试结束

    // MARK: - 证据必须出自原话                                          // 分节：证据

    func testEvidenceIsSubstringOfAnswer() {                             // 证据必须是考生原话的一部分
        let answer = "税收中性要求税制不改变纳税人的经济选择。另外还要考虑征管成本。"  // 两句
        let response = LocalEvaluator.evaluate(request(answer))           // 评分
        let evidence = response.evaluation[ScoreDimension.completeness.rawValue]?.evidence ?? ""  // 取证据
        XCTAssertFalse(evidence.isEmpty)                                  // 应有证据
        XCTAssertTrue(answer.contains(evidence), "证据必须出自原话，实际取到：\(evidence)")  // 断言子串
    }                                                                     // 测试结束

    // MARK: - 判不出来就说判不出来                                       // 分节：诚实

    func testMannerIsAlwaysUnjudged() {                                  // 综合素养离线永远不判
        let response = LocalEvaluator.evaluate(request("首先我认为税负要公平其次要有效最后要便于征管"))  // 结构完整的回答
        let manner = response.evaluation[ScoreDimension.manner.rawValue]  // 取素养维度
        XCTAssertEqual(manner?.score, 0)                                  // 分数为 0
        XCTAssertEqual(manner?.evidence, "")                              // 证据为空
        XCTAssertEqual(manner?.comment, "")                               // 不编点评
    }                                                                     // 测试结束

    func testConfidenceIsAlwaysLow() {                                    // 离线永远低置信
        let response = LocalEvaluator.evaluate(request("税负"))              // 随便一个回答
        XCTAssertEqual(response.confidence, "low")                         // 置信度固定 low
    }                                                                     // 测试结束

    func testUncertaintyCarriesOfflineTag() {                             // 必须打上离线标记
        let response = LocalEvaluator.evaluate(request("税负公平"))           // 评分
        let note = response.uncertainty ?? ""                              // 说明文字
        XCTAssertTrue(note.hasPrefix(LocalEvaluator.tag))                  // 以标记开头，UI 靠它识别
    }                                                                     // 测试结束

    // MARK: - 专业词与外语                                              // 分节：识别

    func testTaxTermsRaiseProfessionalScore() {                          // 术语越多专业表达越高
        let plain = "这个问题的答案我认为需要从多个方面来看而且要结合实际工作情况加以分析说明"    // 无术语
        let rich = "增值税的税基、税率与进项抵扣共同决定税负，征管成本也是重要考量，还要看发票链条"  // 多个术语
        let a = LocalEvaluator.evaluate(request(plain))                   // 无术语评分
        let b = LocalEvaluator.evaluate(request(rich))                    // 有术语评分
        XCTAssertGreaterThan(score(b, .professionalExpression) ?? 0, score(a, .professionalExpression) ?? 0)  // 应更高
    }                                                                     // 测试结束

    func testForeignPhaseUsesEnglishWords() {                            // 外语环节按英文词数打分
        let english = "I choose taxation because it is the foundation of public finance and I want to work on tax policy design in the future"  // 约 24 个英文词的答句
        let response = LocalEvaluator.evaluate(request(english, speaker: .foreign))  // 外语环节评分
        let professional = score(response, .professionalExpression) ?? 0  // 专业表达分
        XCTAssertGreaterThan(professional, 40)                            // 英文词够多应高于基础分 40
    }                                                                     // 测试结束

    // MARK: - 建议条数                                                  // 分节：建议

    func testImprovementsLimitedToTwo() {                                // 建议最多两条
        let response = LocalEvaluator.evaluate(request("不知道"))             // 什么都缺的回答
        XCTAssertLessThanOrEqual(response.improvements.count, 2)            // 不超过两条
    }                                                                     // 测试结束

    // MARK: - 整场总结                                                  // 分节：总结

    func testSummaryMentionsOfflineTag() {                                // 总结开头必须声明离线
        let turns = [SummaryRequest.SummaryTurn(index: 0, phase: "major", speaker: "majorA", question: "问题", answer: "回答内容")]  // 一轮
        let scores = [DimensionScore(dimension: .completeness, score: 70, evidence: "回答内容", comment: "")]  // 一个可判维度
        let response = LocalEvaluator.summarize(turns: turns, scores: scores)  // 生成总结
        XCTAssertTrue((response.headline ?? "").hasPrefix(LocalEvaluator.tag))  // 结论带离线标记
        XCTAssertTrue((response.uncertainty ?? []).first?.hasPrefix(LocalEvaluator.tag) ?? false)  // 说明也带标记
        XCTAssertEqual(response.confidence, "low")                         // 低置信
        XCTAssertEqual(response.disclaimer, ScoreDimension.scaleNote)      // 强制带上量表声明
    }                                                                     // 测试结束

    func testSummaryWithoutJudgedDimensions() {                           // 全不可判时如实说明
        let turns = [SummaryRequest.SummaryTurn(index: 0, phase: "major", speaker: "majorA", question: "问题", answer: "答了")]  // 一轮
        let scores = [DimensionScore(dimension: .manner, score: 0, evidence: "", comment: "")]  // 只有不可判维度
        let response = LocalEvaluator.summarize(turns: turns, scores: scores)  // 生成总结
        XCTAssertTrue((response.headline ?? "").contains("没有可判分"))         // 应明说没有可判分的回答
    }                                                                        // 测试结束

    func testSummaryCountsAnsweredTurns() {                               // 只数真正作答的轮次
        let turns = [                                                      // 两轮
            SummaryRequest.SummaryTurn(index: 0, phase: "major", speaker: "majorA", question: "问一", answer: "答了"),  // 有答
            SummaryRequest.SummaryTurn(index: 1, phase: "major", speaker: "majorA", question: "问二", answer: "   ")   // 空白
        ]                                                                  // 数组结束
        let scores = [DimensionScore(dimension: .logic, score: 60, evidence: "答了", comment: "")]  // 一个可判维度
        let response = LocalEvaluator.summarize(turns: turns, scores: scores)  // 生成总结
        XCTAssertTrue((response.headline ?? "").contains("共作答 1 轮"))          // 空白的一轮不计数
    }                                                                         // 测试结束
}                                                                             // 测试类结束
