//  TodayView.swift —— 首页                                          // 文件说明
//  三件事：今天该做什么、宠物什么状态、离考试还有几天                   // 页面职责
//  所有数字都来自 AppState，页面不算任何业务数字                      // 数据约束
//  2026-11-03 按 Web 样板重做：补大标题、右上圆钮、蓝色渐变主卡、四格统计；
//  原来点了没反应的任务行与「去练」全部接上真实跳转                    // 改动说明

import SwiftUI  // 界面框架

struct TodayView: View {  // 首页
    @Environment(AppState.self) private var app  // 注入全局状态

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                header  // 大标题 + 右上圆钮
                if let error = app.loadError {  // 题库加载失败
                    ErrorState(error: error) { app.loadBank() }  // 显示错误并可重试
                        .frame(height: 260)  // 限高
                } else {  // 正常
                    heroCard  // 蓝色渐变主卡
                    statsRow  // 四格统计
                    coachCard  // AI 学伴（本地建议免费，点「问问」才联网）
                    petCard  // 宠物卡
                    todayTasks  // 今日任务
                    weakTopics  // 薄弱点
                }  // 分支结束
            }  // 排列结束
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 页面底色
        .toolbar(.hidden, for: .navigationBar)  // 隐藏系统导航栏，标题由 PageHeader 自己画
    }  // body 结束

    // MARK: - 页头                                                      // 分节：页头

    private var header: some View {  // 页头
        PageHeader(title: "今日", subtitle: "距复试 \(app.profile.daysLeft) 天") {  // 标题与倒计时
            HStack(spacing: Space.xs) {  // 右侧两个圆钮
                CircleIconButton(  // 打卡按钮
                    systemImage: checkedInToday ? "checkmark" : "leaf.fill",  // 已打卡变勾
                    tint: checkedInToday ? .appOK : .appWarn,  // 已打卡绿，未打卡橙
                    active: checkedInToday  // 已打卡时淡底高亮
                ) {  // 点击动作
                    app.checkIn()  // 调唯一写入口打卡
                }  // 打卡按钮结束
                NavigationLink {  // 齿轮进「我的」
                    ProfileView()  // 复用个人中心当设置页
                } label: {  // 圆钮外观
                    Image(systemName: "gearshape.fill")  // 齿轮图标
                        .font(.system(size: 15, weight: .semibold))  // 图标大小
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .frame(width: 36, height: 36)  // 圆形尺寸
                        .background(Circle().fill(Color.appCard))  // 白底圆
                }  // 外观结束
                .buttonStyle(.plain)  // 去掉默认样式
                .accessibilityLabel("设置")  // 无障碍标签
            }  // 排列结束
        }  // 页头结束
    }  // header 结束

    private var checkedInToday: Bool {  // 今天是否已打卡
        guard let last = app.data.lastCheckInDate else { return false }  // 从没打过
        return Calendar.current.isDateInToday(last)  // 是不是今天
    }  // 属性结束

    // MARK: - 主视觉卡                                                  // 分节：蓝卡

    private var heroCard: some View {  // 蓝色渐变主卡
        HStack(spacing: Space.l) {  // 左环右字
            ProgressRing(  // 倒计时圆环
                progress: ringProgress,  // 已过去的时间比例
                center: "\(app.profile.daysLeft)",  // 剩余天数
                caption: "天后复试"  // 说明
            )  // 圆环结束

            VStack(alignment: .leading, spacing: Space.xs) {  // 右侧文字区
                Text(app.profile.venue.title)  // 备考方向
                    .font(.system(size: 19, weight: .bold, design: .rounded))  // 大号圆体
                Text(verbatim: "\(examYear) 届 · \(app.profile.stage.title)")  // 届数与阶段（verbatim 防止 2027 被格式化成 2,027）
                    .font(AppFont.caption)  // 小字
                    .opacity(0.85)  // 略淡
                HStack(spacing: Space.xxs) {  // 连续登录徽章
                    Image(systemName: "flame.fill")  // 火苗图标
                        .font(.system(size: 11))  // 小图标
                    Text(verbatim: "连续登录 \(app.data.streakDays) 天")  // 连签天数（verbatim 同上，避免四位数带逗号）
                        .font(AppFont.captionStrong)  // 小字加粗
                }  // 徽章内容结束
                .padding(.horizontal, Space.s)  // 左右内边距
                .padding(.vertical, 5)  // 上下内边距
                .background(Capsule().fill(Color.white.opacity(0.18)))  // 半透明白胶囊
                .padding(.top, 2)  // 与上面留一点空
            }  // 文字区结束
            Spacer(minLength: 0)  // 撑开
        }  // 排列结束
        .padding(Space.l)  // 卡片内边距
        .foregroundStyle(.white)  // 卡内文字全白
        .background(  // 卡片背景
            RoundedRectangle(cornerRadius: Radius.card + 4, style: .continuous)  // 比普通卡片更圆
                .fill(Color.brandGradient)  // 品牌渐变
        )  // 背景结束
        .cardShadow()  // 投影
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        .accessibilityElement(children: .combine)  // 合并朗读
    }  // heroCard 结束

    private var examYear: Int {  // 考试年份
        Calendar.current.component(.year, from: app.profile.examDate)  // 取 examDate 的年份
    }  // 属性结束

    private var ringProgress: Double {  // 圆环进度
        let total = 365.0  // 按一年备考周期算
        let left = Double(min(365, max(0, app.profile.daysLeft)))  // 剩余天数不超过一年
        return (total - left) / total  // 已经过去多少
    }  // 属性结束

    // MARK: - 四格统计                                                  // 分节：统计

    private var statsRow: some View {  // 四格统计
        Card {  // 白卡
            HStack(spacing: 0) {  // 四格横排
                StatTile(value: "\(app.data.streakDays)", title: "连续登录")  // 连签
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.data.attempts.count)", title: "已答题")  // 累计答题
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: accuracyText, title: "正确率", tint: accuracyColor)  // 正确率
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.data.sessions.count)", title: "面试场次", tint: .appViolet)  // 面试场次
            }  // 排列结束
        }  // 卡片结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
    }  // statsRow 结束

    private var accuracyText: String {  // 正确率文本
        guard let acc = app.todayAccuracy else { return "—" }  // 今天没答过显示横杠
        return "\(Int((acc * 100).rounded()))%"  // 百分比取整
    }  // 属性结束

    private var accuracyColor: Color {  // 正确率配色
        guard let acc = app.todayAccuracy else { return .textPrimary }  // 没数据用主文字色
        if acc >= 0.8 { return .appOK }  // 80% 以上绿
        if acc >= 0.6 { return .appWarn }  // 60% 以上橙
        return .appErr  // 低于 60% 红
    }  // 属性结束

    // MARK: - AI 学伴                                                  // 分节：学伴

    private var coachCard: some View {  // 学伴卡片外壳
        CoachCard()  // 卡片自身只管内容
            .padding(.horizontal, Metrics.pagePadding)  // 与其它卡片对齐左右边距
    }  // coachCard 结束

    // MARK: - 宠物卡                                                    // 分节：宠物

    private var petCard: some View {  // 宠物卡
        Card {  // 卡片容器
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                HStack {  // 标题行
                    Text("我的伙伴").font(AppFont.section)  // 标题
                    Spacer()  // 撑开
                    Text(app.pet.statusText)  // 状态文案
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(petStatusColor)  // 按状态上色
                }  // 排列结束

                HStack(spacing: Space.l) {  // 图标加数据
                    ZStack {  // 叠放
                        Circle()  // 圆形底
                            .fill(Color.appBrand.opacity(0.12))  // 淡品牌色
                            .frame(width: 64, height: 64)  // 尺寸
                        Text(app.stage.title)  // 阶段名
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(Color.appBrand)  // 品牌色
                    }  // 叠放结束
                    VStack(alignment: .leading, spacing: Space.xs) {  // 右侧数据
                        Meter(  // 体力条
                            value: Double(app.pet.energy) / Double(Pet.maxEnergy),  // 比例
                            tint: petStatusColor,  // 按状态上色
                            label: "体力 \(app.pet.energy)/\(Pet.maxEnergy)"  // 语义标签
                        )  // 体力条结束
                        HStack(spacing: Space.s) {  // 口粮与好感
                            Label("口粮 \(app.pet.food)", systemImage: "leaf")  // 口粮
                            Label("好感 \(app.pet.affinity)", systemImage: "heart")  // 好感
                        }  // 排列结束
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                    }  // 右侧结束
                }  // 排列结束

                if app.pet.starved {  // 已饿死
                    Text("宠物已饿死。闯关可以换口粮，先去过一关再来喂它。")  // 提示
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.appErr)  // 红色
                } else if app.pet.isHungry {  // 濒危
                    Text("体力快见底了，去闯关拿口粮。")  // 提示
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.appWarn)  // 橙色
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
    }  // petCard 结束

    private var petStatusColor: Color {  // 宠物状态配色
        if app.pet.starved { return .appErr }  // 饿死红
        if app.pet.isHungry { return .appWarn }  // 濒危橙
        return .appOK  // 正常绿
    }  // 属性结束

    // MARK: - 今日任务                                                  // 分节：任务

    private var todayTasks: some View {  // 今日任务区
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("今日任务").font(AppFont.section)  // 区段标题
                .padding(.horizontal, Metrics.pagePadding)  // 左右边距

            Card {  // 任务卡
                VStack(spacing: Space.m) {  // 纵向排列
                    taskRow(  // 任务一：刷题
                        icon: "checklist",  // 图标
                        title: "刷一组题",  // 标题
                        detail: app.bank == nil ? "题库加载中…" : "已完成 \(app.todayAnswered) 题",  // 详情
                        status: app.todayAnswered > 0 ? "已完成" : "未完成",  // 右侧状态
                        done: app.todayAnswered > 0  // 是否完成
                    ) {  // 点击目的地
                        firstLevelDestination  // 直奔第一关
                    }  // 任务一结束
                    Divider()  // 分隔线
                    taskRow(  // 任务二：模拟面试
                        icon: "person.2.wave.2",  // 图标
                        title: "做一次模拟面试",  // 标题
                        detail: "今日剩 \(app.entitlement.remaining(.interviewDaily) ?? 0) 场",  // 剩余场次
                        status: "\(todayInterviewCount)/1",  // 今天完成的场次
                        done: todayInterviewCount > 0  // 是否完成
                    ) {  // 点击目的地
                        InterviewHomeView()  // 面试设置页
                    }  // 任务二结束
                    Divider()  // 分隔线
                    taskRow(  // 任务三：喂伙伴
                        icon: "pawprint",  // 图标
                        title: "喂一次伙伴",  // 标题
                        detail: app.pet.food > 0 ? "口粮 \(app.pet.food) 颗" : "没有口粮，先去闯关",  // 详情
                        status: app.pet.energy >= Pet.maxEnergy ? "已吃饱" : "待投喂",  // 右侧状态
                        done: app.pet.energy >= Pet.maxEnergy  // 是否吃饱
                    ) {  // 点击目的地
                        CompanionHomeView()  // 伙伴页，在那里投喂
                    }  // 任务三结束
                }  // 排列结束
            }  // 卡片结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        }  // 排列结束
    }  // todayTasks 结束

    private var todayInterviewCount: Int {  // 今天已完成的面试场次
        app.data.sessions.filter {  // 逐场判断
            Calendar.current.isDateInToday($0.startedAt) && $0.state == .archived  // 今天且已归档
        }.count  // 计数
    }  // 属性结束

    @ViewBuilder  // 目的地随题库状态变化
    private var firstLevelDestination: some View {  // 第一关目的地
        if let bank = app.bank,  // 题库已加载
           let chapter = QuestionBankLoader.chapters(from: bank).first {  // 取第一章
            let questions = QuestionBankLoader.questions(inChapter: chapter.id, levelIndex: 1, bank: bank)  // 第一关题目
            if questions.isEmpty {  // 题不够
                QuizHomeView()  // 退回刷题首页
            } else {  // 有题
                LevelPlayView(questions: questions, levelID: chapter.levelID(1))  // 直接开打
            }  // 分支结束
        } else {  // 题库没来
            QuizHomeView()  // 先看刷题首页
        }  // 分支结束
    }  // firstLevelDestination 结束

    private func taskRow<Destination: View>(  // 单条任务（可点击）
        icon: String,  // 图标名
        title: String,  // 标题
        detail: String,  // 详情
        status: String,  // 右侧状态文字
        done: Bool,  // 是否完成
        @ViewBuilder destination: () -> Destination  // 点击进入的页面
    ) -> some View {  // 返回视图
        NavigationLink {  // 整行可跳转
            destination()  // 目的地
        } label: {  // 行外观
            HStack(spacing: Space.m) {  // 横向排列
                Image(systemName: done ? "checkmark.circle.fill" : icon)  // 完成换勾图标
                    .font(.system(size: 20))  // 图标大小
                    .foregroundStyle(done ? Color.appOK : Color.appBrand)  // 完成绿，未完品牌色
                    .frame(width: 28)  // 固定宽度
                VStack(alignment: .leading, spacing: 2) {  // 文字区
                    Text(title)  // 标题
                        .font(AppFont.bodyStrong)  // 加粗
                        .strikethrough(done, color: .textTertiary)  // 完成划线
                    Text(detail).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 详情
                }  // 文字区结束
                Spacer()  // 撑开
                Text(status)  // 右侧状态
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(done ? Color.appOK : Color.textTertiary)  // 完成绿，未完灰
                Image(systemName: "chevron.right")  // 箭头示意可点
                    .font(.system(size: 11, weight: .semibold))  // 小箭头
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 排列结束
            .contentShape(Rectangle())  // 整行可点
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
        .accessibilityElement(children: .combine)  // 合并朗读
        .accessibilityLabel("\(title)，\(detail)，\(done ? "已完成" : "未完成")")  // 朗读文案
    }  // taskRow 结束

    // MARK: - 薄弱点                                                    // 分节：薄弱点

    @ViewBuilder  // 可能不渲染
    private var weakTopics: some View {  // 薄弱点区
        let weak = app.weakTopics()  // 取薄弱点
        if !weak.isEmpty {  // 有才显示
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                Text("薄弱点").font(AppFont.section)  // 区段标题
                    .padding(.horizontal, Metrics.pagePadding)  // 左右边距
                Card {  // 卡片
                    VStack(spacing: Space.m) {  // 纵向排列
                        ForEach(weak.prefix(3), id: \.topic.id) { item in  // 最多三条
                            NavigationLink {  // 「去练」真的能进
                                weakDestination(chapterID: item.topic.id)  // 该板块第一关
                            } label: {  // 行外观
                                HStack {  // 横向排列
                                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                                        Text(item.topic.name).font(AppFont.bodyStrong)  // 板块名
                                        Text("答了 \(item.total) 题，正确率 \(Int((item.accuracy * 100).rounded()))%")  // 统计
                                            .font(AppFont.caption)  // 小字
                                            .foregroundStyle(Color.textSecondary)  // 次要色
                                    }  // 文字区结束
                                    Spacer()  // 撑开
                                    Text("去练")  // 引导文案
                                        .font(AppFont.captionStrong)  // 小字加粗
                                        .foregroundStyle(Color.appBrand)  // 品牌色
                                    Image(systemName: "chevron.right")  // 箭头
                                        .font(.system(size: 11, weight: .semibold))  // 小箭头
                                        .foregroundStyle(Color.textTertiary)  // 弱化色
                                }  // 排列结束
                                .contentShape(Rectangle())  // 整行可点
                            }  // 外观结束
                            .buttonStyle(.plain)  // 不用默认高亮
                        }  // 遍历结束
                    }  // 排列结束
                }  // 卡片结束
                .padding(.horizontal, Metrics.pagePadding)  // 左右边距
            }  // 排列结束
        }  // 分支结束
    }  // weakTopics 结束

    @ViewBuilder  // 目的地随题库状态变化
    private func weakDestination(chapterID: String) -> some View {  // 某板块第一关
        if let bank = app.bank {  // 题库已加载
            let questions = QuestionBankLoader.questions(inChapter: chapterID, levelIndex: 1, bank: bank)  // 第一关题目
            if questions.isEmpty {  // 没题
                QuizHomeView()  // 退回刷题首页
            } else {  // 有题
                LevelPlayView(questions: questions, levelID: "\(chapterID)-1")  // 直接开打
            }  // 分支结束
        } else {  // 题库没来
            QuizHomeView()  // 先看刷题首页
        }  // 分支结束
    }  // weakDestination 结束
}  // TodayView 结束
