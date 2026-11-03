//  PaperListView.swift —— 试卷列表（历年真题 / 自编模拟卷）        // 文件说明
//  真题区不造假：没有合法来源的试卷就显示空态并说明原因，不拿模拟卷冒充真题  // 诚实约束
//  模拟卷全部标注「按考纲自编」，来源写在卡片上                          // 诚实约束

import SwiftUI  // 界面框架

struct PaperListView: View {  // 试卷列表页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var kind: PaperKind  // 当前看哪一类

    init(initialKind: PaperKind = .real) {  // 构造器：可指定默认分类
        _kind = State(initialValue: initialKind)  // 初始化分段选中
    }  // 构造结束

    private var papers: [Paper] {  // 当前分类的试卷（只看当前考试方向）
        PaperCatalog.shared.papers(kind: kind, track: app.currentTrack.id)  // 按种类 + 方向筛
    }  // 属性结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                Picker("分类", selection: $kind) {  // 分段控件
                    Text("历年真题").tag(PaperKind.real)  // 真题
                    Text("自编模拟卷").tag(PaperKind.mock)  // 模拟
                }  // 分段结束
                .pickerStyle(.segmented)  // 分段样式

                if papers.isEmpty {  // 这一类没有试卷
                    emptyState  // 空态说明
                } else {  // 有试卷
                    ForEach(papers) { paper in  // 逐套
                        paperCard(paper)  // 试卷卡
                    }  // 遍历结束
                }  // 分支结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("整套试卷")  // 标题
    }  // body 结束

    private func spec(icon: String, text: String) -> some View {  // 一个规格小项
        HStack(spacing: 3) {  // 紧密排列
            Image(systemName: icon)  // 图标
            Text(verbatim: text)  // 文字（verbatim 防止 2026 变成 2,026）
        }  // 排列结束
    }  // spec 结束

    private var emptyState: some View {  // 空态
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack(spacing: Space.xs) {  // 标题行
                    Image(systemName: "exclamationmark.circle.fill")  // 提示图标
                        .foregroundStyle(Color.appWarn)  // 橙色
                    Text("「\(app.currentTrack.name)」方向还没有真题卷")  // 标题（带上当前方向，避免误解成整个库都空）
                        .font(AppFont.bodyStrong)  // 加粗正文
                }  // 排列结束
                Text("现有的院校真题考点卷覆盖：税务（中南财 2016 / 2019、人大）、金融（复旦 2022、上财 2021）。法律、计算机两个方向还在补。")  // 写清实际覆盖范围
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Text("要说清的是：这些卷不是原题。官方不公开复试真题，市面上流传的都是机构整理的考生回忆版，没有标准答案；我们只取它的考点，题目与解析按现行法条重写，每张卷卡的说明里都写明了来源。")  // 如实说明真题卷的口径
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Button {  // 先切到模拟卷
                    kind = .mock  // 切分类
                } label: {  // 按钮外观
                    Text("先做自编模拟卷 →")  // 文案
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 按钮结束
                .buttonStyle(.plain)  // 不用默认高亮
            }  // 排列结束
        }  // 卡片结束
    }  // emptyState 结束

    private func paperCard(_ paper: Paper) -> some View {  // 单套试卷卡
        NavigationLink {  // 进作答页
            PaperPlayView(paper: paper)  // 整套试卷
        } label: {  // 卡片外观
            Card {  // 卡片
                VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                    HStack {  // 标题行
                        Text(paper.title).font(AppFont.section)  // 试卷标题
                        Spacer()  // 撑开
                        Chip(text: paper.kind.title, tint: paper.kind == .real ? .appOK : .appBrand)  // 来源标签
                    }  // 排列结束
                    HStack(spacing: Space.s) {  // 规格行
                        spec(icon: "calendar", text: "\(paper.year)")  // 年份
                        spec(icon: "list.number", text: "\(paper.questionCount) 题")  // 题量
                        spec(icon: "clock", text: "\(paper.minutes) 分钟")  // 时长
                    }  // 排列结束
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色

                    Text(paper.sourceNote)  // 来源说明
                        .font(.system(size: 11))  // 更小的字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                        .fixedSize(horizontal: false, vertical: true)  // 允许换行

                    HStack {  // 底部一行
                        Text(paper.subject).font(AppFont.caption)  // 科目
                            .foregroundStyle(Color.textSecondary)  // 次要色
                        Spacer()  // 撑开
                        Text("开始作答")  // 引导
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(Color.appBrand)  // 品牌色
                        Image(systemName: "chevron.right")  // 箭头
                            .font(.system(size: 11, weight: .semibold))  // 小箭头
                            .foregroundStyle(Color.textTertiary)  // 弱化色
                    }  // 排列结束
                }  // 排列结束
            }  // 卡片结束
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // paperCard 结束
}  // PaperListView 结束
