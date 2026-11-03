//  WorldMapView.swift —— 学习地图（3D 浮空岛 + 岛内地点）               // 文件说明
//  上半屏是 RealityKit 浮空岛（照样板 world3d.js），点岛有真实回应：        // 3D 部分
//    当前方向的岛 → 提示「你已经在 X 了，往下选地点」；别的岛 → 如实说在建设中。
//  下半屏是岛内地点：图书馆 / 食堂 / 集市 / 公共广场进各自的 3D 漫游房，    // 地点部分
//  副本战场 / 面试间 / 模考广场跳到现有模块。                            // 地点部分

import SwiftUI  // 界面框架

struct WorldMapView: View {  // 学习地图
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // 减弱动效
    @AppStorage("app.pet.static3D") private var staticMode = false  // 省电开关
    @State private var toast: String?  // 点岛的提示

    private var islands: [WorldIsland] { WorldIsland.layout(track: app.data.track) }  // 三座岛
    private var animationsOff: Bool { staticMode || reduceMotion }  // 任一开关都关动效

    /// 岛内地点：进 3D 漫游房的那四个（样板 data-roam）
    private let roamSpots: [(id: String, name: String, detail: String, icon: String)] = [  // 四个可走进去的房子
        ("lib", "图书馆", "走进去翻知识卡", "books.vertical"),  // 图书馆
        ("diner", "食堂", "打饭窗口能投喂", "fork.knife"),  // 食堂
        ("market", "集市", "积分换口粮", "bag"),  // 集市
        ("plaza", "公共广场", "喷泉边坐坐", "figure.socialdance")  // 广场
    ]  // 数组结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                worldSection  // 3D 浮空岛
                roamSection  // 能走进去的四个地点
                pageSection  // 跳到现有模块的三个入口
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("学习地图")  // 标题
        .overlay(alignment: .top) { toastLayer }  // 点岛提示
    }  // body 结束

    // MARK: - 3D 地图                                                  // 分节：3D

    private var worldSection: some View {  // 浮空岛区
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack {  // 标题行
                Text("考研岛").font(AppFont.section)  // 区段标题
                Spacer()  // 撑开
                Text("\(islands.count) 座 · 可点").font(AppFont.caption)  // 数量说明
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 排列结束

            World3DView(track: app.data.track,  // 当前方向决定哪座岛亮
                        animationsOff: animationsOff,  // 省电开关
                        onPick: { id in pickIsland(id) })  // 点岛
                .frame(height: 330)  // 画布高度
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角
                .overlay(  // 细边
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 同形
                        .stroke(Color.separator, lineWidth: 1)  // 细线
                )  // 覆盖层结束

            islandChips  // 三座岛的名字胶囊（3D 里点不准也能看明白）
        }  // 排列结束
    }  // worldSection 结束

    private var islandChips: some View {  // 岛屿名胶囊
        HStack(spacing: Space.xs) {  // 横向排列
            ForEach(islands) { island in  // 逐座
                HStack(spacing: 4) {  // 圆点 + 名字
                    Circle()  // 状态点
                        .fill(island.active ? Color.appOK : Color.separator)  // 当前亮绿
                        .frame(width: 6, height: 6)  // 小点
                    Text(island.name).font(AppFont.caption)  // 岛名
                    Text(verbatim: "\(island.people)").font(.system(size: 10))  // 样例人数
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
                .padding(.horizontal, 9)  // 左右
                .frame(height: 26)  // 高度
                .background(Capsule().fill(island.active ? Color.appOK.opacity(0.12) : Color.appCard))  // 当前淡绿
                .overlay(  // 当前岛描边
                    Capsule().stroke(island.active ? Color.appOK.opacity(0.35) : Color.clear, lineWidth: 1)  // 细线
                )  // 覆盖层结束
            }  // 遍历结束
            Spacer()  // 撑开
        }  // 排列结束
    }  // islandChips 结束

    // MARK: - 岛内地点                                                // 分节：地点

    private var roamSection: some View {  // 能走进去的四个地点
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("岛内地点 · 走进去").font(AppFont.section)  // 区段标题
            ForEach(roamSpots, id: \.id) { spot in  // 逐个
                NavigationLink {  // 进 3D 房间
                    RoamView(roomID: spot.id)  // 漫游页
                } label: {  // 行外观
                    row(name: spot.name, detail: spot.detail, icon: spot.icon, badge: "3D")  // 复用行样式
                }  // 链接结束
                .buttonStyle(.plain)  // 去掉系统高亮
            }  // 遍历结束
        }  // 排列结束
    }  // roamSection 结束

    private var pageSection: some View {  // 跳到现有模块的三个入口
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("岛内地点 · 直达").font(AppFont.section)  // 区段标题
            NavigationLink { LevelMapView() } label: {  // 副本战场
                row(name: "副本战场", detail: "闯关赚口粮", icon: "flame", badge: nil)  // 行
            }  // 链接结束
            .buttonStyle(.plain)  // 去掉系统高亮
            NavigationLink { InterviewHomeView() } label: {  // 面试间
                row(name: "面试间", detail: "5 位导师", icon: "person.2.wave.2", badge: nil)  // 行
            }  // 链接结束
            .buttonStyle(.plain)  // 去掉系统高亮
            NavigationLink { MockExamView() } label: {  // 模考广场
                row(name: "模考广场", detail: "48 所院校卷", icon: "chart.bar.xaxis", badge: nil)  // 行
            }  // 链接结束
            .buttonStyle(.plain)  // 去掉系统高亮
        }  // 排列结束
    }  // pageSection 结束

    private func row(name: String, detail: String, icon: String, badge: String?) -> some View {  // 单行
        Card {  // 卡片
            HStack(spacing: Space.m) {  // 横向排列
                Image(systemName: icon)  // 图标
                    .font(.system(size: 18))  // 图标大小
                    .foregroundStyle(Color.appViolet)  // 紫色
                    .frame(width: 28)  // 固定宽度
                VStack(alignment: .leading, spacing: 2) {  // 文字区
                    Text(name).font(AppFont.bodyStrong)  // 名称
                    Text(detail).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                }  // 文字区结束
                Spacer()  // 撑开
                if let badge {  // 有角标就显示
                    Chip(text: badge, tint: .appViolet, filled: true)  // 3D 角标
                }  // 分支结束
                Image(systemName: "chevron.right")  // 右箭头
                    .font(.system(size: 12, weight: .semibold))  // 小箭头
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 排列结束
        }  // 卡片结束
    }  // row 结束

    // MARK: - 点岛                                                    // 分节：点岛

    private func pickIsland(_ id: String) {  // 点了某座岛
        guard let island = islands.first(where: { $0.id == id }) else { return }  // 找到那座
        if island.active {  // 就是当前岛
            show("你已经在\(island.name)了 · 往下选地点进入")  // 样板原话
        } else {  // 别的岛
            show("\(island.name)正在建设中 · 已有 \(island.people) 人预约")  // 样板原话
        }  // 分支结束
    }  // pickIsland 结束

    private func show(_ text: String) {  // 顶部提示
        withAnimation { toast = text }  // 显示
        Task {  // 2.4 秒后自动消失
            try? await Task.sleep(nanoseconds: 2_400_000_000)  // 等 2.4 秒
            withAnimation { if toast == text { toast = nil } }  // 只清自己这条
        }  // 任务结束
    }  // show 结束

    @ViewBuilder  // 可能为空
    private var toastLayer: some View {  // 顶部提示条
        if let msg = toast {  // 有提示才显示
            Text(msg)  // 内容
                .font(.system(size: 12))  // 12 号
                .foregroundStyle(.white)  // 白字
                .padding(.horizontal, 14)  // 左右
                .padding(.vertical, 9)  // 上下
                .background(Capsule().fill(Color.black.opacity(0.78)))  // 深色胶囊
                .padding(.top, 8)  // 离顶部一点
                .transition(.opacity)  // 淡入淡出
        }  // 分支结束
    }  // toastLayer 结束
}  // WorldMapView 结束
