//  InterviewDomainTests.swift —— 面试领域模型的不变量测试               // 文件说明
//  锁住政策依据与状态机规则：导师 5 人、每场 1200 秒、终态只有两个          // 测试目标
//  这些是「还原真实考场」的底线，改坏了就等于不按教育部规定做              // 风险说明

import XCTest                       // 测试框架
@testable import FuShiZhuan         // 拿到被测模块的内部类型

final class InterviewDomainTests: XCTestCase {  // 面试领域测试

    // MARK: - 政策依据                                                  // 分节：政策

    func testSeatedMentorsCountIsFive() {                              // 面试小组不少于 5 人
        XCTAssertEqual(MentorRole.seated.count, 5)                     // 教育部规定小组不少于 5 人
    }                                                                  // 测试结束

    func testSecretaryIsNotSeated() {                                  // 秘书只记录不提问
        XCTAssertFalse(MentorRole.seated.contains(.secretary))         // 秘书不在提问席
        XCTAssertFalse(MentorRole.secretary.scores)                    // 秘书不参与评分
    }                                                                  // 测试结束

    func testAllSeatedMentorsScore() {                                 // 坐着的五位都要打分
        for role in MentorRole.seated {                                // 逐个检查
            XCTAssertTrue(role.scores, "\(role.title) 应该参与评分")     // 断言打分
        }                                                              // 循环结束
    }                                                                  // 测试结束

    func testTotalDurationIsTwentyMinutes() {                          // 全场合计 1200 秒
        let total = InterviewPhase.allCases.reduce(0) { $0 + $1.seconds }  // 逐环节累加
        XCTAssertEqual(total, 1_200)                                   // 20 分钟，教育部规定每生不少于 20 分钟
    }                                                                  // 测试结束

    func testEachPhaseDuration() {                                     // 逐环节时长
        XCTAssertEqual(InterviewPhase.opening.seconds, 60)             // 开场 1 分钟
        XCTAssertEqual(InterviewPhase.foreign.seconds, 300)            // 外语 5 分钟
        XCTAssertEqual(InterviewPhase.major.seconds, 540)              // 专业 9 分钟
        XCTAssertEqual(InterviewPhase.comprehensive.seconds, 240)      // 综合 4 分钟
        XCTAssertEqual(InterviewPhase.closing.seconds, 60)             // 收尾 1 分钟
    }                                                                  // 测试结束

    func testMajorPhaseSpeakers() {                                    // 专业环节由谁提问
        XCTAssertEqual(InterviewPhase.major.speakers, [.majorA, .majorB, .lead])  // 两位专业导师加组长
        XCTAssertEqual(InterviewPhase.opening.speakers, [.lead])       // 开场只有组长
        XCTAssertEqual(InterviewPhase.foreign.speakers, [.foreign])    // 外语只有外语导师
    }                                                                  // 测试结束

    // MARK: - 状态机                                                    // 分节：状态机

    func testOnlyTwoTerminalStates() {                                 // 终态只有归档与放弃
        XCTAssertTrue(InterviewState.archived.isTerminal)              // 归档是终态
        XCTAssertTrue(InterviewState.abandoned.isTerminal)             // 放弃是终态
        XCTAssertFalse(InterviewState.idle.isTerminal)                 // 未开始不是
        XCTAssertFalse(InterviewState.asking.isTerminal)               // 提问中不是
        XCTAssertFalse(InterviewState.evaluating.isTerminal)           // 评分中不是
    }                                                                  // 测试结束

    func testFeedbackIsNotTerminal() {                                 // 出结果之后还要再推一步
        XCTAssertFalse(InterviewState.feedback.isTerminal)             // feedback 不算终态
    }                                                                  // 测试结束

    func testTimerRunsWhileAskingAndStopsWhenPaused() {                // 计时开关
        XCTAssertTrue(InterviewState.greeting.timerRunning)            // 开场计时走
        XCTAssertTrue(InterviewState.asking.timerRunning)              // 提问计时走
        XCTAssertTrue(InterviewState.listening.timerRunning)           // 录音计时走
        XCTAssertFalse(InterviewState.paused.timerRunning)             // 暂停不走
        XCTAssertFalse(InterviewState.archived.timerRunning)           // 归档不走
        XCTAssertFalse(InterviewState.idle.timerRunning)               // 未开始不走
    }                                                                  // 测试结束

    func testEveryStateHasTitle() {                                    // 每个状态都有中文文案
        let states: [InterviewState] = [                               // 手工列出全部 17 个状态
            .idle, .preparing, .connecting, .greeting, .asking,         // 前五个
            .listening, .transcribing, .reviewing, .evaluating,         // 中间四个
            .followingUp, .switching, .paused, .finishing, .feedback,   // 再五个
            .archived, .error, .abandoned                               // 最后三个
        ]                                                              // 数组结束
        XCTAssertEqual(states.count, 17)                               // 确认是 17 态
        for state in states {                                          // 逐个检查
            XCTAssertFalse(state.title.isEmpty, "状态 \(state.rawValue) 缺少文案")  // 文案不能为空
        }                                                              // 循环结束
    }                                                                  // 测试结束

    // MARK: - 会话派生数据                                              // 分节：会话

    func testRemainingSecondsNeverNegative() {                         // 剩余秒数不为负
        var session = InterviewSession(limitSeconds: 60)               // 限时 60 秒
        session.elapsedSeconds = 90                                    // 已超时 30 秒
        XCTAssertEqual(session.remainingSeconds, 0)                    // 最低是 0
    }                                                                  // 测试结束

    func testAnsweredCountSkipsBlank() {                               // 空回答不算答过
        var session = InterviewSession()                               // 空会话
        session.turns = [                                              // 造三轮
            InterviewTurn(index: 0, phase: .opening, speaker: .lead, question: "问一", answer: "答了"),  // 已答
            InterviewTurn(index: 1, phase: .opening, speaker: .lead, question: "问二", answer: "   "),   // 空白
            InterviewTurn(index: 2, phase: .opening, speaker: .lead, question: "问三", answer: "")       // 未答
        ]                                                              // 数组结束
        XCTAssertEqual(session.answeredCount, 1)                       // 只有一轮算答过
    }                                                                  // 测试结束

    func testOverallScoreIgnoresUnjudged() {                           // 综合分只算可判维度
        var session = InterviewSession()                               // 空会话
        session.scores = [                                             // 造两个维度
            DimensionScore(dimension: .completeness, score: 80, evidence: "原话", comment: ""),  // 可判 80
            DimensionScore(dimension: .manner, score: 0, evidence: "", comment: "")             // 不可判
        ]                                                              // 数组结束
        XCTAssertEqual(session.overallScore, 80)                       // 不应把 0 分算进平均
    }                                                                  // 测试结束

    func testOverallScoreNilWhenNothingJudged() {                      // 全不可判就返回 nil
        var session = InterviewSession()                               // 空会话
        session.scores = [DimensionScore(dimension: .manner, score: 0, evidence: "", comment: "")]  // 只有不可判
        XCTAssertNil(session.overallScore)                             // 应为 nil，页面据此不显示分数
    }                                                                  // 测试结束

    func testIsOfflineDetectsTag() {                                   // 离线标记能被识别
        var session = InterviewSession()                               // 空会话
        XCTAssertFalse(session.isOffline)                              // 默认不是离线
        session.uncertainty = ["\(InterviewNotes.offlineTag)：模型未参与"]  // 写入离线说明
        XCTAssertTrue(session.isOffline)                               // 应识别为离线
    }                                                                  // 测试结束

    func testTurnIsAnsweredTrimsWhitespace() {                         // 判断是否作答要去空白
        let blank = InterviewTurn(index: 0, phase: .major, speaker: .lead, question: "问", answer: "  \n ")  // 全是空白
        let filled = InterviewTurn(index: 1, phase: .major, speaker: .lead, question: "问", answer: "答")    // 有内容
        XCTAssertFalse(blank.isAnswered)                               // 空白不算作答
        XCTAssertTrue(filled.isAnswered)                               // 有内容算作答
    }                                                                  // 测试结束

    func testScaleNoteIsPresent() {                                    // 量表声明必须存在
        XCTAssertTrue(ScoreDimension.scaleNote.contains("非院校官方评分"))   // 这句话不能删，是合规要求
    }                                                                  // 测试结束
}                                                                    // 测试类结束
