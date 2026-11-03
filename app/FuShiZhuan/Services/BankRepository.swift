//  BankRepository.swift —— 按考试方向取题库                          // 文件说明
//  数据来源与样板 track.js 的 loadBank 一致：
//    · 税务方向 → Resources/questions.json
//    · 其余四方向 → Resources/banks.json 里对应的那一套
//  本文件只负责「读文件 + 拼成 QuestionBank」，不做缓存、不发通知，
//  缓存在 AppState 里（那边是 @Observable，换方向视图才会刷新）。

import Foundation  // 基础库

enum BankRepository {  // 题库仓库
    enum LoadError: Error {  // 加载错误
        case fileMissing(String)  // 文件缺失
        case decodeFailed(String)  // 解析失败
    }  // LoadError 结束

    /// banks.json 里的一套题库。与 QuestionBank 的区别：没有 meta 段，
    /// 多一个 name（方向中文名）。所以不能直接复用 QuestionBank 解码。
    private struct DirectionBank: Codable {  // 单方向题库
        let name: String  // 方向名，如「金融专硕」
        let topics: [Topic]  // 知识点
        let questions: [Question]  // 题目
    }  // DirectionBank 结束

    /// 文件级缓存：只缓存原始 Data，避免切方向时反复读盘。
    /// 不缓存 QuestionBank，避免和 AppState 里的那份状态出现两个来源。
    private static var rawCache: [String: Data] = [:]  // 文件名 → 内容

    private static func raw(_ name: String, bundle: Bundle) throws -> Data {  // 读文件（带缓存）
        if let hit = rawCache[name] { return hit }  // 读过就直接给
        guard let url = bundle.url(forResource: name, withExtension: "json") else {  // 找文件
            throw LoadError.fileMissing(name)  // 没找到
        }  // 分支结束
        let data = try Data(contentsOf: url)  // 读内容
        rawCache[name] = data  // 记进缓存
        return data  // 返回内容
    }  // raw 结束

    /// 取某个方向的整套题库。
    /// 税务方向会按 Track.topicIDs 白名单过滤：iOS 的 questions.json 比样板
    /// 多收了金融、经管两块知识点，不筛的话税务方向的「选择知识点」会混进
    /// 与税务无关的板块。
    static func load(_ track: Track, bundle: Bundle = .main) throws -> QuestionBank {  // 按方向取库
        if track.id == "tax" {  // 税务走主库
            return try loadMain(bundle: bundle, only: track.topicIDs)  // 过滤出税务四块
        }  // 分支结束
        return try loadDirection(track, bundle: bundle)  // 其余走 banks.json
    }  // load 结束

    private static func loadMain(bundle: Bundle, only: [String]) throws -> QuestionBank {  // 读主库
        let data = try raw("questions", bundle: bundle)  // 读 questions.json
        let bank: QuestionBank  // 解码结果
        do {  // 尝试解析
            bank = try JSONDecoder().decode(QuestionBank.self, from: data)  // 直接解码
        } catch {  // 解析失败
            throw LoadError.decodeFailed("questions.json：\(error)")  // 包装抛错
        }  // 分支结束
        guard !only.isEmpty else { return bank }  // 没白名单就整库返回
        let allowed = Set(only)  // 白名单转集合
        let topics = bank.topics.filter { allowed.contains($0.id) }  // 只留白名单里的知识点
        let questions = bank.questions.filter { allowed.contains($0.topic) }  // 只留这些知识点的题
        return QuestionBank(meta: bank.meta, topics: topics, questions: questions)  // 组装返回
    }  // loadMain 结束

    private static func loadDirection(_ track: Track, bundle: Bundle) throws -> QuestionBank {  // 读方向库
        let data = try raw("banks", bundle: bundle)  // 读 banks.json
        let table: [String: DirectionBank]  // 方向 → 题库
        do {  // 尝试解析
            table = try JSONDecoder().decode([String: DirectionBank].self, from: data)  // 解码整张表
        } catch {  // 解析失败
            throw LoadError.decodeFailed("banks.json：\(error)")  // 包装抛错
        }  // 分支结束
        guard let one = table[track.id] else {  // 找不到该方向
            throw LoadError.fileMissing("banks.json 里没有 \(track.id)")  // 抛错
        }  // 分支结束
        let meta = QuestionBank.Meta(title: one.name, version: "1",  // 补一个占位 meta
                                     note: "来自 banks.json 的 \(track.name) 题库")  // 说明来源
        return QuestionBank(meta: meta, topics: one.topics, questions: one.questions)  // 组装返回
    }  // loadDirection 结束

    /// 跨方向查知识点名字。错题本只存了 topic id，用户切方向后
    /// 那些题的板块名不在当前题库里，得回原始库里找。
    static func topicName(_ id: String, in banks: [String: QuestionBank]) -> String {  // 查知识点名
        for bank in banks.values {  // 遍历已加载的各方向题库
            if let hit = bank.topics.first(where: { $0.id == id }) { return hit.name }  // 命中就返回
        }  // 循环结束
        let fallback = ["tax-system": "税制结构", "vat": "增值税",  // 兜底表（照样板 track.js）
                        "income-tax": "所得税", "admin": "税收征管"]  // 税务四块
        return fallback[id] ?? id  // 兜底不到就显示 id
    }  // topicName 结束
}  // BankRepository 结束
