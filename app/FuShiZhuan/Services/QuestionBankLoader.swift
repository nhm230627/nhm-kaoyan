//  QuestionBankLoader.swift —— 题库加载                            // 文件说明
//  当前读 App 内置 questions.json，结构与 Web 样板一致               // 数据来源
//  后续接后台只替换本文件实现，不动上层                               // 扩展说明

import Foundation  // 基础库

enum QuestionBankLoader {  // 题库加载器
    enum LoadError: Error {  // 加载错误
        case fileMissing  // 文件缺失
        case decodeFailed(String)  // 解析失败
    }  // LoadError 结束

    static func loadBundled(bundle: Bundle = .main) throws -> QuestionBank {  // 读内置题库
        guard let url = bundle.url(forResource: "questions", withExtension: "json") else {  // 找文件
            throw LoadError.fileMissing  // 没找到就抛错
        }  // 分支结束
        return try decode(Data(contentsOf: url))  // 读内容并解析
    }  // 方法结束

    static func decode(_ data: Data) throws -> QuestionBank {  // 解析 JSON
        do {  // 尝试解析
            return try JSONDecoder().decode(QuestionBank.self, from: data)  // 解码
        } catch {  // 解析失败
            throw LoadError.decodeFailed(String(describing: error))  // 包装抛错
        }  // 分支结束
    }  // 方法结束

    static func chapters(from bank: QuestionBank) -> [Chapter] {  // 生成章节列表
        bank.topics.map { topic in  // 每个板块一章
            Chapter(id: topic.id, name: topic.name, desc: topic.desc)  // 构造成章
        }  // 映射结束
    }  // 方法结束

    static func questions(  // 取某一关的题
        inChapter chapterID: String,  // 章节 id
        levelIndex: Int,  // 第几关
        bank: QuestionBank,  // 题库
        perLevel: Int = 3  // 每关题数
    ) -> [Question] {  // 返回题目数组
        let pool = bank.questions.filter { $0.topic == chapterID }  // 本章全部题
        guard levelIndex > 0 else { return [] }  // 关卡号非法返回空
        let start = (levelIndex - 1) * perLevel  // 起始下标
        guard start < pool.count else { return [] }  // 越界返回空
        let end = min(pool.count, start + perLevel)  // 结束下标
        return Array(pool[start..<end])  // 切片返回
    }  // 方法结束
}  // QuestionBankLoader 结束
