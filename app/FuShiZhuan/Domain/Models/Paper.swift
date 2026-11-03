//  Paper.swift —— 整套试卷模型                                      // 文件说明
//  为什么单独建模型：知识点训练是「一道一道刷」，整套试卷是「一次做完一套再交卷」，
//  两者的作答流程、计时、算分都不同，不能共用一套 UI。                    // 设计说明
//  试卷只存题目 id 的引用，不复制题目本身——避免同一道题两份数据不一致。    // 数据约定

import Foundation  // 基础库

// MARK: - 方向                                                        // 分节：方向

enum StudyDirection: String, Codable, CaseIterable, Identifiable {  // 备考方向
    case tax  // 税务
    case finance  // 金融
    case management  // 经管

    var id: String { rawValue }  // 用原始值当 id

    var title: String {  // 方向名
        switch self {  // 按方向分支
        case .tax: "税务"  // 税务
        case .finance: "金融"  // 金融
        case .management: "经管"  // 经管
        }  // 分支结束
    }  // title 结束
}  // StudyDirection 结束

// MARK: - 试卷种类                                                    // 分节：种类

enum PaperKind: String, Codable {  // 试卷来源
    case real  // 历年真题（只在用户自己导入后才有）
    case mock  // 按考纲自编的模拟卷

    var title: String {  // 种类名
        switch self {  // 按种类分支
        case .real: "历年真题"  // 真题
        case .mock: "自编模拟卷"  // 模拟
        }  // 分支结束
    }  // title 结束
}  // PaperKind 结束

// MARK: - 试卷                                                        // 分节：试卷

struct PaperSection: Codable, Identifiable, Hashable {  // 试卷里的一道大题
    var id: String { title }  // 用标题当 id
    let title: String  // 大题名，如「一、单项选择题」
    let questionIDs: [String]  // 这道大题包含的题目 id
}  // PaperSection 结束

struct Paper: Codable, Identifiable, Hashable {  // 一整套试卷
    let id: String  // 试卷 id
    let title: String  // 试卷标题
    let kind: PaperKind  // 真题还是自编
    let direction: StudyDirection  // 方向
    let year: Int  // 年份
    let subject: String  // 科目名
    let minutes: Int  // 建议时长（分钟）
    let totalScore: Int  // 总分
    let sourceNote: String  // 来源说明，必须写清楚
    let sections: [PaperSection]  // 各大题

    var questionIDs: [String] {  // 全卷题目 id（按大题顺序展开）
        sections.flatMap { $0.questionIDs }  // 展平
    }  // 属性结束

    var questionCount: Int {  // 全卷题量
        questionIDs.count  // 数一下
    }  // 属性结束
}  // Paper 结束

struct PaperCatalog: Codable {  // 试卷总表
    struct Meta: Codable {  // 元信息
        let version: String  // 版本
        let note: String  // 备注
    }  // Meta 结束
    let meta: Meta  // 元信息
    let papers: [Paper]  // 全部试卷

    static let empty = PaperCatalog(meta: .init(version: "0", note: "试卷未加载"), papers: [])  // 兜底

    static let shared = load()  // 全 App 共用一份

    static func load() -> PaperCatalog {  // 从 App 包读 papers.json
        guard let url = Bundle.main.url(forResource: "papers", withExtension: "json"),  // 找文件
              let data = try? Data(contentsOf: url),  // 读字节
              let catalog = try? JSONDecoder().decode(PaperCatalog.self, from: data) else {  // 解码
            return .empty  // 失败就退回空表，不崩
        }  // 分支结束
        return catalog  // 读成功就用它
    }  // load 结束

    func papers(kind: PaperKind) -> [Paper] {  // 按种类筛
        papers.filter { $0.kind == kind }  // 真题或模拟卷
    }  // 方法结束

    func paper(id: String) -> Paper? {  // 按 id 找
        papers.first { $0.id == id }  // 线性找
    }  // 方法结束
}  // PaperCatalog 结束
