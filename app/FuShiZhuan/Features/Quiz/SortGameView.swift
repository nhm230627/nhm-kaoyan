//  SortGameView.swift —— 闯关玩法「知识分拣站」（对齐样板 js/sortgame.js）   // 文件说明
//  不考选择题，考手上的动作：把卡片拖进正确的分类槽，靠即时反馈记知识点     // 玩法定位
//  规则照样板：3 条命；放对 → 连击 +1、槽计数 +1；放错 → 连击清零、扣命、给依据
//  结算照样板：清空全部 = 过关，星级 = max(1, 剩余命)；命耗尽 = 失败 0 星     // 规则约定

import SwiftUI  // 界面框架

struct SortGameView: View {  // 分拣关卡页
    @Environment(AppState.self) private var app  // 写成绩
    @Environment(\.dismiss) private var dismiss  // 回地图

    let level: SortLevel  // 这一关的数据
    var onNext: (() -> Void)? = nil  // 点「下一关」（截图时不需要，所以给默认 nil）

    // MARK: - 运行状态                                                // 分节：状态

    @State private var cards: [SortCard] = []  // 洗过顺序的卡片
    @State private var done: Set<Int> = []  // 已归位的卡片下标
    @State private var filled: [String: Int] = [:]  // 每个槽已归位数
    @State private var lives = 3  // 剩余命数
    @State private var combo = 0  // 当前连击
    @State private var maxCombo = 0  // 最高连击
    @State private var tip = ""  // 底部提示行
    @State private var tipBad = false  // 提示是否是「错了」
    @State private var dragIndex: Int? = nil  // 正在拖的卡片下标
    @State private var dragOffset: CGSize = .zero  // 拖动位移
    @State private var slotFrames: [String: CGRect] = [:]  // 槽在画布里的位置
    @State private var cardFrames: [Int: CGRect] = [:]  // 卡片原位
    @State private var flashSlot: String? = nil  // 正在闪的槽
    @State private var flashGood = true  // 闪的是对还是错
    @State private var finished = false  // 是否已结算
    @State private var passed = false  // 是否过关
    @State private var stars = 0  // 得了几星

    // MARK: - 视图                                                    // 分节：视图

    var body: some View {  // 视图主体
        ZStack {  // 结算层盖在上面
            VStack(spacing: 0) {  // 纵向排列
                topBar  // 退出 + 标题 + 命
                ScrollView {  // 内容可滚
                    VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                        slotsSection  // 三个分类槽
                        comboLine  // 连击提示
                        poolHeader  // 待分拣张数
                        poolGrid  // 卡片池
                        tipLine  // 底部提示
                    }  // 排列结束
                    .padding(Metrics.pagePadding)  // 内边距
                    .padding(.bottom, Space.xxl)  // 底部留白
                }  // 滚动结束
            }  // 排列结束
            .coordinateSpace(name: "sort")  // 给拖拽用的坐标系
            .onPreferenceChange(SlotFrameKey.self) { slotFrames = $0 }  // 收集槽位置
            .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }  // 收集卡片位置

            if finished {  // 结算层
                resultOverlay  // 星级与按钮
            }  // 分支结束
        }  // 叠放结束
        .background(Color.appBG)  // 底色
        .navigationTitle(level.title)  // 标题
        .navigationBarTitleDisplayMode(.inline)  // 内联标题
        .navigationBarBackButtonHidden(true)  // 用自定义退出键
        .onAppear(perform: reset)  // 进来就洗牌开局
    }  // body 结束

    private var topBar: some View {  // 顶部：退出 + 玩法提示 + 命
        HStack(spacing: Space.s) {  // 横向排列
            Button {  // 退出
                dismiss()  // 回地图
            } label: {  // 按钮外观
                Image(systemName: "xmark")  // 叉号
                    .font(.system(size: 13, weight: .semibold))  // 小图标
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .frame(width: 30, height: 30)  // 触控区
                    .background(Circle().fill(Color.appCard))  // 白圆底
            }  // 外观结束
            .buttonStyle(.plain)  // 不用默认高亮

            VStack(alignment: .leading, spacing: 1) {  // 标题与提示
                Text(level.title).font(AppFont.bodyStrong)  // 关卡名
                Text(level.hint).font(.system(size: 11))  // 玩法提示
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .lineLimit(1)  // 一行就够
            }  // 排列结束

            Spacer(minLength: 0)  // 撑开

            HStack(spacing: 3) {  // 三条命
                ForEach(0..<3, id: \.self) { i in  // 逐个位置
                    Text(i < lives ? "♥" : "♡")  // 有命实心，没命空心
                        .font(.system(size: 15))  // 心形字号
                        .foregroundStyle(i < lives ? Color.appErr : Color.textTertiary)  // 红或灰
                }  // 遍历结束
            }  // 排列结束
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
        .padding(.vertical, Space.s)  // 上下内边距
    }  // topBar 结束

    private var slotsSection: some View {  // 三个分类槽（样板 .sg-slots 竖排）
        VStack(spacing: Space.s) {  // 纵向排列
            ForEach(level.slots) { slot in  // 逐槽
                slotCard(slot)  // 单个槽
            }  // 遍历结束
        }  // 排列结束
    }  // slotsSection 结束

    private func slotCard(_ slot: SortSlot) -> some View {  // 一个槽
        let need = level.cards.filter { $0.slot == slot.id }.count  // 这个槽该收几张
        let got = filled[slot.id] ?? 0  // 已收几张
        let tint = color(slot.color)  // 槽主题色
        let isFlash = flashSlot == slot.id  // 是否正在闪
        return VStack(alignment: .leading, spacing: 7) {  // 纵向排列
            HStack(spacing: Space.xs) {  // 标题行
                Text(slot.name)  // 槽名
                    .font(.system(size: 13.5, weight: .semibold))  // 加粗
                    .foregroundStyle(tint)  // 用主题色
                Spacer(minLength: 0)  // 撑开
                Text(verbatim: "\(got)/\(need)")  // 计数
                    .font(.system(size: 11, weight: .semibold))  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .monospacedDigit()  // 等宽不跳
            }  // 排列结束

            HStack(spacing: 5) {  // 已收的小标签
                ForEach(0..<need, id: \.self) { i in  // 逐个位置
                    if i < got {  // 已填
                        Text(filledText(slot: slot, index: i))  // 填上卡片文字
                            .font(.system(size: 10.5, weight: .medium))  // 小字
                            .foregroundStyle(tint)  // 主题色
                            .padding(.horizontal, 7)  // 左右内边距
                            .frame(height: 22)  // 小胶囊高
                            .background(Capsule().fill(tint.opacity(0.12)))  // 淡底
                    } else {  // 空位
                        Capsule()  // 虚线占位（实心淡灰代替）
                            .fill(Color.separator.opacity(0.35))  // 淡灰
                            .frame(width: 26, height: 22)  // 与小胶囊同高
                    }  // 分支结束
                }  // 遍历结束
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束
        }  // 排列结束
        .padding(11)  // 内边距
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满
        .background(  // 槽底
            RoundedRectangle(cornerRadius: 13, style: .continuous)  // 圆角
                .fill(isFlash ? (flashGood ? Color.appOK : Color.appErr).opacity(0.12) : Color.appCard)  // 闪一下
        )  // 背景结束
        .overlay(  // 描边
            RoundedRectangle(cornerRadius: 13, style: .continuous)  // 同形
                .stroke(isFlash ? (flashGood ? Color.appOK : Color.appErr) : tint.opacity(0.35), lineWidth: isFlash ? 1.6 : 1)  // 闪时变粗
        )  // 描边结束
        .background(  // 上报位置
            GeometryReader { g in  // 读几何
                Color.clear.preference(key: SlotFrameKey.self,  // 写进偏好
                                       value: [slot.id: g.frame(in: .named("sort"))])  // 键是槽 id
            }  // 读取器结束
        )  // 上报结束
    }  // slotCard 结束

    private var comboLine: some View {  // 连击提示
        Group {  // 有条件显示
            if combo > 1 {  // 连击两次以上才显
                Text(verbatim: "连击 ×\(combo)")  // 连击数
                    .font(.system(size: 12, weight: .bold))  // 加粗
                    .foregroundStyle(Color.appBrand)  // 品牌色
                    .transition(.scale.combined(with: .opacity))  // 弹一下
            }  // 分支结束
        }  // 分组结束
        .frame(height: 16, alignment: .leading)  // 占位固定高，避免跳动
    }  // comboLine 结束

    private var poolHeader: some View {  // 待分拣计数
        HStack(spacing: 5) {  // 横向排列
            Text("待分拣")  // 标题
                .font(.system(size: 13, weight: .semibold))  // 小标题
            Text(verbatim: "\(cards.count - done.count)")  // 剩余张数
                .font(.system(size: 13, weight: .semibold))  // 同字号
                .foregroundStyle(Color.appBrand)  // 品牌色
            Text("张")  // 量词
                .font(.system(size: 12))  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
            Spacer(minLength: 0)  // 撑开
        }  // 排列结束
    }  // poolHeader 结束

    private var poolGrid: some View {  // 卡片池
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],  // 两列
                  spacing: 8) {  // 行间距
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in  // 逐张卡
                if !done.contains(i) {  // 已归位的不再显示
                    cardView(card, index: i)  // 卡片本体
                }  // 分支结束
            }  // 遍历结束
        }  // 栅格结束
    }  // poolGrid 结束

    private func cardView(_ card: SortCard, index: Int) -> some View {  // 一张可拖的卡
        let dragging = dragIndex == index  // 是否正在拖
        return Text(card.text)  // 卡面文字
            .font(.system(size: 13, weight: .medium))  // 字号
            .foregroundStyle(Color.textPrimary)  // 主色
            .lineLimit(2)  // 最多两行
            .multilineTextAlignment(.center)  // 居中
            .padding(.horizontal, 8)  // 左右内边距
            .frame(maxWidth: .infinity)  // 撑满格宽
            .frame(height: 52)  // 固定卡高
            .background(  // 卡底
                RoundedRectangle(cornerRadius: 12, style: .continuous)  // 圆角
                    .fill(Color.appCard)  // 白底
                    .shadow(color: .black.opacity(dragging ? 0.18 : 0.05),  // 拖动时投影更重
                            radius: dragging ? 12 : 3, y: dragging ? 6 : 1)  // 抬起来的感觉
            )  // 背景结束
            .overlay(  // 描边
                RoundedRectangle(cornerRadius: 12, style: .continuous)  // 同形
                    .stroke(Color.separator, lineWidth: 1)  // 细边
            )  // 描边结束
            .scaleEffect(dragging ? 1.06 : 1)  // 拿起时放大
            .offset(dragging ? dragOffset : .zero)  // 跟随手指
            .zIndex(dragging ? 10 : 0)  // 拖的时候盖在上面
            .background(  // 上报原位
                GeometryReader { g in  // 读几何
                    Color.clear.preference(key: CardFrameKey.self,  // 写进偏好
                                           value: [index: g.frame(in: .named("sort"))])  // 键是下标
                }  // 读取器结束
            )  // 上报结束
            .highPriorityGesture(  // 优先于滚动，否则竖直拖动会被 ScrollView 抢走
                DragGesture(coordinateSpace: .named("sort"))  // 用同一坐标系
                    .onChanged { value in  // 拖动中
                        dragIndex = index  // 记住在拖哪张
                        dragOffset = value.translation  // 跟随
                    }  // 变化结束
                    .onEnded { value in  // 松手
                        let start = cardFrames[index]  // 原位
                        dragIndex = nil  // 清拖拽态
                        dragOffset = .zero  // 归零
                        guard let start else { return }  // 拿不到位就不判
                        let point = CGPoint(x: start.midX + value.translation.width,  // 松手点 X
                                            y: start.midY + value.translation.height)  // 松手点 Y
                        guard let hit = slotFrames.first(where: { $0.value.contains(point) })?.key else { return }  // 落在哪个槽
                        judge(cardIndex: index, slotID: hit)  // 判定
                    }  // 结束结束
            )  // 手势结束
    }  // cardView 结束

    private var tipLine: some View {  // 底部提示
        Text(tip)  // 提示文案
            .font(.system(size: 11.5))  // 小字
            .foregroundStyle(tipBad ? Color.appErr : Color.textTertiary)  // 错了标红
            .fixedSize(horizontal: false, vertical: true)  // 允许换行
            .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
    }  // tipLine 结束

    // MARK: - 结算层                                                  // 分节：结算

    private var resultOverlay: some View {  // 结算卡片
        ZStack {  // 遮罩 + 卡片
            Color.black.opacity(0.28)  // 半透明遮罩
                .ignoresSafeArea()  // 铺满

            VStack(spacing: Space.s) {  // 卡片内容
                HStack(spacing: 6) {  // 三颗星
                    ForEach(0..<3, id: \.self) { i in  // 逐个
                        Text("★")  // 星
                            .font(.system(size: 30))  // 大号
                            .foregroundStyle(i < stars ? Color.appWarn : Color.separator.opacity(0.5))  // 亮或灰
                    }  // 遍历结束
                }  // 排列结束

                Text(passed ? (stars == 3 ? "一次没错！" : "全部分完") : "这关先放一放")  // 标题（样板同文案）
                    .font(AppFont.section)  // 区段标题

                Text(passed  // 副标题两种
                     ? "归位 \(done.count)/\(cards.count) · 最高连击 \(maxCombo) · \(stars) 星"  // 过关
                     : "还有 \(cards.count - done.count) 张没归位，知识点已经记下来了，随时回来再试")  // 失败
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .multilineTextAlignment(.center)  // 居中
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行

                HStack(spacing: Space.s) {  // 两个按钮
                    GhostButton(title: "回地图", systemImage: "map") {  // 回地图
                        dismiss()  // 关掉
                    }  // 按钮结束

                    if passed {  // 过关给下一关
                        PrimaryButton(title: "下一关", systemImage: "chevron.right") {  // 下一关
                            onNext?()  // 交给外面换关
                        }  // 按钮结束
                    } else {  // 没过就重来
                        PrimaryButton(title: "再来一遍", systemImage: "arrow.clockwise") {  // 重来
                            reset()  // 原地重置
                        }  // 按钮结束
                    }  // 分支结束
                }  // 排列结束
                .padding(.top, Space.xs)  // 与上文隔开
            }  // 排列结束
            .padding(Space.l)  // 卡片内边距
            .frame(maxWidth: 320)  // 最大宽度
            .background(  // 卡片底
                RoundedRectangle(cornerRadius: 20, style: .continuous)  // 大圆角
                    .fill(Color.appCard)  // 白底
            )  // 背景结束
        }  // 叠放结束
    }  // resultOverlay 结束

    // MARK: - 逻辑                                                    // 分节：逻辑

    private func reset() {  // 开局或重来
        cards = level.cards.shuffled()  // 每次洗顺序（样板也洗）
        done = []  // 没有归位的
        filled = [:]  // 槽计数清零
        lives = 3  // 三条命
        combo = 0  // 连击清零
        maxCombo = 0  // 最高连击清零
        tip = "按住卡片，拖到上面的分类里"  // 样板默认提示
        tipBad = false  // 不是错误态
        finished = false  // 没结算
        passed = false  // 没过
        stars = 0  // 没星
        flashSlot = nil  // 没在闪
    }  // reset 结束

    private func judge(cardIndex: Int, slotID: String) {  // 判定一次投放
        guard !finished, !done.contains(cardIndex) else { return }  // 结算后或已归位不再判
        let card = cards[cardIndex]  // 这张卡
        if card.slot == slotID {  // 放对了
            done.insert(cardIndex)  // 标记归位
            filled[slotID, default: 0] += 1  // 槽计数 +1
            combo += 1  // 连击 +1
            maxCombo = max(maxCombo, combo)  // 记录最高
            flash(slotID, good: true)  // 绿闪
            if done.count >= cards.count { finish(pass: true) }  // 全清即过关
        } else {  // 放错了
            combo = 0  // 连击清零
            lives -= 1  // 扣命
            tip = "「\(card.text)」不属于这一类 · \(card.note)"  // 给依据（样板同文案）
            tipBad = true  // 标红
            flash(slotID, good: false)  // 红闪
            if lives <= 0 { finish(pass: false) }  // 命耗尽结算
        }  // 分支结束
    }  // judge 结束

    private func flash(_ slotID: String, good: Bool) {  // 槽闪一下
        flashGood = good  // 记下颜色
        flashSlot = slotID  // 记下哪个槽
        Task {  // 延时复位
            try? await Task.sleep(nanoseconds: 420_000_000)  // 0.42 秒（样板 420ms）
            if flashSlot == slotID { flashSlot = nil }  // 还是它就复位
        }  // 任务结束
    }  // flash 结束

    private func finish(pass: Bool) {  // 结算
        guard !finished else { return }  // 只结算一次
        passed = pass  // 记结果
        stars = pass ? max(1, lives) : 0  // 星级照样板公式
        finished = true  // 弹出结算层
        app.finishSortLevel(id: level.id, cleared: done.count, total: cards.count, stars: stars)  // 写成绩与口粮
    }  // finish 结束

    private func filledText(slot: SortSlot, index: Int) -> String {  // 第 index 个已填卡片的文字
        let ok = cards.enumerated()  // 带下标的卡片
            .filter { done.contains($0.offset) && $0.element.slot == slot.id }  // 本槽已归位
            .map(\.element.text)  // 取文字
        guard ok.indices.contains(index) else { return "" }  // 越界给空
        return ok[index]  // 返回文字
    }  // filledText 结束

    private func color(_ hex: String) -> Color {  // "#4a6bff" 转 Color
        let cleaned = hex.replacingOccurrences(of: "#", with: "")  // 去掉井号
        let value = UInt32(cleaned, radix: 16) ?? 0x6B8CFF  // 转成数值，失败给品牌蓝
        return Color(hex: value)  // 交给设计系统扩展
    }  // color 结束
}  // SortGameView 结束

// MARK: - 位置收集                                                      // 分节：偏好键

private struct SlotFrameKey: PreferenceKey {  // 收集槽位置
    static let defaultValue: [String: CGRect] = [:]  // 默认空
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {  // 合并
        value.merge(nextValue()) { _, new in new }  // 后写的覆盖
    }  // reduce 结束
}  // SlotFrameKey 结束

private struct CardFrameKey: PreferenceKey {  // 收集卡片原位
    static let defaultValue: [Int: CGRect] = [:]  // 默认空
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {  // 合并
        value.merge(nextValue()) { _, new in new }  // 后写的覆盖
    }  // reduce 结束
}  // CardFrameKey 结束
