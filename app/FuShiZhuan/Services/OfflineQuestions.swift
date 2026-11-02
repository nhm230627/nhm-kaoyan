//  OfflineQuestions.swift —— 离线题库                                 // 文件说明
//  断网时也要能开考：按环节给固定问题，不联网、不烧额度                      // 用途
//  Mock 与真实引擎的兜底都从这里取，避免两份题目不一致                     // 一致性约束

import Foundation                                                  // 基础库

enum OfflineQuestions {                                            // 离线题库
    /// 按环节与轮次取题。index 用来在同一环节里轮换，避免连续两问完全一样
    static func question(phase: String, index: Int) -> (question: String, points: [String]) { // 取题
        let list = questions(for: phase)                            // 该环节的题
        let picked = list[abs(index) % max(list.count, 1)]           // 轮换取一条
        return (picked, points(for: phase))                          // 连知识点一起返回
    }                                                               // 方法结束

    /// 每个环节的候选题
    private static func questions(for phase: String) -> [String] {   // 题目表
        switch phase {                                              // 按环节分支
        case "opening": return ["先简单做个自我介绍，重点说为什么考这个专业。", // 开场一
                                 "用一分钟介绍你自己，说清本科背景和报考动机。"] // 开场二
        case "foreign": return ["Please introduce your undergraduate major in English.", // 外语一
                                 "Please describe one tax course you have learned in English."] // 外语二
        case "major": return ["增值税的进项税额在什么情况下不得抵扣？",          // 专业一
                              "税收的公平原则和效率原则在实践中会不会冲突？",      // 专业二
                              "企业所得税税前扣除的凭证要求有哪些？",            // 专业三
                              "税收征管法对滞纳金是怎么规定的？"]                // 专业四
        case "comprehensive": return ["如果这次没录取，你下一步怎么安排？",      // 综合一
                                       "读研期间你打算怎么补足科研能力的短板？"]   // 综合二
        default: return ["最后你还有什么想问我们的？"]                        // 收尾
        }                                                            // 分支结束
    }                                                                // 方法结束

    /// 每个环节对应的知识点提示
    private static func points(for phase: String) -> [String] {       // 知识点表
        switch phase {                                               // 按环节分支
        case "opening": return ["报考动机", "本科背景", "表达条理"]      // 开场
        case "foreign": return ["英文表达", "专业词汇"]                 // 外语
        case "major": return ["进项税额", "抵扣条件", "政策依据"]        // 专业
        case "comprehensive": return ["抗压能力", "规划清晰度"]          // 综合
        default: return ["提问质量"]                                   // 收尾
        }                                                            // 分支结束
    }                                                                // 方法结束
}                                                                    // OfflineQuestions 结束
