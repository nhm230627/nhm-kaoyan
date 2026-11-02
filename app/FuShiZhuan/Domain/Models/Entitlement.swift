//  Entitlement.swift —— 会员与权益                                 // 文件说明
//  判断规则集中在这里，禁止页面自己判断 isVip                        // 使用约束

import Foundation  // 基础库

enum Feature: String, Codable, CaseIterable, Identifiable {  // 可限制的能力
    case quizUnlimited  // 无限刷题
    case interviewDaily  // 每日面试场次
    case courseLibrary  // 课程资料库
    case wrongBookAll  // 全部错题解析
    case reportDetail  // 详细复盘报告
    case plazaFull  // 广场全部互动

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 能力名
        switch self {  // 按能力分支
        case .quizUnlimited: "无限刷题"  // 刷题
        case .interviewDaily: "每日 AI 面试"  // 面试
        case .courseLibrary: "课程与资料库"  // 课程
        case .wrongBookAll: "错题全解析"  // 错题
        case .reportDetail: "详细复盘报告"  // 报告
        case .plazaFull: "广场全部互动"  // 广场
        }  // 分支结束
    }  // title 结束

    var freeQuota: Int? {  // 免费额度，nil 为不限
        switch self {  // 按能力分支
        case .quizUnlimited: return 30  // 每日 30 题
        case .interviewDaily: return 1  // 每日 1 场
        case .courseLibrary: return 3  // 试看 3 节
        case .wrongBookAll: return 5  // 5 条解析
        case .reportDetail: return 0  // 免费不给
        case .plazaFull: return nil  // 广场全开
        }  // 分支结束
    }  // freeQuota 结束
}  // Feature 结束

enum Plan: String, Codable, CaseIterable, Identifiable {  // 订阅档位
    case free  // 免费
    case monthly  // 月付
    case yearly  // 年付
    case lifetime  // 永久

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 档位名
        switch self {  // 按档位分支
        case .free: "免费版"  // 免费
        case .monthly: "连续月付"  // 月付
        case .yearly: "连续年付"  // 年付
        case .lifetime: "永久"  // 永久
        }  // 分支结束
    }  // title 结束

    var isPaid: Bool { self != .free }  // 是否付费档
}  // Plan 结束

struct Entitlement: Codable, Equatable {  // 权益状态
    var plan: Plan  // 当前档位
    var expiresAt: Date?  // 到期时间
    var originalTransactionID: String?  // 原始交易号
    var dailyUsage: [String: Int]  // 今日已用额度
    var usageDate: Date  // 额度记账日期

    static let `default` = Entitlement(  // 默认免费档
        plan: .free,  // 免费
        expiresAt: nil,  // 无到期
        originalTransactionID: nil,  // 无交易号
        dailyUsage: [:],  // 未用过
        usageDate: .now  // 今天开始记
    )  // 默认值结束

    func isActive(now: Date = .now) -> Bool {  // 会员是否有效
        switch plan {  // 按档位分支
        case .free: return false  // 免费无效
        case .lifetime: return true  // 永久有效
        case .monthly, .yearly:  // 订阅看到期
            guard let expiresAt else { return false }  // 没到期时间算过期
            return expiresAt > now  // 未过期才有效
        }  // 分支结束
    }  // isActive 结束

    func remaining(_ feature: Feature, now: Date = .now) -> Int? {  // 剩余额度
        if isActive(now: now) { return nil }  // 会员不限
        guard let quota = feature.freeQuota else { return nil }  // 本就不限
        let used = (usageDate.isSameDay(as: now)) ? (dailyUsage[feature.rawValue] ?? 0) : 0  // 今天用过多少
        return max(0, quota - used)  // 不为负
    }  // remaining 结束

    func canUse(_ feature: Feature, now: Date = .now) -> Bool {  // 能否使用
        guard let left = remaining(feature, now: now) else { return true }  // 不限就通过
        return left > 0  // 还有额度才通过
    }  // canUse 结束

    @discardableResult  // 返回值可忽略
    mutating func consume(_ feature: Feature, now: Date = .now) -> Bool {  // 扣一次额度
        guard canUse(feature, now: now) else { return false }  // 没额度直接拒
        if !usageDate.isSameDay(as: now) {  // 跨天了
            dailyUsage.removeAll()  // 计数清零
            usageDate = now  // 刷新日期
        }  // 分支结束
        if isActive(now: now) || feature.freeQuota == nil { return true }  // 不限次不记账
        dailyUsage[feature.rawValue, default: 0] += 1  // 记账加一
        return true  // 扣成功
    }  // consume 结束

    mutating func apply(plan: Plan, expiresAt: Date?, transactionID: String?) {  // 写入购买结果
        self.plan = plan  // 更新档位
        self.expiresAt = expiresAt  // 更新到期
        self.originalTransactionID = transactionID  // 更新交易号
        self.dailyUsage.removeAll()  // 清空额度计数
    }  // apply 结束

    mutating func revoke() {  // 退款或到期回落
        plan = .free  // 回到免费
        expiresAt = nil  // 清到期
        dailyUsage.removeAll()  // 清额度
    }  // revoke 结束
}  // Entitlement 结束

extension Date {  // 日期扩展
    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {  // 是否同一天
        calendar.isDate(self, inSameDayAs: other)  // 交给日历判断
    }  // 方法结束
}  // Date 扩展结束
