//  InterviewReviewView.swift —— 单场面试复盘                          // 文件说明
//  只读一场已结束的面试记录，不重新评分、不改数据                       // 职责约束
//  分数栏与面试房间结果页同一口径，避免两套算法                          // 一致性约束

import SwiftUI                                                       // 界面框架

struct InterviewReviewView: View {                                   // 复盘详情
    let session: InterviewSession                                    // 要复盘的那一场

    @Environment(AppState.self) private var app                      // 全局状态，取题库与错题

    var body: some View {                                            // 视图主体
        ScrollView {                                                 // 可滚动
            VStack(spacing: Space.l) {                               // 纵向排列
                summaryCard                                          // 本场概要
                if session.state == .abandoned {                     // 中途结束
                    abandonedCard                                    // 只说明没评分
                } else {                                             // 正常结束
                    ForEach(session.scores) { item in                // 逐维展示
                        dimensionCard(item)                          // 单维卡
                    }                                                // 遍历结束
                    if !session.improvements.isEmpty {               // 有建议才显示
                        improvementCard                              // 建议卡
                    }                                                // 分支结束
                    if !session.uncertainty.isEmpty {                // 有低置信项
                        uncertaintyCard                              // 说明卡
                    }                                                // 分支结束
                }                                                    // 分支结束
                nextStepCard                                         // 下一步练什么
            }                                                        // 排列结束
            .padding(Metrics.pagePadding)                            // 内边距
            .padding(.bottom, Space.xxl)                             // 底部留白
        }                                                            // 滚动结束
        .background(Color.appBG)                                     // 底色
        .navigationTitle("复盘")                                      // 标题
        .navigationBarTitleDisplayMode(.inline)                      // 小标题
    }                                                                // body 结束

    // MARK: - 概要                                                      // 分节：概要

    private var summaryCard: some View {                             // 概要卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                HStack {                                             // 顶部行
                    Text(session.mode.title).font(AppFont.section)    // 面试类型
                    Spacer()                                         // 撑开
                    Text(session.startedAt.formatted(date: .numeric, time: .shortened)) // 日期时间
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textSecondary)        // 次要色
                }                                                    // 排列结束
                Text(headlineText)                                   // 一句话结论
                    .font(AppFont.body)                              // 正文字号
                    .fixedSize(horizontal: false, vertical: true)    // 允许换行
                if session.isOffline {                               // 用过离线兜底
                    Chip(text: "离线粗评", tint: .appWarn)              // 明确标出来
                }                                                    // 分支结束
                if let overall = session.overallScore {              // 有综合分
                    HStack(alignment: .firstTextBaseline, spacing: Space.xxs) { // 横向排列
                        Text("\(overall)").font(AppFont.hero).foregroundStyle(Color.appBrand) // 分数
                        Text("/ 100").font(AppFont.caption).foregroundStyle(Color.textSecondary) // 满分
                    }                                                    // 排列结束
                }                                                    // 分支结束
                Text("用时 \(session.elapsedSeconds / 60) 分钟 · 共 \(session.turns.filter { !$0.answer.isEmpty }.count) 轮作答") // 过程指标
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textTertiary)             // 弱化色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // summaryCard 结束

    private var headlineText: String {                               // 结论兜底文案
        session.headline.isEmpty ? "本场没有生成总结" : session.headline // 空则给中性说明
    }                                                                // 属性结束

    private var abandonedCard: some View {                           // 未完成说明卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                Text("本场未完成").font(AppFont.section)               // 标题
                Text("中途结束的场次不生成评分，也不计入薄弱点统计。")       // 说明
                    .font(AppFont.caption)                            // 小字
                    .foregroundStyle(Color.textSecondary)             // 次要色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // abandonedCard 结束

    // MARK: - 单维                                                      // 分节：单维

    private func dimensionCard(_ item: DimensionScore) -> some View { // 单维卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                HStack {                                             // 标题行
                    Text(item.dimension.title).font(AppFont.bodyStrong) // 维度名
                    Spacer()                                         // 撑开
                    Text(item.isJudged ? "\(item.score)" : "依据不足")  // 分数或提示
                        .font(AppFont.captionStrong)                 // 小字加粗
                        .foregroundStyle(item.isJudged ? Color.appBrand : Color.textTertiary) // 上色
                }                                                    // 排列结束
                if item.isJudged {                                   // 能判才画条
                    Meter(value: Double(item.score) / 100, tint: .appBrand) // 分数条
                    Text("「\(item.evidence)」")                       // 证据原文
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textSecondary)        // 次要色
                        .fixedSize(horizontal: false, vertical: true) // 允许换行
                    if !item.comment.isEmpty {                       // 有点评
                        Text(item.comment)                           // 点评
                            .font(AppFont.caption)                   // 小字
                            .foregroundStyle(Color.textSecondary)    // 次要色
                            .fixedSize(horizontal: false, vertical: true) // 允许换行
                    }                                                // 分支结束
                } else {                                             // 不能判
                    Text("模型没有从回答里找到依据，这一维不计分。")        // 说明
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textTertiary)         // 弱化色
                }                                                    // 分支结束
                Text(ScoreDimension.scaleNote)                       // 量表声明
                    .font(.system(size: 10))                         // 极小字
                    .foregroundStyle(Color.textTertiary)             // 弱化色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // dimensionCard 结束

    // MARK: - 建议                                                      // 分节：建议

    private var improvementCard: some View {                         // 建议卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                Text("改进建议").font(AppFont.section)                  // 标题
                ForEach(session.improvements) { item in              // 遍历建议
                    VStack(alignment: .leading, spacing: 2) {         // 单条
                        Text("· \(item.issue)")                        // 问题
                            .font(AppFont.bodyStrong)                // 加粗
                        Text("改写示例：\(item.rewrite)")              // 改写
                            .font(AppFont.caption)                    // 小字
                            .foregroundStyle(Color.textSecondary)     // 次要色
                            .fixedSize(horizontal: false, vertical: true) // 允许换行
                    }                                                // 单条结束
                }                                                    // 遍历结束
                Text("示例非唯一答案")                                     // 免责
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textTertiary)             // 弱化色
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // improvementCard 结束

    private var uncertaintyCard: some View {                         // 低置信说明卡
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {           // 纵向排列
                Text("需要你自己复核的地方").font(AppFont.section)      // 标题
                ForEach(Array(session.uncertainty.enumerated()), id: \.offset) { _, note in // 遍历说明
                    Text("· \(note)")                                 // 单条
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textSecondary)        // 次要色
                        .fixedSize(horizontal: false, vertical: true) // 允许换行
                }                                                    // 遍历结束
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // uncertaintyCard 结束

    // MARK: - 下一步                                                    // 分节：下一步

    /// 推荐项：一个章节 + 它的第 1 关
    private struct Recommendation: Identifiable {                     // 推荐结构
        let chapter: Chapter                                         // 章节
        let reason: String                                           // 为什么推它
        let questions: [Question]                                    // 第 1 关的题
        var id: String { chapter.id }                                // 用章节 id 当唯一键
        var levelID: String { chapter.levelID(1) }                   // 第 1 关的 id
    }                                                                // Recommendation 结束

    private var weakestDimension: DimensionScore? {                  // 本场最低的一维
        session.scores.filter(\.isJudged).min { $0.score < $1.score } // 只在有依据的维度里挑
    }                                                                // 属性结束

    private var recommendations: [Recommendation] {                  // 推荐章节
        guard let bank = app.bank else { return [] }                  // 题库没加载就不推
        var list: [Recommendation] = []                               // 结果容器
        let chapters = QuestionBankLoader.chapters(from: bank)         // 全部章节
        for item in app.weakTopics(minAttempts: 1).prefix(2) {        // 正确率最低的两个板块
            guard let chapter = chapters.first(where: { $0.id == item.topic.id }) else { continue } // 找到对应章节
            let questions = QuestionBankLoader.questions(inChapter: chapter.id, levelIndex: 1, bank: bank) // 第 1 关
            guard !questions.isEmpty else { continue }                // 没题就跳过
            let percent = Int((item.accuracy * 100).rounded())        // 正确率百分比
            list.append(Recommendation(chapter: chapter,              // 追加推荐
                                       reason: "正确率 \(percent)%（\(item.total) 题样本）", // 理由
                                       questions: questions))         // 题目
        }                                                             // 遍历结束
        if list.isEmpty, let first = chapters.first {                 // 没有答题记录
            let questions = QuestionBankLoader.questions(inChapter: first.id, levelIndex: 1, bank: bank) // 第 1 关
            if !questions.isEmpty {                                   // 有题才推
                list.append(Recommendation(chapter: first,             // 推第一章
                                           reason: "还没有答题记录，先从这一章开始", // 理由
                                           questions: questions))     // 题目
            }                                                         // 分支结束
        }                                                             // 分支结束
        return list                                                   // 返回
    }                                                                 // 属性结束

    private var nextStepCard: some View {                            // 下一步练什么
        Card {                                                       // 卡片
            VStack(alignment: .leading, spacing: Space.s) {           // 纵向排列
                Text("下一步练什么").font(AppFont.section)              // 标题
                if let weakest = weakestDimension {                   // 有低分维度
                    Text("本场最低的一维是「\(weakest.dimension.title)」：\(weakest.dimension.hint)") // 点名短板
                        .font(AppFont.caption)                        // 小字
                        .foregroundStyle(Color.textSecondary)         // 次要色
                        .fixedSize(horizontal: false, vertical: true) // 允许换行
                }                                                    // 分支结束
                if recommendations.isEmpty {                         // 没有可推的
                    Text("题库还没加载好，先去「刷题」页试试。")               // 说明
                        .font(AppFont.caption)                       // 小字
                        .foregroundStyle(Color.textTertiary)         // 弱化色
                } else {                                             // 有推荐
                    ForEach(recommendations) { item in               // 逐个推荐
                        NavigationLink {                             // 点进去直接开练
                            LevelPlayView(questions: item.questions, levelID: item.levelID) // 第 1 关
                        } label: {                                   // 行外观
                            recommendRow(item)                       // 单行
                        }                                            // 链接结束
                        .buttonStyle(.plain)                         // 不用默认高亮
                    }                                                // 遍历结束
                }                                                    // 分支结束
            }                                                        // 排列结束
        }                                                            // 卡片结束
    }                                                                // nextStepCard 结束

    private func recommendRow(_ item: Recommendation) -> some View {  // 推荐行
        HStack(spacing: Space.xs) {                                  // 横向排列
            VStack(alignment: .leading, spacing: 2) {                // 左侧文字
                Text(item.chapter.name).font(AppFont.bodyStrong)     // 章节名
                Text(item.reason)                                    // 推荐理由
                    .font(AppFont.caption)                           // 小字
                    .foregroundStyle(Color.textSecondary)            // 次要色
            }                                                        // 文字结束
            Spacer()                                                 // 撑开
            Text("练第 1 关")                                          // 动作
                .font(AppFont.captionStrong)                         // 小字加粗
                .foregroundStyle(Color.appBrand)                     // 品牌色
            Image(systemName: "chevron.right")                       // 箭头
                .font(.system(size: 11))                             // 小图标
                .foregroundStyle(Color.textTertiary)                 // 弱化色
        }                                                            // 排列结束
        .contentShape(Rectangle())                                   // 整行可点
    }                                                                // recommendRow 结束
}                                                                    // InterviewReviewView 结束
