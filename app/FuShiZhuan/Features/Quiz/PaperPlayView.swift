//  PaperPlayView.swift —— 整套试卷作答页                          // 文件说明
//  流程按真实考试来：先把整卷做完再交卷，中间不显示对错；交卷后一次性给分并逐题复盘
//  交卷时才写 AppState.recordAnswer —— 保证错题本、成长值、薄弱点统计口径统一
import SwiftUI  // 界面框架

struct PaperPlayView: View {  // 试卷作答页
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 返回

    let paper: Paper  // 当前试卷

    @State private var index = 0  // 当前第几题
    @State private var answers: [String: Set<Int>] = [:]  // 题号到已选的映射
    @State private var submitted = false  // 是否已交卷
    @State private var showSubmitConfirm = false  // 交卷二次确认

    // MARK: - 题目装配                                                // 分节：装配

    private struct Item: Identifiable {  // 一道有序题
        var id: String { question.id }  // 用题目 id
        let section: String  // 所属大题
        let question: Question  // 题目本体
    }  // Item 结束

    private var items: [Item] {  // 按试卷顺序装配题目
        guard let bank = app.bank else { return [] }  // 题库没加载
        let byID = Dictionary(uniqueKeysWithValues: bank.questions.map { ($0.id, $0) })  // 建索引
        var list: [Item] = []  // 结果容器
        for section in paper.sections {  // 逐个大题
            for qid in section.questionIDs {  // 逐个题号
                if let question = byID[qid] {  // 题库里找得到
                    list.append(Item(section: section.title, question: question))  // 加进来
                }  // 分支结束
            }  // 循环结束
        }  // 循环结束
        return list  // 返回有序卷面
    }  // items 结束

    private var current: Item? {  // 当前题
        items.indices.contains(index) ? items[index] : nil  // 越界给 nil
    }  // 属性结束

    private var answeredCount: Int {  // 已作答题数
        items.filter { !(answers[$0.question.id] ?? []).isEmpty }.count  // 有选项就算答了
    }  // 属性结束

    // MARK: - 视图                                                    // 分节：视图

    var body: some View {  // 视图主体
        VStack(spacing: 0) {  // 纵向排列
            if submitted {  // 已交卷
                reviewBody  // 用 ScrollView 包着的复盘
            } else if let current {  // 有题
                questionBody(current)  // 作答界面
            } else {  // 没题
                EmptyState(  // 空态
                    icon: "doc.text",  // 图标
                    title: "这套卷子暂时打不开",  // 标题
                    message: "题库还没加载完，或者试卷引用的题目缺失。返回后再试一次。",  // 说明
                    actionTitle: "返回",  // 按钮
                    action: { dismiss() }  // 返回
                )  // 空态结束
            }  // 分支结束
        }  // 排列结束
        .background(Color.appBG)  // 底色
        .navigationBarTitleDisplayMode(.inline)  // 标题内联
        .navigationBarBackButtonHidden(submitted)  // 交卷后隐藏返回键
        .toolbar {  // 工具栏
            ToolbarItem(placement: .topBarLeading) {  // 左侧
                if !submitted {  // 未交卷可退出
                    Button("退出") { dismiss() }  // 退出按钮
                }  // 分支结束
            }  // 工具栏项结束
            ToolbarItem(placement: .principal) {  // 中间
                Text(verbatim: submitted ? "试卷复盘" : "\(answeredCount)/\(items.count)")  // 进度或标题
                    .font(AppFont.bodyStrong)  // 加粗
            }  // 工具栏项结束
        }  // 工具栏结束
        .confirmationDialog(  // 交卷确认
            "确定交卷？",  // 标题
            isPresented: $showSubmitConfirm,  // 绑定
            titleVisibility: .visible  // 标题可见
        ) {  // 按钮区
            Button("交卷并看结果") { submit() }  // 确认交卷
            Button("再检查一下", role: .cancel) {}  // 取消
        } message: {  // 说明
            Text(unansweredHint)  // 还有几题没答
        }  // 弹窗结束
    }  // body 结束

    private var unansweredHint: String {  // 未答提示
        let left = items.count - answeredCount  // 还剩几题
        return left == 0 ? "全部答完了，交卷后统一判分。" : "还有 \(left) 题没答，交卷后这些题会按答错计。"  // 两种情况
    }  // 属性结束

    // MARK: - 作答                                                    // 分节：作答

    private func questionBody(_ item: Item) -> some View {  // 作答界面
        VStack(spacing: 0) {  // 纵向排列
            numberStrip  // 题号条
            ScrollView {  // 题目区
                VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                    Text(item.section)  // 所属大题
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                    Text(verbatim: "第 \(index + 1) 题 · \(item.question.type.title)")  // 题号与题型
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                    Text(item.question.stem)  // 题干
                        .font(AppFont.body)  // 正文
                        .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    VStack(spacing: Space.s) {  // 选项列表
                        ForEach(Array(item.question.options.enumerated()), id: \.offset) { offset, text in  // 逐个选项
                            optionRow(item: item, offset: offset, text: text)  // 选项行
                        }  // 遍历结束
                    }  // 排列结束
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
                .padding(.bottom, Space.xxl)  // 底部留白
            }  // 滚动结束
            footerBar  // 底部按钮
        }  // 排列结束
    }  // questionBody 结束

    private var numberStrip: some View {  // 题号导航条
        ScrollView(.horizontal, showsIndicators: false) {  // 横向滚动
            HStack(spacing: Space.xxs) {  // 横向排列
                ForEach(items.indices, id: \.self) { i in  // 逐题号
                    let done = !(answers[items[i].question.id] ?? []).isEmpty  // 是否答过
                    Button {  // 点题号跳转
                        index = i  // 跳过去
                    } label: {  // 方块外观
                        Text(verbatim: "\(i + 1)")  // 题号
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(i == index ? Color.white : (done ? Color.appBrand : Color.textSecondary))  // 三种状态
                            .frame(width: 30, height: 30)  // 方块尺寸
                            .background(  // 背景
                                Circle().fill(i == index ? Color.appBrand : (done ? Color.appBrand.opacity(0.12) : Color.appCard))  // 当前实心
                            )  // 背景结束
                    }  // 外观结束
                    .buttonStyle(.plain)  // 不用默认高亮
                }  // 遍历结束
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
            .padding(.vertical, Space.s)  // 上下内边距
        }  // 滚动结束
    }  // numberStrip 结束

    private func optionRow(item: Item, offset: Int, text: String) -> some View {  // 单个选项
        let picked = (answers[item.question.id] ?? []).contains(offset)  // 是否选中
        return Button {  // 点击选择
            var set = answers[item.question.id] ?? []  // 当前已选
            if set.contains(offset) { set.remove(offset) } else { set.insert(offset) }  // 切换
            answers[item.question.id] = set  // 写回
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
        .accessibilityLabel("选项 \(Question.letter(offset))，\(text)，\(picked ? "已选" : "未选")")  // 朗读
    }  // optionRow 结束

    private var footerBar: some View {  // 底部按钮条
        HStack(spacing: Space.s) {  // 横向排列
            GhostButton(title: "上一题", systemImage: "chevron.left", enabled: index > 0) {  // 上一题
                if index > 0 { index -= 1 }  // 前移
            }  // 按钮结束
            if index < items.count - 1 {  // 不是最后一题
                PrimaryButton(title: "下一题", systemImage: "chevron.right") {  // 下一题
                    index += 1  // 后移
                }  // 按钮结束
            } else {  // 最后一题
                PrimaryButton(title: "交卷", systemImage: "checkmark.seal") {  // 交卷
                    showSubmitConfirm = true  // 弹确认
                }  // 按钮结束
            }  // 分支结束
        }  // 排列结束
        .padding(Metrics.pagePadding)  // 内边距
        .background(.ultraThinMaterial)  // 毛玻璃底
    }  // footerBar 结束

    // MARK: - 交卷与复盘                                              // 分节：复盘

    private func submit() {  // 交卷
        for item in items {  // 逐题记账
            let picked = answers[item.question.id] ?? []  // 用户选项，没答就是空
            _ = app.recordAnswer(question: item.question, picked: picked, inLevel: false)  // 唯一写入口
        }  // 循环结束
        submitted = true  // 切到复盘
    }  // submit 结束

    private var correctCount: Int {  // 答对题数
        items.filter { item in  // 逐题判断
            let picked = answers[item.question.id] ?? []  // 用户选项
            return item.question.isCorrect(picked)  // 是否答对
        }.count  // 计数
    }  // 属性结束

    private var score: Int {  // 折算得分
        guard !items.isEmpty else { return 0 }  // 没题就是 0
        return Int((Double(correctCount) / Double(items.count) * Double(paper.totalScore)).rounded())  // 按满分折算
    }  // 属性结束

    private var reviewBody: some View {  // 复盘界面
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                scoreCard  // 得分卡
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in  // 逐题
                    reviewRow(offset: offset, item: item)  // 复盘行
                }  // 遍历结束
                PrimaryButton(title: "返回试卷列表", systemImage: "arrow.left") {  // 返回
                    dismiss()  // 关掉
                }  // 按钮结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
    }  // reviewBody 结束

    private var scoreCard: some View {  // 得分卡
        Card {  // 卡片
            VStack(spacing: Space.s) {  // 纵向排列
                Text(verbatim: "\(score) 分")  // 折算分
                    .font(.system(size: 34, weight: .bold, design: .rounded))  // 大号圆体
                    .foregroundStyle(scoreColor)  // 按分数上色
                Text(verbatim: "答对 \(correctCount) / \(items.count) 题，满分 \(paper.totalScore) 分")  // 明细
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                Divider()  // 分隔
                Text(paper.sourceNote)  // 来源说明再强调一次
                    .font(.system(size: 11))  // 更小的字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .multilineTextAlignment(.center)  // 居中
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
            }  // 排列结束
            .frame(maxWidth: .infinity)  // 撑满
        }  // 卡片结束
    }  // scoreCard 结束

    private var scoreColor: Color {  // 分数配色
        guard !items.isEmpty else { return .textPrimary }  // 没题用主色
        let ratio = Double(correctCount) / Double(items.count)  // 正确率
        if ratio >= 0.8 { return .appOK }  // 80% 以上绿
        if ratio >= 0.6 { return .appWarn }  // 60% 以上橙
        return .appErr  // 低于 60% 红
    }  // 属性结束

    private func reviewRow(offset: Int, item: Item) -> some View {  // 一道题的复盘
        let picked = answers[item.question.id] ?? []  // 用户选项
        let correct = item.question.isCorrect(picked)  // 是否答对
        return Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
                HStack(spacing: Space.xs) {  // 标题行
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")  // 对错图标
                        .foregroundStyle(correct ? Color.appOK : Color.appErr)  // 配色
                    Text(verbatim: "第 \(offset + 1) 题")  // 题号
                        .font(AppFont.captionStrong)  // 小字加粗
                    Spacer()  // 撑开
                    Text(item.section)  // 大题名
                        .font(.system(size: 10))  // 很小的字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
                Text(item.question.stem)  // 题干
                    .font(AppFont.body)  // 正文
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Text(verbatim: "你选：\(pickedText(picked))")  // 用户答案
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(correct ? Color.appOK : Color.appErr)  // 对绿错红
                if !correct {  // 答错才给正确答案
                    Text(verbatim: "正确：\(item.question.answerText)")  // 正确答案
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 分支结束
                Text(item.question.explain)  // 解析一律给
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    .padding(.top, 2)  // 与上面隔开
            }  // 排列结束
        }  // 卡片结束
    }  // reviewRow 结束

    private func pickedText(_ picked: Set<Int>) -> String {  // 用户答案文本
        guard !picked.isEmpty else { return "未作答" }  // 没答
        return picked.sorted().map { Question.letter($0) }.joined(separator: "、")  // 字母拼起来
    }  // pickedText 结束
}  // PaperPlayView 结束
