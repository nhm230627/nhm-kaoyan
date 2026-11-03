//  School.swift —— 院校与卷别（对齐样板 public/data/schools.json）    // 文件说明
//  48 所院校、每所三类卷（初试 / 复试笔试 / 面试），数据与样板一致。
//  注意：样板 meta 里写明「院校清单与卷别为演示数据，正式版按各校研究生院
//  公布的招生目录与真题接入」，所以这里不宣称是真题。

import Foundation  // 基础库

enum MockKind: String, CaseIterable, Identifiable {  // 卷别
    case initial  // 初试模考
    case written  // 复试笔试
    case interview  // 面试模考

    var id: String { rawValue }  // 用原始值当 id

    var tabTitle: String {  // Tab 上的名字
        switch self {  // 按卷别分支
        case .initial: "初试模考"  // 初试
        case .written: "复试笔试"  // 笔试
        case .interview: "面试模考"  // 面试
        }  // 分支结束
    }  // tabTitle 结束

    var shortLabel: String {  // 列表里「N 套初试卷」的卷字前缀
        switch self {  // 按卷别分支
        case .initial: "初试"  // 初试
        case .written: "笔试"  // 笔试
        case .interview: "面试"  // 面试
        }  // 分支结束
    }  // shortLabel 结束

    var questionCount: Int {  // 该卷别抽多少题
        switch self {  // 按卷别分支
        case .initial: 20  // 初试 20 题（样板 openSchool 里的 n）
        case .written: 10  // 复试笔试 10 题
        case .interview: 0  // 面试不走做题，进面试间
        }  // 分支结束
    }  // questionCount 结束
}  // MockKind 结束

struct SchoolPapers: Codable, Hashable {  // 一所院校的三类卷
    let initial: [String]  // 初试卷名
    let written: [String]  // 复试笔试卷名
    let interview: [String]  // 面试卷名

    func list(for kind: MockKind) -> [String] {  // 按卷别取卷名
        switch kind {  // 按卷别分支
        case .initial: initial  // 初试
        case .written: written  // 笔试
        case .interview: interview  // 面试
        }  // 分支结束
    }  // list 结束
}  // SchoolPapers 结束

struct School: Codable, Identifiable, Hashable {  // 一所院校
    let id: String  // 院校 id，如 ruc
    let name: String  // 院校全名
    let city: String  // 所在城市
    let tags: [String]  // 标签，如 985 / 211 / 双一流 / 财经
    let focus: String  // 侧重方向，决定抽题权重
    let tier: String  // 档次，决定列表左侧角标
    let papers: SchoolPapers  // 三类卷
    let hot: Bool?  // 是否热门（可空，样板里部分院校没有）

    var isHot: Bool { hot ?? false }  // 缺省不算热门

    var badge: String {  // 左侧方角标上的字
        switch tier {  // 按档次分支
        case "财经": "财"  // 财经类
        case "普通": "研"  // 普通院校
        default: tier  // 985 / 211 / 双一流 直接显示
        }  // 分支结束
    }  // badge 结束

    var focusLabel: String {  // 侧重方向的中文名（选卷弹层里会显示）
        switch focus {  // 按侧重分支
        case "vat": "增值税计算与抵扣"  // 增值税
        case "income": "所得税"  // 所得税
        case "admin": "税收征管"  // 征管
        case "tax-system": "税制结构"  // 税制
        default: "四大板块均衡"  // balanced 或未知
        }  // 分支结束
    }  // focusLabel 结束
}  // School 结束

struct SchoolMeta: Codable {  // schools.json 的 meta 段
    let note: String?  // 数据说明
    let updated: String?  // 更新时间
}  // SchoolMeta 结束

struct SchoolFile: Codable {  // schools.json 根结构
    let meta: SchoolMeta?  // 元信息，可缺
    let schools: [School]  // 院校列表
}  // SchoolFile 结束

enum SchoolCatalog {  // 院校数据入口
    private static var cached: SchoolFile?  // 读一次就记住

    static func file(bundle: Bundle = .main) -> SchoolFile {  // 读整份院校文件
        if let cached { return cached }  // 已经读过直接给
        guard let url = bundle.url(forResource: "schools", withExtension: "json"),  // 找文件
              let data = try? Data(contentsOf: url),  // 读内容
              let parsed = try? JSONDecoder().decode(SchoolFile.self, from: data) else {  // 解析
            let empty = SchoolFile(meta: nil, schools: [])  // 失败就记空，避免每次重试
            cached = empty  // 缓存空表
            return empty  // 返回空
        }  // 分支结束
        cached = parsed  // 缓存结果
        return parsed  // 返回整份文件
    }  // file 结束

    static func load(bundle: Bundle = .main) -> [School] {  // 只取院校列表
        file(bundle: bundle).schools  // 从整份文件里拿
    }  // load 结束

    static var note: String {  // 页脚那句数据说明（样板 mkNote 直接用 meta.note）
        file().meta?.note ?? ""  // 没有就空串
    }  // note 结束

    static func school(id: String) -> School? {  // 按 id 查院校
        load().first { $0.id == id }  // 线性查找即可，只有 48 条
    }  // 方法结束
}  // SchoolCatalog 结束
