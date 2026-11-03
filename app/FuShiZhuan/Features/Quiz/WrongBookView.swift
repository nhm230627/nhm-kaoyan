//  WrongBookView.swift —— 错题本                                      // 文件说明
//  数据早就有了（WrongItem + AppState.wrongs），这里只做查看与消除        // 数据来源
//  免费版只给看 5 条解析，规则在 Entitlement 里，页面不自己判断            // 权益约束

import SwiftUI  // 界面框架

struct WrongBookView: View {  // 错题本
    @Environment(AppState.self) private var app  // 全局状态
    @State private var showResolved = false  // 是否看「已掌握」
    @State private var expanded: Set<String> = []  // 当前展开了解析的题目 id
    @State private var showPaywall = false  // 额度用完时弹付费墙

    private var items: [WrongItem] {  // 当前分段下的错题
        let all = app.data.wrongs  // 全部错题
        return showResolved  // 按分段过滤
            ? all.filter(\.resolved).sorted { $0.lastWrongAt > $1.lastWrongAt }  // 已掌握按时间倒序
            : all.filter { !$0.resolved }.sorted { $0.lastWrongAt > $1.lastWrongAt }  // 待攻按时间倒序
    }  // 属性结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                summary  // 顶部统计
                filterBar  // 分段切换
                if app.bank == nil {  // 题库没加载
                    LoadingState(text: "题库加载中…")  // 转圈
                        .frame(height: 200)  // 限高
                } else if items.isEmpty {  // 空了
                    emptyState  // 空态
                } else {  // 有错题
                    ForEach(items) { item in  // 逐条渲染
                        wrongCard(item)  // 单条卡片
                    }  // 遍历结束
                }  // 分支结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("错题本")  // 标题
        .sheet(isPresented: $showPaywall) {  // 额度用完弹付费墙
            NavigationStack { PaywallView() }  // 包一层导航
        }  // 弹窗结束
    }  // body 结束

    private var summary: some View {  // 顶部统计
        Card {  // 卡片
            HStack(spacing: 0) {  // 三个指标
                StatTile(value: "\(app.unresolvedWrongs.count)", title: "待攻错题", tint: .appErr)  // 待攻
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.data.wrongs.filter(\.resolved).count)", title: "已掌握", tint: .appOK)  // 已掌握
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: explainQuotaText, title: "剩余解析", tint: .appBrand)  // 今日还能看几条
            }  // 排列结束
        }  // 卡片结束
    }  // summary 结束

    private var explainQuotaText: String {  // 剩余解析额度文本
        guard let left = app.entitlement.remaining(.wrongBookAll) else { return "不限" }  // 会员不限
        return "\(left) 条"  // 免费显示剩余条数
    }  // 属性结束

    private var filterBar: some View {  // 分段切换
        Picker("分类", selection: $showResolved) {  // 两个分段
            Text("待攻 \(app.unresolvedWrongs.count)").tag(false)  // 待攻
            Text("已掌握 \(app.data.wrongs.filter(\.resolved).count)").tag(true)  // 已掌握
        }  // 选择器结束
        .pickerStyle(.segmented)  // 分段样式
    }  // filterBar 结束

    private var emptyState: some View {  // 空态
        EmptyState(  // 空态组件
            icon: showResolved ? "checkmark.seal" : "checklist",  // 图标
            title: showResolved ? "还没有掌握记录" : "错题本是空的",  // 标题
            message: showResolved  // 说明
                ? "把待攻错题重新做对一次，它就会出现在这里。"  // 未掌握时的提示
                : "去闯关或刷题，答错的题会自动收进来，按板块归类。"  // 文案分支
        )  // 空态结束
        .frame(height: 300)  // 限高
    }  // emptyState 结束

    private func wrongCard(_ item: WrongItem) -> some View {  // 单条错题卡
        let question = app.bank?.questions.first { $0.id == item.questionID }  // 找题目原文
        let topicName = app.bank?.topics.first { $0.id == item.topic }?.name ?? item.topic  // 板块中文名
        let isOpen = expanded.contains(item.questionID)  // 是否已展开

        return Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack {  // 顶部标签行
                    Chip(text: topicName, tint: .appBrand)  // 板块
                    Chip(text: "错 \(item.wrongCount) 次", tint: .appErr)  // 错次
                    Spacer()  // 撑开
                    Text(item.lastWrongAt.formatted(date: .numeric, time: .omitted))  // 最近答错日期
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束

                Text(question?.stem ?? "题目原文缺失（题库未加载或题号不存在）")  // 题干
                    .font(AppFont.body)  // 正文
                    .foregroundStyle(question == nil ? Color.textTertiary : Color.textPrimary)  // 缺题灰字
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行

                if isOpen, let question {  // 展开且有题目
                    VStack(alignment: .leading, spacing: Space.xxs) {  // 解析区
                        Text("正确答案：\(question.answerText)")  // 正确选项
                            .font(AppFont.captionStrong)  // 加粗小字
                            .foregroundStyle(Color.appOK)  // 绿色
                        Text(question.explain)  // 解析正文
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                            .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    }  // 解析区结束
                    .padding(Space.s)  // 内边距
                    .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
                    .background(Color.appBG, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 淡底
                }  // 分支结束

                HStack(spacing: Space.s) {  // 底部按钮行
                    Button {  // 展开或收起解析
                        toggleExplain(item.questionID)  // 处理额度
                    } label: {  // 按钮外观
                        HStack(spacing: Space.xxs) {  // 图标加文字
                            Image(systemName: isOpen ? "chevron.up" : "lightbulb")  // 展开换箭头
                                .font(.system(size: 11))  // 小图标
                            Text(isOpen ? "收起解析" : "看解析")  // 文案
                                .font(AppFont.captionStrong)  // 小字加粗
                        }  // 排列结束
                        .foregroundStyle(Color.appBrand)  // 品牌色
                    }  // 外观结束
                    .buttonStyle(.plain)  // 不用默认高亮

                    Spacer()  // 撑开

                    if !item.resolved {  // 待攻的可以标记掌握
                        Button {  // 标记已掌握
                            app.resolveWrong(questionID: item.questionID)  // 唯一写入口
                        } label: {  // 按钮外观
                            Text("已掌握")  // 文案
                                .font(AppFont.captionStrong)  // 小字加粗
                                .foregroundStyle(Color.appOK)  // 绿色
                        }  // 外观结束
                        .buttonStyle(.plain)  // 不用默认高亮
                    } else {  // 已掌握的可以放回待攻
                        Button {  // 放回待攻
                            app.reopenWrong(questionID: item.questionID)  // 唯一写入口，不伪造答题记录
                        } label: {  // 按钮外观
                            Text("放回待攻")  // 文案
                                .font(AppFont.captionStrong)  // 小字加粗
                                .foregroundStyle(Color.appWarn)  // 橙色
                        }  // 外观结束
                        .buttonStyle(.plain)  // 不用默认高亮
                    }  // 分支结束
                }  // 排列结束
            }  // 排列结束
        }  // 卡片结束
    }  // wrongCard 结束

    private func toggleExplain(_ questionID: String) {  // 展开/收起解析，并扣额度
        if expanded.contains(questionID) {  // 已展开就收起
            expanded.remove(questionID)  // 不退还额度，符合「看过就算用过」
            return  // 结束
        }  // 分支结束
        guard app.consume(.wrongBookAll) else {  // 额度不足
            showPaywall = true  // 弹付费墙
            return  // 结束
        }  // 分支结束
        expanded.insert(questionID)  // 展开
    }  // toggleExplain 结束
}  // WrongBookView 结束
