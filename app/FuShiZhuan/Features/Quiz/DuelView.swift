//  DuelView.swift —— 1V1 知识竞赛                                     // 文件说明
//  协议与样板 duel.js 完全一致：join → poll → progress → state，
//  题目不出服务器：双方拿同一个 seed，各自用本地题库出同样的题。        // 设计说明
//  9 秒配不到真人自动上 AI 陪练，界面明写「AI 陪练」，绝不冒充真人。      // 诚实原则
//  结算照样板：胜 +20、平 +8、负 +5 成长值，亲密度 +2，错题回流错题本。   // 结算口径

import SwiftUI  // 界面框架
import Foundation  // 时间与随机

// MARK: - 接口数据                                                    // 分节：接口

private struct DuelFoeInfo: Decodable {  // 对手静态信息
    let nick: String  // 昵称
    let school: String?  // 院校，可能是空串
}  // DuelFoeInfo 结束

private struct DuelJoinResp: Decodable {  // join 的返回
    let status: String  // waiting / matched / offline
    let pid: String?  // 我的配对标识
    let duelId: String?  // 对局 id
    let seed: Int?  // 出题种子
    let count: Int?  // 题量
    let foe: DuelFoeInfo?  // 先到的那个人
}  // DuelJoinResp 结束

private struct DuelPollResp: Decodable {  // poll 的返回
    let status: String  // waiting / matched / timeout / expired
    let pid: String?  // 我的配对标识
    let duelId: String?  // 对局 id
    let seed: Int?  // 出题种子
    let count: Int?  // 题量
    let foe: DuelFoeInfo?  // 对手
}  // DuelPollResp 结束

private struct DuelProgress: Decodable {  // 对手实时进度
    let answered: Int  // 已答数
    let correct: Int  // 答对数
    let done: Bool  // 是否交卷
    let ms: Int  // 用时毫秒
}  // DuelProgress 结束

private struct DuelStateResp: Decodable {  // progress / state 的返回
    let foe: DuelProgress?  // 对手进度，取消匹配时为空
}  // DuelStateResp 结束

// MARK: - 接口封装                                                    // 分节：网络

private enum DuelAPI {  // 配对接口封装
    private static var root: String {  // 服务根地址
        AppConfig.bffBaseURL.absoluteString  // 与 AI 接口同一个 BFF
    }  // root 结束

    private static func make(_ path: String, method: String) -> URLRequest? {  // 构造请求
        guard let url = URL(string: root + "/api/duel/" + path) else { return nil }  // 拼地址
        var req = URLRequest(url: url)  // 建请求
        req.httpMethod = method  // 方法
        req.timeoutInterval = 8  // 配对接口快，8 秒足够
        req.setValue(AppConfig.deviceID, forHTTPHeaderField: "X-Device-Id")  // 设备标识
        req.setValue(AppConfig.serviceToken, forHTTPHeaderField: "X-Service-Token")  // 客户端令牌
        return req  // 返回
    }  // make 结束

    static func get(_ path: String) async throws -> Data {  // GET
        guard let req = make(path, method: "GET") else { throw DuelError.badURL }  // 地址不合法
        let (data, _) = try await URLSession.shared.data(for: req)  // 发请求
        return data  // 返回原文
    }  // get 结束

    static func post(_ path: String, _ body: [String: Any]) async throws -> Data {  // POST
        guard var req = make(path, method: "POST") else { throw DuelError.badURL }  // 地址不合法
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")  // 声明 JSON
        req.httpBody = try JSONSerialization.data(withJSONObject: body)  // 序列化请求体
        let (data, _) = try await URLSession.shared.data(for: req)  // 发请求
        return data  // 返回原文
    }  // post 结束

    static func online() async -> Int {  // 在线人数
        do {  // 拿不到就当 0，不影响主流程
            let data = try await get("online")  // 请求
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]  // 解析
            return (obj?["online"] as? Int) ?? 0  // 取 online 字段
        } catch {  // 失败
            return 0  // 显示 0 人
        }  // 分支结束
    }  // online 结束

    static func join(nick: String, count: Int, track: String) async throws -> DuelJoinResp {  // 报名
        let data = try await post("join", [  // 请求体
            "nick": nick,  // 昵称
            "school": "",  // 院校留空，App 没有院校体系
            "count": count,  // 题量
            "track": track,  // 考试方向：不同方向题不同，不能配
        ])  // 请求结束
        return try JSONDecoder().decode(DuelJoinResp.self, from: data)  // 解析
    }  // join 结束

    static func poll(pid: String) async throws -> DuelPollResp {  // 轮询是否配上
        let data = try await get("poll?pid=\(pid)")  // 请求
        return try JSONDecoder().decode(DuelPollResp.self, from: data)  // 解析
    }  // poll 结束

    static func cancel(pid: String) async {  // 取消匹配
        _ = try? await post("progress", ["duelId": "__cancel__", "pid": pid])  // 服务端约定值
    }  // cancel 结束

    static func progress(duelId: String, pid: String, answered: Int, correct: Int,  // 上报进度
                         done: Bool, ms: Int) async -> DuelProgress? {  // 参数
        do {  // 上报失败不影响答题
            let data = try await post("progress", [  // 请求体
                "duelId": duelId,  // 对局
                "pid": pid,  // 我
                "answered": answered,  // 已答
                "correct": correct,  // 答对
                "done": done,  // 交卷
                "ms": ms,  // 用时
            ])  // 请求结束
            return try JSONDecoder().decode(DuelStateResp.self, from: data).foe  // 顺带拿对手进度
        } catch {  // 失败
            return nil  // 交给下次轮询补
        }  // 分支结束
    }  // progress 结束

    static func state(duelId: String, pid: String) async -> DuelProgress? {  // 只读对手进度
        do {  // 失败就跳过这一轮
            let data = try await get("state?duelId=\(duelId)&pid=\(pid)")  // 请求
            return try JSONDecoder().decode(DuelStateResp.self, from: data).foe  // 解析
        } catch {  // 失败
            return nil  // 保持上一次的进度
        }  // 分支结束
    }  // state 结束
}  // DuelAPI 结束

private enum DuelError: Error {  // 配对错误
    case badURL  // 地址拼不出来
}  // DuelError 结束

// MARK: - 随机数                                                        // 分节：随机

/// 与样板 duel.js 的 rng() 同款：双方同 seed 必须出同一套题，算法一个字都不能变。
private struct DuelRng {  // 线性同余随机数
    private var s: UInt32  // 内部状态
    init(seed: UInt32) { s = seed }  // 用种子初始化
    mutating func next() -> Double {  // 下一个 0 到 1 的小数
        s = 1664525 &* s &+ 1013904223  // 与 Math.imul 加法的 32 位回绕一致
        return Double(s) / 4294967296.0  // 归一化
    }  // next 结束
}  // DuelRng 结束

// MARK: - 统计                                                          // 分节：统计

private struct DuelStat {  // 一方的战绩
    var answered = 0  // 已答
    var correct = 0  // 答对
    var done = false  // 是否交卷
    var ms = 0  // 用时毫秒
}  // DuelStat 结束

private struct DuelFoe {  // 对手
    var nick = "对手"  // 昵称
    var school = ""  // 院校
    var bot = false  // 是否 AI 陪练
}  // DuelFoe 结束

// MARK: - 主界面                                                        // 分节：界面

struct DuelView: View {  // 1V1 知识竞赛
    @Environment(AppState.self) private var app  // 读题库、写成长值
    @Environment(\.dismiss) private var dismiss  // 关闭

    private enum Stage { case lobby, searching, ready, play, result }  // 页面阶段

    @State private var stage: Stage = .lobby  // 当前阶段
    @State private var count = 5  // 题量，默认 5
    @State private var custom = 10  // 自定题量
    @State private var useCustom = false  // 是否用自定量
    @State private var online = 0  // 在线人数

    @State private var pid: String?  // 我的配对标识
    @State private var duelId: String?  // 对局 id
    @State private var seed = 0  // 出题种子
    @State private var foe = DuelFoe()  // 对手

    @State private var list: [Question] = []  // 本场题目
    @State private var index = 0  // 当前第几题
    @State private var picked: Set<Int> = []  // 已选选项
    @State private var locked = false  // 本题已提交
    @State private var mine = DuelStat()  // 我的战绩
    @State private var theirs = DuelStat()  // 对手战绩
    @State private var startedAt = Date()  // 开赛时间
    @State private var leftSeconds = 15.0  // 本题剩余秒
    @State private var waitText = "0.0s"  // 匹配已等秒数
    @State private var gained = 0  // 本局加的成长值

    @State private var ticker: Task<Void, Never>?  // 本题倒计时
    @State private var waiter: Task<Void, Never>?  // 匹配计时与轮询
    @State private var botTask: Task<Void, Never>?  // AI 陪练节奏
    @State private var pollTask: Task<Void, Never>?  // 对手进度轮询

    private let qSeconds = 15.0  // 每题秒数，照样板

    var body: some View {  // 视图主体
        VStack(spacing: 0) {  // 纵向铺满
            topBar  // 顶部标题栏
            Divider()  // 分隔线
            content  // 阶段内容
        }  // 排列结束
        .background(Color.appBG)  // 底色
        .task {  // 进页面即拉在线人数
            online = await DuelAPI.online()  // 拿真实在线数，拿不到显示 0
        }  // 任务结束
        .onDisappear {  // 离开要停掉所有后台任务
            stopAll()  // 停计时与轮询
        }  // 离开处理结束
    }  // body 结束

    // MARK: 顶部栏                                                     // 分节：顶部

    private var topBar: some View {  // 顶部标题栏
        HStack(spacing: Space.s) {  // 横排
            Button {  // 关闭
                stopAll()  // 先停任务
                dismiss()  // 再关页面
            } label: {  // 按钮外观
                Image(systemName: "xmark")  // 叉号
                    .font(.system(size: 14, weight: .semibold))  // 图标大小
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .frame(width: 30, height: 30)  // 点击区域
            }  // 按钮结束
            .buttonStyle(.plain)  // 去掉系统高亮
            .accessibilityLabel("关闭")  // 无障碍

            Text(stage == .searching ? "正在匹配" : "1V1 知识竞赛")  // 标题随阶段变
                .font(AppFont.bodyStrong)  // 正文加粗
            Spacer()  // 撑开
            HStack(spacing: 4) {  // 在线人数
                Circle().fill(Color.appOK).frame(width: 6, height: 6)  // 绿点
                Text(verbatim: "\(online) 人在线")  // 真实人数
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
            }  // 横排结束
        }  // 横排结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
        .padding(.vertical, Space.s)  // 上下内边距
    }  // topBar 结束

    @ViewBuilder  // 按阶段给内容
    private var content: some View {  // 阶段内容
        switch stage {  // 分支
        case .lobby:  // 大厅
            lobby  // 选题量与规则
        case .searching:  // 匹配中
            searching  // 雷达
        case .ready:  // 开赛前
            readyCard  // VS 与倒计时
        case .play:  // 答题
            playBoard  // 题目与选项
        case .result:  // 结算
            resultBoard  // 胜负与收益
        }  // 分支结束
    }  // content 结束

    // MARK: 大厅                                                       // 分节：大厅

    private var lobby: some View {  // 大厅
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                hero  // 项目说明
                countPicker  // 选题量
                rulesCard  // 规则
                PrimaryButton(title: "开始匹配", systemImage: "bolt.fill") {  // 开始
                    startMatch()  // 走匹配
                }  // 按钮结束
                if app.duelGames > 0 {  // 打过才有战绩
                    Text(verbatim: "已打 \(app.duelGames) 场 · 胜 \(app.duelWins) 场")  // 战绩
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 分支结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
        }  // 滚动结束
    }  // lobby 结束

    private var hero: some View {  // 大厅头图
        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
            Chip(text: "同题同场 · 真人对战", tint: .appBrand)  // 标签
            Text(verbatim: "\(app.currentTrack.name) · 抢答赛")  // 方向名
                .font(AppFont.section)  // 区段字号
            Text("两人同一套题、同时开始，答对多者胜；同分比总用时。匹配不到真人自动上 AI 陪练。")  // 说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
        .padding(Space.l)  // 内边距
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 卡片底
            .fill(Color.appCard))  // 白卡
    }  // hero 结束

    private var countPicker: some View {  // 选题量
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            Text("选择题量").font(AppFont.captionStrong).foregroundStyle(Color.textSecondary)  // 标题
            HStack(spacing: Space.s) {  // 横排
                ForEach([3, 5, 10], id: \.self) { n in  // 三档常用
                    countChip(label: "\(n)", sub: "题", on: !useCustom && count == n) {  // 一格
                        useCustom = false  // 关掉自定
                        count = n  // 选中档位
                    }  // 选择结束
                }  // 遍历结束
                countChip(label: "自定", sub: "\(custom) 题", on: useCustom) {  // 自定档
                    useCustom = true  // 打开自定
                }  // 选择结束
            }  // 横排结束
            if useCustom {  // 自定才给输入
                HStack(spacing: Space.s) {  // 横排
                    TextField("10", value: $custom, format: .number)  // 数字输入
                        .keyboardType(.numberPad)  // 数字键盘
                        .font(AppFont.body)  // 字号
                        .frame(width: 70)  // 宽度
                        .padding(.horizontal, Space.s)  // 左右内边距
                        .padding(.vertical, 6)  // 上下内边距
                        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 输入底
                            .fill(Color.appCard))  // 白底
                    Text("题（3 ~ 50）")  // 范围提示
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                    Spacer()  // 撑开
                }  // 横排结束
            }  // 分支结束
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
    }  // countPicker 结束

    private func countChip(label: String, sub: String, on: Bool, tap: @escaping () -> Void) -> some View {  // 一档题量
        Button(action: tap) {  // 点击
            VStack(spacing: 1) {  // 纵向
                Text(label)  // 主字
                    .font(.system(size: 15, weight: .bold, design: .rounded))  // 圆体
                    .foregroundStyle(on ? Color.white : Color.textPrimary)  // 选中白字
                Text(sub)  // 副字
                    .font(.system(size: 9.5))  // 极小
                    .foregroundStyle(on ? Color.white.opacity(0.9) : Color.textTertiary)  // 副色
            }  // 排列结束
            .frame(width: 62, height: 46)  // 尺寸
            .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 底
                .fill(on ? Color.appBrand : Color.appCard))  // 选中品牌色
        }  // 按钮结束
        .buttonStyle(.plain)  // 去高亮
        .accessibilityLabel("\(label) \(sub)")  // 无障碍
    }  // countChip 结束

    private var rulesCard: some View {  // 规则卡
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            ruleLine("每题 15 秒，超时算错")  // 时限
            ruleLine("答错不扣分，但会拖时间")  // 扣分
            ruleLine("对手进度实时可见")  // 对手
            ruleLine("错题自动进错题本")  // 回流
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
        .padding(Space.l)  // 内边距
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 卡片
            .fill(Color.appCard))  // 白卡
    }  // rulesCard 结束

    private func ruleLine(_ text: String) -> some View {  // 一行规则
        Text("· \(text)")  // 圆点开头
            .font(AppFont.caption)  // 小字
            .foregroundStyle(Color.textSecondary)  // 次要色
    }  // ruleLine 结束

    // MARK: 匹配中                                                     // 分节：匹配

    private var searching: some View {  // 匹配中
        VStack(spacing: Space.l) {  // 纵向排列
            Spacer()  // 撑开
            ZStack {  // 雷达
                ForEach(0..<3, id: \.self) { i in  // 三圈
                    Circle()  // 圈
                        .stroke(Color.appBrand.opacity(0.18), lineWidth: 1)  // 淡蓝线
                        .frame(width: 70 + CGFloat(i) * 46, height: 70 + CGFloat(i) * 46)  // 逐圈变大
                }  // 遍历结束
                ZStack {  // 中间的我
                    Circle().fill(Color.appBrand).frame(width: 54, height: 54)  // 实心圆
                    Text("你").font(AppFont.captionStrong).foregroundStyle(.white)  // 文字
                }  // 叠放结束
            }  // 叠放结束
            .accessibilityElement(children: .ignore)  // 合并朗读
            .accessibilityLabel("正在匹配对手")  // 无障碍
            Text("正在为你找同题量的对手…")  // 提示
                .font(AppFont.body)  // 正文
            Text(verbatim: "\(waitText) · 9 秒内没人就上 AI 陪练")  // 等待秒数
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
                .monospacedDigit()  // 等宽防跳
            Spacer()  // 撑开
            GhostButton(title: "取消匹配", systemImage: "xmark") {  // 取消
                cancelMatch()  // 清服务端排队
            }  // 按钮结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
        }  // 排列结束
        .padding(.bottom, Space.xxl)  // 底部留白
    }  // searching 结束

    // MARK: 开赛                                                       // 分节：开赛

    private var readyCard: some View {  // VS 卡
        VStack(spacing: Space.l) {  // 纵向排列
            Spacer()  // 撑开
            HStack(alignment: .top, spacing: Space.m) {  // 横排
                sideCard(name: "你", sub: app.currentTrack.name, me: true)  // 我
                Text("VS")  // 中间
                    .font(.system(size: 15, weight: .heavy, design: .rounded))  // 粗体
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .padding(.top, 16)  // 与头像对齐
                sideCard(name: foe.nick, sub: foe.bot ? "AI 陪练" : (foe.school.isEmpty ? "真人对手" : foe.school), me: false)  // 对手
            }  // 横排结束
            Text(verbatim: "\(list.count) 题 · 同题同场")  // 场次说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
            if foe.bot {  // 陪练要写明原因
                Text("岛上暂时没别的真人，先和 AI 练手")  // 说明
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.appWarn)  // 警示色
            }  // 分支结束
            Spacer()  // 撑开
        }  // 排列结束
        .padding(Metrics.pagePadding)  // 内边距
    }  // readyCard 结束

    private func sideCard(name: String, sub: String, me: Bool) -> some View {  // 一方
        VStack(spacing: Space.xs) {  // 纵向排列
            ZStack {  // 头像
                Circle()  // 圆
                    .fill(me ? Color.appBrand : Color.appViolet)  // 我蓝对手紫
                    .frame(width: 56, height: 56)  // 尺寸
                Text(String(name.prefix(1)))  // 首字
                    .font(.system(size: 20, weight: .bold))  // 大字
                    .foregroundStyle(.white)  // 白字
            }  // 叠放结束
            Text(name)  // 名字
                .font(AppFont.bodyStrong)  // 加粗
                .lineLimit(1)  // 单行
            Text(sub)  // 副标题
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
                .lineLimit(1)  // 单行
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 等宽
        .accessibilityElement(children: .combine)  // 合并朗读
    }  // sideCard 结束

    // MARK: 答题                                                       // 分节：答题

    private var playBoard: some View {  // 答题板
        VStack(spacing: 0) {  // 纵向
            progressHeader  // 比分与双进度条
            ScrollView {  // 题目滚动
                VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                    questionBlock  // 题干与选项
                    if locked {  // 已作答才给解析
                        explainBlock  // 解析
                    }  // 分支结束
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
            }  // 滚动结束
            if current?.type == .multi && !locked {  // 多选才要确认
                PrimaryButton(title: "确认选择", systemImage: "checkmark") {  // 确认
                    submit(picked, timeout: false)  // 提交
                }  // 按钮结束
                .disabled(picked.isEmpty)  // 没选不给交
                .padding(Metrics.pagePadding)  // 内边距
            }  // 分支结束
        }  // 排列结束
    }  // playBoard 结束

    private var current: Question? {  // 当前题
        list.indices.contains(index) ? list[index] : nil  // 越界给空
    }  // current 结束

    private var progressHeader: some View {  // 比分头
        VStack(spacing: Space.xs) {  // 纵向
            HStack {  // 比分行
                Text(verbatim: "第 \(index + 1) / \(list.count) 题")  // 题号
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(Color.textSecondary)  // 次要色
                Spacer()  // 撑开
                Text(verbatim: "你 \(mine.correct)")  // 我的分
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(Color.appBrand)  // 蓝
                Text(":").font(AppFont.caption).foregroundStyle(Color.textTertiary)  // 冒号
                Text(verbatim: "\(theirs.correct) 对手")  // 对手分
                    .font(AppFont.captionStrong)  // 小字加粗
                    .foregroundStyle(Color.appViolet)  // 紫
            }  // 横排结束
            HStack(spacing: Space.xs) {  // 双进度条
                bar(value: Double(mine.answered) / Double(max(list.count, 1)), tint: .appBrand)  // 我的
                bar(value: Double(theirs.answered) / Double(max(list.count, 1)), tint: .appViolet)  // 对手
            }  // 横排结束
            if locked {  // 已作答才显示对手状态
                Text(verbatim: theirs.done ? "对手已交卷" : "对手 \(theirs.answered) / \(list.count)")  // 对手进度
                    .font(.system(size: 10.5))  // 极小
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
            }  // 分支结束
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
        .padding(.vertical, Space.s)  // 上下内边距
        .background(Color.appCard)  // 白底
    }  // progressHeader 结束

    private func bar(value: Double, tint: Color) -> some View {  // 一条进度
        GeometryReader { geo in  // 取宽
            ZStack(alignment: .leading) {  // 左对齐叠放
                Capsule().fill(Color.separator)  // 底槽
                Capsule().fill(tint)  // 已答
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))  // 按比例
            }  // 叠放结束
        }  // 几何结束
        .frame(height: 5)  // 条高
        .accessibilityHidden(true)  // 纯装饰
    }  // bar 结束

    private var questionBlock: some View {  // 题干与选项
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向
            HStack(spacing: Space.xs) {  // 题型行
                Chip(text: app.topicName(current?.topic ?? ""), tint: .appBrand)  // 知识点
                Chip(text: current?.type.title ?? "单选", tint: .appViolet)  // 题型
                Spacer()  // 撑开
                Text(verbatim: String(format: "%.0fs", max(0, leftSeconds)))  // 剩余秒
                    .font(AppFont.captionStrong)  // 小字加粗
                    .monospacedDigit()  // 等宽
                    .foregroundStyle(leftSeconds <= 5 ? Color.appErr : Color.textSecondary)  // 最后 5 秒变红
            }  // 横排结束
            timerBar  // 时间条
            Text(current?.stem ?? "")  // 题干
                .font(AppFont.section)  // 区段字号
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
            VStack(spacing: Space.s) {  // 选项列表
                ForEach(Array((current?.options ?? []).enumerated()), id: \.offset) { i, text in  // 逐项
                    optionRow(index: i, text: text)  // 一项
                }  // 遍历结束
            }  // 排列结束
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
    }  // questionBlock 结束

    private var timerBar: some View {  // 剩余时间条
        GeometryReader { geo in  // 取宽
            ZStack(alignment: .leading) {  // 左对齐
                Capsule().fill(Color.separator)  // 底槽
                Capsule().fill(leftSeconds <= 5 ? Color.appErr : Color.appOK)  // 剩余
                    .frame(width: geo.size.width * CGFloat(min(max(leftSeconds / qSeconds, 0), 1)))  // 按比例
            }  // 叠放结束
        }  // 几何结束
        .frame(height: 4)  // 条高
        .accessibilityHidden(true)  // 纯装饰
    }  // timerBar 结束

    private func optionRow(index i: Int, text: String) -> some View {  // 一个选项
        let isAnswer = current?.answer.contains(i) ?? false  // 是否正确答案
        let isPicked = picked.contains(i)  // 我是否选了
        let border: Color = locked ? (isAnswer ? .appOK : (isPicked ? .appErr : .separator)) : (isPicked ? .appBrand : .separator)  // 结果色
        let fill: Color = locked ? (isAnswer ? Color.appOK.opacity(0.10) : (isPicked ? Color.appErr.opacity(0.10) : Color.appCard)) : (isPicked ? Color.appBrand.opacity(0.08) : Color.appCard)  // 底色
        let hint = locked ? (isAnswer ? "，正确答案" : (isPicked ? "，你选错了" : "")) : ""  // 朗读后缀
        return Button {  // 点击选
            guard !locked else { return }  // 已交就别动
            if current?.type == .multi {  // 多选切换
                if picked.contains(i) { picked.remove(i) } else { picked.insert(i) }  // 翻转
            } else {  // 单选与判断直接交
                picked = [i]  // 只有这一项
                submit(picked, timeout: false)  // 提交
            }  // 分支结束
        } label: {  // 外观
            HStack(alignment: .top, spacing: Space.s) {  // 横排
                Text(Question.letter(i))  // 字母
                    .font(.system(size: 12, weight: .bold))  // 小粗体
                    .foregroundStyle(isPicked || (locked && isAnswer) ? Color.white : Color.textSecondary)  // 字色
                    .frame(width: 22, height: 22)  // 圆底尺寸
                    .background(Circle().fill(isPicked || (locked && isAnswer) ? (isAnswer && locked ? Color.appOK : Color.appBrand) : Color.separator))  // 圆底
                Text(text)  // 选项文字
                    .font(AppFont.body)  // 正文
                    .foregroundStyle(Color.textPrimary)  // 主色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
            }  // 横排结束
            .padding(Space.s)  // 内边距
            .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(fill))  // 底
            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(border, lineWidth: 1))  // 边
        }  // 外观结束
        .buttonStyle(.plain)  // 去高亮
        .accessibilityLabel("选项 \(Question.letter(i)) \(text)\(hint)")  // 无障碍
    }  // optionRow 结束

    private var explainBlock: some View {  // 解析块
        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向
            Text(current?.answerText ?? "")  // 正确答案
                .font(AppFont.captionStrong)  // 小字加粗
                .foregroundStyle(Color.appOK)  // 绿色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
            Text(current?.explain ?? "")  // 解析
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
            Text(verbatim: "来源：\(current?.source ?? "")")  // 来源标注
                .font(.system(size: 10))  // 极小
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
        .padding(Space.m)  // 内边距
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 底
            .fill(Color.appCard))  // 白卡
    }  // explainBlock 结束

    // MARK: 结算                                                       // 分节：结算

    private var isWin: Bool { mine.correct > theirs.correct }  // 我赢
    private var isDraw: Bool { mine.correct == theirs.correct }  // 平局

    private var resultBoard: some View {  // 结算板
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向
                VStack(spacing: Space.xs) {  // 头
                    Text(isDraw ? "平" : (isWin ? "胜" : "负"))  // 大字
                        .font(.system(size: 46, weight: .heavy, design: .rounded))  // 巨字
                        .foregroundStyle(isDraw ? Color.appWarn : (isWin ? Color.appOK : Color.textTertiary))  // 颜色
                    Text(isDraw ? "势均力敌" : (isWin ? "你赢了" : "这次差一点"))  // 结论
                        .font(AppFont.section)  // 区段字号
                    Text(verbatim: foe.bot ? "\(foe.nick)（AI 陪练）" : "\(foe.nick) · 真人对手")  // 对手身份
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 排列结束

                HStack(alignment: .center, spacing: Space.l) {  // 比分
                    VStack(spacing: 2) {  // 我
                        Text(verbatim: "\(mine.correct)")  // 分
                            .font(.system(size: 30, weight: .bold, design: .rounded))  // 大字
                            .foregroundStyle(Color.appBrand)  // 蓝
                        Text("你答对").font(AppFont.caption).foregroundStyle(Color.textTertiary)  // 说明
                    }  // 排列结束
                    Text(":").font(AppFont.section).foregroundStyle(Color.textTertiary)  // 冒号
                    VStack(spacing: 2) {  // 对手
                        Text(verbatim: "\(theirs.correct)")  // 分
                            .font(.system(size: 30, weight: .bold, design: .rounded))  // 大字
                            .foregroundStyle(Color.appViolet)  // 紫
                        Text("对手答对").font(AppFont.caption).foregroundStyle(Color.textTertiary)  // 说明
                    }  // 排列结束
                }  // 横排结束
                .padding(.vertical, Space.s)  // 上下内边距

                HStack(spacing: Space.s) {  // 三格统计
                    statCell(value: "\(accuracy)%", title: "正确率")  // 正确率
                    statCell(value: String(format: "%.1fs", duration), title: "总用时")  // 用时
                    statCell(value: "+\(gained)", title: "成长值")  // 收益
                }  // 横排结束

                Text(tipText)  // 一句话建议
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐

                HStack(spacing: Space.s) {  // 两个按钮
                    GhostButton(title: "再来一局", systemImage: "arrow.clockwise") {  // 再来
                        resetToLobby()  // 回大厅
                    }  // 按钮结束
                    PrimaryButton(title: "完成", systemImage: "checkmark") {  // 收工
                        dismiss()  // 关页面
                    }  // 按钮结束
                }  // 横排结束
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
        }  // 滚动结束
    }  // resultBoard 结束

    private var accuracy: Int {  // 正确率
        mine.answered == 0 ? 0 : Int((Double(mine.correct) / Double(mine.answered) * 100).rounded())  // 四舍五入
    }  // accuracy 结束

    private var duration: Double {  // 总用时秒
        mine.ms == 0 ? 0 : Double(mine.ms) / 1000  // 毫秒换秒
    }  // duration 结束

    private var tipText: String {  // 结算建议
        if isDraw { return "同分时用时短的赢；你们用时接近，再来一局分胜负。" }  // 平局
        if isWin { return "答得又快又准，去下一局试试更难的题量。" }  // 赢
        return "错的那几题已经进错题本，练完再来。"  // 输
    }  // tipText 结束

    private func statCell(value: String, title: String) -> some View {  // 一格统计
        VStack(spacing: 2) {  // 纵向
            Text(verbatim: value)  // 数值
                .font(.system(size: 16, weight: .bold, design: .rounded))  // 圆体
                .foregroundStyle(Color.textPrimary)  // 主色
                .monospacedDigit()  // 等宽
            Text(title)  // 标题
                .font(.system(size: 10.5))  // 极小
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 等宽
        .padding(.vertical, Space.s)  // 上下内边距
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(Color.appCard))  // 白卡
    }  // statCell 结束

    // MARK: 匹配逻辑                                                   // 分节：匹配逻辑

    private var realCount: Int {  // 本场题量
        useCustom ? min(50, max(3, custom)) : count  // 夹到 3 到 50
    }  // realCount 结束

    private func myNick() -> String {  // 我的昵称
        "研友\(Int.random(in: 100...999))"  // App 没昵称体系，不冒充真实姓名
    }  // myNick 结束

    private func startMatch() {  // 开始匹配
        guard !(app.bank?.questions.isEmpty ?? true) else { return }  // 没题库就不进场
        stage = .searching  // 进匹配页
        let t0 = Date()  // 计时起点
        let nick = myNick()  // 生成昵称

        waiter = Task { @MainActor in  // 计时 + 请求
            while !Task.isCancelled && stage == .searching {  // 每 100ms 刷等待秒数
                waitText = String(format: "%.1fs", Date().timeIntervalSince(t0))  // 真实已等秒数
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }  // 循环结束
        }  // 计时任务结束

        Task { @MainActor in  // 发 join
            do {  // 正常路径
                let resp = try await DuelAPI.join(nick: nick, count: realCount, track: app.currentTrack.id)  // 报名
                pid = resp.pid  // 记下标识
                if resp.status == "matched", let id = resp.duelId, let s = resp.seed {  // 立刻配上
                    matched(duelId: id, seed: s, count: resp.count ?? realCount, info: resp.foe, bot: false)  // 进开赛
                    return  // 结束
                }  // 分支结束
                if resp.status == "waiting" {  // 排队中
                    pollLoop()  // 轮询
                    return  // 结束
                }  // 分支结束
                startBotMatch()  // 其它情况（服务端不可用）直接上陪练
            } catch {  // 服务端连不上
                if stage == .searching { startBotMatch() }  // 纯静态托管时也能玩
            }  // 分支结束
        }  // 任务结束
    }  // startMatch 结束

    private func pollLoop() {  // 轮询是否配上
        guard let myPid = pid else { startBotMatch(); return }  // 没标识就陪练
        pollTask = Task { @MainActor in  // 每 0.9 秒查一次
            var tries = 0  // 已查次数
            while !Task.isCancelled && stage == .searching && tries < 12 {  // 最多约 11 秒
                tries += 1  // 次数加一
                try? await Task.sleep(nanoseconds: 900_000_000)  // 0.9 秒
                if Task.isCancelled || stage != .searching { return }  // 已取消就退出
                guard let resp = try? await DuelAPI.poll(pid: myPid) else { continue }  // 网络抖动跳过
                if resp.status == "matched", let id = resp.duelId, let s = resp.seed {  // 配上了
                    matched(duelId: id, seed: s, count: resp.count ?? realCount, info: resp.foe, bot: false)  // 进开赛
                    return  // 结束
                }  // 分支结束
                if resp.status == "timeout" || resp.status == "expired" {  // 没等到人
                    startBotMatch()  // 上陪练
                    return  // 结束
                }  // 分支结束
            }  // 循环结束
            if stage == .searching { startBotMatch() }  // 兜底：一直没人也上陪练
        }  // 任务结束
    }  // pollLoop 结束

    private func startBotMatch() {  // 上 AI 陪练
        let names = ["上岸的橘子", "背税法的猫", "二战不上班", "图书馆钉子户", "凌晨四点的研友"]  // 照样板的陪练名
        foe = DuelFoe(nick: names.randomElement() ?? "AI 陪练", school: "", bot: true)  // 标记为陪练
        seed = Int.random(in: 1...999_999_999)  // 本地种子
        duelId = nil  // 不对接服务端
        pid = nil  // 清掉标识
        list = pickQuestions(realCount, seed)  // 出题
        stage = .ready  // 进开赛页
        runCountdown()  // 停一下看 VS 再开打
    }  // startBotMatch 结束

    private func matched(duelId id: String, seed s: Int, count n: Int, info: DuelFoeInfo?, bot: Bool) {  // 配上了
        duelId = id  // 记下对局
        seed = s  // 同一个种子
        foe = DuelFoe(nick: info?.nick ?? "对手", school: info?.school ?? "", bot: bot)  // 对手信息
        list = pickQuestions(n, s)  // 双方用同款算法出同样的题
        stage = .ready  // 进开赛页
        runCountdown()  // 停一下看 VS 再开打
    }  // matched 结束

    private func runCountdown() {  // 开赛倒计时
        Task { @MainActor in  // 3 秒后开打
            try? await Task.sleep(nanoseconds: 1_300_000_000)  // 停 1.3 秒看 VS
            guard stage == .ready else { return }  // 已被取消
            beginPlay()  // 开始答题
        }  // 任务结束
    }  // runCountdown 结束

    private func cancelMatch() {  // 取消匹配
        stopAll()  // 停本地任务
        if let myPid = pid {  // 通知服务端把自己摘掉
            Task { await DuelAPI.cancel(pid: myPid) }  // 别让别人配到已走的人
        }  // 分支结束
        resetToLobby()  // 回大厅
    }  // cancelMatch 结束

    private func resetToLobby() {  // 回大厅
        stopAll()  // 停所有任务
        stage = .lobby  // 大厅
        list = []  // 清题
        index = 0  // 归零
        picked = []  // 清选项
        locked = false  // 解锁
        mine = DuelStat()  // 清我的战绩
        theirs = DuelStat()  // 清对手战绩
        gained = 0  // 清收益
        pid = nil  // 清标识
        duelId = nil  // 清对局
        Task { online = await DuelAPI.online() }  // 刷新在线数
    }  // resetToLobby 结束

    // MARK: 答题逻辑                                                   // 分节：答题逻辑

    private func beginPlay() {  // 开始答题
        stage = .play  // 进答题
        index = 0  // 第一题
        picked = []  // 清选项
        locked = false  // 解锁
        startedAt = Date()  // 记录开赛时间
        startQuestion()  // 出第一题
        if foe.bot { startBot() } else { startFoePolling() }  // 陪练走本地节奏，真人走轮询
    }  // beginPlay 结束

    private func startQuestion() {  // 开始一题
        picked = []  // 清空选择
        locked = false  // 解锁
        leftSeconds = qSeconds  // 重置倒计时
        ticker?.cancel()  // 停上一题的计时
        ticker = Task { @MainActor in  // 新计时
            let t0 = Date()  // 起点
            while !Task.isCancelled && !locked {  // 未提交才继续
                let left = qSeconds - Date().timeIntervalSince(t0)  // 剩余
                leftSeconds = max(0, left)  // 不为负
                if left <= 0 {  // 超时
                    submit([], timeout: true)  // 算错
                    return  // 结束
                }  // 分支结束
                try? await Task.sleep(nanoseconds: 80_000_000)  // 80ms 刷新
            }  // 循环结束
        }  // 任务结束
    }  // startQuestion 结束

    private func submit(_ choice: Set<Int>, timeout: Bool) {  // 提交一题
        guard !locked, let q = current else { return }  // 防重复
        locked = true  // 锁住
        ticker?.cancel()  // 停计时
        let right = !timeout && q.isCorrect(choice)  // 判定
        mine.answered += 1  // 已答加一
        if right { mine.correct += 1 }  // 答对加一
        app.recordAnswer(question: q, picked: choice)  // 唯一写入口：错题本、答题记录、成长值都在这
        mine.ms = Int(Date().timeIntervalSince(startedAt) * 1000)  // 累计用时
        report(done: false)  // 上报进度

        Task { @MainActor in  // 720ms 后进下一题
            try? await Task.sleep(nanoseconds: 720_000_000)  // 让人看清对错
            if index + 1 >= list.count { finish() } else { index += 1; startQuestion() }  // 下一题或结算
        }  // 任务结束
    }  // submit 结束

    private func report(done: Bool) {  // 上报我的进度
        guard let id = duelId, let myPid = pid else { return }  // 陪练局不用报
        let answered = mine.answered  // 快照，避免跨线程读
        let correct = mine.correct  // 快照
        let ms = mine.ms  // 快照
        Task { @MainActor in  // 异步上报
            if let f = await DuelAPI.progress(duelId: id, pid: myPid, answered: answered,  // 发请求
                                              correct: correct, done: done, ms: ms) {  // 参数
                adopt(f)  // 顺带更新对手进度
            }  // 分支结束
        }  // 任务结束
    }  // report 结束

    private func adopt(_ f: DuelProgress) {  // 采纳对手进度
        theirs.answered = f.answered  // 已答
        theirs.correct = f.correct  // 答对
        theirs.done = f.done  // 交卷
        theirs.ms = f.ms  // 用时
    }  // adopt 结束

    private func startFoePolling() {  // 轮询真人对手进度
        guard let id = duelId, let myPid = pid else { return }  // 陪练局不轮询
        pollTask = Task { @MainActor in  // 每 1.2 秒
            while !Task.isCancelled && stage == .play {  // 打的时候才轮
                try? await Task.sleep(nanoseconds: 1_200_000_000)  // 1.2 秒
                if Task.isCancelled || stage != .play { return }  // 已结束
                if let f = await DuelAPI.state(duelId: id, pid: myPid) { adopt(f) }  // 拿到就更新
            }  // 循环结束
        }  // 任务结束
    }  // startFoePolling 结束

    private func startBot() {  // AI 陪练节奏
        let pace = Double.random(in: 4.2...6.8)  // 4.2 到 6.8 秒答一题
        botTask = Task { @MainActor in  // 按节奏推进
            while !Task.isCancelled && stage == .play {  // 打的时候才推
                try? await Task.sleep(nanoseconds: UInt64(pace * 1_000_000_000))  // 等一个节奏
                if Task.isCancelled || stage != .play { return }  // 已结束
                if theirs.answered >= list.count { theirs.done = true; return }  // 已答完就交卷
                theirs.answered += 1  // 答一题
                if Double.random(in: 0..<1) < 0.62 { theirs.correct += 1 }  // 约 62% 正确率
            }  // 循环结束
        }  // 任务结束
    }  // startBot 结束

    private func finish() {  // 结算
        ticker?.cancel()  // 停计时
        pollTask?.cancel()  // 停轮询
        botTask?.cancel()  // 停陪练
        mine.done = true  // 标记交卷
        mine.ms = Int(Date().timeIntervalSince(startedAt) * 1000)  // 总用时
        report(done: true)  // 告诉服务端我交卷了
        let win = mine.correct > theirs.correct  // 是否赢
        let draw = mine.correct == theirs.correct  // 是否平
        gained = app.finishDuel(win: win, draw: draw)  // 唯一写入口：成长值、场次、亲密度
        stage = .result  // 进结算
    }  // finish 结束

    private func stopAll() {  // 停所有后台任务
        ticker?.cancel()  // 停计时
        waiter?.cancel()  // 停等待计时
        pollTask?.cancel()  // 停轮询
        botTask?.cancel()  // 停陪练
        ticker = nil  // 清引用
        waiter = nil  // 清引用
        pollTask = nil  // 清引用
        botTask = nil  // 清引用
    }  // stopAll 结束

    // MARK: 出题                                                       // 分节：出题

    /// 与样板 pickQuestions 逐行对齐：同 seed + 同题库 = 同样的题、同样的顺序。
    private func pickQuestions(_ n: Int, _ seed: Int) -> [Question] {  // 种子出题
        let pool = app.bank?.questions ?? []  // 当前方向的题库
        guard !pool.isEmpty else { return [] }  // 没题就空
        var rand = DuelRng(seed: UInt32(truncatingIfNeeded: seed))  // 同款随机数
        var a = pool  // 洗牌副本
        if a.count > 1 {  // 至少两题才洗
            for i in stride(from: a.count - 1, through: 1, by: -1) {  // 从后往前
                let j = Int(rand.next() * Double(i + 1))  // 0 到 i 的下标
                a.swapAt(i, min(j, i))  // 交换
            }  // 循环结束
        }  // 分支结束
        var out: [Question] = []  // 结果
        for i in 0..<n { out.append(a[i % a.count]) }  // 题不够就循环取
        return out  // 返回
    }  // pickQuestions 结束
}  // DuelView 结束
