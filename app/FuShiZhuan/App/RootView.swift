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
}  // RootView 结束
