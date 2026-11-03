//  QuizResultView.swift —— 练习结果页（严格对齐 Web 样板 page-result）      // 文件说明
//  结构：结果卡（得分 + 答对/答错/用时）→ 再来一组 / 查看解析 → 逐题解析
//  得分口径照样板：百分制 = 答对数 ÷ 总题数 × 100                         // 口径说明
//  解析行照样板：✓/✕ 方块 + 「第 N 题」软标签 + 知识点标签 + 题干 + 你选｜正确 + 解析

import SwiftUI  // 界面框架

struct QuizResultItem: Identifiable {  // 结果页里的一道题
    var id: String { question.id }  // 用题目 id 当唯一键
    let question: Question  // 题目本体
    let picked: Set<Int>  // 用户选了什么
    let ok: Bool  // 是否答对
}  // QuizResultItem 结束

struct QuizResultView: View {  // 练习结果页
    @Environment(AppState.self) private var app  // 取知识点中文名

    let items: [QuizResultItem]  // 逐题结果
    let seconds: Int  // 用时秒数
    let revealInstant: Bool  // 是否「每题即时看」模式
    let unanswered: Int  // 未作答题数，照样板提示
    var onAgain: () -> Void  // 再来一组
    var onClose: () -> Void  // 离开结果页

    // MARK: - 统计                                                    // 分节：统计

    private var rightCount: Int { items.filter(\.ok).count }  // 答对题数
    private var wrongCount: Int { items.count - rightCount }  // 答错题数

    private var score: Int {  // 百分制得分（与样板一致）
        guard !items.isEmpty else { return 0 }  // 没题就是 0
        return Int((Double(rightCount) / Double(items.count) * 100).rounded())  // 四舍五入
    }  // score 结束

    private var timeText: String {  // 秒数转 mm:ss
        String(format: "%02d:%02d", seconds / 60, seconds % 60)  // 补零输出
    }  // timeText 结束

    // MARK: - 视图                                                    // 分节：视图

    var body: some View {  // 视图主体
        ScrollViewReader { proxy in  // 用于「查看解析」滚动定位
            ScrollView {  // 可滚动
                VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                    hero  // 结果卡
                    if unanswered > 0 { unansweredNote }  // 未答提示
                    actionRow(proxy)  // 再来一组 / 查看解析
                    reviewSection  // 逐题解析
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
                .padding(.bottom, Space.xxl)  // 底部留白
            }  // 滚动结束
        }  // 阅读器结束
    }  // body 结束

    private var hero: some View {  // 渐变结果卡（样板 .result-hero）
        HStack(spacing: Space.m) {  // 左分数右三栏
            VStack(spacing: 2) {  // 得分
                Text(verbatim: "\(score)")  // 大号分数
                    .font(.system(size: 46, weight: .bold, design: .rounded))  // 圆体大数字
                Text("得分")  // 单位说明
                    .font(.system(size: 11))  // 小字
                    .opacity(0.85)  // 略透明
            }  // 得分结束
            .frame(minWidth: 78)  // 固定宽度占位

            HStack(spacing: Space.xs) {  // 三栏明细
                metaCell(value: "\(rightCount)", title: "答对")  // 答对
                metaCell(value: "\(wrongCount)", title: "答错")  // 答错
                metaCell(value: timeText, title: "用时")  // 用时
            }  // 明细结束
            .frame(maxWidth: .infinity)  // 撑满剩余宽度
        }  // 排列结束
        .foregroundStyle(.white)  // 白字
        .padding(18)  // 与样板 padding 一致
        .background(  // 渐变底（样板 140deg #1b2a6b → #2b54e8）
            LinearGradient(colors: [Color(hex: 0x1B2A6B), Color(hex: 0x2B54E8)],  // 两个色标
                           startPoint: .topLeading, endPoint: .bottomTrailing)  // 左上到右下
        )  // 背景结束
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))  // 圆角 20
    }  // hero 结束

    private func metaCell(value: String, title: String) -> some View {  // 一栏明细
        VStack(spacing: 3) {  // 上数字下标题
            Text(verbatim: value)  // 数值
                .font(.system(size: 17, weight: .bold, design: .rounded))  // 加粗
                .monospacedDigit()  // 等宽，三栏不错位
            Text(title)  // 标题
                .font(.system(size: 10.5))  // 小字
                .opacity(0.82)  // 略透明
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 三等分
    }  // metaCell 结束

    private var unansweredNote: some View {  // 未作答提示（样板是 toast，这里常驻更不容易漏看）
        HStack(spacing: Space.xs) {  // 图标 + 文案
            Image(systemName: "exclamationmark.circle.fill")  // 提示图标
                .foregroundStyle(Color.appWarn)  // 橙色
            Text(verbatim: "还有 \(unanswered) 题未作答，已按答错计入")  // 与样板文案一致
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
        }  // 排列结束
        .padding(.horizontal, Space.s)  // 左右内边距
        .padding(.vertical, 8)  // 上下内边距
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
        .background(  // 淡橙底
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 圆角
                .fill(Color.appWarn.opacity(0.10))  // 淡色
        )  // 背景结束
    }  // unansweredNote 结束

    private func actionRow(_ proxy: ScrollViewProxy) -> some View {  // 两个按钮（样板 row-2 等分）
        HStack(spacing: Space.s) {  // 横向等分
            PrimaryButton(title: "再来一组", systemImage: "arrow.clockwise") {  // 主按钮
                onAgain()  // 重新组卷
            }  // 按钮结束
            GhostButton(title: "查看解析", systemImage: "text.magnifyingglass") {  // 次按钮
                withAnimation { proxy.scrollTo("review", anchor: .top) }  // 滚到解析区
            }  // 按钮结束
        }  // 排列结束
    }  // actionRow 结束

    private var reviewSection: some View {  // 逐题解析
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack(spacing: Space.xs) {  // 标题行
                Text("逐题解析")  // 标题
                    .font(AppFont.section)  // 分节字号
                Text(revealInstant ? "每题即时展示已开启" : "交卷模式 · 全部解析")  // 与样板一致
                    .font(.system(size: 10.5))  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束
            .id("review")  // 滚动锚点

            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in  // 逐题
                reviewRow(item, index: offset)  // 复盘行
            }  // 遍历结束
        }  // 排列结束
    }  // reviewSection 结束

    private func reviewRow(_ item: QuizResultItem, index: Int) -> some View {  // 一道题的解析卡
        VStack(alignment: .leading, spacing: 7) {  // 纵向排列
            HStack(spacing: 7) {  // 头部：对错 + 题号 + 知识点
                Text(item.ok ? "✓" : "✕")  // 对错符号
                    .font(.system(size: 10, weight: .bold))  // 小字加粗
                    .foregroundStyle(.white)  // 白字
                    .frame(width: 18, height: 18)  // 与样板同尺寸
                    .background(  // 底色
                        RoundedRectangle(cornerRadius: 6, style: .continuous)  // 圆角 6
                            .fill(item.ok ? Color.appOK : Color.appErr)  // 对绿错红
                    )  // 背景结束
                softTag("第 \(index + 1) 题")  // 软标签
                brandTag(topicName(item.question.topic))  // 知识点标签
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束

            Text(item.question.stem)  // 题干
                .font(.system(size: 13.5, weight: .semibold))  // 与样板 .rv-stem 一致
                .fixedSize(horizontal: false, vertical: true)  // 允许换行

            Text(verbatim: "你选：\(pickedText(item.picked)) ｜ 正确：\(item.question.answerText)")  // 你选与正确
                .font(.system(size: 11.5))  // 与样板 .rv-line 一致
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行

            DashedRule()  // 虚线分割
                .stroke(Color.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))  // 细虚线
                .frame(height: 1)  // 一线高
                .padding(.top, 5)  // 与上文隔开

            Text(item.question.explain)  // 解析
                .font(.system(size: 11.5))  // 与样板 .rv-exp 一致
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .padding(13)  // 与样板 .rv-item padding 一致
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
        .background(  // 卡片底
            RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                .fill(Color.appCard)  // 卡片色
        )  // 背景结束
    }  // reviewRow 结束

    // MARK: - 小件                                                    // 分节：小件

    private func softTag(_ text: String) -> some View {  // 软标签（样板 .tag.soft）
        Text(text)  // 内容
            .font(.system(size: 11, weight: .medium))  // 11 号
            .foregroundStyle(Color.textSecondary)  // 次要色
            .padding(.horizontal, 9)  // 左右内边距
            .frame(height: 22)  // 与样板同高
            .background(  // 浅灰底
                RoundedRectangle(cornerRadius: 7, style: .continuous)  // 圆角 7
                    .fill(Color(hex: 0xF2F2F7))  // 样板同色
            )  // 背景结束
    }  // softTag 结束

    private func brandTag(_ text: String) -> some View {  // 知识点标签（样板 .tag）
        Text(text)  // 内容
            .font(.system(size: 11, weight: .semibold))  // 11 号加粗
            .foregroundStyle(Color.appBrand)  // 品牌色
            .padding(.horizontal, 9)  // 左右内边距
            .frame(height: 22)  // 与样板同高
            .background(  // 淡蓝底
                RoundedRectangle(cornerRadius: 7, style: .continuous)  // 圆角 7
                    .fill(Color.appBrand.opacity(0.10))  // 品牌色淡底
            )  // 背景结束
    }  // brandTag 结束

    private func topicName(_ id: String) -> String {  // 知识点 id 转中文名
        app.bank?.topics.first { $0.id == id }?.name ?? id  // 找不到就显示 id
    }  // topicName 结束

    private func pickedText(_ picked: Set<Int>) -> String {  // 用户答案文本
        guard !picked.isEmpty else { return "未作答" }  // 没答
        return picked.sorted().map { Question.letter($0) }.joined(separator: "、")  // 字母拼起来
    }  // pickedText 结束
}  // QuizResultView 结束

struct DashedRule: Shape {  // 虚线与实线共用的横线形状
    func path(in rect: CGRect) -> Path {  // 画出路径
        var path = Path()  // 空路径
        path.move(to: CGPoint(x: 0, y: rect.midY))  // 左端
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))  // 右端
        return path  // 返回
    }  // path 结束
}  // DashedRule 结束
