//  TodayView.swift —— 首页                                          // 文件说明
//  三件事：今天该做什么、宠物什么状态、离考试还有几天                   // 页面职责
//  所有数字都来自 AppState，页面不算任何业务数字                      // 数据约束

import SwiftUI  // 界面框架

struct TodayView: View {  // 首页
    @Environment(AppState.self) private var app  // 注入全局状态

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                header  // 顶部概览
                if let error = app.loadError {  // 有加载错误
                    ErrorState(error: error) { app.loadBank() }  // 显示错误并可重试
                        .frame(height: 260)  // 限高
                } else {  // 正常
                    petCard  // 宠物卡
                    todayTasks  // 今日任务
                    weakTopics  // 薄弱点
                }  // 分支结束
            }  // 排列结束
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 页面底色
        .navigationBarTitleDisplayMode(.inline)  // 标题内联
        .toolbar {  // 工具栏
            ToolbarItem(placement: .topBarTrailing) {  // 右上角
                NavigationLink {  // 跳转链接
                    WorldMapView()  // 学习地图
                } label: {  // 链接外观
                    Image(systemName: "map")  // 地图图标
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 外观结束
                .accessibilityLabel("学习地图")  // 无障碍标签
            }  // 工具栏项结束
        }  // 工具栏结束
    }  // body 结束

    private var header: some View {  // 顶部概览卡
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            HStack(alignment: .firstTextBaseline) {  // 横向排列
                Text("\(app.profile.nickname)，今天也要上岸")  // 问候语
                    .font(AppFont.title)  // 标题字号
                Spacer()  // 撑开
            }  // 排列结束
            HStack(spacing: Space.xs) {  // 标签行
                Chip(text: app.profile.venue.title, tint: .appBrand, filled: true)  // 考研岛
                Chip(text: app.profile.stage.title, tint: .appViolet)  // 备考阶段
                Chip(text: "距考试 \(app.profile.daysLeft) 天", tint: .appWarn)  // 倒计时
            }  // 排列结束

            HStack(spacing: 0) {  // 三个指标
                StatTile(value: "\(app.todayAnswered)", title: "今日答题")  // 今日答题数
                Divider().frame(height: 32)  // 分隔线
                StatTile(  // 正确率指标
                    value: app.todayAccuracy.map { "\(Int($0 * 100))%" } ?? "—",  // 没答过显示横杠
                    title: "今日正确率",  // 说明
                    tint: accuracyColor  // 按正确率变色
                )  // 指标结束
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.data.streakDays)", title: "连续打卡", tint: .appBrand)  // 连签天数
            }  // 排列结束
            .padding(.top, Space.xxs)  // 上边距
        }  // 排列结束
        .padding(Space.l)  // 内边距
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 白底圆角
        .cardShadow()  // 投影
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        .padding(.top, Space.xs)  // 上边距
    }  // header 结束

    private var accuracyColor: Color {  // 正确率配色
        guard let acc = app.todayAccuracy else { return .textPrimary }  // 没数据用主文字色
        if acc >= 0.8 { return .appOK }  // 80% 以上绿色
        if acc >= 0.6 { return .appWarn }  // 60% 以上橙色
        return .appErr  // 低于 60% 红色
    }  // 属性结束

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
                    ZStack {  // 叠放，3D 阶段 5 接
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

    private var todayTasks: some View {  // 今日任务区
        VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
            Text("今日任务").font(AppFont.section)  // 区段标题
                .padding(.horizontal, Metrics.pagePadding)  // 左右边距

            Card {  // 任务卡
                VStack(spacing: Space.m) {  // 纵向排列
                    taskRow(  // 任务一
                        icon: "checklist",  // 图标
                        title: "刷一组题",  // 标题
                        detail: app.bank == nil ? "题库加载中…" : "已完成 \(app.todayAnswered) 题",  // 详情
                        done: app.todayAnswered > 0  // 是否完成
                    )  // 任务一结束
                    Divider()  // 分隔线
                    taskRow(  // 任务二
                        icon: "person.2.wave.2",  // 图标
                        title: "做一次模拟面试",  // 标题
                        detail: "今日剩 \(app.entitlement.remaining(.interviewDaily) ?? 0) 场",  // 剩余场次
                        done: app.data.sessions.contains {  // 今天有没有完成的面试
                            Calendar.current.isDateInToday($0.startedAt) && $0.state == .archived  // 今天且已归档
                        }  // 判断结束
                    )  // 任务二结束
                    Divider()  // 分隔线
                    taskRow(  // 任务三
                        icon: "pawprint",  // 图标
                        title: "喂一次伙伴",  // 标题
                        detail: app.pet.food > 0 ? "口粮 \(app.pet.food) 颗" : "没有口粮，先去闯关",  // 详情
                        done: app.pet.energy >= Pet.maxEnergy  // 是否吃饱
                    )  // 任务三结束
                }  // 排列结束
            }  // 卡片结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        }  // 排列结束
    }  // todayTasks 结束

    private func taskRow(icon: String, title: String, detail: String, done: Bool) -> some View {  // 单条任务
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
        }  // 排列结束
        .accessibilityElement(children: .combine)  // 合并朗读
        .accessibilityLabel("\(title)，\(detail)，\(done ? "已完成" : "未完成")")  // 朗读文案
    }  // 方法结束

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
                            HStack {  // 横向排列
                                VStack(alignment: .leading, spacing: 2) {  // 文字区
                                    Text(item.topic.name).font(AppFont.bodyStrong)  // 板块名
                                    Text("答了 \(item.total) 题，正确率 \(Int(item.accuracy * 100))%")  // 统计
                                        .font(AppFont.caption)  // 小字
                                        .foregroundStyle(Color.textSecondary)  // 次要色
                                }  // 文字区结束
                                Spacer()  // 撑开
                                Text("去练")  // 引导文案
                                    .font(AppFont.captionStrong)  // 小字加粗
                                    .foregroundStyle(Color.appBrand)  // 品牌色
                            }  // 排列结束
                        }  // 遍历结束
                    }  // 排列结束
                }  // 卡片结束
                .padding(.horizontal, Metrics.pagePadding)  // 左右边距
            }  // 排列结束
        }  // 分支结束
    }  // weakTopics 结束
}  // TodayView 结束
