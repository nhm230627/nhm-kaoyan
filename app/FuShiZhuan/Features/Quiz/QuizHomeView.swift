//  QuizHomeView.swift —— 刷题首页                                    // 文件说明
//  按章节列出关卡与星级，关卡由题库实时生成（9 题/章，每关 3 题）        // 数据说明
//  不伪装：题库没加载完显示加载态，题不够就明说                        // 诚实约束

import SwiftUI  // 界面框架

struct QuizHomeView: View {  // 刷题首页
    @Environment(AppState.self) private var app  // 全局状态

    private var chapters: [Chapter] {  // 章节列表
        guard let bank = app.bank else { return [] }  // 题库没来给空
        return QuestionBankLoader.chapters(from: bank)  // 由题库生成章节
    }  // 属性结束

    var body: some View {  // 视图主体
        Group {  // 分组切换状态
            if app.bank == nil {  // 题库未加载
                if let error = app.loadError {  // 有错误
                    ErrorState(error: error) { app.loadBank() }  // 显示错误可重试
                } else {  // 加载中
                    LoadingState(text: "题库加载中…")  // 转圈
                }  // 分支结束
            } else if chapters.isEmpty {  // 没章节
                EmptyState(  // 空态
                    icon: "tray",  // 图标
                    title: "还没有题库",  // 标题
                    message: "当前备考方向还没有接入题目。换个方向或者稍后再来。",  // 说明
                    actionTitle: "重新加载",  // 按钮
                    action: { app.loadBank() }  // 重试
                )  // 空态结束
            } else {  // 正常
                content  // 主内容
            }  // 分支结束
        }  // 分组结束
        .background(Color.appBG)  // 底色
        .navigationTitle("刷题闯关")  // 标题
    }  // body 结束

    private var content: some View {  // 主内容
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                summary  // 顶部统计
                wrongBookEntry  // 错题本入口
                ForEach(chapters) { chapter in  // 遍历章节
                    chapterCard(chapter)  // 章节卡
                }  // 遍历结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
    }  // content 结束

    private var summary: some View {  // 顶部统计卡
        Card {  // 卡片
            HStack(spacing: 0) {  // 三个指标
                StatTile(value: "\(totalStars)", title: "累计星数", tint: .appWarn)  // 星数
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(clearedLevels)", title: "已通关", tint: .appBrand)  // 通关数
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.unresolvedWrongs.count)", title: "待攻错题", tint: .appErr)  // 错题数
            }  // 排列结束
        }  // 卡片结束
    }  // summary 结束

    private var wrongBookEntry: some View {  // 错题本入口
        NavigationLink {  // 进错题本
            WrongBookView()  // 错题本页面
        } label: {  // 行外观
            Card {  // 卡片
                HStack(spacing: Space.m) {  // 横向排列
                    Image(systemName: "bandage.fill")  // 创可贴图标
                        .font(.system(size: 18))  // 图标大小
                        .foregroundStyle(Color.appErr)  // 红色
                        .frame(width: 28)  // 固定宽度
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text("错题本").font(AppFont.bodyStrong)  // 标题
                        Text("答错自动收进来，按板块归类").font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                    }  // 文字区结束
                    Spacer()  // 撑开
                    Text("\(app.unresolvedWrongs.count)")  // 待攻数量
                        .font(AppFont.section)  // 区段字号
                        .foregroundStyle(Color.appErr)  // 红色
                    Image(systemName: "chevron.right")  // 箭头
                        .font(.system(size: 11, weight: .semibold))  // 小箭头
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
                .contentShape(Rectangle())  // 整行可点
            }  // 卡片结束
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
        .accessibilityLabel("错题本，待攻 \(app.unresolvedWrongs.count) 题")  // 无障碍标签
    }  // wrongBookEntry 结束

    private var totalStars: Int {  // 累计星数
        app.data.levelResults.reduce(0) { $0 + $1.stars }  // 累加
    }  // 属性结束

    private var clearedLevels: Int {  // 已通关数
        app.data.levelResults.filter { $0.stars > 0 }.count  // 有星即通关
    }  // 属性结束

    private func chapterCard(_ chapter: Chapter) -> some View {  // 单个章节卡
        let pool = app.bank?.questions.filter { $0.topic == chapter.id } ?? []  // 本章题
        let levelCount = max(1, Int(ceil(Double(pool.count) / 3.0)))  // 每关 3 题算关数
        let stars = app.stars(inChapter: chapter.id)  // 本章星数

        return Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                HStack {  // 标题行
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text(chapter.name).font(AppFont.section)  // 章节名
                        Text(chapter.desc).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                    }  // 文字区结束
                    Spacer()  // 撑开
                    Chip(text: "\(stars)★", tint: .appWarn)  // 星数标签
                }  // 排列结束

                HStack(spacing: Space.s) {  // 关卡格
                    ForEach(1...levelCount, id: \.self) { i in  // 遍历关卡
                        levelCell(chapter: chapter, index: i, pool: pool)  // 单个格子
                    }  // 遍历结束
                    if levelCount < 3 {  // 题不够
                        Text("本模块题库不足，暂只开放 \(levelCount) 关")  // 明说
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textTertiary)  // 弱化色
                    }  // 分支结束
                    Spacer(minLength: 0)  // 撑开
                }  // 排列结束
            }  // 排列结束
        }  // 卡片结束
    }  // chapterCard 结束

    private func levelCell(chapter: Chapter, index: Int, pool: [Question]) -> some View {  // 关卡格
        let levelID = chapter.levelID(index)  // 关卡 id
        let stars = app.levelResult(for: levelID)?.stars  // 已有星级
        let questions = app.bank.map {  // 题库存在才取题
            QuestionBankLoader.questions(inChapter: chapter.id, levelIndex: index, bank: $0)  // 本关题
        } ?? []  // 没有就空数组

        return NavigationLink {  // 点击进入闯关
            LevelPlayView(questions: questions, levelID: levelID)  // 闯关页
        } label: {  // 格子外观
            VStack(spacing: 2) {  // 纵向排列
                Text("\(index)")  // 关卡序号
                    .font(AppFont.bodyStrong)  // 加粗
                    .foregroundStyle(Color.appBrand)  // 一律品牌色：灰字会让人以为点不动
                HStack(spacing: 1) {  // 三颗小星
                    ForEach(0..<3, id: \.self) { s in  // 遍历三颗
                        Image(systemName: s < (stars ?? 0) ? "star.fill" : "star")  // 实心或空心
                            .font(.system(size: 7))  // 星号很小
                            .foregroundStyle(s < (stars ?? 0) ? Color.appWarn : Color.separator)  // 亮或灰
                    }  // 遍历结束
                }  // 排列结束
            }  // 排列结束
            .frame(width: 56, height: 56)  // 固定方块
            .background(  // 背景
                (stars == nil ? Color.appBrand.opacity(0.06) : Color.appBrand.opacity(0.14)),  // 未过关淡底，过关稍深
                in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 圆角
            )  // 背景结束
            .overlay(  // 描边
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 同圆角
                    .stroke(Color.appBrand.opacity(stars == nil ? 0.30 : 0), lineWidth: 1)  // 未过关才有边框
            )  // 描边结束
        }  // 外观结束
        .buttonStyle(.plain)  // 去掉默认样式
        .disabled(questions.isEmpty)  // 没题不能点
        .accessibilityLabel("第 \(index) 关，\(stars.map { "\($0) 星" } ?? "未通关")")  // 无障碍描述
    }  // levelCell 结束
}  // QuizHomeView 结束
