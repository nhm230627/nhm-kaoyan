//  WorldMapView.swift —— 学习地图                                    // 文件说明
//  入口在首页右上角，只放真实可去的地方                               // 使用约束
//  未接入的明确标「阶段 X 开放」，不做点了没反应的地图点                 // 诚实约束

import SwiftUI  // 界面框架

struct WorldMapView: View {  // 学习地图
    @Environment(AppState.self) private var app  // 全局状态

    private struct Spot: Identifiable {  // 岛内地点
        let id: String  // 地点 id
        let name: String  // 地点名
        let detail: String  // 说明
        let icon: String  // 图标名
        let available: Bool  // 是否可进入
        let destination: AnyView?  // 可进入时跳转目标
    }  // Spot 结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                islandSection  // 岛屿列表
                spotSection  // 地点列表
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("学习地图")  // 标题
    }  // body 结束

    private var islandSection: some View {  // 岛屿区
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("考研岛").font(AppFont.section)  // 区段标题
            ForEach(Venue.allCases) { venue in  // 遍历五座岛
                Card {  // 岛屿卡
                    HStack(spacing: Space.m) {  // 横向排列
                        ZStack {  // 叠放
                            Circle()  // 圆形底
                                .fill(venue.isReady ? Color.appBrand.opacity(0.12) : Color.separator)  // 已接入品牌色
                                .frame(width: 40, height: 40)  // 尺寸
                            Image(systemName: "leaf.fill")  // 叶子图标
                                .foregroundStyle(venue.isReady ? Color.appBrand : Color.textTertiary)  // 已接入上色
                        }  // 叠放结束
                        VStack(alignment: .leading, spacing: 2) {  // 文字区
                            Text(venue.title).font(AppFont.bodyStrong)  // 岛名
                            Text(venue.isReady ? "题库与面试已接入" : "题库与面试尚未接入")  // 状态说明
                                .font(AppFont.caption)  // 小字
                                .foregroundStyle(Color.textSecondary)  // 次要色
                        }  // 文字区结束
                        Spacer()  // 撑开
                        if venue == app.profile.venue && venue.isReady {  // 当前岛
                            Chip(text: "当前", tint: .appOK, filled: true)  // 当前标记
                        } else if !venue.isReady {  // 未开放
                            Chip(text: "未开放", tint: .textTertiary)  // 未开放标记
                        }  // 分支结束
                    }  // 排列结束
                }  // 卡片结束
            }  // 遍历结束
        }  // 排列结束
    }  // islandSection 结束

    private var spots: [Spot] {  // 地点列表
        [  // 数组开始
            Spot(  // 面试间
                id: "interview",  // id
                name: "面试间",  // 名字
                detail: "5 位导师、5 个环节、20 分钟一场",  // 说明
                icon: "person.2.wave.2",  // 图标
                available: true,  // 可进入
                destination: AnyView(InterviewHomeView())  // 跳面试页
            ),  // 结束
            Spot(  // 图书馆
                id: "library",  // id
                name: "图书馆",  // 名字
                detail: "课程与资料库，尚未排期",  // 说明
                icon: "books.vertical",  // 图标
                available: false,  // 未开放
                destination: nil  // 无目标
            ),  // 结束
            Spot(  // 食堂
                id: "canteen",  // id
                name: "食堂",  // 名字
                detail: "用学习时长换口粮，阶段 5 接入",  // 说明
                icon: "fork.knife",  // 图标
                available: false,  // 未开放
                destination: nil  // 无目标
            ),  // 结束
            Spot(  // 广场
                id: "plaza",  // id
                name: "广场",  // 名字
                detail: "3D 学习社区与他人伙伴，阶段 6 接入",  // 说明
                icon: "figure.socialdance",  // 图标
                available: false,  // 未开放
                destination: nil  // 无目标
            ),  // 结束
            Spot(  // 模考区
                id: "exam",  // id
                name: "模考广场",  // 名字（样板地图 POI 原话）
                detail: "通用卷 + 48 所院校卷",  // 说明（照样板 POI 副标题）
                icon: "chart.bar.xaxis",  // 图标
                available: true,  // 可进入
                destination: AnyView(MockExamView())  // 跳院校模考页
            )  // 结束
        ]  // 数组结束
    }  // spots 结束

    private var spotSection: some View {  // 地点区
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("岛内地点").font(AppFont.section)  // 区段标题
            ForEach(spots) { spot in  // 遍历地点
                if let dest = spot.destination {  // 可进入
                    NavigationLink { dest } label: { spotRow(spot) }  // 点击跳转
                        .buttonStyle(.plain)  // 去掉默认样式
                } else {  // 不可进入
                    spotRow(spot)  // 只展示
                        .opacity(0.6)  // 灰掉表明不可点
                }  // 分支结束
            }  // 遍历结束
        }  // 排列结束
    }  // spotSection 结束

    private func spotRow(_ spot: Spot) -> some View {  // 单个地点行
        Card {  // 卡片
            HStack(spacing: Space.m) {  // 横向排列
                Image(systemName: spot.icon)  // 图标
                    .font(.system(size: 18))  // 图标大小
                    .foregroundStyle(spot.available ? Color.appViolet : Color.textTertiary)  // 可用紫否则灰
                    .frame(width: 28)  // 固定宽度
                VStack(alignment: .leading, spacing: 2) {  // 文字区
                    Text(spot.name).font(AppFont.bodyStrong)  // 名称
                    Text(spot.detail).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                }  // 文字区结束
                Spacer()  // 撑开
                if spot.available {  // 可进入才给箭头
                    Image(systemName: "chevron.right")  // 右箭头
                        .font(.system(size: 12, weight: .semibold))  // 小箭头
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // spotRow 结束
}  // WorldMapView 结束
