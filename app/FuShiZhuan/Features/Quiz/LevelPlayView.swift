//  LevelPlayView.swift —— 闯关答题页                                 // 文件说明
//  一关 3 题，答错立刻拆解知识点，不是只报分数                        // 产品原则
//  游戏化服务于知识点掌握，不做抽卡与概率掉落                         // 产品原则

import SwiftUI  // 界面框架

struct LevelPlayView: View {  // 闯关页
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 返回上一页

    let questions: [Question]  // 本关题目
    let levelID: String  // 关卡 id

    @State private var index = 0  // 当前第几题
    @State private var picked: Set<Int> = []  // 已选选项
    @State private var submitted = false  // 是否已提交
    @State private var correctCount = 0  // 答对数量
    @State private var finished = false  // 是否已结束
    @State private var result: LevelResult?  // 本关成绩
    @State private var foodGained = 0  // 本次得几颗口粮

    private var current: Question? {  // 当前题目
        questions.indices.contains(index) ? questions[index] : nil  // 越界给 nil
    }  // 属性结束

    var body: some View {  // 视图主体
        VStack(spacing: 0) {  // 纵向排列
            progressBar  // 顶部进度
            if finished {  // 已结束
                resultView  // 显示结果
            } else if let q = current {  // 有题
                questionBody(q)  // 显示题目
            } else {  // 没题
                EmptyState(  // 空态
                    icon: "tray",  // 图标
                    title: "本关暂无题目",  // 标题
                    message: "这一关的题目还没配好，先去做别的章节。",  // 说明
                    actionTitle: "返回",  // 按钮
                    action: { dismiss() }  // 返回动作
                )  // 空态结束
            }  // 分支结束
        }  // 排列结束
        .background(Color.appBG)  // 底色
        .navigationBarTitleDisplayMode(.inline)  // 标题内联
        .navigationBarBackButtonHidden(finished)  // 结束后隐藏返回键
        .toolbar {  // 工具栏
            ToolbarItem(placement: .topBarLeading) {  // 左侧
                if !finished {  // 未结束才显示
                    Button("退出") { dismiss() }  // 退出按钮
                }  // 分支结束
            }  // 工具栏项结束
            ToolbarItem(placement: .principal) {  // 中间标题
                Text("第 \(Chapter.index(from: levelID)) 关")  // 第几关
                    .font(AppFont.bodyStrong)  // 加粗
            }  // 工具栏项结束
        }  // 工具栏结束
    }  // body 结束

    private var progressBar: some View {  // 顶部进度条
        VStack(spacing: Space.xs) {  // 纵向排列
            HStack {  // 横向排列
                Text("\(min(index + 1, questions.count)) / \(questions.count)")  // 第几题/共几题
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(Color.textSecondary)  // 次要色
                Spacer()  // 撑开
                Text("答对 \(correctCount)")  // 答对数量
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(Color.appOK)  // 绿色
            }  // 排列结束
            Meter(  // 进度条
                value: questions.isEmpty ? 0 : Double(index) / Double(questions.count),  // 进度比例
                tint: .appBrand  // 品牌色
            )  // 进度条结束
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        .padding(.vertical, Space.m)  // 上下边距
        .background(Color.appCard)  // 白底
    }  // progressBar 结束

    private func questionBody(_ q: Question) -> some View {  // 题目主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                HStack(spacing: Space.xs) {  // 标签行
                    Chip(text: q.type.title, tint: .appViolet)  // 题型
                    Chip(text: topicName(q.topic), tint: .appBrand)  // 板块
                }  // 排列结束

                Text(q.stem)  // 题干
                    .font(AppFont.section)  // 区段字号
                    .fixedSize(horizontal: false, vertical: true)  // 允许纵向撑开

                VStack(spacing: Space.s) {  // 选项列表
                    ForEach(Array(q.options.enumerated()), id: \.offset) { offset, text in  // 遍历选项
                        optionRow(q: q, offset: offset, text: text)  // 单行选项
                    }  // 遍历结束
                }  // 选项列表结束

                if submitted {  // 提交后
                    explanation(q)  // 显示解析
                }  // 分支结束

                Spacer(minLength: Space.l)  // 撑开

                if !submitted {  // 未提交
                    PrimaryButton(  // 提交按钮
                        title: "提交答案",  // 文案
                        enabled: !picked.isEmpty,  // 没选不能点
                        action: { submit(q) }  // 提交动作
                    )  // 按钮结束
                } else {  // 已提交
                    PrimaryButton(  // 下一步按钮
                        title: index + 1 < questions.count ? "下一题" : "看结果",  // 文案随进度变
                        systemImage: "arrow.right",  // 右箭头
                        action: { next() }  // 下一步动作
                    )  // 按钮结束
                }  // 分支结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
        }  // 滚动结束
    }  // questionBody 结束

    private func optionRow(q: Question, offset: Int, text: String) -> some View {  // 单行选项
        let selected = picked.contains(offset)  // 我选了吗
        let isRight = q.answer.contains(offset)  // 是正确答案吗
        let showState = submitted  // 是否揭示答案

        var border: Color {  // 边框色
            if showState && isRight { return .appOK }  // 揭晓后的正确答案绿
            if showState && selected && !isRight { return .appErr }  // 选错的变红
            return selected ? .appBrand : .separator  // 选中品牌色，否则灰
        }  // 属性结束

        var bg: Color {  // 背景色
            if showState && isRight { return Color.appOK.opacity(0.10) }  // 正确答案淡绿
            if showState && selected && !isRight { return Color.appErr.opacity(0.10) }  // 选错淡红
            return selected ? Color.appBrand.opacity(0.08) : Color.appCard  // 选中淡蓝
        }  // 属性结束

        return Button {  // 选项按钮
            guard !submitted else { return }  // 已提交不再响应
            if q.type == .multi {  // 多选
                if selected { picked.remove(offset) } else { picked.insert(offset) }  // 切换选中
            } else {  // 单选或判断
                picked = [offset]  // 只留一个
            }  // 分支结束
        } label: {  // 按钮外观
            HStack(alignment: .top, spacing: Space.m) {  // 横向排列
                Text(Question.letter(offset))  // 选项字母
                    .font(AppFont.bodyStrong)  // 加粗
                    .frame(width: 24, height: 24)  // 固定尺寸
                    .background(Circle().fill(selected || (showState && isRight) ? border : Color.separator))  // 圆底
                    .foregroundStyle(selected || (showState && isRight) ? .white : Color.textSecondary)  // 字色
                Text(text)  // 选项内容
                    .font(AppFont.body)  // 正文字号
                    .foregroundStyle(Color.textPrimary)  // 主文字色
                    .multilineTextAlignment(.leading)  // 左对齐
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Spacer(minLength: 0)  // 撑开
                if showState && isRight {  // 揭晓后正确项
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appOK)  // 勾
                } else if showState && selected && !isRight {  // 选错的
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.appErr)  // 叉
                }  // 分支结束
            }  // 排列结束
            .padding(Space.m)  // 内边距
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 圆角底
            .overlay(  // 描边
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 同圆角
                    .stroke(border, lineWidth: selected || (showState && isRight) ? 1.5 : 1)  // 选中加粗
            )  // 描边结束
        }  // 外观结束
        .buttonStyle(.plain)  // 去掉默认样式
        .disabled(submitted)  // 提交后禁用
    }  // optionRow 结束

    private func explanation(_ q: Question) -> some View {  // 解析块
        let right = q.isCorrect(picked)  // 是否答对
        return VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
            HStack(spacing: Space.xxs) {  // 结果行
                Image(systemName: right ? "checkmark.seal.fill" : "lightbulb.fill")  // 图标
                Text(right ? "答对了" : "答错了")  // 文案
                    .font(AppFont.bodyStrong)  // 加粗
            }  // 排列结束
            .foregroundStyle(right ? Color.appOK : Color.appErr)  // 对绿错红

            if !right {  // 答错才给正确答案
                Text("正确答案：\(q.answerText)")  // 正确答案
                    .font(AppFont.body)  // 正文字号
                    .foregroundStyle(Color.textPrimary)  // 主文字色
            }  // 分支结束
            Text(q.explain)  // 解析正文
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .padding(Space.m)  // 内边距
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
        .background(  // 背景
            (right ? Color.appOK : Color.appWarn).opacity(0.08),  // 对绿错橙淡底
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 圆角
        )  // 背景结束
    }  // explanation 结束

    private var resultView: some View {  // 结果页
        VStack(spacing: Space.l) {  // 纵向排列
            Spacer()  // 撑开
            Text("\(correctCount) / \(questions.count)")  // 得分
                .font(.system(size: 48, weight: .bold, design: .rounded))  // 大号数字
                .foregroundStyle(starsColor)  // 按星级上色
            HStack(spacing: Space.xs) {  // 三颗星
                ForEach(0..<3, id: \.self) { i in  // 遍历三颗
                    Image(systemName: i < (result?.stars ?? 0) ? "star.fill" : "star")  // 实心或空心
                        .font(.system(size: 26))  // 星号大小
                        .foregroundStyle(i < (result?.stars ?? 0) ? Color.appWarn : Color.separator)  // 亮或灰
                }  // 遍历结束
            }  // 排列结束
            Text(feedbackText)  // 反馈文案
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .multilineTextAlignment(.center)  // 居中
                .padding(.horizontal, Space.xl)  // 左右边距

            if let r = result, r.stars > 0 {  // 过关才显示奖励
                Chip(text: "口粮 +\(foodGained)", tint: .appOK, filled: true)  // 口粮奖励
            }  // 分支结束

            Spacer()  // 撑开

            VStack(spacing: Space.s) {  // 底部按钮
                PrimaryButton(title: "返回关卡列表", action: { dismiss() })  // 返回
                GhostButton(title: "再打一次", systemImage: "arrow.clockwise") {  // 重打
                    restart()  // 重置状态
                }  // 按钮结束
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右边距
            .padding(.bottom, Space.xl)  // 底部边距
        }  // 排列结束
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 撑满
    }  // resultView 结束

    private var starsColor: Color {  // 得分颜色
        (result?.stars ?? 0) > 0 ? .appOK : .appErr  // 过绿不过红
    }  // 属性结束

    private var feedbackText: String {  // 反馈文案
        guard let r = result else { return "" }  // 无成绩给空
        switch r.stars {  // 按星级分支
        case 3: return "全对。这一关的知识点已经拿下，可以进下一关。"  // 三星
        case 2: return "错 1 题。错的那题已经进了错题本，明天重做一次。"  // 二星
        case 1: return "错 2 题。建议先回去看这章的解析，再来打。"  // 一星
        default: return "这一关没过。别急，先把错题搞懂比刷更多题有用。"  // 零星
        }  // 分支结束
    }  // 属性结束

    private func submit(_ q: Question) {  // 提交答案
        if app.recordAnswer(question: q, picked: picked, inLevel: true) {  // 唯一写入口记账
            correctCount += 1  // 答对计数加一
        }  // 分支结束
        withAnimation(.easeOut(duration: 0.2)) {  // 带动画
            submitted = true  // 标记已提交
        }  // 动画结束
    }  // submit 结束

    private func next() {  // 下一题或结算
        if index + 1 < questions.count {  // 还有题
            index += 1  // 前进一题
            picked = []  // 清空选择
            submitted = false  // 重置提交态
        } else {  // 最后一题
            let isFirstClear = app.levelResult(for: levelID) == nil  // 首通必须在写盘前判
            result = app.finishLevel(id: levelID, correct: correctCount, total: questions.count)  // 结算
            foodGained = isFirstClear ? 2 : 1  // 首通 2 颗否则 1 颗
            withAnimation { finished = true }  // 切到结果页
        }  // 分支结束
    }  // next 结束

    private func restart() {  // 重打本关
        index = 0  // 回到第一题
        picked = []  // 清空选择
        submitted = false  // 重置提交态
        correctCount = 0  // 答对清零
        result = nil  // 清空成绩
        foodGained = 0  // 清空奖励
        finished = false  // 退出结果页
    }  // restart 结束

    private func topicName(_ id: String) -> String {  // 板块名
        app.bank?.topics.first { $0.id == id }?.name ?? "综合"  // 找不到给综合
    }  // 方法结束
}  // LevelPlayView 结束
