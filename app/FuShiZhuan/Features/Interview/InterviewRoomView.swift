//  InterviewRoomView.swift —— 面试房间与结果页                          // 文件说明
//  只读 engine 的状态、只调 engine 的方法，不自己拼流程                  // 架构约束
//  导师席 5 人、当前发言人高亮，还原真实考场                             // 场景原则

import SwiftUI                                                        // 界面框架

struct InterviewRoomView: View {                                      // 面试房间
    let mode: InterviewMode                                          // 面试类型
    let style: MentorStyle                                           // 导师风格

    @Environment(AppState.self) private var app                      // 全局状态
    @Environment(\.dismiss) private var dismiss                      // 返回
    @State private var engine = InterviewEngine()                    // 面试引擎
    @State private var answer = ""                                   // 当前回答
    @State private var speech = SpeechService()                      // 语音识别
    @StateObject private var voice = MentorVoice()                   // 导师播报

    var body: some View {                                            // 视图主体
        ScrollView {                                                 // 可滚动
            VStack(spacing: Space.l) {                               // 纵向排列
                statusBar                                            // 顶部状态
                mentorSeats                                          // 导师席
                if engine.isFinished {                               // 已结束
                    resultSection                                    // 结果区
                } else {                                             // 进行中
                    questionCard                                     // 问题卡
                    if engine.session.state == .paused {             // 暂停中
                        pausedCard                                   // 只给继续入口
                    } else {                                         // 正常作答
                        answerEditor                                 // 作答框
                        actionRow                                    // 操作按钮
                    }                                                // 分支结束
                }                                                    // 分支结束
            }                                                        // 排列结束
            .padding(Metrics.pagePadding)                            // 内边距
            .padding(.bottom, Space.xxl)                             // 底部留白
        }                                                            // 滚动结束
        .background(Color.appBG)                                     // 底色
        .navigationTitle("模拟面试")                                  // 标题
        .navigationBarBackButtonHidden(!engine.isFinished)           // 进行中禁止返回
        .toolbar {                                                   // 工具栏
            ToolbarItemGroup(placement: .topBarLeading) {            // 左侧按钮组
                if !engine.isFinished {                              // 进行中才有控制
                    Button(engine.session.state == .paused ? "继续" : "暂停") { // 暂停或继续
                        togglePause()                                // 切换
                    }                                                // 按钮结束
                    Button("结束") { engine.abandon() }               // 强制结束
                        .foregroundStyle(Color.appErr)               // 红色提示严重
                }                                                    // 分支结束
            }                                                        // 工具栏项结束
            ToolbarItemGroup(placement: .topBarTrailing) {            // 右侧按钮组
                Button {                                             // 静音开关
                    if voice.isSpeaking { voice.stop() }              // 正在读就先掐掉
                    voice.toggleMute()                               // 翻转静音
                } label: {                                           // 按钮外观
                    Image(systemName: voice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") // 图标随状态
                }                                                    // 按钮结束
                .accessibilityLabel(voice.isMuted ? "打开播报" : "关闭播报") // 无障碍
                Text(timeText)                                       // 倒计时
                    .font(AppFont.captionStrong)                     // 小字加粗
                    .monospacedDigit()                               // 等宽防跳
                    .foregroundStyle(engine.session.remainingSeconds <= 60 ? Color.appErr : Color.textSecondary) // 最后一分钟变红
            }                                                        // 工具栏项结束
        }                                                            // 工具栏结束
        .task {                                                      // 进入即开始
            guard engine.session.state == .preparing else { return }  // 只开一次
            await engine.start(mode: mode, style: style, tier: .medium) // 启动引擎
        }                                                            // 任务结束
        .onChange(of: engine.currentQuestion) { _, question in        // 出新题
            voice.speak(question, as: engine.currentSpeaker)          // 用对应角色的声音读出来
        }                                                            // 监听新题
        .onChange(of: engine.session.state) { _, state in             // 状态变化
            if state == .paused || state == .finishing { voice.stop() } // 暂停或收尾就别读了
        }                                                            // 监听状态
        .onChange(of: engine.isFinished) { _, finished in             // 结束时
            guard finished else { return }                            // 只处理结束
            speech.stop()                                             // 关掉录音，别占着麦克风
            voice.stop()                                              // 关掉播报
            app.saveSession(engine.session)                          // 落库到唯一状态源
        }                                                            // 监听结束
        .onDisappear {                                               // 离开页面
            speech.stop()                                            // 释放麦克风
            voice.stop()                                             // 释放音频
        }                                                            // 离开处理结束
    }                                                                // body 结束

    // MARK: 顶部状态                                                   // 分节：状态

    private var statusBar: some View {                               // 状态条
        VStack(spacing: Space.xs) {                                  // 纵向排列
            HStack {                                                 // 横向排列
                Text(engine.phase.title).font(AppFont.section)        // 当前环节
                Spacer()                                             // 撑开
                Text("第 \(engine.stepNumber) / \(engine.totalSteps) 问") // 进度
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textSecondary)            // 次要色
            }                                                        // 排列结束
            Meter(                                                   // 进度条
                value: engine.totalSteps == 0 ? 0 : Double(engine.stepNumber - 1) / Double(engine.totalSteps), // 已答比例
                tint: .appBrand                                      // 品牌色
            )                                                        // 进度条结束
        }                                                            // 排列结束
    }                                                                // statusBar 结束

    private var timeText: String {                                   // 倒计时文本
        let s = engine.session.remainingSeconds                      // 剩余秒
        return String(format: "%02d:%02d", s / 60, s % 60)           // 分:秒
    }                                                                // 属性结束

    // MARK: 导师席                                                    // 分节：导师席

    private var mentorSeats: some View {                             // 五位导师
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.m) {           // 纵向排列
                HStack(spacing: Space.xs) {                          // 五个座位
                    ForEach(MentorRole.seated) { role in             // 遍历导师
                        VStack(spacing: Space.xxs) {                 // 单个座位
                            ZStack {                                 // 叠放
                                Circle()                             // 圆形底
                                    .fill(role == engine.currentSpeaker ? Color.appBrand : Color.separator) // 发言高亮
                                    .frame(width: 34, height: 34)    // 尺寸
                                Image(systemName: "person.fill")   // 人形
                                    .font(.system(size: 14))         // 图标大小
                                    .foregroundStyle(role == engine.currentSpeaker ? .white : Color.textTertiary) // 字色
                            }                                        // 叠放结束
                            Text(role.title)                         // 角色名
                                .font(.system(size: 9))              // 极小字
                                .foregroundStyle(role == engine.currentSpeaker ? Color.appBrand : Color.textTertiary) // 高亮
                                .lineLimit(1)                        // 单行
                        }                                            // 座位结束
                    }                                                // 遍历结束
                }                                                    // 排列结束
                Text("AI 模拟角色，非真实导师")                            // 必须声明
                    .font(.system(size: 10))                         // 极小字
                    .foregroundStyle(Color.textTertiary)             // 弱化色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // mentorSeats 结束

    // MARK: 问题与作答                                                // 分节：问答

    private var questionCard: some View {                            // 问题卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                HStack(spacing: Space.xs) {                          // 提问人行
                    Chip(text: engine.currentSpeaker.title, tint: .appViolet) // 谁在问
                    if voice.isSpeaking {                            // 正在读题
                        Image(systemName: "speaker.wave.2.fill")     // 喇叭图标
                            .font(.system(size: 11))                 // 小图标
                            .foregroundStyle(Color.appBrand)         // 品牌色
                    }                                                // 分支结束
                    if engine.isBusy {                               // 正在请求
                        ProgressView().scaleEffect(0.6)              // 小转圈
                    }                                                // 分支结束
                }                                                    // 排列结束
                if engine.currentQuestion.isEmpty {                  // 还没出题
                    Text("正在准备问题…").font(AppFont.body).foregroundStyle(Color.textSecondary) // 提示
                } else {                                             // 有题
                    Text(engine.currentQuestion)                     // 问题
                        .font(AppFont.section)                       // 区段字号
                        .fixedSize(horizontal: false, vertical: true) // 允许换行
                }                                                    // 分支结束
                if !engine.knowledgePoints.isEmpty {                 // 有知识点才显示
                    Text("考察：\(engine.knowledgePoints.joined(separator: "、"))") // 展示
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textTertiary)         // 弱化色
                }                                                    // 分支结束
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // questionCard 结束

    private var answerEditor: some View {                            // 作答框
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                Text("你的回答").font(AppFont.captionStrong).foregroundStyle(Color.textSecondary) // 标题
                TextEditor(text: $answer)                            // 多行输入
                    .frame(minHeight: 120)                           // 最小高度
                    .scrollContentBackground(.hidden)                // 去掉默认底
                    .font(AppFont.body)                              // 正文字号
                    .disabled(!engine.canAnswer)                     // 不可作答时禁用
                Text("字数 \(answer.count)")                          // 字数统计
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textTertiary)             // 弱化色
                HStack(spacing: Space.xs) {                          // 语音行
                    GhostButton(                                     // 语音按钮
                        title: speech.isRecording ? "停止并填入" : "语音作答", // 文案随状态变
                        systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill", // 图标随状态变
                        action: { toggleSpeech() }                   // 点击切换
                    )                                                // 按钮结束
                }                                                    // 行结束
                if speech.isRecording {                               // 正在录
                    Text(speech.transcript.isEmpty ? "在听…" : speech.transcript) // 实时文本
                        .font(AppFont.caption)                        // 小字
                        .foregroundStyle(Color.textSecondary)         // 次要色
                        .lineLimit(2)                                 // 最多两行
                        .frame(maxWidth: .infinity, alignment: .leading) // 左对齐
                }                                                     // 分支结束
                if let speechError = speech.error {                   // 语音出错
                    Text("\(speechError.title)：\(speechError.action)") // 标题与下一步
                        .font(AppFont.caption)                        // 小字
                        .foregroundStyle(Color.appErr)                // 红色
                        .fixedSize(horizontal: false, vertical: true) // 允许换行
                }                                                     // 分支结束
                Text("语音只在本机识别，不上传服务器")                      // 隐私说明
                    .font(.system(size: 10))                          // 极小字
                    .foregroundStyle(Color.textTertiary)              // 弱化色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // answerEditor 结束

    private var pausedCard: some View {                              // 暂停卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                Text("已暂停").font(AppFont.section)                   // 标题
                Text("计时已经停下，继续后从当前秒数接上，不会补扣时间。")    // 说明
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textSecondary)            // 次要色
                PrimaryButton(title: "继续作答", systemImage: "play.fill") { // 按钮
                    engine.resume()                                  // 恢复
                }                                                    // 按钮结束
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // pausedCard 结束

    private func togglePause() {                                     // 暂停/继续切换
        if engine.session.state == .paused {                         // 当前是暂停
            engine.resume()                                          // 继续
        } else {                                                     // 当前在作答
            engine.pause()                                           // 暂停
        }                                                            // 分支结束
    }                                                                // togglePause 结束

    private var actionRow: some View {                               // 操作区
        VStack(spacing: Space.s) {                                   // 纵向排列
            if let error = engine.error {                            // 有错误
                VStack(alignment: .leading, spacing: Space.xxs) {      // 错误块
                    Text(error.title).font(AppFont.captionStrong).foregroundStyle(Color.appErr) // 标题
                    Text(error.action).font(AppFont.caption).foregroundStyle(Color.textSecondary) // 动作
                }                                                    // 错误块结束
                .frame(maxWidth: .infinity, alignment: .leading)      // 左对齐
            }                                                        // 分支结束

            PrimaryButton(                                           // 提交按钮
                title: engine.isBusy ? "评分中…" : "提交回答",         // 文案
                systemImage: "paperplane.fill",                       // 图标
                enabled: engine.canAnswer && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, // 可答且非空
                action: { submit() }                                 // 点击
            )                                                        // 按钮结束

            if engine.session.state == .error {                      // 出错态
                GhostButton(title: "重试本题", systemImage: "arrow.clockwise") { // 重试
                    Task { await engine.retry() }                     // 真正把状态拉回可作答
                }                                                    // 按钮结束
            }                                                        // 分支结束
        }                                                            // 排列结束
    }                                                                // actionRow 结束

    private func toggleSpeech() {                                    // 语音开关
        if speech.isRecording {                                      // 正在录
            speech.stop()                                            // 停
            appendSpeech()                                           // 把识别结果拼进回答
        } else {                                                     // 没在录
            voice.stop()                                             // 先掐掉播报，否则录进去的是导师的声音
            Task { await speech.start() }                            // 开始录
        }                                                            // 分支结束
    }                                                                // toggleSpeech 结束

    private func appendSpeech() {                                    // 拼接语音结果
        let text = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines) // 去空白
        guard !text.isEmpty else { return }                          // 空的不拼
        answer = answer.isEmpty ? text : answer + "。" + text        // 已有内容用句号接上
    }                                                                // appendSpeech 结束

    private func submit() {                                          // 提交回答
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines) // 去空白
        guard !text.isEmpty else { return }                           // 空答不提交
        Task {                                                        // 异步执行
            await engine.submit(text)                                 // 交给引擎
            if engine.error == nil { answer = "" }                    // 只在成功时清空，失败要把原文留给用户改
        }                                                             // 任务结束
    }                                                                 // submit 结束

    // MARK: 结果                                                      // 分节：结果

    private var resultSection: some View {                           // 结果区
        VStack(spacing: Space.l) {                                   // 纵向排列
            if engine.session.state == .abandoned {                   // 中途结束
                Card {                                                // 说明卡
                    VStack(alignment: .leading, spacing: Space.xs) {   // 纵向排列
                        Text("本场未完成").font(AppFont.section)       // 标题
                        Text("中途结束不生成评分，当天这一次已经用掉。下次从头开始即可。") // 说明
                            .font(AppFont.caption)                    // 小字
                            .foregroundStyle(Color.textSecondary)     // 次要色
                    }                                                 // 排列结束
                }                                                     // 卡片结束
            } else {                                                  // 正常走完
                Card {                                               // 总览卡
                    VStack(alignment: .leading, spacing: Space.s) {   // 纵向排列
                        Text(engine.session.headline.isEmpty ? "本场已结束" : engine.session.headline)  // 结论
                            .font(AppFont.section)                    // 区段字号
                        if engine.session.isOffline {                 // 用过离线兜底
                            Chip(text: "离线粗评", tint: .appWarn)      // 明确标出来
                        }                                             // 分支结束
                        if let overall = engine.session.overallScore {  // 有综合分
                            HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {  // 横向排列
                                Text("\(overall)").font(AppFont.hero).foregroundStyle(Color.appBrand)  // 分数
                                Text("/ 100").font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 满分
                            }                                             // 排列结束
                        }                                             // 分支结束
                        Text(ScoreDimension.scaleNote)                // 量表声明
                            .font(AppFont.caption)                    // 小字
                            .foregroundStyle(Color.textTertiary)      // 弱化色
                    }                                                 // 排列结束
                }                                                     // 卡片结束

                ForEach(engine.session.scores) { item in               // 逐维展示
                    Card {                                            // 单维卡
                        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
                            HStack {                                  // 标题行
                                Text(item.dimension.title).font(AppFont.bodyStrong)  // 维度名
                                Spacer()                              // 撑开
                                Text(item.isJudged ? "\(item.score)" : "依据不足")  // 分数或提示
                                    .font(AppFont.captionStrong)      // 小字加粗
                                    .foregroundStyle(item.isJudged ? Color.appBrand : Color.textTertiary)  // 上色
                            }                                         // 排列结束
                            if item.isJudged {                        // 可判才画条
                                Meter(value: Double(item.score) / 100, tint: .appBrand)  // 分数条
                                Text("「\(item.evidence)」")             // 证据引用
                                    .font(AppFont.caption)            // 小字
                                    .foregroundStyle(Color.textSecondary)  // 次要色
                                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                            } else {                                  // 不可判
                                Text("模型没有从你的回答里找到依据，这一维不计分。")  // 说明
                                    .font(AppFont.caption)            // 小字
                                    .foregroundStyle(Color.textTertiary)  // 弱化色
                            }                                         // 分支结束
                        }                                             // 排列结束
                    }                                                 // 卡片结束
                }                                                     // 遍历结束

                if !engine.session.improvements.isEmpty {             // 有改进建议
                    Card {                                            // 建议卡
                        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                            Text("改进建议").font(AppFont.section)       // 标题
                            ForEach(engine.session.improvements) { item in  // 遍历建议
                                VStack(alignment: .leading, spacing: 2) {  // 单条
                                    Text("· \(item.issue)")              // 问题
                                        .font(AppFont.bodyStrong)     // 加粗
                                    Text("改写示例：\(item.rewrite)")   // 改写
                                        .font(AppFont.caption)        // 小字
                                        .foregroundStyle(Color.textSecondary)  // 次要色
                                }                                     // 单条结束
                            }                                         // 遍历结束
                            Text("示例非唯一答案")                         // 免责
                                .font(AppFont.caption)                // 小字
                                .foregroundStyle(Color.textTertiary)  // 弱化色
                        }                                             // 排列结束
                    }                                                 // 卡片结束
                }                                                     // 建议分支结束
            }                                                         // else 结束

            PrimaryButton(title: "返回", action: { dismiss() })         // 返回按钮
        }                                                             // 排列结束
    }                                                                 // resultSection 结束
}                                                                     // InterviewRoomView 结束
