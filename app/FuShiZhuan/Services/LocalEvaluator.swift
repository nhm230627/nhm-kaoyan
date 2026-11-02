//  LocalEvaluator.swift —— 离线粗评（无网/无 Key 时的兜底）            // 文件说明
//  只用确定性规则算分：字数、句子数、结构词、专业词、英文词数              // 实现约束
//  绝不假装是模型评分，所有结论都带「离线粗评」标签                      // 诚实原则

import Foundation                                                    // 基础库

enum LocalEvaluator {                                                // 离线评分器
    /// 不确定性说明的统一前缀，用来在 UI 上识别「这一场是离线算的」
    static let tag = InterviewNotes.offlineTag                        // 引用 Domain 里的统一标记

    /// 结构性连接词：出现越多，说明回答越有层次
    private static let structureWords = ["首先", "其次", "再次", "然后", "最后", "第一", "第二", "第三", // 顺序词
                                         "一方面", "另一方面", "总之", "综上", "因此", "所以", "因为", "但是"] // 转折因果

    /// 税务专业词：命中越多，说明越像专业表达
    private static let taxWords = ["税负", "税率", "税基", "纳税人", "征税", "征管", "抵扣", "进项", "销项", // 基础概念
                                   "增值税", "所得税", "消费税", "发票", "筹划", "避税", "偷税", "优惠", // 税种与实务
                                   "公平", "效率", "中性", "法定", "备案", "申报", "稽查", "评估"] // 原则与流程

    // MARK: - 单题评分                                                  // 分节：单题

    /// 按确定性规则给一次回答打分。返回结构与 BFF 完全一致，调用方无需分支
    static func evaluate(_ request: EvaluateRequest) -> EvaluateResponse { // 评分入口
        let answer = request.answer.trimmingCharacters(in: .whitespacesAndNewlines) // 去空白
        let compact = answer.replacingOccurrences(of: " ", with: "")  // 去掉空格再数字数
        let chars = compact.count                                    // 中文字数
        let sentences = splitSentences(answer)                       // 句子列表
        let isForeign = request.speaker == MentorRole.foreign.rawValue // 是否外语环节
        let englishWords = countEnglishWords(answer)                 // 英文词数
        let structureHits = countHits(answer, in: structureWords)    // 结构词命中数
        let taxHits = countHits(answer, in: taxWords)                // 专业词命中数
        let evidence = evidenceText(from: sentences, answer: answer)  // 真实原文片段
        let cap = chars < 20 ? 50 : 92                                // 太短的回答不许拿高分

        var evaluation: [String: DimensionPayload] = [:]             // 五维结果
        evaluation[ScoreDimension.completeness.rawValue] = DimensionPayload( // 完整性看长度
            score: clamp(35 + chars / 2, 35, cap),                     // 每 2 字加 1 分，封顶 cap
            evidence: evidence,                                       // 引用原文
            comment: "离线规则：回答约 \(chars) 字，\(chars >= 120 ? "篇幅足够" : "偏短，建议展开到 120 字以上")。" // 说明
        )                                                            // 完整性结束
        evaluation[ScoreDimension.logic.rawValue] = DimensionPayload( // 逻辑看结构词
            score: clamp(40 + structureHits * 10 + (sentences.count >= 3 ? 5 : 0), 40, cap), // 结构词加分，封顶 cap
            evidence: evidence,                                       // 引用原文
            comment: "离线规则：命中 \(structureHits) 个结构词、\(sentences.count) 句。\(structureHits >= 2 ? "层次清楚" : "建议用「首先 / 其次 / 最后」把层次说出来")。" // 说明
        )                                                            // 逻辑结束
        if isForeign {                                               // 外语环节看英文
            evaluation[ScoreDimension.professionalExpression.rawValue] = DimensionPayload( // 专业表达
                score: clamp(40 + englishWords / 2, 40, cap),          // 每 2 个英文词加 1 分，封顶 cap
                evidence: evidence,                                   // 引用原文
                comment: "离线规则：识别到 \(englishWords) 个英文词。\(englishWords >= 60 ? "篇幅达标" : "英文篇幅偏短")。" // 说明
            )                                                        // 外语维度结束
        } else {                                                     // 中文环节看专业词
            evaluation[ScoreDimension.professionalExpression.rawValue] = DimensionPayload( // 专业表达
                score: clamp(40 + taxHits * 9, 40, cap),               // 每个专业词 9 分，封顶 cap
                evidence: evidence,                                   // 引用原文
                comment: "离线规则：命中 \(taxHits) 个税务术语。\(taxHits >= 3 ? "术语使用到位" : "建议至少点出 3 个专业术语")。" // 说明
            )                                                        // 中文维度结束
        }                                                            // 分支结束
        evaluation[ScoreDimension.languageOrganization.rawValue] = DimensionPayload( // 语言组织看句子数
            score: clamp(42 + min(sentences.count, 5) * 7, 42, min(cap, 90)),   // 句子越多越连贯（上限 5 句，且不超过 cap）
            evidence: evidence,                                       // 引用原文
            comment: "离线规则：共 \(sentences.count) 句，平均每句 \(max(chars / max(sentences.count, 1), 1)) 字。" // 说明
        )                                                            // 语言组织结束
        evaluation[ScoreDimension.manner.rawValue] = DimensionPayload( // 综合素养
            score: 0,                                                 // 离线无法判断
            evidence: "",                                             // 空证据 = 依据不足
            comment: ""                                               // 不编造点评
        )                                                            // 素养结束

        return EvaluateResponse(                                     // 组装响应
            requestId: "local-\(UUID().uuidString)",                  // 本地标识
            evaluation: evaluation,                                   // 五维
            improvements: improvements(answer: answer, taxHits: taxHits, structureHits: structureHits, chars: chars), // 建议
            confidence: "low",                                        // 永远低置信
            uncertainty: "\(tag)：模型未参与，只按字数、句子数、结构词与专业词估算，不代表真实水平。联网后建议重考一次。" // 明确声明
        )                                                            // 组装结束
    }                                                                // evaluate 结束

    // MARK: - 整场总结                                                  // 分节：总结

    /// 离线总结：只用最后一题的五维分与已答轮数，明确说明没做全局均分
    static func summarize(turns: [SummaryRequest.SummaryTurn],         // 全部轮次
                          scores: [DimensionScore]) -> SummaryResponse { // 最后一题的五维
        let answered = turns.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } // 真答过的轮
        let judged = scores.filter { $0.isJudged }                    // 有依据的维度
        let average = judged.isEmpty ? 0 : judged.reduce(0) { $0 + $1.score } / judged.count // 简单均分
        let weakest = judged.min { $0.score < $1.score }              // 最弱一项

        var headline = "\(tag)：共作答 \(answered.count) 轮"                // 结论开头
        if judged.isEmpty {                                           // 没有可判维度
            headline += "，没有可判分的回答。"                              // 如实说明
        } else {                                                      // 有分
            headline += "，最近一题五维均分约 \(average) 分"                 // 均分
            if let weakest = weakest {                                // 有短板
                headline += "，\(weakest.dimension.title)是最主要短板。"     // 点名短板
            }                                                         // 分支结束
        }                                                             // 分支结束

        var actions: [TopActionPayload] = []                          // 可执行动作
        if let weakest = weakest {                                    // 按短板给动作
            actions.append(                                           // 第一条
                TopActionPayload(                                     // 构造动作
                    action: "下一场专门练「\(weakest.dimension.title)」：\(weakest.dimension.hint)", // 做什么
                    why: "这是本场得分最低的一维，提升它对总分拉动最大。",        // 为什么
                    howToCheck: "再答一次同类问题，看这一维是否不再显示「依据不足」。" // 怎么自检
                )                                                     // 构造结束
            )                                                         // 追加结束
        }                                                             // 分支结束
        actions.append(                                               // 第二条固定动作
            TopActionPayload(                                         // 构造动作
                action: "每答一题先用一句话给结论，再展开两到三个理由。",          // 做什么
                why: "结构清楚是面试里最容易被记住的优点。",                  // 为什么
                howToCheck: "录音回放，能否听出「结论—理由—例子」三段。"         // 怎么自检
            )                                                         // 构造结束
        )                                                             // 追加结束

        return SummaryResponse(                                       // 组装响应
            requestId: "local-\(UUID().uuidString)",                  // 本地标识
            headline: headline,                                       // 结论
            perQuestion: nil,                                         // 离线不做逐题复盘
            topActions: actions,                                      // 动作
            confidence: "low",                                        // 低置信
            uncertainty: ["\(tag)：没有做全局均分，只用最近一题的评分推导，联网后请重看一次总结。"], // 声明
            disclaimer: ScoreDimension.scaleNote                      // 量表声明
        )                                                            // 组装结束
    }                                                                // summarize 结束

    // MARK: - 工具                                                      // 分节：工具

    /// 夹在区间里
    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { // 限幅
        min(max(value, low), high)                                    // 先保底再封顶
    }                                                                // clamp 结束

    /// 切句：按中英文句读符号
    private static func splitSentences(_ text: String) -> [String] {   // 切句
        let parts = text.components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n")) // 按句读拆
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } // 去空
    }                                                                // splitSentences 结束

    /// 统计英文单词个数
    private static func countEnglishWords(_ text: String) -> Int {     // 英文词数
        let tokens = text.components(separatedBy: CharacterSet.letters.inverted) // 按非字母拆
        return tokens.filter { !$0.isEmpty }.count                     // 非空即一个词
    }                                                                // countEnglishWords 结束

    /// 统计关键词命中数（每个词最多算一次，避免重复堆分）
    private static func countHits(_ text: String, in words: [String]) -> Int { // 命中数
        words.reduce(0) { sum, word in sum + (text.contains(word) ? 1 : 0) } // 出现过就加一
    }                                                                // countHits 结束

    /// 取一段真实原文作为证据，保证「证据必须出自回答」这条规则在本地同样成立
    private static func evidenceText(from sentences: [String], answer: String) -> String { // 取证据
        if let first = sentences.first, first.count <= 30 {            // 首句够短就直接用
            return first                                               // 用首句
        }                                                             // 分支结束
        let compact = answer.replacingOccurrences(of: " ", with: "")   // 去空格
        guard compact.count > 6 else { return compact }                // 太短就整句返回
        return String(compact.prefix(20))                              // 否则截前 20 字
    }                                                                // evidenceText 结束

    /// 按最弱的两项给建议，最多两条
    private static func improvements(answer: String,                   // 原回答
                                     taxHits: Int,                     // 专业词命中
                                     structureHits: Int,               // 结构词命中
                                     chars: Int) -> [ImprovementPayload] { // 建议列表
        var list: [ImprovementPayload] = []                           // 结果容器
        let example = String(answer.replacingOccurrences(of: " ", with: "").prefix(16)) // 考生原话片段
        if chars < 120 {                                              // 太短
            list.append(ImprovementPayload(                           // 加一条
                issue: "回答偏短，信息量不够。",                            // 问题
                example: example,                                     // 原话
                rewrite: "结论一句 + 两个理由各一句 + 一个税务例子，凑到 150 字左右。" // 改写
            ))                                                        // 追加结束
        }                                                             // 分支结束
        if structureHits < 2 {                                        // 没层次
            list.append(ImprovementPayload(                           // 加一条
                issue: "缺少层次词，听起来像想到哪说到哪。",                   // 问题
                example: example,                                     // 原话
                rewrite: "先说「这个问题要分两层看」，再用「首先……其次……」展开。" // 改写
            ))                                                        // 追加结束
        }                                                             // 分支结束
        if taxHits < 3 {                                              // 术语少
            list.append(ImprovementPayload(                           // 加一条
                issue: "专业术语密度不够，显得不像本专业考生。",                // 问题
                example: example,                                     // 原话
                rewrite: "至少点到三个术语，例如「税基、税率、征管成本」。"        // 改写
            ))                                                        // 追加结束
        }                                                             // 分支结束
        return Array(list.prefix(2))                                  // 只留两条
    }                                                                // improvements 结束
}                                                                    // LocalEvaluator 结束
