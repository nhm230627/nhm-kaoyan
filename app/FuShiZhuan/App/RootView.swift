//  RootView.swift —— 五个 Tab 的根容器                              // 文件说明
//  3D 场景页不进 Tab，从「伙伴」推入，避免反复重建 RealityKit 场景     // 设计说明

import SwiftUI  // 界面框架
import UIKit  // 用到 UIApplication 通知

enum AppTab: String, CaseIterable, Identifiable {  // Tab 枚举
    case today  // 今日
    case quiz  // 刷题
    case interview  // 面试
    case companion  // 伙伴
    case profile  // 我的

    var id: String { rawValue }  // 可识别 id

    var title: String {  // Tab 标题
        switch self {  // 按 Tab 分支
        case .today: "今日"  // 今日
        case .quiz: "刷题"  // 刷题
        case .interview: "面试"  // 面试
        case .companion: "伙伴"  // 伙伴
        case .profile: "我的"  // 我的
        }  // 分支结束
    }  // title 结束

    var icon: String {  // Tab 图标
        switch self {  // 按 Tab 分支
        case .today: "sun.max"  // 太阳
        case .quiz: "checklist"  // 清单
        case .interview: "person.2.wave.2"  // 双人
        case .companion: "pawprint"  // 爪印
        case .profile: "person.crop.circle"  // 头像
        }  // 分支结束
    }  // icon 结束
}  // AppTab 结束

struct RootView: View {  // 根视图
    @Environment(AppState.self) private var app  // 注入全局状态
    @State private var tab: AppTab = RootView.initialTab  // 当前 Tab（可用启动参数指定，见下）
    @State private var shot: Shot? = RootView.initialShot  // 截图用：启动即弹开的子页面
    @State private var showChat = false  // AI 学伴面板是否打开（全局浮标，样板 ai.js 同款入口）
    @State private var didTick = false  // 冷启动只结算一次

    /// 截图用：允许 CI 通过启动参数直接落到某个 Tab。
    /// 为什么要它：模拟器里没人点按钮，`simctl` 也点不了 UI。
    /// 加一个 `-startTab quiz` 这样的启动参数，就能让 App 启动即停在该页，
    /// 逐个 Tab 各截一张图，不需要写一整套 XCUITest。
    /// 线上运行时没有这个参数，永远返回 .today，行为与以前完全一致。
    static var initialTab: AppTab {  // 解析启动参数
        let args = ProcessInfo.processInfo.arguments  // 命令行参数
        if let i = args.firstIndex(of: "-startTab"), args.count > i + 1,  // 找到参数且后面确实有值
           let picked = AppTab(rawValue: args[i + 1]) {  // 值是合法的 Tab 名
            return picked  // 用指定的 Tab
        }  // 分支结束
        return .today  // 默认落在今日页
    }  // initialTab 结束

    /// 截图用：直接弹出某个子页面，因为子页面藏得深，截图脚本点不进去。
    /// 只在带 `-startShot <名字>` 启动时生效，正常启动为 nil，不影响任何线上行为。
    enum Shot: String, Identifiable {  // 可截图的子页面
        case avatar  // 换装工坊
        case papers  // 试卷列表
        case paper  // 整套试卷作答
        case wrongbook  // 错题本
        case run  // 练习作答（样板 page-run）
        case result  // 练习结果（样板 page-result）
        case sortmap  // 关卡地图
        case sortplay  // 分拣关卡
        case diy  // 我的题库
        case mock  // 院校模考
        case tracksheet  // 考试方向选择层
        case community  // 研友论坛（样板 page-community）
        case post  // 帖子详情（样板 page-post）
        case room  // 2D 考场（样板 page-room）
        case ritual  // 拨穗礼成（样板 page-ritual）
        case duel  // 1V1 知识竞赛（样板 page-game 的浮层）
        case plaza  // 广场画布（样板 page-plaza）
        case world  // 3D 浮空岛地图（样板 page-map）
        case roam  // 岛内 3D 漫游（样板 page-roam）
        case shop  // 严选好物（样板 page-shop）
        case aichat  // AI 学伴面板（样板 ai.js）

        var id: String { rawValue }  // 用原始值当 id
    }  // Shot 结束

    static var initialShot: Shot? {  // 解析启动参数
        let args = ProcessInfo.processInfo.arguments  // 命令行参数
        guard let i = args.firstIndex(of: "-startShot"), args.count > i + 1 else { return nil }  // 没带参数
        return Shot(rawValue: args[i + 1])  // 有就解析
    }  // initialShot 结束

    var body: some View {  // 视图主体
        TabView(selection: $tab) {  // 五 Tab 容器
            NavigationStack {  // 今日栈
                TodayView()  // 今日页
            }  // 栈结束
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.icon) }  // 今日标签
            .tag(AppTab.today)  // 绑定值

            NavigationStack {  // 刷题栈
                QuizHomeView()  // 刷题页
            }  // 栈结束
            .tabItem { Label(AppTab.quiz.title, systemImage: AppTab.quiz.icon) }  // 刷题标签
            .tag(AppTab.quiz)  // 绑定值

            NavigationStack {  // 面试栈
                InterviewHomeView()  // 面试页
            }  // 栈结束
            .tabItem { Label(AppTab.interview.title, systemImage: AppTab.interview.icon) }  // 面试标签
            .tag(AppTab.interview)  // 绑定值

            NavigationStack {  // 伙伴栈
                CompanionHomeView()  // 伙伴页
            }  // 栈结束
            .tabItem { Label(AppTab.companion.title, systemImage: AppTab.companion.icon) }  // 伙伴标签
            .tag(AppTab.companion)  // 绑定值

            NavigationStack {  // 我的栈
                ProfileView()  // 我的页
            }  // 栈结束
            .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.icon) }  // 我的标签
            .tag(AppTab.profile)  // 绑定值
        }  // TabView 结束
        .tint(Color.appBrand)  // 选中色
        .overlay(alignment: .bottomTrailing) { chatFab }  // 全局 AI 学伴浮标，五个 Tab 都在
        .sheet(isPresented: $showChat) {  // 面板以 sheet 呈现
            NavigationStack {  // 套导航栈才有标题栏与关闭按钮
                AIChatView()  // 对话面板
                    .toolbar {  // 导航栏
                        ToolbarItem(placement: .cancellationAction) {  // 左上
                            Button("关闭") { showChat = false }  // 关掉面板
                        }  // 按钮结束
                    }  // 工具栏结束
            }  // 栈结束
        }  // sheet 结束
        .fullScreenCover(item: $shot) { target in  // 截图专用：直接盖到某个子页面
            NavigationStack {  // 套一层导航栈，才有标题栏
                shotBody(target)  // 按名字给页面
            }  // 栈结束
        }  // 覆盖层结束
        .task {  // 首次出现执行
            app.loadBank()  // 加载题库
            guard !didTick else { return }  // 已结算就跳过
            didTick = true  // 标记已结算
            app.dailyTick()  // 跑每日结算
        }  // 任务结束
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in  // 监听进后台
            app.flush()  // 立刻落盘防丢
        }  // 监听结束
    }  // body 结束

    private var chatFab: some View {  // 全局 AI 学伴浮标
        Button {  // 点开面板
            showChat = true  // 打开
        } label: {  // 外观
            Image(systemName: "sparkles")  // 星火图标
                .font(.system(size: 20, weight: .semibold))  // 大小
                .foregroundStyle(.white)  // 白图标
                .frame(width: 52, height: 52)  // 触控区大于 44，符合 HIG
                .background(  // 渐变底
                    LinearGradient(colors: [.appBrand, .appBrand2],  // 品牌两端色
                                   startPoint: .topLeading,  // 左上
                                   endPoint: .bottomTrailing)  // 右下
                )  // 背景结束
                .clipShape(Circle())  // 圆形
                .shadow(color: Color.appBrand.opacity(0.35), radius: 10, y: 4)  // 轻投影
        }  // 标签结束
        .buttonStyle(.plain)  // 不用默认高亮
        .padding(.trailing, Space.l)  // 右边距
        .padding(.bottom, 92)  // 让开悬浮 TabBar
        .accessibilityIdentifier("chat-fab")  // 便于 UI 测试
        .accessibilityLabel("AI 学伴")  // 朗读名
    }  // chatFab 结束

    @ViewBuilder  // 按名字返回对应子页面
    private func shotBody(_ target: Shot) -> some View {  // 截图用页面分发
        switch target {  // 按名字分支
        case .avatar:  // 换装工坊
            AvatarStudioView()  // 换装页
        case .papers:  // 试卷列表
            PaperListView(initialKind: .mock)  // 默认停在自编模拟卷，免得截到空态
        case .paper:  // 整套试卷
            if let paper = PaperCatalog.shared.papers(kind: .mock).first {  // 取第一套
                PaperPlayView(paper: paper)  // 直接开始作答
            } else {  // 没有试卷
                EmptyState(icon: "doc.text", title: "暂无试卷", message: "papers.json 里没有可用的模拟卷。")  // 空态
            }  // 分支结束
        case .wrongbook:  // 错题本
            WrongBookView()  // 错题本页
        case .run:  // 练习作答
            ShotRunHost()  // 等题库加载好再建
        case .result:  // 练习结果
            ShotResultHost()  // 造一份结果数据
        case .sortmap:  // 关卡地图
            LevelMapView()  // 四章十二关
        case .diy:  // 我的题库
            DiyBankView(startWithForm: true)  // 录题页（截图时展开表单）
        case .mock:  // 院校模考
            MockExamView()  // 通用卷 + 48 所院校分卷
        case .tracksheet:  // 方向选择层
            TrackPickerSheet()  // 直接铺满整屏截（正常是从胶囊弹出的 sheet）
        case .community:  // 研友论坛
            CommunityView()  // 帖子流
        case .post:  // 帖子详情
            if let first = CommunitySeed.posts.first {  // 拿第一条种子帖
                PostDetailView(post: first)  // 直接看详情
            } else {  // 数据没了（不该发生）
                EmptyState(icon: "doc.text", title: "帖子不存在", message: "Community.swift 里的种子帖没读到。")  // 空态
            }  // 分支结束
        case .sortplay:  // 分拣关卡
            if let level = SortCatalog.level(SortCatalog.order.first ?? "") {  // 第一关
                SortGameView(level: level)  // 直接开玩
            } else {  // 数据没读到
                EmptyState(icon: "square.grid.3x3", title: "关卡数据缺失", message: "sort-levels.json 没打进包里。")  // 空态
            }  // 分支结束
        case .room:  // 2D 考场
            ShotRoomHost()  // 等题库就绪再建，免得截到加载态
        case .ritual:  // 拨穗礼成
            RitualView()  // 直接进证书页（时序动画自己会跑）
        case .duel:  // 1V1 知识竞赛
            DuelView()  // 停在大厅页（截选题量与规则）
        case .plaza:  // 广场画布
            PlazaView()  // 多宠物同场，进来就动
        case .world:  // 3D 浮空岛
            WorldMapView()  // 三座岛，等一两秒让相机与建筑铺开
        case .roam:  // 岛内漫游
            RoamView(roomID: ShotRoamRoom.current)  // 默认进图书馆，可用启动参数换房间逐间截图
        case .shop:  // 严选好物
            ShopView()  // 商品网格 + 商家合作
        case .aichat:  // AI 学伴面板
            AIChatView()  // 空态提示 + 输入框
        }  // 分支结束
    }  // shotBody 结束
}  // RootView 结束

// MARK: - 截图专用宿主                                                 // 分节：截图宿主

private enum ShotRoamRoom {  // 截图时进哪间房
    static var current: String {  // 读启动参数 -shotRoom
        let args = ProcessInfo.processInfo.arguments  // 全部启动参数
        if let i = args.firstIndex(of: "-shotRoom"), i + 1 < args.count {  // 有指定就听它的
            return args[i + 1]  // lib / diner / market / plaza
        }  // 判断结束
        return "lib"  // 默认图书馆，房间最丰富
    }  // current 结束
}  // ShotRoamRoom 结束

private struct ShotRunHost: View {  // 等题库就绪再建作答页
    @Environment(AppState.self) private var app  // 观察题库

    var body: some View {  // 视图主体
        if let bank = app.bank, !bank.questions.isEmpty {  // 题库已好
            QuizRunView(pool: bank.questions, size: 15, revealEach: true)  // 造一组练习（即时看模式更能看清解析块）
        } else {  // 还没好
            LoadingState(text: "题库加载中…")  // 转圈
        }  // 分支结束
    }  // body 结束
}  // ShotRunHost 结束

private struct ShotResultHost: View {  // 截结果页
    @Environment(AppState.self) private var app  // 观察题库

    private var items: [QuizResultItem] {  // 造假数据：三题里两错一对
        guard let bank = app.bank, bank.questions.count >= 3 else { return [] }  // 题库不够
        return bank.questions.prefix(3).enumerated().map { offset, q in  // 取前三题
            let ok = offset == 1  // 第二题算答对
            let picked: Set<Int> = ok ? Set(q.answer) : [0]  // 对的选正确答案，错的选 A
            return QuizResultItem(question: q, picked: picked, ok: ok)  // 组装
        }  // 映射结束
    }  // items 结束

    var body: some View {  // 视图主体
        if items.isEmpty {  // 题库没好
            LoadingState(text: "题库加载中…")  // 转圈
        } else {  // 有数据
            QuizResultView(items: items, seconds: 372, revealInstant: false,  // 6 分 12 秒
                           unanswered: 1, onAgain: {}, onClose: {})  // 回调留空，只截图
        }  // 分支结束
    }  // body 结束
}  // ShotResultHost 结束

private struct ShotRoomHost: View {  // 截 2D 考场内部
    var body: some View {  // 视图主体
        InterviewRoomView(mode: .professional, style: .standard)  // 专业面试 + 标准风格，进页即出考场
    }  // body 结束
}  // ShotRoomHost 结束
