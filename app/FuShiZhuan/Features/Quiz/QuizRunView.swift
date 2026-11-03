//  QuizRunView.swift —— 练习作答页（严格对齐 Web 样板 page-run）          // 文件说明
//  结构：进度条 pill + 计时 + 交卷 → 进度条 → 题目卡 → 上一题/下一题 → 答题卡
//  最后一题按钮文案变「交卷」；交卷后切结果页（page-result），不在这里堆解析   // 交互约定
//  交卷时才写 AppState.recordAnswer —— 错题本/成长值/薄弱点只走这一个写入口   // 状态约束

import SwiftUI  // 界面框架

struct QuizRunView: View {  // 练习作答页
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 返回

    let pool: [Question]  // 题池，「再来一组」时从这里重新抽
    let size: Int  // 每组题量
    let revealEach: Bool  // 作答模式：true = 每题即时看

    @State private var paper: [Question] = []  // 本组题目
    @State private var index = 0  // 当前第几题
    @State private var answers: [String: Set<Int>] = [:]  // 题号到已选
    @State private var startedAt = Date()  // 开练时间
    @State private var submitted = false  // 是否已交卷
    @State private var seconds = 0  // 交卷时定格的用时
    @State private var unanswered = 0  // 交卷时未答数

    init(pool: [Question], size: Int, revealEach: Bool) {  // 初始化并存下第一组题
        self.pool = pool  // 题池
        self.size = size  // 题量
        self.revealEach = revealEach  // 模式
        _paper = State(initialValue: Array(pool.shuffled().prefix(max(1, size))))  // 先抽一组
    }  // init 结束

    // MARK: - 视图                                                    // 分节：视图

    var body: some View {  // 视图主体
        Group {  // 两种状态
            if submitted {  // 已交卷
                QuizResultView(  // 结果页
                    items: results,  // 逐题结果
                    seconds: seconds,  // 用时
                    revealInstant: revealEach,  // 模式
                    unanswered: unanswered,  // 未答数
                    onAgain: restart,  // 再来一组
                    onClose: { dismiss() }  // 离开
                )  // 结果页结束
            } else {  // 作答中
                runBody  // 作答界面
            }  // 分支结束
        }  // 分组结束
        .background(Color.appBG)  // 底色
        .navigationTitle(submitted ? "练习结果" : "练习")  // 标题跟着状态走
        .navigationBarTitleDisplayMode(.inline)  // 标题内联
        .toolbar {  // 工具栏
            ToolbarItem(placement: .topBarLeading) {  // 左侧
                if !submitted {  // 交卷后不给退
                    Button("退出") { dismiss() }  // 中途退出
                }  // 分支结束
            }  // 工具栏项结束
        }  // 工具栏结束
    }  // body 结束

    private var runBody: some View {  // 作答界面
        VStack(spacing: 0) {  // 纵向排列
            runBar  // 进度与计时
            progressBar  // 细进度条
            ScrollView {  // 可滚动
                VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                    quizCard  // 题目卡
                    runNav  // 上一题 / 下一题
                    answerSheet  // 答题卡
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
                .padding(.bottom, Space.xxl)  // 底部留白
            }  // 滚动结束
        }  // 排列结束
    }  // runBody 结束

    // MARK: - 顶部                                                    // 分节：顶部

    private var runBar: some View {  // 进度 pill + 计时 + 交卷
        HStack(spacing: Space.s) {  // 横向排列
            Text(verbatim: "\(index + 1) / \(paper.count)")  // 进度文案（verbatim 防千位逗号）
                .font(.system(size: 11.5, weight: .medium))  // 与样板 .pill 一致
                .foregroundStyle(Color(hex: 0x5B5B61))  // 样板灰
                .padding(.horizontal, 10)  // 左右内边距
                .frame(height: 26)  // 样板高度
                .background(Capsule().fill(Color(hex: 0xE9E9EF)))  // 灰底胶囊

            Spacer(minLength: 0)  // 撑开

            timerView  // 计时

            Button("交卷") { submit() }  // 交卷（样板是文字链接按钮）
                .font(.system(size: 13, weight: .semibold))  // 与 link-btn 一致
                .foregroundStyle(Color.appBrand)  // 品牌色
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
        .padding(.top, Space.xs)  // 上边距
        .padding(.bottom, 9)  // 下边距（样板 9px）
    }  // runBar 结束

    private var progressBar: some View {  // 细进度条（样板 .progress）
        GeometryReader { geo in  // 拿宽度算比例
            ZStack(alignment: .leading) {  // 底条 + 进度条叠放
                Capsule().fill(Color(hex: 0xE3E3E9))  // 底条
                Capsule()  // 进度条
                    .fill(LinearGradient(colors: [Color.appBrand, Color.appBrand2],  // 品牌渐变
                                         startPoint: .leading, endPoint: .trailing))  // 左到右
                    .frame(width: geo.size.width * progress)  // 按比例定宽
            }  // 叠放结束
        }  // 读取器结束
        .frame(height: 4)  // 样板 4px
        .padding(.horizontal, Metrics.pagePadding + 2)  // 左右与样板一致
        .padding(.bottom, 12)  // 下方留白
    }  // progressBar 结束

    private var progress: CGFloat {  // 当前进度比例
        paper.isEmpty ? 0 : CGFloat(index + 1) / CGFloat(paper.count)  // 已到第几题
    }  // progress 结束

    private var timerView: some View {  // 已用时间（样板 .run-timer）
        TimelineView(.periodic(from: startedAt, by: 1)) { context in  // 每秒刷新
            Text(verbatim: elapsedText(context.date))  // mm:ss
                .font(.system(size: 12.5))  // 样板字号
                .monospacedDigit()  // 等宽数字不抖
                .foregroundStyle(Color.textSecondary)  // 次要色
        }  // 时间线结束
    }  // timerView 结束

    private func elapsedText(_ now: Date) -> String {  // 秒数转 mm:ss
        let total = max(0, Int(now.timeIntervalSince(startedAt)))  // 已过秒数
        return String(format: "%02d:%02d", total / 60, total % 60)  // 补零输出
    }  // elapsedText 结束

    // MARK: - 题目卡                                                  // 分节：题目

    private var current: Question? {  // 当前题
        paper.indices.contains(index) ? paper[index] : nil  // 越界给 nil
    }  // current 结束

    private var quizCard: some View {  // 题目卡（样板 .card.quiz-card）
        Card {  // 白卡片
            if let q = current {  // 有题才画
                VStack(alignment: .leading, spacing: 0) {  // 纵向排列
                    HStack(spacing: 6) {  // 两个标签（样板 .q-meta）
                        tagChip(topicName(q.topic), soft: false)  // 知识点
                        tagChip(q.type.title, soft: true)  // 题型
                        Spacer(minLength: 0)  // 撑开
                    }  // 排列结束
                    .padding(.bottom, 9)  // 与样板 9px

                    Text(q.stem)  // 题干
                        .font(.system(size: 15.5, weight: .semibold))  // 样板 15.5 / 650
                        .lineSpacing(4)  // 行距贴近 1.62
                        .fixedSize(horizontal: false, vertical: true)  // 允许换行
                        .padding(.bottom, 14)  // 与样板 14px

                    VStack(spacing: 8) {  // 选项（样板 gap 8）
                        ForEach(Array(q.options.enumerated()), id: \.offset) { offset, text in  // 逐个选项
                            optionRow(q, offset: offset, text: text)  // 选项行
                        }  // 遍历结束
                    }  // 排列结束

                    if revealEach, let picked = answers[q.id], !picked.isEmpty {  // 每题即时看
                        explainBlock(q, picked: picked)  // 立刻给对错与解析
                    }  // 分支结束
                }  // 排列结束
                .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
            }  // 分支结束
        }  // 卡片结束
    }  // quizCard 结束

    private func tagChip(_ text: String, soft: Bool) -> some View {  // 标签（样板 .tag / .tag.soft）
        Text(text)  // 内容
            .font(.system(size: 11, weight: soft ? .medium : .semibold))  // soft 不加粗
            .foregroundStyle(soft ? Color.textSecondary : Color.appBrand)  // 两种配色
            .padding(.horizontal, 9)  // 左右内边距
            .frame(height: 22)  // 样板高度
            .background(  // 底色
                RoundedRectangle(cornerRadius: 7, style: .continuous)  // 圆角 7
                    .fill(soft ? Color(hex: 0xF2F2F7) : Color.appBrand.opacity(0.10))  // 灰或淡蓝
            )  // 背景结束
    }  // tagChip 结束

    private func optionRow(_ q: Question, offset: Int, text: String) -> some View {  // 单个选项
        let picked = (answers[q.id] ?? []).contains(offset)  // 是否选中
        let locked = revealEach && !(answers[q.id] ?? []).isEmpty  // 即时看模式下选完即锁
        return Button {  // 点击选择
            guard !locked else { return }  // 锁定后不再改
            var set = answers[q.id] ?? []  // 当前已选
            if set.contains(offset) { set.remove(offset) } else { set.insert(offset) }  // 切换
            answers[q.id] = set  // 写回
        } label: {  // 行外观
            HStack(spacing: Space.s) {  // 横向排列
                Text(Question.letter(offset))  // 选项字母
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(picked ? Color.white : Color.textSecondary)  // 选中白字
                    .frame(width: 24, height: 24)  // 圆形尺寸
                    .background(Circle().fill(picked ? Color.appBrand : Color.separator.opacity(0.4)))  // 选中实心
                Text(text)  // 选项文字
                    .font(AppFont.body)  // 正文
                    .foregroundStyle(Color.textPrimary)  // 主文字色
                    .multilineTextAlignment(.leading)  // 左对齐
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束
            .padding(Space.s)  // 内边距
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满
            .background(  // 背景
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 圆角
                    .fill(picked ? Color.appBrand.opacity(0.10) : Color.appCard)  // 选中淡色
            )  // 背景结束
            .overlay(  // 描边
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 同形
                    .stroke(picked ? Color.appBrand.opacity(0.5) : Color.separator, lineWidth: 1)  // 选中蓝边
            )  // 描边结束
            .contentShape(Rectangle())  // 整行可点
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // optionRow 结束

    private func explainBlock(_ q: Question, picked: Set<Int>) -> some View {  // 即时解析（样板 .q-explain）
        let correct = q.isCorrect(picked)  // 是否答对
        return VStack(alignment: .leading, spacing: 4) {  // 纵向排列
            HStack(spacing: Space.xxs) {  // 结论行
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")  // 图标
                    .foregroundStyle(correct ? Color.appOK : Color.appErr)  // 对绿错红
                Text(correct ? "答对了" : "答错了")  // 结论
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(correct ? Color.appOK : Color.appErr)  // 同色
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束
            if !correct {  // 答错给正确答案
                Text(verbatim: "正确答案：\(q.answerText)")  // 正确选项
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.appBrand)  // 品牌色
            }  // 分支结束
            Text(q.explain)  // 解析
                .font(.system(size: 12.5))  // 样板 12.5
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .padding(.horizontal, 13)  // 样板内边距
        .padding(.vertical, 12)  // 样板内边距
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
        .background(  // 灰底
            RoundedRectangle(cornerRadius: 12, style: .continuous)  // 圆角 12
                .fill(Color(hex: 0xF7F7FA))  // 样板底色
        )  // 背景结束
        .overlay(alignment: .leading) {  // 左侧品牌色竖条（样板 border-left 3px）
            Rectangle()  // 细条
                .fill(Color.appBrand)  // 品牌色
                .frame(width: 3)  // 3px
                .clipShape(RoundedRectangle(cornerRadius: 2))  // 两端圆一点
        }  // 叠层结束
        .padding(.top, 12)  // 与选项隔开
    }  // explainBlock 结束

    // MARK: - 导航与答题卡                                            // 分节：导航

    private var runNav: some View {  // 上一题 / 下一题（样板 .run-nav 栅格 1:1.4，此处等分近似）
        HStack(spacing: 9) {  // 横向排列
            GhostButton(title: "上一题", systemImage: "chevron.left", enabled: index > 0) {  // 上一题
                if index > 0 { index -= 1 }  // 前移
            }  // 按钮结束

            if index + 1 >= paper.count {  // 最后一题
                PrimaryButton(title: "交卷", systemImage: "checkmark.seal") {  // 文案变交卷（样板同）
                    submit()  // 直接交卷
                }  // 按钮结束
            } else {  // 还有下一题
                PrimaryButton(title: "下一题", systemImage: "chevron.right") {  // 下一题
                    index += 1  // 后移
                }  // 按钮结束
            }  // 分支结束
        }  // 排列结束
    }  // runNav 结束

    private var answerSheet: some View {  // 答题卡（样板 .answer-sheet）
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 9),  // 每行九格
                  alignment: .leading, spacing: 6) {  // 间距与样板一致
            ForEach(paper.indices, id: \.self) { i in  // 逐题号
                let done = !(answers[paper[i].id] ?? []).isEmpty  // 是否答过
                Button {  // 点题号跳转
                    index = i  // 跳过去
                } label: {  // 格子外观
                    Text(verbatim: "\(i + 1)")  // 题号
                        .font(.system(size: 11.5, weight: .semibold))  // 样板字号
                        .foregroundStyle(i == index ? Color.white : (done ? Color.appBrand : Color.textSecondary))  // 三种状态
                        .frame(width: 28, height: 28)  // 样板尺寸
                        .background(  // 背景
                            RoundedRectangle(cornerRadius: 8, style: .continuous)  // 圆角 8
                                .fill(i == index ? Color.appBrand : (done ? Color.appBrand.opacity(0.12) : Color.appCard))  // 当前实心
                        )  // 背景结束
                        .overlay(  // 未答格子要有细边，否则白块隐形
                            RoundedRectangle(cornerRadius: 8, style: .continuous)  // 同形
                                .stroke(i == index || done ? Color.clear : Color.separator, lineWidth: 1)  // 只有未答才描边
                        )  // 描边结束
                }  // 外观结束
                .buttonStyle(.plain)  // 不用默认高亮
            }  // 遍历结束
        }  // 栅格结束
    }  // answerSheet 结束

    // MARK: - 交卷与重来                                              // 分节：结算

    private var results: [QuizResultItem] {  // 逐题结果
        paper.map { q in  // 每题转成结果项
            let picked = answers[q.id] ?? []  // 用户选项
            return QuizResultItem(question: q, picked: picked, ok: q.isCorrect(picked))  // 对错判定
        }  // 映射结束
    }  // results 结束

    private func submit() {  // 交卷
        guard !paper.isEmpty else { return }  // 没题不交
        seconds = max(0, Int(Date().timeIntervalSince(startedAt)))  // 定格用时
        unanswered = paper.filter { (answers[$0.id] ?? []).isEmpty }.count  // 未答数
        for q in paper {  // 逐题记账
            _ = app.recordAnswer(question: q, picked: answers[q.id] ?? [], inLevel: false)  // 唯一写入口
        }  // 循环结束
        submitted = true  // 切到结果页
    }  // submit 结束

    private func restart() {  // 再来一组
        paper = Array(pool.shuffled().prefix(max(1, size)))  // 重新抽题
        index = 0  // 回到第一题
        answers = [:]  // 清空作答
        startedAt = Date()  // 重新计时
        seconds = 0  // 清用时
        unanswered = 0  // 清未答数
        submitted = false  // 回到作答界面
    }  // restart 结束

    private func topicName(_ id: String) -> String {  // 知识点 id 转中文名
        app.bank?.topics.first { $0.id == id }?.name ?? id  // 找不到就显示 id
    }  // topicName 结束
}  // QuizRunView 结束
