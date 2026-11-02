//  PrepProfile.swift —— 用户与备考档案                             // 文件说明
//  整个 App 只有一个根对象，其余数据都挂在它下面                      // 数据约束

import Foundation  // 基础库

enum Venue: String, Codable, CaseIterable, Identifiable {  // 备考方向（岛）
    case tax  // 税务专硕
    case finance  // 金融专硕
    case law  // 法律硕士
    case cs  // 计算机
    case medicine  // 医学

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 岛的全名
        switch self {  // 按方向分支
        case .tax: "税务考研岛"  // 税务
        case .finance: "金融考研岛"  // 金融
        case .law: "法硕考研岛"  // 法硕
        case .cs: "计算机考研岛"  // 计算机
        case .medicine: "医学考研岛"  // 医学
        }  // 分支结束
    }  // title 结束

    var shortTitle: String {  // 岛的简称
        switch self {  // 按方向分支
        case .tax: "税务"  // 税务
        case .finance: "金融"  // 金融
        case .law: "法硕"  // 法硕
        case .cs: "计算机"  // 计算机
        case .medicine: "医学"  // 医学
        }  // 分支结束
    }  // shortTitle 结束

    var isReady: Bool { self == .tax }  // 目前只有税务接入题库
}  // Venue 结束

enum PrepStage: String, Codable, CaseIterable, Identifiable {  // 备考阶段
    case foundation  // 基础期
    case intensive  // 强化期
    case sprint  // 冲刺期
    case interview  // 复试期

    var id: String { rawValue }  // 可识别 id

    var title: String {  // 阶段名
        switch self {  // 按阶段分支
        case .foundation: "基础期"  // 基础
        case .intensive: "强化期"  // 强化
        case .sprint: "冲刺期"  // 冲刺
        case .interview: "复试期"  // 复试
        }  // 分支结束
    }  // title 结束
}  // PrepStage 结束

struct PrepProfile: Codable, Equatable {  // 备考档案
    var nickname: String  // 昵称
    var venue: Venue  // 备考方向
    var stage: PrepStage  // 当前阶段
    var targetSchool: String  // 目标院校，仅文案用
    var examDate: Date  // 考试日期
    var dailyMinutes: Int  // 每日可投入分钟数

    static let `default` = PrepProfile(  // 默认档案
        nickname: "同学",  // 默认昵称
        venue: .tax,  // 默认税务
        stage: .interview,  // 默认复试期
        targetSchool: "",  // 未填院校
        examDate: Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now,  // 60 天后
        dailyMinutes: 60  // 每日 60 分钟
    )  // 默认值结束

    var daysLeft: Int {  // 距考试天数
        let cal = Calendar.current  // 取日历
        let from = cal.startOfDay(for: .now)  // 今天零点
        let to = cal.startOfDay(for: examDate)  // 考试日零点
        return max(0, cal.dateComponents([.day], from: from, to: to).day ?? 0)  // 不为负
    }  // 属性结束
}  // PrepProfile 结束
