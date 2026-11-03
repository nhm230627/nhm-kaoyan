//  SortLevel.swift —— 闯关分拣的数据模型与关卡表                          // 文件说明
//  数据来自 Web 样板 public/data/sort-levels.json（已原样拷进 Resources）   // 数据来源
//  闯关不是选择题：把知识点卡片拖进正确的分类槽，靠动作和即时反馈记        // 玩法说明
//  章节结构照抄样板 js/game.js 的 CHAPTERS：4 章 × 每章 3 关              // 章节约定

import Foundation  // 基础库

struct SortSlot: Codable, Identifiable, Hashable {  // 一个分类槽
    let id: String  // 槽 id（卡片靠它判对错）
    let name: String  // 槽名，如「中央税」
    let color: String  // 主题色，如 #4a6bff
}  // SortSlot 结束

struct SortCard: Codable, Hashable, Identifiable {  // 一张待分拣卡片
    var id: String { text + slot }  // 文案加归属当唯一键
    let text: String  // 卡面文字，如「消费税」
    let slot: String  // 正确归属的槽 id
    let note: String  // 放错时给出的依据
}  // SortCard 结束

struct SortLevel: Identifiable {  // 一关（id 来自 json 字典的 key，不在对象里）
    let id: String  // 关卡 id，如 tax-system-1
    let title: String  // 关卡名，如「税种归位」
    let hint: String  // 一句话玩法提示
    let slots: [SortSlot]  // 三个分类槽
    let cards: [SortCard]  // 八张卡片
}  // SortLevel 结束

private struct SortLevelBody: Decodable {  // json 里关卡对象本身没有 id，先按 body 解
    let title: String  // 关卡名
    let hint: String  // 玩法提示
    let slots: [SortSlot]  // 分类槽
    let cards: [SortCard]  // 卡片
}  // SortLevelBody 结束

struct SortChapter: Identifiable {  // 一章 = 一座知识岛
    let id: String  // 章 id
    let name: String  // 章名
    let boss: String  // 守关名字（样板里是 3D 岛上的 Boss）
    let color: String  // 主题色
}  // SortChapter 结束

enum SortCatalog {  // 关卡表
    static let chapters: [SortChapter] = [  // 与样板 game.js CHAPTERS 完全一致
        SortChapter(id: "tax-system", name: "税制结构", boss: "税制守卫", color: "4A6BFF"),  // 第一章
        SortChapter(id: "vat", name: "增值税", boss: "增值税巨兽", color: "E8890C"),  // 第二章
        SortChapter(id: "income-tax", name: "所得税", boss: "所得税魔王", color: "0F9D58"),  // 第三章
        SortChapter(id: "admin", name: "税收征管", boss: "征管判官", color: "7C4DFF"),  // 第四章
    ]  // 章节表结束

    static let perChapter = 3  // 每章三关（与样板一致）

    static let order: [String] = chapters.flatMap { chapter in  // 全部关卡 id 的先后顺序
        (1...perChapter).map { "\(chapter.id)-\($0)" }  // 章 id 加序号
    }  // order 结束

    static let levels: [String: SortLevel] = load()  // 关卡内容，失败就是空表

    static func level(_ id: String) -> SortLevel? { levels[id] }  // 按 id 取关

    static func chapter(of levelID: String) -> SortChapter? {  // 关卡属于哪一章
        let chapterID = levelID.replacingOccurrences(of: "-\\d+$", with: "", options: .regularExpression)  // 去掉尾号
        return chapters.first { $0.id == chapterID }  // 匹配章 id
    }  // chapter 结束

    static func nextLevel(after id: String) -> String? {  // 下一关 id
        guard let i = order.firstIndex(of: id), i + 1 < order.count else { return nil }  // 已是最后一关
        return order[i + 1]  // 返回下一关
    }  // nextLevel 结束

    private static func load() -> [String: SortLevel] {  // 读内置 json
        guard let url = Bundle.main.url(forResource: "sort-levels", withExtension: "json") else { return [:] }  // 找不到就空
        guard let data = try? Data(contentsOf: url) else { return [:] }  // 读不出来就空
        struct File: Decodable { let levels: [String: SortLevelBody] }  // 只关心 levels 字段
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }  // 解析失败给空表
        var out: [String: SortLevel] = [:]  // 结果容器
        for (key, body) in file.levels {  // 逐个关卡
            out[key] = SortLevel(id: key, title: body.title, hint: body.hint,  // 用字典 key 当 id
                                 slots: body.slots, cards: body.cards)  // 其余原样搬
        }  // 循环结束
        return out  // 返回关卡表
    }  // load 结束
}  // SortCatalog 结束
