//  FuShiZhuanApp.swift —— App 入口                                   // 文件说明
//  只做三件事：建状态、注入状态、进后台落盘                            // 职责约束

import SwiftUI  // 界面框架

@main  // 程序入口标记
struct FuShiZhuanApp: App {  // App 结构体
    @State private var app = AppState()  // 全局唯一状态实例
    @Environment(\.scenePhase) private var scenePhase  // 前台后台状态

    var body: some Scene {  // 场景主体
        WindowGroup {  // 主窗口
            RootView()  // 根视图
                .environment(app)  // 注入全局状态
                .preferredColorScheme(nil)  // 跟随系统深浅色
        }  // 窗口结束
        .onChange(of: scenePhase) { _, phase in  // 监听前后台切换
            switch phase {  // 按阶段分支
            case .background:  // 进后台
                app.flush()  // 立刻落盘
            case .active:  // 回前台
                app.dailyTick()  // 补一次每日结算
            default:  // 其它
                break  // 不处理
            }  // 分支结束
        }  // 监听结束
    }  // body 结束
}  // FuShiZhuanApp 结束
