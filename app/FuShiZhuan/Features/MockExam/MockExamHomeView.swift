//  MockExamHomeView.swift —— 模考大厅（单机模拟版）                    // 文件说明
//  只做「看排期 / 预约 / 看自己和模拟对手的差距」                        // 页面职责
//  没有服务端，所以同考对手与排名全部是本地模拟，UI 里必须写明             // 诚实约束

import SwiftUI                                                     // 界面框架

// MARK: - 本地数据                                                      // 分节：数据

/// 一场模考。当前全部来自本地排期表，不是真的有人在同一时间开考
struct MockExamSlot: Identifiable, Hashable {                      // 模考场次
    let id: String                                                 // 唯一 id
    let title: String                                              // 场次名
    let startsAt: Date                                             // 开考时间
    let capacity: Int                                              // 报名上限
    let reserved: Int                                              // 已报名（模拟）
}                                                                  // MockExamSlot 结束

/// 排期与对手分都是本地算的，换成服务端时只需要替换这两个方法
enum MockExamCatalog {                                             // 本地排期表
    /// 未来三场：按「每周日 20:00」往后推，不依赖任何服务器
    static func slots(after now: Date = .now, calendar: Calendar = .current) -> [MockExamSlot] { // 生成排期
        (1...3).map { week in                                      // 三场
            let date = sunday(weeksAhead: week, after: now, calendar: calendar) // 算日期
            return MockExamSlot(                                   // 构造场次
                id: "mock-\(Int(date.timeIntervalSince1970))",     // 用时间戳当 id
                title: "全真模考 #\(12 + week)",                    // 场次名
                startsAt: date,                                    // 开考时间
                capacity: 30,                                      // 30 个名额
                reserved: 9 + week * 4                             // 模拟已报名人数
            )                                                      // 构造结束
        }                                                          // 映射结束
    }                                                              // 方法结束

    /// 第 n 个周日的 20:00
    static func sunday(weeksAhead: Int, after now: Date, calendar: Calendar) -> Date { // 算周日
        let start = calendar.startOfDay(for: now)                  // 今天零点
        let weekday = calendar.component(.weekday, from: start)    // 今天星期几（1 是周日）
        let daysToSunday = (8 - weekday) % 7                        // 到本周日还差几天
        let base = calendar.date(byAdding: .day, value: daysToSunday, to: start) ?? start // 本周日
        let shifted = calendar.date(byAdding: .day, value: (weeksAhead - 1) * 7, to: base) ?? base // 往后推周
        return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: shifted) ?? shifted // 定到 20:00
    }                                                              // 方法结束

    /// 模拟对手的总分。用 id 做种子，保证同一场次每次打开看到的分布一致，不会"刷新变好"
    static func peerScores(seed: String, count: Int = 24) -> [Int] { // 生成对手分
        var state = seed.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) } // 简单散列当种子
        var list: [Int] = []                                        // 结果
        for _ in 0..<count {                                       // 逐个生成
            state = (state &* 1103515245 &+ 12345) & 0x7FFF_FFFF   // 线性同余
            let span = 58 + (state % 31)                           // 58–88 分区间
            list.append(span)                                      // 收进来
        }                                                          // 循环结束
        return list.sorted()                                       // 升序返回
    }                                                              // 方法结束
}                                                                  // MockExamCatalog 结束

// MARK: - 页面                                                          // 分节：页面

struct MockExamHomeView: View {                                     // 模考大厅
    @Environment(AppState.self) private var app                     // 全局状态，取自己的成绩

    @AppStorage("app.mock.reserved") private var reservedIDs = ""    // 已预约的场次 id，逗号分隔

    private var slots: [MockExamSlot] { MockExamCatalog.slots() }    // 未来三场

    private var myScore: Int? {                                     // 我最近一次的面试分
        app.data.sessions.compactMap { $0.overallScore }.last      // 取最后一题有分的场次
    }                                                               // 属性结束

    var body: some View {                                           // 视图主体
        ScrollView {                                                // 可滚动
            VStack(spacing: Space.l) {                              // 纵向排列
                noticeCard                                          // 首屏必须说明是模拟
                ForEach(slots) { slot in                            // 逐场排期
                    slotCard(slot)                                  // 单场卡
                }                                                   // 遍历结束
                if let score = myScore, let first = slots.first {    // 有成绩才能对比
                    compareCard(myScore: score, slot: first)         // 对比卡
                } else {                                            // 没有成绩
                    noScoreCard                                     // 提示先面一场
                }                                                   // 分支结束
                gapCard                                             // 逐问差距的现状说明
            }                                                       // 排列结束
            .padding(Metrics.pagePadding)                           // 内边距
            .padding(.bottom, Space.xxl)                            // 底部留白
        }                                                           // 滚动结束
        .background(Color.appBG)                                    // 底色
        .navigationTitle("模考大厅")                                  // 标题
        .navigationBarTitleDisplayMode(.inline)                     // 小标题
    }                                                               // body 结束

    // MARK: - 说明                                                      // 分节：说明

    private var noticeCard: some View {                             // 首屏声明
        Card {                                                      // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {          // 纵向排列
                HStack(spacing: Space.xs) {                         // 标题行
                    Text("模考大厅").font(AppFont.section)            // 标题
                    Chip(text: "单机模拟", tint: .appWarn)            // 显著标记
                }                                                   // 排列结束
                Text("当前版本没有服务端：排期、同考人数、对手分数全部是本地模拟数据，用于先把「预约—对比—复盘」这条路走通。") // 说明
                    .font(AppFont.caption)                          // 小字
                    .foregroundStyle(Color.textSecondary)           // 次要色
                    .fixedSize(horizontal: false, vertical: true)   // 允许换行
                Text("接入后端前，任何「全服排名」的说法都不会出现在这里。") // 底线
                    .font(AppFont.caption)                          // 小字
                    .foregroundStyle(Color.textTertiary)            // 弱化色
            }                                                       // 排列结束
        }                                                           // 卡片结束
    }                                                               // noticeCard 结束

    // MARK: - 场次                                                      // 分节：场次

    private func slotCard(_ slot: MockExamSlot) -> some View {       // 单场卡
        let booked = isReserved(slot)                                // 是否已预约
        return Card {                                                // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                HStack {                                             // 标题行
                    Text(slot.title).font(AppFont.bodyStrong)        // 场次名
                    Spacer()                                         // 撑开
                    Text(booked ? "已预约" : "可预约")                    // 状态
                        .font(AppFont.captionStrong)                 // 小字加粗
                        .foregroundStyle(booked ? Color.appOK : Color.appBrand) // 上色
                }                                                    // 排列结束
                Text(MockExamHomeView.formatter.string(from: slot.startsAt)) // 开考时间
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textSecondary)            // 次要色
                HStack(spacing: Space.xs) {                          // 名额行
                    Text("余 \(max(slot.capacity - slot.reserved, 0)) / \(slot.capacity) 个名额") // 名额
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textTertiary)         // 弱化色
                    Spacer()                                         // 撑开
                    GhostButton(title: booked ? "取消预约" : "预约这场", // 按钮文案
                                systemImage: booked ? "xmark" : "calendar.badge.plus") { // 图标
                        toggle(slot)                                 // 切换预约
                    }                                                // 按钮结束
                    .frame(width: 130)                               // 固定宽度，别撑满一行
                }                                                    // 排列结束
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // slotCard 结束

    private func isReserved(_ slot: MockExamSlot) -> Bool {           // 是否已预约
        reservedSet.contains(slot.id)                                // 查集合
    }                                                                // 方法结束

    private var reservedSet: Set<String> {                           // 预约集合
        Set(reservedIDs.split(separator: ",").map(String.init).filter { !$0.isEmpty }) // 拆分
    }                                                                // 属性结束

    private func toggle(_ slot: MockExamSlot) {                      // 切换预约
        var set = reservedSet                                        // 拷一份
        if set.contains(slot.id) { set.remove(slot.id) } else { set.insert(slot.id) } // 增删
        reservedIDs = set.sorted().joined(separator: ",")            // 写回
    }                                                                // 方法结束

    // MARK: - 对比                                                      // 分节：对比

    private func compareCard(myScore: Int, slot: MockExamSlot) -> some View { // 对比卡
        let peers = MockExamCatalog.peerScores(seed: slot.id)         // 模拟对手分
        let average = peers.isEmpty ? 0 : peers.reduce(0, +) / peers.count // 平均
        let highest = peers.max() ?? 0                                // 最高
        let rank = 1 + peers.filter { $0 > myScore }.count            // 我的名次
        return Card {                                                 // 卡片
            VStack(alignment: .leading, spacing: Space.m) {            // 纵向排列
                HStack {                                              // 标题行
                    Text("成绩对比").font(AppFont.section)              // 标题
                    Spacer()                                          // 撑开
                    Chip(text: "对手为模拟数据", tint: .appWarn)         // 再提醒一次
                }                                                     // 排列结束
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.s) { // 四宫格
                    StatTile(value: "\(myScore)", title: "我的", tint: .appBrand) // 我的
                    StatTile(value: "\(average)", title: "平均", tint: .textSecondary) // 平均
                    StatTile(value: "\(highest)", title: "最高", tint: .appViolet) // 最高
                    StatTile(value: "\(rank) / \(peers.count + 1)", title: "名次", tint: .appOK) // 名次
                }                                                     // 网格结束
                Text("名次按「模拟对手中比我高的人数 + 1」计算，不含并列处理。") // 口径说明
                    .font(AppFont.caption)                            // 小字
                    .foregroundStyle(Color.textTertiary)              // 弱化色
                    .fixedSize(horizontal: false, vertical: true)     // 允许换行
            }                                                         // 排列结束
        }                                                             // 卡片结束
    }                                                                 // compareCard 结束

    private var noScoreCard: some View {                             // 没有成绩时
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                Text("还没有可比的分").font(AppFont.section)            // 标题
                Text("先完成一场模拟面试，这里才会出现你的分数、平均分与名次。") // 说明
                    .font(AppFont.caption)                            // 小字
                    .foregroundStyle(Color.textSecondary)             // 次要色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // noScoreCard 结束

    private var gapCard: some View {                                 // 逐问差距现状
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                Text("逐问差距").font(AppFont.section)                  // 标题
                Text("这一项需要「同一套题、同一场次」的真实作答数据才能算。当前是单机版，没有其他考生的逐题记录，所以这里先空着，接服务端后再开。") // 说明
                    .font(AppFont.caption)                            // 小字
                    .foregroundStyle(Color.textSecondary)             // 次要色
                    .fixedSize(horizontal: false, vertical: true)     // 允许换行
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // gapCard 结束

    private static let formatter: DateFormatter = {                   // 时间格式
        let f = DateFormatter()                                      // 构造器
        f.locale = Locale(identifier: "zh_CN")                       // 中文
        f.dateFormat = "M月d日 EEEE HH:mm"                             // 月日 周几 时间
        return f                                                     // 返回
    }()                                                              // 闭包结束
}                                                                    // MockExamHomeView 结束
