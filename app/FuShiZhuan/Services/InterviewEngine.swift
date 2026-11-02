//  InterviewEngine.swift —— 面试状态机驱动                             // 文件说明
//  唯一职责：按 InterviewState 推进流程，视图只读状态、只调方法          // 职责约束
//  状态转移全在这里，视图层不许写 if 拼流程                            // 架构约束

import Foundation                                                     // 基础库
import Observation                                                    // 观察框架

@Observable                                                           // 视图自动刷新
final class InterviewEngine {                                         // 面试引擎
    private(set) var session: InterviewSession                        // 当前这场面试
    private(set) var currentQuestion: String = ""                     // 当前问题
    private(set) var currentSpeaker: MentorRole = .lead               // 当前提问人
    private(set) var knowledgePoints: [String] = []                   // 本题知识点
    private(set) var error: AppError?                                 // 最近一次错误
    private(set) var isBusy = false                                    // 是否正在等网络
    private var isFinishing = false                                   // 是否正在收尾，专门防重入

    private let service: InterviewService                             // 服务实现
    private var plan: [(phase: InterviewPhase, count: Int)] = []       // 本场题量计划
    private var step = 0                                              // 已推进到第几题
    private var ticker: Task<Void, Never>?                            // 计时任务

    /// 题量计划：开场 1、外语 2、专业 3、综合 2、收尾 1，共 9 轮
    static let defaultPlan: [(InterviewPhase, Int)] = [                // 默认计划
        (.opening, 1),                                                // 开场
        (.foreign, 2),                                                // 外语
        (.major, 3),                                                  // 专业
        (.comprehensive, 2),                                          // 综合
        (.closing, 1)                                                 // 收尾
    ]                                                                 // 计划结束

    init(service: InterviewService? = nil) {                           // 构造器，可注入 Mock
        self.service = service ?? (AppConfig.useMockService             // 按配置选实现
            ? MockInterviewService()                                   // 本地 Mock，不联网
            : RemoteInterviewService())                                // 真实 BFF
        self.session = InterviewSession()                             // 先建一个空会话
        self.plan = Self.defaultPlan.map { ($0.0, $0.1) }             // 复制计划
    }                                                                 // 构造结束

    // MARK: - 只读派生                                                  // 分节：派生

    /// 当前环节
    var phase: InterviewPhase { session.phase }                        // 转发

    /// 总题数
    var totalSteps: Int { plan.reduce(0) { $0 + $1.count } }           // 累加计划

    /// 第几题（从 1 开始）
    var stepNumber: Int { min(step + 1, max(totalSteps, 1)) }          // 不超过总数

    /// 是否可以作答
    var canAnswer: Bool { session.state == .asking && !isBusy }        // 提问中且不忙

    /// 是否已结束
    var isFinished: Bool { session.state == .feedback || session.state == .archived || session.state == .abandoned } // 终态判断

    // MARK: - 开始                                                      // 分节：开始

    func start(mode: InterviewMode, style: MentorStyle, tier: RenderTier) async { // 开始一场
        session = InterviewSession(mode: mode, style: style, tier: tier, state: .connecting) // 新会话
        error = nil                                                   // 清错误
        step = 0                                                      // 重置进度
        await askNext()                                               // 出第一题
        startTimer()                                                  // 开始计时
    }                                                                 // 方法结束

    // MARK: - 作答                                                      // 分节：作答

    func submit(_ answer: String) async {                             // 提交一轮回答
        guard !isBusy, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return } // 防重复提交与空答
        isBusy = true                                                 // 标记忙

        if let idx = session.turns.indices.last {                     // 找到最后一轮
            session.turns[idx].answer = answer                        // 写入回答
            session.turns[idx].answeredAt = .now                      // 记作答时间
        }                                                             // 分支结束
        session.state = .evaluating                                   // 进入评分

        do {                                                          // 尝试评分
            let resp = try await service.evaluate(                    // 调服务
                EvaluateRequest(                                      // 组装请求
                    sessionId: session.id.uuidString,                 // 场次 id
                    turnIndex: step,                                  // 轮次
                    speaker: currentSpeaker.rawValue,                 // 提问人
                    question: currentQuestion,                        // 问题
                    answer: answer                                    // 回答
                )                                                     // 组装结束
            )                                                         // 请求结束
            applyEvaluation(resp)                                     // 写入评分
            error = nil                                               // 清错误
            await advance()                                           // 推进下一题或收尾
        } catch {                                                     // 评分失败
            if fallbackEvaluate(answer: answer, cause: error) {         // 能离线顶上就先顶上
                await advance()                                       // 继续下一题，整场不中断
            } else {                                                  // 兜不住（额度/鉴权）
                handle(error)                                         // 交给统一错误处理
            }                                                         // 分支结束
        }                                                             // 分支结束
        isBusy = false                                                // 解除忙
    }                                                                 // 方法结束

    // MARK: - 推进                                                      // 分节：推进

    private func advance() async {                                    // 推进到下一题
        step += 1                                                     // 步数加一
        if step >= totalSteps {                                       // 全部答完
            await finish()                                            // 直接收尾
        } else {                                                      // 还有题
            await askNext()                                           // 出下一题
        }                                                             // 分支结束
    }                                                                 // 方法结束

    private func askNext() async {                                    // 请求下一题
        guard let target = targetForStep(step) else { await finish(); return } // 没有目标就收尾
        session.phase = target.phase                                  // 更新环节
        currentSpeaker = pickSpeaker(for: target.phase, index: step)   // 选提问人
        session.state = .asking                                       // 进入提问

        do {                                                          // 尝试出题
            let resp = try await service.nextQuestion(                // 调服务
                TurnRequest(                                          // 组装请求
                    sessionId: session.id.uuidString,                 // 场次 id
                    turnIndex: step,                                  // 轮次
                    phase: target.phase.rawValue,                     // 环节
                    speaker: currentSpeaker.rawValue,                 // 提问人
                    mode: session.mode.rawValue,                      // 类型
                    style: session.style.rawValue,                    // 风格
                    history: history()                                // 历史问答
                )                                                     // 组装结束
            )                                                         // 请求结束
            currentQuestion = resp.question                            // 记下问题
            knowledgePoints = resp.knowledgePoints                     // 记下知识点
            session.turns.append(                                     // 追加一轮
                InterviewTurn(                                        // 构造轮次
                    index: step,                                      // 轮次号
                    phase: target.phase,                              // 环节
                    speaker: currentSpeaker,                          // 提问人
                    question: resp.question                           // 问题
                )                                                     // 构造结束
            )                                                         // 追加结束
            error = nil                                               // 清错误
        } catch {                                                     // 出题失败
            if fallbackQuestion(phase: target.phase, index: step, cause: error) { // 离线题库顶上
                return                                                // 已经就位，直接返回
            }                                                         // 分支结束
            handle(error)                                             // 兜不住才走统一错误
        }                                                             // 分支结束
    }                                                                 // 方法结束

    // MARK: - 收尾                                                      // 分节：收尾

    func finish() async {                                             // 生成总结并结束
        // 这里不能用 isBusy 当重入锁：答完最后一题时 submit 正持有 isBusy，
        // 用 isBusy 判断会让 finish 直接 return，本场永远停在「评分中」。
        guard !isFinishing else { return }                            // 只防收尾自身重入
        isFinishing = true                                            // 标记收尾中
        isBusy = true                                                 // 让按钮显示忙
        stopTimer()                                                   // 停计时
        session.state = .finishing                                    // 进入收尾

        let request = SummaryRequest(                                 // 组装请求（离线总结复用同一份）
            sessionId: session.id.uuidString,                         // 场次 id
            mode: session.mode.rawValue,                              // 类型
            turns: session.turns.map { turn in                        // 逐轮转换
                SummaryRequest.SummaryTurn(                           // 构造单轮
                    index: turn.index,                                // 轮次
                    phase: turn.phase.rawValue,                       // 环节
                    speaker: turn.speaker.rawValue,                   // 提问人
                    question: turn.question,                          // 问题
                    answer: turn.answer                               // 回答
                )                                                     // 构造结束
            }                                                         // 映射结束
        )                                                             // 组装结束

        do {                                                          // 尝试总结
            let resp = try await service.summarize(request)           // 调服务
            session.headline = resp.headline ?? ""                    // 结论
            session.uncertainty = resp.uncertainty ?? []              // 不确定项
            session.summaryGenerated = true                           // 标记已生成
            error = nil                                               // 清错误
            session.endedAt = .now                                    // 结束时间
            session.state = .feedback                                 // 出结果
        } catch {                                                     // 总结失败
            applyLocalSummary(request: request)                       // 离线总结顶上，不许空白结束
            if let appError = error as? AppError, !appError.allowsLocalFallback { // 兜不住的才亮错
                self.error = appError                                 // 让用户看见
            }                                                         // 分支结束
        }                                                             // 分支结束
        // 出结果即归档：成长值与「第一场完成」的判定都靠 .archived，不做这一步就永远发不出成长值
        if session.state == .feedback { session.state = .archived }    // 只在本场正常出结果时归档
        isBusy = false                                                // 解除忙
        isFinishing = false                                            // 收尾结束
    }                                                                 // 方法结束

    // MARK: - 控制                                                      // 分节：控制

    func pause() {                                                    // 暂停
        guard session.state != .paused else { return }                // 已暂停就不动
        session.state = .paused                                       // 进入暂停
        stopTimer()                                                   // 停计时
    }                                                                 // 方法结束

    func resume() {                                                   // 恢复
        guard session.state == .paused else { return }                // 非暂停不动
        session.state = .asking                                       // 回到提问
        startTimer()                                                  // 继续计时
    }                                                                 // 方法结束

    func abandon() {                                                  // 主动放弃
        stopTimer()                                                   // 停计时
        session.state = .abandoned                                    // 标记未完成
        session.endedAt = .now                                        // 结束时间
    }                                                                 // 方法结束

    /// 重试当前这一步：只清错误是不够的，必须把状态从 error 拉回 asking，否则按钮永远不可用
    func retry() async {                                              // 重试当前题
        guard !isBusy else { return }                                 // 正在请求就别叠加
        error = nil                                                   // 先清错误
        if currentQuestion.isEmpty {                                  // 连题都没出出来
            await askNext()                                           // 重新出题
        } else {                                                      // 题已经在了
            session.state = .asking                                   // 回到可作答
            startTimer()                                              // 恢复计时
        }                                                             // 分支结束
    }                                                                 // 方法结束

    func clearError() { error = nil }                                  // 清错误

    // MARK: - 内部工具                                                  // 分节：工具

    /// 第 n 步属于哪个环节
    private func targetForStep(_ n: Int) -> (phase: InterviewPhase, count: Int)? { // 定位环节
        var cursor = 0                                                // 计数器
        for item in plan {                                            // 遍历计划
            if n < cursor + item.count { return item }                // 落在本段
            cursor += item.count                                       // 推进计数
        }                                                             // 遍历结束
        return nil                                                    // 超出计划
    }                                                                 // 方法结束

    /// 按环节选提问人（追问归属由角色决定，不随机漂移）
    private func pickSpeaker(for phase: InterviewPhase, index: Int) -> MentorRole { // 选人
        let pool = phase.speakers                                     // 该环节可提问的人
        guard !pool.isEmpty else { return .lead }                     // 兜底组长
        return pool[index % pool.count]                                // 轮流提问
    }                                                                 // 方法结束

    /// 已问过的问答，供模型接续
    private func history() -> [TurnRequest.HistoryItem] {              // 生成历史
        session.turns.map { turn in                                   // 逐轮转换
            TurnRequest.HistoryItem(                                  // 构造单条
                question: turn.question,                              // 问题
                answer: turn.answer,                                  // 回答
                speaker: turn.speaker.rawValue                         // 提问人
            )                                                         // 构造结束
        }                                                             // 映射结束
    }                                                                 // 方法结束

    /// 把服务返回的五维评分写进会话
    private func applyEvaluation(_ resp: EvaluateResponse) {           // 写入评分
        var dims: [DimensionScore] = []                               // 结果容器
        for dimension in ScoreDimension.allCases {                    // 遍历五个维度
            let payload = resp.evaluation[dimension.rawValue]         // 取对应载荷
            dims.append(                                              // 追加一维
                DimensionScore(                                       // 构造单维
                    dimension: dimension,                             // 维度
                    score: payload?.score ?? 0,                       // 分数
                    evidence: payload?.evidence ?? "",                // 证据
                    comment: payload?.comment ?? ""                   // 点评
                )                                                     // 构造结束
            )                                                         // 追加结束
        }                                                             // 遍历结束
        session.scores = dims                                         // 覆盖评分
        session.improvements = resp.improvements.map { item in        // 转换建议
            Improvement(issue: item.issue, example: item.example, rewrite: item.rewrite) // 建议
        }                                                             // 映射结束
        // 幂等：同样的说明只记一次，避免九个回合写九条重复的离线提示
        if let note = resp.uncertainty, !note.isEmpty, !session.uncertainty.contains(note) { // 有说明且没记过
            session.uncertainty.append(note)                          // 累积
        }                                                             // 分支结束
    }                                                                 // 方法结束

    /// 用离线题库顶替一次失败的出题。只有服务侧问题才允许，额度/鉴权失败必须让用户看见
    private func fallbackQuestion(phase: InterviewPhase, index: Int, cause: Error) -> Bool { // 离线出题
        if let appError = cause as? AppError {                        // 已知类型的错误
            guard appError.allowsLocalFallback else { return false }   // 不允许就不兜
        }                                                             // 未知异常按服务侧问题处理
        let offline = OfflineQuestions.question(phase: phase.rawValue, index: index) // 取离线题
        currentQuestion = offline.question                            // 记下问题
        knowledgePoints = offline.points                              // 记下知识点
        session.turns.append(                                         // 追加一轮
            InterviewTurn(                                            // 构造轮次
                index: index,                                         // 轮次号
                phase: phase,                                         // 环节
                speaker: currentSpeaker,                              // 提问人
                question: offline.question                            // 问题
            )                                                         // 构造结束
        )                                                             // 追加结束
        session.state = .asking                                       // 回到可作答
        noteOffline()                                                 // 记一笔离线说明
        error = nil                                                   // 不留红色错误条
        return true                                                   // 兜住了
    }                                                                 // 方法结束

    /// 记录「本场用过离线兜底」，同样的说明只写一次
    private func noteOffline() {                                      // 记录离线
        guard !session.uncertainty.contains(where: { $0.hasPrefix(InterviewNotes.offlineTag) }) else { return } // 已记过就不写
        session.uncertainty.append("\(InterviewNotes.offlineTag)：本场有环节用了本地题库与本地规则评分，模型没有参与，结果只供练习参考。") // 统一文案
    }                                                                 // 方法结束

    /// 用离线粗评顶替一次失败的评分。
    /// 只有服务侧问题（连不上 / 超时 / 模型挂 / 未知异常）才允许；额度用完、未登录必须让用户看见真实原因
    private func fallbackEvaluate(answer: String, cause: Error) -> Bool { // 本地兜底
        if let appError = cause as? AppError {                        // 已知类型的错误
            guard appError.allowsLocalFallback else { return false }   // 不允许就放弃兜底
        }                                                             // 未知异常按服务侧问题处理
        let response = LocalEvaluator.evaluate(                       // 本地算一份
            EvaluateRequest(                                          // 组装请求
                sessionId: session.id.uuidString,                     // 场次 id
                turnIndex: step,                                      // 轮次
                speaker: currentSpeaker.rawValue,                     // 提问人
                question: currentQuestion,                            // 问题
                answer: answer                                        // 回答
            )                                                         // 组装结束
        )                                                             // 调用结束
        applyEvaluation(response)                                     // 写进会话，含离线说明
        error = nil                                                   // 不留红色错误条
        return true                                                   // 兜住了
    }                                                                 // 方法结束

    /// 离线总结：模型不可用时也要给结论，但必须标明是离线算的
    private func applyLocalSummary(request: SummaryRequest) {         // 离线总结
        let local = LocalEvaluator.summarize(turns: request.turns, scores: session.scores) // 本地生成
        session.headline = local.headline ?? ""                       // 结论
        session.uncertainty.append(contentsOf: local.uncertainty ?? []) // 追加离线说明
        session.summaryGenerated = true                               // 视为已有结论
        session.endedAt = .now                                        // 结束时间
        session.state = .feedback                                     // 出结果页
    }                                                                 // 方法结束

    /// 统一错误处理：留下错误并给出可恢复状态
    private func handle(_ error: Error) {                              // 处理错误
        let appError = (error as? AppError) ?? .aiUnavailable(String(describing: error)) // 归一
        self.error = appError                                          // 记下错误
        if appError.canDegrade {                                       // 可降级的
            session.state = .asking                                    // 回到可作答
        } else {                                                       // 不可降级
            session.state = .error                                     // 进入错误态
        }                                                             // 分支结束
    }                                                                 // 方法结束

    /// 开始计时：每秒加一，到点自动收尾
    private func startTimer() {                                        // 起计时
        ticker?.cancel()                                              // 先停旧的
        ticker = Task { [weak self] in                                // 新任务
            while !Task.isCancelled {                                 // 循环
                try? await Task.sleep(nanoseconds: 1_000_000_000)      // 等 1 秒
                guard let self else { return }                         // 弱引用检查
                guard self.session.state.timerRunning else { continue } // 不在计时态就跳过
                self.session.elapsedSeconds += 1                       // 加一秒
                if self.session.elapsedSeconds >= self.session.limitSeconds { // 到点
                    await self.finish()                                // 自动收尾
                    return                                             // 结束任务
                }                                                     // 分支结束
            }                                                         // 循环结束
        }                                                             // 任务结束
    }                                                                 // 方法结束

    /// 停止计时
    private func stopTimer() {                                         // 停计时
        ticker?.cancel()                                              // 取消任务
        ticker = nil                                                  // 清引用
    }                                                                 // 方法结束
}                                                                     // InterviewEngine 结束
