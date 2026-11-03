//  Pet.swift —— 电子宠物与口粮                                     // 文件说明
//  产品规则：口粮只能靠闯关产出，不投喂就会饿死                        // 核心规则
//  宠物状态是学习行为的结果，不是独立小游戏；所有写入口都在 AppState    // 核心规则

import Foundation  // 基础库

enum PetStage: String, Codable, CaseIterable {  // 成长阶段
    case seed  // 幼体
    case growing  // 成长
    case mature  // 成熟
    case master  // 硕士

    var title: String {  // 阶段名
        switch self {  // 按阶段分支
        case .seed: "幼体"  // 幼体
        case .growing: "成长"  // 成长
        case .mature: "成熟"  // 成熟
        case .master: "硕士"  // 硕士
        }  // 分支结束
    }  // title 结束

    var threshold: Int {  // 进入所需成长值
        switch self {  // 按阶段分支
        case .seed: 0  // 起步 0
        case .growing: 200  // 200
        case .mature: 600  // 600
        case .master: 1200  // 1200
        }  // 分支结束
    }  // threshold 结束

    var level: Int {  // 等级数字（样板宠物名后面显示 Lv.N）
        switch self {  // 按阶段分支
        case .seed: 1  // 幼体 Lv.1
        case .growing: 2  // 成长 Lv.2
        case .mature: 3  // 成熟 Lv.3
        case .master: 4  // 硕士 Lv.4
        }  // 分支结束
    }  // level 结束

    static func stage(for growth: Int) -> PetStage {  // 由成长值推阶段
        PetStage.allCases.last { growth >= $0.threshold } ?? .seed  // 取够得到的最高阶段
    }  // 方法结束
}  // PetStage 结束

enum FeedOutcome: Equatable {  // 投喂结果
    case ok(energy: Int, affinity: Int)  // 成功，回体力与好感
    case noFood  // 没口粮
    case alreadyFull  // 已吃饱
    case dead  // 已饿死
}  // FeedOutcome 结束

struct Pet: Codable, Equatable {  // 宠物状态
    var energy: Int  // 体力 0-100
    var affinity: Int  // 好感度
    var food: Int  // 口粮存量
    var lastDecayDate: Date?  // 最后结算时间
    var starvedDays: Int  // 连续饿了几天
    var starved: Bool  // 是否已饿死
    var claimed: Bool  // 是否已认领

    static let `default` = Pet(  // 默认状态
        energy: 80,  // 初始体力 80
        affinity: 10,  // 初始好感 10
        food: 2,  // 初始口粮 2 颗
        lastDecayDate: nil,  // 未结算过
        starvedDays: 0,  // 未饿
        starved: false,  // 活着
        claimed: false  // 未认领
    )  // 默认值结束

    static let dailyDecay = 22  // 每日掉多少体力
    static let feedEnergy = 30  // 一次投喂回多少体力
    static let feedAffinity = 4  // 一次投喂加多少好感
    static let maxEnergy = 100  // 体力上限
    static let starveAffinityLoss = 4  // 饿死后每天掉多少好感

    mutating func settle(now: Date = .now, calendar: Calendar = .current) {  // 跨自然日结算
        defer { lastDecayDate = now }  // 无论是否扣都更新时间
        guard let last = lastDecayDate else { return }  // 首次不扣
        let from = calendar.startOfDay(for: last)  // 上次的零点
        let to = calendar.startOfDay(for: now)  // 这次的零点
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0  // 差几天
        guard days > 0 else { return }  // 同一天不扣

        let drop = days * Self.dailyDecay  // 总共扣多少
        energy = max(0, energy - drop)  // 体力不为负

        if energy == 0 {  // 掉到 0
            starvedDays += days  // 累计饿的天数
            if starvedDays > 1 {  // 第二天起才掉好感
                affinity = max(0, affinity - days * Self.starveAffinityLoss)  // 扣好感
            }  // 分支结束
            starved = true  // 标记饿死
        } else {  // 还有体力
            starvedDays = 0  // 重置饿天数
            starved = false  // 取消饿死标记
        }  // 分支结束
    }  // settle 结束

    mutating func feed(now: Date = .now) -> FeedOutcome {  // 投喂一次
        if starved { return .dead }  // 饿了先复活
        if food <= 0 { return .noFood }  // 没口粮
        if energy >= Self.maxEnergy { return .alreadyFull }  // 吃饱了

        food -= 1  // 扣一颗口粮
        energy = min(Self.maxEnergy, energy + Self.feedEnergy)  // 加体力不超上限
        affinity += Self.feedAffinity  // 加好感
        lastDecayDate = now  // 刷新结算时间
        return .ok(energy: energy, affinity: affinity)  // 返回新状态
    }  // feed 结束

    mutating func addFood(_ count: Int) {  // 加口粮
        guard count > 0 else { return }  // 非法数量忽略
        food += count  // 累加
    }  // addFood 结束

    mutating func revive() {  // 复活
        starved = false  // 取消饿死
        starvedDays = 0  // 清零饿天数
        energy = 30  // 给回一点体力
    }  // revive 结束

    var isHungry: Bool { energy <= 30 && !starved }  // 是否濒危

    var statusText: String {  // 状态文案
        if starved { return "已饿死，学习中断太久了" }  // 饿死
        if isHungry { return "快饿死了，去闯关换口粮" }  // 濒危
        if energy >= Self.maxEnergy { return "吃饱了，状态最佳" }  // 吃饱
        return "状态良好"  // 正常
    }  // 属性结束
}  // Pet 结束
