//  CoachCard.swift —— 首页「AI 学伴」卡片                            // 文件说明
//  设计原则：默认先给一条**本地算出来的**建议（不联网、不花钱、一定有内容），
//  用户主动点「问问学伴」才调 AI。这样没网也不会空着，也不会一开 App 就烧额度。  // 成本约束

import SwiftUI  // 界面框架

struct CoachCard: View {  // 学伴卡片
    @Environment(AppState.self) private var app  // 全局状态
    @State private var reply: String?  // AI 回复
    @State private var actions: [CoachAction] = []  // AI 给的动作
    @State private var loading = false  // 是否请求中
    @State private var errorText: String?  // 失败提示
    private let service: CoachAsking = RemoteCoachService()  // 默认走真实服务

    var body: some View {  // 视图主体
        Card {  // 白卡
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack(spacing: Space.xs) {  // 标题行
                    ZStack {  // 圆形图标底
                        Circle().fill(Color.appViolet.opacity(0.12)).frame(width: 30, height: 30)  // 淡紫圆
                        Image(systemName: "sparkles")  // 星光图标
                            .font(.system(size: 13))  // 小图标
                            .foregroundStyle(Color.appViolet)  // 紫色
                    }  // 叠放结束
                    Text("AI 学伴").font(AppFont.bodyStrong)  // 标题
                    Spacer()  // 撑开
                    if loading {  // 请求中
                        ProgressView().scaleEffect(0.7)  // 小转圈
                    } else {  // 空闲
                        Button(reply == nil ? "问问" : "换一个") {  // 触发按钮
                            ask()  // 调服务
                        }  // 按钮结束
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appViolet)  // 紫色
                        .buttonStyle(.plain)  // 不用默认高亮
                    }  // 分支结束
                }  // 排列结束

                Text(reply ?? localHint)  // 有 AI 回复就显示，否则显示本地建议
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    .lineSpacing(3)  // 行距松一点

                if let errorText {  // 请求失败
                    Text(errorText)  // 具体动作，不是「出错了」
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.appWarn)  // 橙色
                }  // 分支结束

                if !actions.isEmpty {  // AI 给了动作
                    VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
                        ForEach(actions) { action in  // 逐条
                            HStack(spacing: Space.xxs) {  // 横向排列
                                Image(systemName: "arrow.right.circle.fill")  // 箭头图标
                                    .font(.system(size: 11))  // 小图标
                                    .foregroundStyle(Color.appViolet)  // 紫色
                                Text(verbatim: "\(action.title)：\(action.detail)")  // 动作与做法
                                    .font(AppFont.caption)  // 小字
                                    .foregroundStyle(Color.textSecondary)  // 次要色
                                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                            }  // 排列结束
                        }  // 遍历结束
                    }  // 排列结束
                    .padding(Space.xs)  // 内边距
                    .background(Color.appViolet.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 淡紫底
                }  // 分支结束

                if reply != nil {  // 已经用过 AI
                    Text("以上由 AI 生成，仅供参考；数据以 App 内记录为准。")  // 免责说明
                        .font(.system(size: 11))  // 更小的字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // body 结束

    // MARK: - 本地建议（不联网）                                          // 分节：本地建议

    private var localHint: String {  // 本地规则算出来的建议
        if let weak = app.weakTopics().first {  // 有薄弱点先补薄弱点
            return "「\(weak.topic.name)」正确率 \(Int((weak.accuracy * 100).rounded()))%（\(weak.total) 题），先补这块最划算。"  // 引用真实数字
        }  // 分支结束
        if app.todayAnswered > 0, let acc = app.todayAccuracy {  // 今天练过了
            return "今天答了 \(app.todayAnswered) 题，正确率 \(Int((acc * 100).rounded()))%。可以去做一次模拟面试了。"  // 引用真实数字
        }  // 分支结束
        if let first = app.bank?.topics.first {  // 完全没练过
            return "还没开始练。建议从「\(first.name)」入手，先把基础分稳住。"  // 推荐第一章
        }  // 分支结束
        return "题库还在加载，稍等一下就能给建议。"  // 兜底
    }  // localHint 结束

    // MARK: - 调服务                                                      // 分节：请求

    private var contextText: String {  // 发给服务端的学习状态摘要
        var parts: [String] = []  // 片段容器
        parts.append("今日答题 \(app.todayAnswered) 题")  // 今日答题数
        if let acc = app.todayAccuracy {  // 有正确率
            parts.append("正确率 \(Int((acc * 100).rounded()))%")  // 正确率
        }  // 分支结束
        parts.append("待攻错题 \(app.unresolvedWrongs.count) 道")  // 错题数
        parts.append("连续登录 \(app.data.streakDays) 天")  // 连签
        parts.append("备考阶段：\(app.profile.stage.title)")  // 阶段
        parts.append("距考试 \(app.profile.daysLeft) 天")  // 倒计时
        return parts.joined(separator: "；")  // 拼成一句
    }  // contextText 结束

    private func ask() {  // 触发一次 AI 建议
        loading = true  // 进入加载态
        errorText = nil  // 清空旧错误
        let context = contextText  // 固定当前状态
        Task {  // 起异步任务
            do {  // 尝试请求
                let result = try await service.ask(question: "今天该练什么？", context: context)  // 发问
                reply = result.reply  // 显示回复
                actions = result.actions  // 显示动作
            } catch let err as AppError {  // 业务错误
                errorText = err.action  // 用统一错误里的「下一步怎么做」
            } catch {  // 其它错误
                errorText = "稍后再试一次"  // 兜底文案
            }  // 分支结束
            loading = false  // 退出加载态
        }  // 任务结束
    }  // ask 结束
}  // CoachCard 结束
