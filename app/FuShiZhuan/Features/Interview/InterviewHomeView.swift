//  InterviewHomeView.swift —— 模拟面试入口                            // 文件说明
//  只做「设置 + 场次说明 + 开始 + 复盘入口」，面试过程在房间页里          // 页面职责
//  不许做成点了没反应，也不许假装能开始                               // 诚实约束

import SwiftUI  // 界面框架

struct InterviewHomeView: View {  // 面试首页
    @Environment(AppState.self) private var app  // 全局状态

    @State private var mode: InterviewMode = .professional  // 面试类型
    @State private var style: MentorStyle = .standard  // 导师风格
    @State private var showRoom = false  // 是否进入面试房间

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                quotaCard  // 场次卡
                setupCard  // 设置卡
                mockExamLink  // 模考大厅入口
                historyCard  // 复盘入口
                compositionCard  // 考场构成
                disclaimer  // 免责声明
                startButton  // 开始按钮
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("模拟面试")  // 标题
    }  // body 结束

    private var quotaCard: some View {  // 场次卡
        Card {  // 卡片
            HStack {  // 横向排列
                VStack(alignment: .leading, spacing: 2) {  // 文字区
                    Text("今日剩余场次").font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                    Text("\(app.entitlement.remaining(.interviewDaily) ?? 99) 场")  // 剩余场次
                        .font(AppFont.metric)  // 指标字号
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 文字区结束
                Spacer()  // 撑开
                if !app.entitlement.isActive() {  // 免费用户
                    Chip(text: "免费版每日 1 场", tint: .appWarn)  // 额度提示
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // quotaCard 结束

    private var setupCard: some View {  // 设置卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                Text("本场设置").font(AppFont.section)  // 区段标题

                labeledPicker("面试类型") {  // 类型选择
                    Picker("面试类型", selection: $mode) {  // 分段控件
                        ForEach(InterviewMode.allCases) { m in  // 遍历选项
                            Text(m.title).tag(m)  // 每项
                        }  // 遍历结束
                    }  // 选择器结束
                    .pickerStyle(.segmented)  // 分段样式
                }  // 选择块结束

                labeledPicker("导师风格") {  // 风格选择
                    Picker("导师风格", selection: $style) {  // 分段控件
                        ForEach(MentorStyle.allCases) { s in  // 遍历选项
                            Text(s.title).tag(s)  // 每项
                        }  // 遍历结束
                    }  // 选择器结束
                    .pickerStyle(.segmented)  // 分段样式
                }  // 选择块结束

                Text("导师风格只影响追问强度与节奏，不影响评分标准。")  // 说明
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 排列结束
        }  // 卡片结束
    }  // setupCard 结束

    private func labeledPicker<Content: View>(  // 带标题的选择器
        _ title: String,  // 标题
        @ViewBuilder content: () -> Content  // 内容
    ) -> some View {  // 返回视图
        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
            Text(title).font(AppFont.captionStrong).foregroundStyle(Color.textSecondary)  // 标题
            content()  // 内容
        }  // 排列结束
    }  // labeledPicker 结束

    private var mockExamLink: some View {  // 模考入口
        NavigationLink {  // 进入大厅
            MockExamHomeView()  // 大厅页
        } label: {  // 行外观
            Card {  // 卡片
                HStack(spacing: Space.xs) {  // 横向排列
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text("模考大厅").font(AppFont.bodyStrong)  // 标题
                        Text("预约场次、看自己和模拟对手的差距")  // 说明
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                    }  // 文字区结束
                    Spacer()  // 撑开
                    Chip(text: "单机模拟", tint: .appWarn)  // 如实标记
                    Image(systemName: "chevron.right")  // 箭头
                        .font(.system(size: 11))  // 小图标
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
            }  // 卡片结束
        }  // 链接结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // mockExamLink 结束

    private var historyCard: some View {  // 复盘卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack {  // 标题行
                    Text("近期场次").font(AppFont.section)  // 标题
                    Spacer()  // 撑开
                    Text("共 \(app.data.sessions.count) 场")  // 总场次
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 排列结束
                if recentSessions.isEmpty {  // 还没面过
                    Text("还没有面试记录，完成一场后这里会出现复盘入口。")  // 说明
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                } else {  // 有记录
                    ForEach(recentSessions) { item in  // 遍历最近五场
                        NavigationLink {  // 点击进复盘
                            InterviewReviewView(session: item)  // 详情页
                        } label: {  // 行外观
                            historyRow(item)  // 单行
                        }  // 链接结束
                        .buttonStyle(.plain)  // 不用默认高亮
                    }  // 遍历结束
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // historyCard 结束

    private var recentSessions: [InterviewSession] {  // 最近五场
        Array(app.data.sessions.sorted { $0.startedAt > $1.startedAt }.prefix(5))  // 时间倒序取五
    }  // 属性结束

    private func historyRow(_ item: InterviewSession) -> some View {  // 单行
        HStack(spacing: Space.xs) {  // 横向排列
            VStack(alignment: .leading, spacing: 2) {  // 左侧文字
                Text(item.startedAt.formatted(date: .numeric, time: .shortened))  // 时间
                    .font(AppFont.bodyStrong)  // 加粗
                Text(item.state == .abandoned ? "未完成" : item.mode.title)  // 状态或类型
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
            }  // 文字结束
            Spacer()  // 撑开
            Text(item.overallScore.map { "\($0)" } ?? "—")  // 分数或占位
                .font(AppFont.captionStrong)  // 小字加粗
                .foregroundStyle(item.overallScore == nil ? Color.textTertiary : Color.appBrand)  // 有分才上色
            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 11))  // 小图标
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .contentShape(Rectangle())  // 整行可点
    }  // historyRow 结束

    private var compositionCard: some View {  // 考场构成卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                HStack {  // 标题行
                    Text("考场构成").font(AppFont.section)  // 标题
                    Spacer()  // 撑开
                    Text("总时长 20 分钟")  // 时长
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 排列结束

                ForEach(InterviewPhase.allCases) { phase in  // 遍历五个环节
                    HStack(alignment: .top, spacing: Space.m) {  // 横向排列
                        Text("\(phase.seconds / 60)′")  // 该环节分钟数
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(Color.appBrand)  // 品牌色
                            .frame(width: 30, alignment: .leading)  // 固定宽度
                        VStack(alignment: .leading, spacing: 2) {  // 文字区
                            Text(phase.title).font(AppFont.bodyStrong)  // 环节名
                            Text(phase.speakers.map(\.title).joined(separator: "、"))  // 提问人
                                .font(AppFont.caption)  // 小字
                                .foregroundStyle(Color.textSecondary)  // 次要色
                        }  // 文字区结束
                        Spacer()  // 撑开
                    }  // 排列结束
                }  // 遍历结束

                Divider()  // 分隔线

                ForEach(MentorRole.seated) { role in  // 遍历五位导师
                    HStack(alignment: .top, spacing: Space.xs) {  // 横向排列
                        Image(systemName: "person.fill")  // 人形图标
                            .font(.system(size: 11))  // 小图标
                            .foregroundStyle(Color.appViolet)  // 紫色
                            .frame(width: 14)  // 固定宽度
                        Text(role.title).font(AppFont.captionStrong).frame(width: 72, alignment: .leading)  // 角色名
                        Text(role.focus)  // 分工说明
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                            .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    }  // 排列结束
                }  // 遍历结束
            }  // 排列结束
        }  // 卡片结束
    }  // compositionCard 结束

    private var disclaimer: some View {  // 免责声明
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            Text("· 导师为 AI 模拟角色，非真实导师，不代表任何院校。")  // 角色声明
            Text("· 评分是训练量表，不是院校官方评分，不预测录取结果。")  // 评分声明
            Text("· 面试小组不少于 5 人、每生不少于 20 分钟，依教育部招生工作管理规定设置。")  // 政策依据
        }  // 排列结束
        .font(AppFont.caption)  // 小字
        .foregroundStyle(Color.textTertiary)  // 弱化色
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐撑满
    }  // disclaimer 结束

    private var startButton: some View {  // 开始按钮区
        VStack(spacing: Space.xs) {  // 纵向排列
            PrimaryButton(  // 主按钮
                title: canStart ? "开始模拟面试" : "今日场次已用完",  // 文案随额度变
                systemImage: canStart ? "play.fill" : "lock.fill",  // 图标
                enabled: canStart,  // 有额度才可点
                action: { begin() }  // 点击开始
            )  // 按钮结束
            Text("全程约 20 分钟，5 位导师依次提问，中途可暂停。")  // 说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .navigationDestination(isPresented: $showRoom) {  // 进入房间
            InterviewRoomView(mode: mode, style: style)  // 面试房间
        }  // 导航结束
    }  // startButton 结束

    private var canStart: Bool {  // 能否开始
        app.entitlement.canUse(.interviewDaily)  // 有额度才能开始
    }  // 属性结束

    private func begin() {  // 开始前扣额度
        app.consume(.interviewDaily)  // 唯一扣费入口
        showRoom = true  // 进入房间
    }  // 方法结束
}  // InterviewHomeView 结束
