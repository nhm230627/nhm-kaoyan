//  QuizHomeView.swift —— 刷题首页（严格对齐 Web 样板 page-quiz）      // 文件说明
//  样板结构：三格统计 → 选择知识点（多选）→ 选择题型 → 每组题量 → 作答模式 → 开始练习 → 工具
//  不得私自增删模块；「历年真题训练」是用户 2026-11-03 明确要求新增的，放在工具区首行并标注
//  题库没加载完显示加载态，筛不出题就明说原因，不装作能开始                 // 诚实约束

import SwiftUI  // 界面框架

struct QuizHomeView: View {  // 刷题首页
    @Environment(AppState.self) private var app  // 全局状态

    @State private var pickedTopics: Set<String> = []  // 已选知识点，空 = 全部
    @State private var pickedType = "all"  // 题型筛选，all/single/multi/judge
    @State private var size = 20  // 每组题量
    @State private var revealEach = false  // 作答模式：false = 交卷后统一看
    @State private var session: Paper?  // 组好的练习题
    @State private var hint: String?  // 轻提示

    private var topics: [Topic] { app.bank?.topics ?? [] }  // 全部知识点

    var body: some View {  // 视图主体
        Group {  // 分组切换状态
            if app.bank == nil {  // 题库未加载
                if let error = app.loadError {  // 有错误
                    ErrorState(error: error) { app.loadBank() }  // 显示错误可重试
                } else {  // 加载中
                    LoadingState(text: "题库加载中…")  // 转圈
                }  // 分支结束
            } else {  // 正常
                content  // 主内容
            }  // 分支结束
        }  // 分组结束
        .background(Color.appBG)  // 底色
        .navigationTitle("刷题闯关")  // 标题
        .fullScreenCover(item: $session) { paper in  // 开始练习
            NavigationStack {  // 套导航栈才有标题栏
                PaperPlayView(paper: paper, revealEach: revealEach)  // 组卷答题
            }  // 栈结束
        }  // 覆盖层结束
        .overlay(alignment: .bottom) {  // 底部提示
            if let hint {  // 有提示才显示
                Text(hint)  // 提示文案
                    .font(AppFont.captionStrong)  // 小字加粗
                    .padding(.horizontal, Space.l)  // 左右内边距
                    .padding(.vertical, Space.s)  // 上下内边距
                    .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃胶囊
                    .padding(.bottom, Space.xxl)  // 距底
                    .transition(.opacity)  // 淡入淡出
            }  // 分支结束
        }  // 浮层结束
    }  // body 结束

    private var content: some View {  // 主内容
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                summary  // 三格统计
                topicGroup  // 选择知识点
                typeGroup  // 选择题型
                sizeGroup  // 每组题量
                modeGroup  // 作答模式
                startButton  // 开始练习
                toolGroup  // 工具
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
    }  // content 结束

    // MARK: - 三格统计                                                // 分节：统计

    private var summary: some View {  // 题库总题数 / 已作答 / 正确率
        Card {  // 卡片
            HStack(spacing: 0) {  // 三格横排
                StatTile(value: "\(app.bank?.questions.count ?? 0)", title: "题库总题数")  // 总题数
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.data.attempts.count)", title: "已作答", tint: .appBrand)  // 已作答
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: overallAccuracy, title: "正确率", tint: accuracyColor)  // 正确率
            }  // 排列结束
        }  // 卡片结束
    }  // summary 结束

    private var overallAccuracy: String {  // 累计正确率
        let all = app.data.attempts  // 全部作答记录
        guard !all.isEmpty else { return "0%" }  // 没答过就是 0%
        let right = all.filter { $0.isCorrect }.count  // 答对数
        return "\(Int((Double(right) / Double(all.count) * 100).rounded()))%"  // 百分比
    }  // 属性结束

    private var accuracyColor: Color {  // 正确率配色
        let all = app.data.attempts  // 全部记录
        guard !all.isEmpty else { return .textPrimary }  // 没数据用主色
        let ratio = Double(all.filter { $0.isCorrect }.count) / Double(all.count)  // 正确率
        if ratio >= 0.8 { return .appOK }  // 80% 以上绿
        if ratio >= 0.6 { return .appWarn }  // 60% 以上橙
        return .appErr  // 低于 60% 红
    }  // 属性结束

    // MARK: - 选择知识点                                              // 分节：知识点

    private var topicGroup: some View {  // 知识点两列网格（样板 .topic-grid）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            groupTitle("选择知识点", note: "可多选，不选即全部")  // 标题
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {  // 两列
                ForEach(topics) { topic in  // 逐个知识点
                    topicCard(topic)  // 知识点卡
                }  // 遍历结束
            }  // 网格结束
        }  // 排列结束
    }  // topicGroup 结束

    private func topicCard(_ topic: Topic) -> some View {  // 单个知识点卡
        let on = pickedTopics.contains(topic.id)  // 是否选中
        let count = app.bank?.questions.filter { $0.topic == topic.id }.count ?? 0  // 该板块题数
        return Button {  // 点击切换
            if on { pickedTopics.remove(topic.id) } else { pickedTopics.insert(topic.id) }  // 多选开关
        } label: {  // 卡片外观
            VStack(alignment: .leading, spacing: 2) {  // 纵向排列
                Text(topic.name).font(AppFont.bodyStrong)  // 名称
                    .foregroundStyle(on ? Color.appBrand : Color.textPrimary)  // 选中变蓝
                Text(topic.desc).font(.system(size: 10.5))  // 说明
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .lineLimit(2)  // 最多两行
                    .multilineTextAlignment(.leading)  // 左对齐
                Text(verbatim: "\(count) 题").font(.system(size: 10))  // 题数
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .padding(.top, 4)  // 与说明隔开
            }  // 排列结束
            .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐撑满
            .padding(.horizontal, 13)  // 左右内边距
            .padding(.vertical, 12)  // 上下内边距
            .background(  // 背景
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角
                    .fill(on ? Color.appBrand.opacity(0.10) : Color.appCard)  // 选中淡蓝
            )  // 背景结束
            .overlay(  // 描边
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // 同形
                    .stroke(on ? Color.appBrand.opacity(0.45) : Color.clear, lineWidth: 1.5)  // 选中才有边
            )  // 描边结束
            .contentShape(Rectangle())  // 整卡可点
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
        .accessibilityLabel("\(topic.name)，\(count) 题，\(on ? "已选" : "未选")")  // 朗读
    }  // topicCard 结束

    // MARK: - 选择题型                                                // 分节：题型

    private var typeGroup: some View {  // 题型 chips（样板 .type-row）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            groupTitle("选择题型", note: "点选筛题")  // 标题
            ScrollView(.horizontal, showsIndicators: false) {  // 横向滚动
                HStack(spacing: Space.xs) {  // 横向排列
                    typeChip(id: "all", title: "全部")  // 全部
                    typeChip(id: "single", title: "单项选择")  // 单选
                    typeChip(id: "multi", title: "多项选择")  // 多选
                    typeChip(id: "judge", title: "判断题")  // 判断
                }  // 排列结束
            }  // 滚动结束
            .scrollClipDisabled()  // 允许边缘溢出
        }  // 排列结束
    }  // typeGroup 结束

    private func typeChip(id: String, title: String) -> some View {  // 单个题型 chip
        let on = pickedType == id  // 是否选中
        return Button {  // 点击切换
            pickedType = id  // 单选互斥
        } label: {  // 胶囊外观
            Text(title)  // 文案
                .font(AppFont.captionStrong)  // 小字加粗
                .foregroundStyle(on ? Color.white : Color.textSecondary)  // 选中白字
                .padding(.horizontal, 13)  // 左右内边距
                .frame(height: 30)  // 与样板 .tchip 同高
                .background(Capsule().fill(on ? Color.appBrand : Color.appCard))  // 选中实心
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // typeChip 结束

    // MARK: - 每组题量                                                // 分节：题量

    private var sizeGroup: some View {  // 三段选一（样板 .seg）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            groupTitle("每组题量", note: nil)  // 标题
            HStack(spacing: 4) {  // 横向排列
                ForEach([15, 20, 30], id: \.self) { n in  // 三个档
                    Button {  // 点击选档
                        size = n  // 记录题量
                    } label: {  // 段外观
                        Text(verbatim: "\(n) 题")  // 文案
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(size == n ? Color.textPrimary : Color.textSecondary)  // 选中主色
                            .frame(maxWidth: .infinity)  // 等分
                            .frame(height: 34)  // 高度
                            .background(  // 背景
                                RoundedRectangle(cornerRadius: 8, style: .continuous)  // 白色滑块
                                    .fill(size == n ? Color.appCard : Color.clear)  // 选中才白
                            )  // 背景结束
                    }  // 外观结束
                    .buttonStyle(.plain)  // 不用默认高亮
                }  // 遍历结束
            }  // 排列结束
            .padding(4)  // 槽内边距
            .background(  // 槽底
                RoundedRectangle(cornerRadius: 11, style: .continuous)  // 圆角
                    .fill(Color.separator.opacity(0.35))  // 灰槽
            )  // 背景结束
        }  // 排列结束
    }  // sizeGroup 结束

    // MARK: - 作答模式                                                // 分节：模式

    private var modeGroup: some View {  // 答案与解析模式
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            groupTitle("作答模式", note: nil)  // 标题
            Card {  // 卡片
                Button {  // 点击切换
                    revealEach.toggle()  // 两种模式互切
                } label: {  // 行外观
                    HStack {  // 横向排列
                        Text("答案与解析").font(AppFont.bodyStrong)  // 标签
                        Spacer()  // 撑开
                        Text(revealEach ? "做一题看一题" : "交卷后统一看")  // 当前值
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                        Image(systemName: "chevron.right")  // 箭头
                            .font(.system(size: 11, weight: .semibold))  // 小箭头
                            .foregroundStyle(Color.textTertiary)  // 弱化色
                    }  // 排列结束
                    .contentShape(Rectangle())  // 整行可点
                }  // 外观结束
                .buttonStyle(.plain)  // 不用默认高亮
            }  // 卡片结束
        }  // 排列结束
    }  // modeGroup 结束

    // MARK: - 开始练习                                                // 分节：开始

    private var startButton: some View {  // 开始练习按钮
        VStack(spacing: Space.xs) {  // 纵向排列
            PrimaryButton(title: "开始练习", systemImage: "play.fill") {  // 主按钮
                beginQuiz()  // 组卷并进入
            }  // 按钮结束
            Text(verbatim: "按当前筛选可抽 \(filtered.count) 题")  // 可用题数
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
    }  // startButton 结束

    private var filtered: [Question] {  // 按筛选条件过滤后的题
        guard let bank = app.bank else { return [] }  // 题库没来
        return bank.questions.filter { q in  // 逐题过滤
            let topicOK = pickedTopics.isEmpty || pickedTopics.contains(q.topic)  // 知识点条件
            let typeOK = pickedType == "all" || q.type.rawValue == pickedType  // 题型条件
            return topicOK && typeOK  // 两个都满足
        }  // 过滤结束
    }  // 属性结束

    private func beginQuiz() {  // 组卷开练
        let pool = filtered.shuffled()  // 打乱
        guard !pool.isEmpty else {  // 一题都没有
            show(pickedType == "all" ? "当前筛选下没有题目，换个知识点试试" : "题库里还没有「\(typeTitle)」类的题")  // 说清原因
            return  // 不进入
        }  // 分支结束
        let picked = Array(pool.prefix(size))  // 取够题量
        session = Paper(  // 现场组一套练习
            id: "paper.practice",  // 固定 id
            title: "练习 · \(picked.count) 题",  // 标题
            kind: .mock,  // 归为自编
            direction: .tax,  // 方向占位
            year: Calendar.current.component(.year, from: Date()),  // 当年
            subject: subjectText,  // 科目描述
            minutes: max(5, picked.count),  // 每题约一分钟
            totalScore: picked.count * 2,  // 每题 2 分
            sourceNote: "按当前筛选条件组卷；题目全部按考纲自编，非官方真题。",  // 来源
            sections: [PaperSection(title: "练习", questionIDs: picked.map { $0.id })]  // 单一大题
        )  // 构造结束
    }  // beginQuiz 结束

    private var typeTitle: String {  // 题型中文名
        switch pickedType {  // 按值分支
        case "single": "单项选择"  // 单选
        case "multi": "多项选择"  // 多选
        case "judge": "判断题"  // 判断
        default: "全部"  // 全部
        }  // 分支结束
    }  // 属性结束

    private var subjectText: String {  // 科目描述
        pickedTopics.isEmpty ? "全部知识点" : "已选 \(pickedTopics.count) 个知识点"  // 两种情况
    }  // 属性结束

    // MARK: - 工具                                                    // 分节：工具

    private var toolGroup: some View {  // 工具区
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            groupTitle("工具", note: nil)  // 标题
            Card {  // 卡片
                VStack(spacing: 0) {  // 纵向排列
                    NavigationLink {  // 历年真题训练（用户要求新增，样板无此行）
                        PaperListView(initialKind: .real)  // 试卷列表
                    } label: {  // 行外观
                        toolRow(icon: "doc.text.fill", title: "历年真题训练",  // 图标与标题
                                trailing: "\(PaperCatalog.shared.papers(kind: .real).count) 套")  // 右侧显示套数
                    }  // 链接结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    Divider().padding(.leading, 44)  // 分隔线
                    NavigationLink {  // 错题本
                        WrongBookView()  // 错题本页
                    } label: {  // 行外观
                        toolRow(icon: "bandage.fill", title: "错题本",  // 图标与标题
                                trailing: "\(app.unresolvedWrongs.count) 题")  // 右侧显示未掌握数
                    }  // 链接结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    Divider().padding(.leading, 44)  // 分隔线
                    NavigationLink {  // 闯关模式
                        ChapterListView()  // 章节关卡列表
                    } label: {  // 行外观
                        toolRow(icon: "flame.fill", title: "闯关模式", trailing: "按章节闯关")  // 行内容
                    }  // 链接结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    Divider().padding(.leading, 44)  // 分隔线
                    Button {  // AI 智能组卷（未开发）
                        show("AI 智能组卷还没做，先用「开始练习」按薄弱点手动筛")  // 如实说
                    } label: {  // 行外观
                        toolRow(icon: "wand.and.stars", title: "AI 智能组卷",  // 图标与标题
                                trailing: "按薄弱点生成", badge: "待开发")  // 右侧标注未开发
                    }  // 按钮结束
                    .buttonStyle(.plain)  // 不用默认高亮
                    Divider().padding(.leading, 44)  // 分隔线
                    Button {  // 我的题库（未开发）
                        show("自建题库还没做，先把内置题库刷完")  // 如实说
                    } label: {  // 行外观
                        toolRow(icon: "square.and.pencil", title: "我的题库",  // 图标与标题
                                trailing: "0 道自建", badge: "待开发")  // 右侧标注未开发
                    }  // 按钮结束
                    .buttonStyle(.plain)  // 不用默认高亮
                }  // 排列结束
            }  // 卡片结束
        }  // 排列结束
    }  // toolGroup 结束

    private func toolRow(icon: String, title: String, trailing: String, badge: String? = nil) -> some View {  // 工具行
        HStack(spacing: Space.m) {  // 横向排列
            Image(systemName: icon)  // 图标
                .font(.system(size: 15))  // 图标大小
                .foregroundStyle(Color.appBrand)  // 品牌色
                .frame(width: 22)  // 固定宽度对齐
            Text(title).font(AppFont.body)  // 标题
            Spacer(minLength: Space.xs)  // 撑开
            if let badge {  // 有待开发标记
                Chip(text: badge, tint: .appWarn)  // 小标签
            }  // 分支结束
            Text(trailing)  // 右侧说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 11, weight: .semibold))  // 小箭头
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .padding(.vertical, Space.s)  // 上下内边距
        .contentShape(Rectangle())  // 整行可点
    }  // toolRow 结束

    private func groupTitle(_ text: String, note: String?) -> some View {  // 分组标题
        HStack(spacing: Space.xs) {  // 横向排列
            Text(text).font(AppFont.section)  // 标题
            if let note {  // 有说明才显示
                Text(note).font(AppFont.caption).foregroundStyle(Color.textTertiary)  // 说明
            }  // 分支结束
            Spacer()  // 撑开
        }  // 排列结束
    }  // groupTitle 结束

    private func show(_ text: String) {  // 弹提示
        withAnimation { hint = text }  // 淡入
        Task {  // 异步延时
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 等 1.8 秒
            withAnimation { hint = nil }  // 淡出
        }  // 任务结束
    }  // show 结束
}  // QuizHomeView 结束
