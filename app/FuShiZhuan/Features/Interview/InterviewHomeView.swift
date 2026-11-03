//  InterviewHomeView.swift —— 面试首屏（严格对齐样板 page-interview）  // 文件说明
//  样板就四块：banner → 模考入口 → 选择面试间 → 面试记录
//  面试类型与导师风格不再单独设置，改成「选房间即定风格」（样板 ROOMS 就是这逻辑）
//  ⚠️ 与原实现的一处取舍：原来的「今日剩余场次」卡被去掉，样板没有这块；
//     剩余场次改成写在 banner 下方的一行小字里，不丢信息也不多一块模块。

import SwiftUI  // 界面框架

struct InterviewHomeView: View {  // 面试首屏
    @Environment(AppState.self) private var app  // 全局状态

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                banner  // 顶部深蓝横幅
                mockExamLink  // 模考入口（样板 mock-entry）
                roomSection  // 选择面试间
                historySection  // 面试记录
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 会压住开始按钮
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("模拟面试")  // 标题
    }  // body 结束

    // MARK: - 横幅                                                      // 分节：banner

    private var banner: some View {  // 复试仿真面试横幅（样板 .banner）
        HStack(spacing: 14) {  // 横向排列
            VStack(alignment: .leading, spacing: 3) {  // 文字区
                Text("复试仿真面试")  // 标题（样板原话）
                    .font(.system(size: 15, weight: .semibold))  // 15 号
                    .foregroundStyle(.white)  // 白字
                Text("视频背景 + 语音对话，练语言表达与临场反应")  // 说明（样板原话）
                    .font(.system(size: 11.5))  // 11.5 号
                    .foregroundStyle(.white.opacity(0.72))  // 半透明白
                    .lineSpacing(2)  // 行距
                Text(quotaLine)  // 场次小字
                    .font(.system(size: 10))  // 10 号
                    .foregroundStyle(.white.opacity(0.6))  // 更淡
                    .padding(.top, 2)  // 上间距
            }  // 竖排结束

            Spacer(minLength: 0)  // 撑开

            Image(systemName: "video.fill")  // 摄像机图标
                .font(.system(size: 19))  // 图标大小
                .foregroundStyle(.white)  // 白图标
                .frame(width: 46, height: 46)  // 46 方块（样板 .bn-icon）
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                    .fill(Color.white.opacity(0.14)))  // 白 14%
        }  // 横排结束
        .padding(16)  // 内边距 16（样板同）
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)  // 圆角 18
            .fill(LinearGradient(colors: [Color(hex: 0x161D3A), Color(hex: 0x2B3F8F)],  // 深蓝渐变
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))  // 140 度
    }  // banner 结束

    private var quotaLine: String {  // 场次小字
        let left = app.entitlement.remaining(.interviewDaily) ?? 99  // 今日剩余
        return left > 0 ? "今日还可练 \(left) 场 · 免费版每日 1 场"  // 有额度
                        : "今日场次已用完 · 明天再来"  // 用完了
    }  // quotaLine 结束

    // MARK: - 模考入口                                                  // 分节：模考

    private var mockExamLink: some View {  // 模考入口（对标样板 page-interview 里的 mock-entry）
        NavigationLink {  // 进入模考板块
            MockExamView()  // 通用卷 + 48 所院校分卷
        } label: {  // 行外观
            HStack(spacing: 11) {  // 图标 + 文字 + 箭头（照样板 .mock-entry）
                Image(systemName: "doc.text")  // 试卷图标
                    .font(.system(size: 15, weight: .regular))  // 图标大小
                    .foregroundStyle(Color.appBrand)  // 品牌蓝
                    .frame(width: 30, height: 30)  // 30 方块
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)  // 圆角 10
                        .fill(Color(hex: 0xE0E7FF)))  // 浅蓝底

                VStack(alignment: .leading, spacing: 1) {  // 文字区
                    Text("模考大厅 · 分院校卷")  // 标题（样板原话是「同题同场」，本工程没有同场活动）
                        .font(.system(size: 12.5, weight: .semibold))  // 12.5 号
                        .foregroundStyle(Color(hex: 0x1F2A52))  // 深蓝
                    Text("\(app.currentTrack.name) · 通用卷随时开考，院校卷按侧重抽题")  // 说明（真实口径）
                        .font(.system(size: 10))  // 10 号
                        .foregroundStyle(Color(hex: 0x6B76A8))  // 灰蓝
                        .lineLimit(1)  // 只留一行
                }  // 文字区结束

                Spacer(minLength: 0)  // 撑开

                Image(systemName: "chevron.right")  // 箭头
                    .font(.system(size: 12, weight: .semibold))  // 图标
                    .foregroundStyle(Color(hex: 0x8F9AD0))  // 浅蓝灰
            }  // 排列结束
            .padding(.horizontal, 13)  // 左右
            .padding(.vertical, 12)  // 上下
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)  // 圆角 15
                .fill(LinearGradient(colors: [Color(hex: 0xEEF2FF), Color(hex: 0xF7F8FF)],  // 浅蓝渐变
                                     startPoint: .leading, endPoint: .trailing)))  // 左到右
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)  // 内描边
                .strokeBorder(Color(hex: 0xDFE5FF), lineWidth: 1))  // 淡蓝边
        }  // 链接结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // mockExamLink 结束

    // MARK: - 面试间                                                    // 分节：面试间

    private var roomSection: some View {  // 选择面试间（样板 group）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack {  // 区段标题行
                Text("选择面试间").font(AppFont.section)  // 标题（样板原话）
                Text("任选一间进入")  // 右侧说明（样板原话）
                    .font(.system(size: 10.5))  // 10.5 号
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                Spacer(minLength: 0)  // 撑开
            }  // 横排结束
            InterviewRoomList()  // 三张房卡
        }  // 排列结束
    }  // roomSection 结束

    // MARK: - 面试记录                                                  // 分节：记录

    private var historySection: some View {  // 面试记录（样板 group + ivHistory）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            Text("面试记录").font(AppFont.section)  // 标题（样板原话）

            if recent.isEmpty {  // 没有记录
                HStack {  // 空态行
                    Text("还没有面试记录")  // 样板原话
                        .font(.system(size: 13))  // 13 号
                        .foregroundStyle(Color(hex: 0x8E8E93))  // 样板灰
                    Spacer(minLength: 0)  // 撑开
                }  // 横排结束
                .padding(.horizontal, 13)  // 左右
                .padding(.vertical, 14)  // 上下
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                    .fill(Color.appCard))  // 白底
            } else {  // 有记录
                VStack(spacing: 0) {  // 一张白卡里排行
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, session in  // 逐场
                        historyRow(session, isLast: index == recent.count - 1)  // 一行
                    }  // 循环结束
                }  // 竖排结束
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                    .fill(Color.appCard))  // 白底
            }  // 分支结束
        }  // 排列结束
    }  // historySection 结束

    private var recent: [InterviewSession] {  // 最近三场
        Array(app.data.sessions.sorted { $0.startedAt > $1.startedAt }.prefix(3))  // 按时间倒序取三
    }  // recent 结束

    private func historyRow(_ session: InterviewSession, isLast: Bool) -> some View {  // 一条记录
        let score = session.scores.isEmpty ? nil  // 没评分就不显示
            : Int(Double(session.scores.map(\.score).reduce(0, +)) / Double(session.scores.count))  // 各维平均分
        return VStack(spacing: 0) {  // 竖排（行 + 分割线）
            HStack {  // 横排
                VStack(alignment: .leading, spacing: 2) {  // 左侧
                    Text(session.mode.title + " · " + session.style.title)  // 类型与风格
                        .font(.system(size: 12.5, weight: .medium))  // 12.5 号
                        .foregroundStyle(Color.textPrimary)  // 主色
                    Text(dateText(session.startedAt))  // 日期
                        .font(.system(size: 10))  // 10 号
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 竖排结束
                Spacer(minLength: 0)  // 撑开
                if let score {  // 有分
                    Text("\(score) 分")  // 分数
                        .font(.system(size: 13, weight: .semibold))  // 13 号
                        .foregroundStyle(Color.appBrand)  // 品牌蓝
                } else {  // 没分（中途退出）
                    Text("未评分")  // 说明
                        .font(.system(size: 11))  // 11 号
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 分支结束
            }  // 横排结束
            .padding(.horizontal, 13)  // 左右
            .padding(.vertical, 11)  // 上下

            if !isLast {  // 不是最后一行
                Divider().padding(.leading, 13)  // 左侧缩进的分割线
            }  // 分支结束
        }  // 竖排结束
    }  // historyRow 结束

    private func dateText(_ date: Date) -> String {  // 日期转文本
        let f = DateFormatter()  // 格式化器
        f.locale = Locale(identifier: "zh_CN")  // 中文区
        f.dateFormat = "M 月 d 日 HH:mm"  // 月日时分
        return f.string(from: date)  // 输出
    }  // dateText 结束
}  // InterviewHomeView 结束
