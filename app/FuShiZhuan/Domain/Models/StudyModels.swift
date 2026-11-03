//  StudyModels.swift —— 题库 / 答题 / 闯关                         // 文件说明
//  字段与样板 public/data/questions.json 完全对齐                      // 数据契约
//  保证同一份 JSON 在 Web 与 iOS 两边解析结果一致                     // 数据契约

import Foundation  // 基础库

// MARK: - 科目                                                        // 分节：科目

struct Topic: Codable, Identifiable, Hashable {  // 知识板块
    let id: String  // 板块 id
    let name: String  // 板块名
    let desc: String  // 板块说明
    var direction: String?  // 所属方向（tax / finance / management），旧数据没有就按税务算

    var directionValue: StudyDirection {  // 方向枚举
        guard let direction, let value = StudyDirection(rawValue: direction) else { return .tax }  // 缺省税务
        return value  // 解析成功就用它
    }  // 属性结束
}  // Topic 结束

// MARK: - 题目                                                        // 分节：题目

enum QuestionType: String, Codable {  // 题型
    case single  // 单选
    case multi  // 多选
    case judge  // 判断

    var title: String {  // 题型名
        switch self {  // 按题型分支
        case .single: "单选"  // 单选
        case .multi: "多选"  // 多选
        case .judge: "判断"  // 判断
        }  // 分支结束
    }  // title 结束
}  // QuestionType 结束

struct Question: Codable, Identifiable, Hashable {  // 题目
    let id: String  // 题目 id
    let topic: String  // 所属板块 id
    let type: QuestionType  // 题型
    let stem: String  // 题干
    let options: [String]  // 选项
    let answer: [Int]  // 正确选项下标
    let explain: String  // 解析
    let source: String  // 来源标注：真题回忆写院校年份，知识点题写「考纲重构」

    func isCorrect(_ picked: Set<Int>) -> Bool {  // 判定对错
        picked == Set(answer)  // 集合相等才算对
    }  // 方法结束

    var answerText: String {  // 正确答案文本
        answer.sorted().map { idx in  // 遍历正确下标
            guard options.indices.contains(idx) else { return "?" }  // 越界给问号
            return "\(Self.letter(idx)). \(options[idx])"  // 字母加点内容
        }.joined(separator: "、")  // 用顿号连接
    }  // 属性结束

    static func letter(_ index: Int) -> String {  // 下标转字母
        guard let scalar = UnicodeScalar(65 + index) else { return "?" }  // A=65 起
        return String(Character(scalar))  // 转成字符串
    }  // 方法结束
}  // Question 结束

struct QuestionBank: Codable {  // 题库文件结构
    struct Meta: Codable {  // 元信息
        let title: String  // 题库标题
        let version: String  // 版本号
        let note: String  // 备注
    }  // Meta 结束
    let meta: Meta  // 元信息
    let topics: [Topic]  // 板块列表
    let questions: [Question]  // 题目列表
}  // QuestionBank 结束

// MARK: - 答题记录                                                     // 分节：记录

struct Attempt: Codable, Identifiable, Equatable {  // 一条答题记录
    let id: UUID  // 唯一 id
    let questionID: String  // 题目 id
    let topic: String  // 板块 id
    let picked: [Int]  // 用户选的选项
    let isCorrect: Bool  // 是否答对
    let inLevel: Bool  // 是否闯关模式
    let at: Date  // 作答时间

    init(  // 构造器
        id: UUID = UUID(),  // 默认新 id
        questionID: String,  // 题目 id
        topic: String,  // 板块
        picked: [Int],  // 选项
        isCorrect: Bool,  // 对错
        inLevel: Bool,  // 是否闯关
        at: Date = .now  // 默认现在
    ) {  // 构造体开始
        self.id = id  // 赋值 id
        self.questionID = questionID  // 赋值题目 id
        self.topic = topic  // 赋值板块
        self.picked = picked  // 赋值选项
        self.isCorrect = isCorrect  // 赋值对错
        self.inLevel = inLevel  // 赋值模式
        self.at = at  // 赋值时间
    }  // 构造结束
}  // Attempt 结束

struct WrongItem: Codable, Identifiable, Equatable {  // 错题条目
    var id: String { questionID }  // 用题目 id 当主键
    let questionID: String  // 题目 id
    let topic: String  // 板块
    var wrongCount: Int  // 累计错次
    var lastWrongAt: Date  // 最近答错时间
    var resolved: Bool  // 是否已掌握
}  // WrongItem 结束

// MARK: - 闯关                                                        // 分节：闯关

struct Chapter: Identifiable, Hashable {  // 章节
    let id: String  // 章节 id
    let name: String  // 章节名
    let desc: String  // 章节说明

    func levelID(_ index: Int) -> String { "\(id)-\(index)" }  // 章节 id 拼关卡号

    static func chapterID(from levelID: String) -> String {  // 从关卡反解章节
        guard let range = levelID.range(of: #"-\d+$"#, options: .regularExpression) else {  // 找尾部数字
            return levelID  // 没数字就当章节 id
        }  // 分支结束
        return String(levelID[..<range.lowerBound])  // 砍掉尾部数字
    }  // 方法结束

    static func index(from levelID: String) -> Int {  // 从关卡取序号
        guard let range = levelID.range(of: #"-\d+$"#, options: .regularExpression) else {  // 找尾部数字
            return 0  // 找不到给 0
        }  // 分支结束
        return Int(levelID[range].dropFirst()) ?? 0  // 去掉横线转数字
    }  // 方法结束
}  // Chapter 结束

struct LevelResult: Codable, Identifiable, Equatable {  // 单关成绩
    let id: String  // 关卡 id
    let correct: Int  // 答对数
    let total: Int  // 总题数
    var stars: Int  // 1-3 星，0 为未过
    let clearedAt: Date  // 通关时间

    static func judgeStars(correct: Int, total: Int) -> Int {  // 星级判定
        guard total > 0 else { return 0 }  // 没题给 0 星
        let wrong = total - correct  // 错题数
        if wrong == 0 { return 3 }  // 全对 3 星
        if wrong == 1 { return 2 }  // 错 1 题 2 星
        if wrong == 2 { return 1 }  // 错 2 题 1 星
        return 0  // 再差 0 星
    }  // 方法结束
}  // LevelResult 结束

// MARK: - 成长值                                                       // 分节：成长值

enum GrowthReason: String, Codable {  // 成长值来源
    case answerCorrect  // 答对一题
    case levelClear  // 通关
    case interviewDone  // 完成面试
    case checkIn  // 每日打卡

    var delta: Int {  // 每项加多少
        switch self {  // 按来源分支
        case .answerCorrect: 2  // 答对加 2
        case .levelClear: 10  // 通关加 10
        case .interviewDone: 30  // 面试加 30
        case .checkIn: 5  // 打卡加 5
        }  // 分支结束
    }  // delta 结束

    var title: String {  // 来源名
        switch self {  // 按来源分支
        case .answerCorrect: "答对题目"  // 答对
        case .levelClear: "闯关通过"  // 通关
        case .interviewDone: "完成模拟面试"  // 面试
        case .checkIn: "每日打卡"  // 打卡
        }  // 分支结束
    }  // title 结束
}  // GrowthReason 结束

struct GrowthEntry: Codable, Identifiable, Equatable {  // 一条成长值流水
    let id: UUID  // 唯一 id
    let reason: GrowthReason  // 来源
    let amount: Int  // 数量
    let note: String  // 备注
    let at: Date  // 时间

    init(  // 构造器
        id: UUID = UUID(),  // 默认新 id
        reason: GrowthReason,  // 来源
        amount: Int? = nil,  // 数量可空
        note: String,  // 备注
        at: Date = .now  // 默认现在
    ) {  // 构造体开始
        self.id = id  // 赋值 id
        self.reason = reason  // 赋值来源
        self.amount = amount ?? reason.delta  // 没传就用默认值
        self.note = note  // 赋值备注
        self.at = at  // 赋值时间
    }  // 构造结束
}  // GrowthEntry 结束
