//  Track.swift —— 考试方向（对齐样板 public/js/track.js）            // 文件说明
//  为什么单拎出来：一个考生只考一个专业，但同一台手机上可能放着两个人的账号，
//  也可能自己从税务跳到金融。所以「考什么」是全局状态，不是某个模块的选项：
//  题库、模考院校、面试间、地图当前岛，都跟着它换。

import Foundation  // 基础库

struct Track: Identifiable, Hashable {  // 一个考试方向
    let id: String  // 方向 id，同时是题库字典的 key
    let name: String  // 全称，如「税务专硕」
    let short: String  // 两字简称，如「税务」（顶栏 chip 用）
    let code: String  // 专业代码，如 MT
    let degree: String  // 学位全称，如「税务硕士（MT）」
    let island: String  // 对应岛 id
    let islandName: String  // 岛名，如「税喵岛」
    let people: Int  // 岛上备考人数（样板写死的展示值）
    let room: String  // 面试间名字
    let desc: String  // 一句话说明考什么
    let topicIDs: [String]  // 本方向题库包含的知识点 id（空 = 整库都用）

    /// 四个方向，内容与样板 track.js 的 TRACKS 对应（医学方向按用户要求移除，不提供）。
    static let all: [Track] = [  // 全部方向
        Track(id: "tax", name: "税务专硕", short: "税务", code: "MT",  // 税务
              degree: "税务硕士（MT）", island: "tax", islandName: "税喵岛",  // 岛信息
              people: 1286, room: "税务专硕复试间",  // 人数与面试间
              desc: "税法 · 税制 · 征管，财经类院校主力方向",  // 说明
              topicIDs: ["tax-system", "vat", "income-tax", "admin"]),  // 只取税务四块
        Track(id: "fin", name: "金融专硕", short: "金融", code: "MF",  // 金融
              degree: "金融硕士（MF）", island: "fin", islandName: "金融喵岛",  // 岛信息
              people: 842, room: "金融专硕复试间",  // 人数与面试间
              desc: "货币银行 · 公司理财 · 投资学",  // 说明
              topicIDs: []),  // 整库都用（banks.json 自带四块）
        Track(id: "law", name: "法律硕士", short: "法学", code: "JM",  // 法硕
              degree: "法律硕士（JM）", island: "law", islandName: "法喵岛",  // 岛信息
              people: 613, room: "法硕复试间",  // 人数与面试间
              desc: "民法 · 刑法 · 宪法 · 法理",  // 说明
              topicIDs: []),  // 整库都用
        Track(id: "cs", name: "计算机", short: "计算机", code: "CS",  // 计算机
              degree: "工学硕士（计算机）", island: "cs", islandName: "计喵岛",  // 岛信息
              people: 1547, room: "计算机复试间",  // 人数与面试间
              desc: "数据结构 · 操作系统 · 网络 · 数据库",  // 说明
              topicIDs: []),  // 整库都用
    ]  // 方向表结束

    static let fallback = all[0]  // 找不到方向时退回税务

    static func meta(_ id: String) -> Track {  // 按 id 查方向
        all.first { $0.id == id } ?? fallback  // 查不到就退回默认
    }  // 方法结束

    var sub: String { "\(name) · \(code)" }  // 页面副标题用的「全称 · 代码」
}  // Track 结束
