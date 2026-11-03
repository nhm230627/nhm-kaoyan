//  RoamView.swift —— 岛内漫游页面（对齐样板 #page-roam）                // 文件说明
//  结构：标题 + 副标题 + 3D 场景 + 交互点胶囊 + 弹出卡片                  // 页面结构
//  卡片文案逐条照抄样板 roam.js 的 openSpot：书架翻知识卡 / 打饭窗口投喂 / 摊位换口粮…
//  所有结果都走 AppState 唯一写入口，页面不自己算数                       // 状态约束

import SwiftUI  // 界面框架

struct RoamView: View {  // 漫游页
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // 减弱动效
    @AppStorage("app.pet.static3D") private var staticMode = false  // 省电开关

    let roomID: String  // lib / diner / market / plaza
    @State private var activeSpot: RoamSpot?  // 当前弹开的交互点
    @State private var toast: String?  // 底部轻提示
    @State private var knowledge: Question?  // 本次翻到的知识卡

    private var room: RoamRoom { RoamRooms.room(roomID) }  // 当前房间配置
    private var animationsOff: Bool { staticMode || reduceMotion }  // 任一个开关都关动效

    var body: some View {  // 视图主体
        ScrollView {  // 整页可滚（小屏也能看全）
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                header  // 标题与副标题
                scene  // 3D 场景
                spotChips  // 交互点胶囊（点不到 3D 也能用）
                hintCard  // 玩法说明
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle(room.name)  // 房间名当标题
        .navigationBarTitleDisplayMode(.inline)  // 内联标题
        .overlay(alignment: .bottom) { cardLayer }  // 交互卡片浮在底部
        .overlay(alignment: .top) { toastLayer }  // 轻提示浮在顶部
    }  // body 结束

    // MARK: - 头部                                                    // 分节：头部

    private var header: some View {  // 标题与副标题
        VStack(alignment: .leading, spacing: 3) {  // 纵向排列
            Text(room.name).font(AppFont.section)  // 房间名
            Text(room.sub).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 样板原话
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
    }  // header 结束

    // MARK: - 3D 场景                                                 // 分节：场景

    private var scene: some View {  // 3D 画布
        RoamSceneView(room: room,  // 房间配置
                      stage: app.stage,  // 猫的阶段
                      outfit: app.outfit,  // 猫的穿戴
                      animationsOff: animationsOff,  // 省电
                      onSpot: { id in open(id) })  // 走到交互点后开卡片
            .frame(height: 380)  // 画布高度
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角卡片
            .overlay(  // 细边，白墙与页面底色才分得开
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 同形
                    .stroke(Color.separator, lineWidth: 1)  // 细边
            )  // 覆盖层结束
    }  // scene 结束

    // MARK: - 交互点胶囊                                              // 分节：胶囊

    private var spotChips: some View {  // 一排地点
        ScrollView(.horizontal, showsIndicators: false) {  // 横向滚动
            HStack(spacing: Space.xs) {  // 横向排列
                ForEach(room.spots) { spot in  // 逐个
                    Button {  // 点一下就开卡片（3D 里走过去也会开）
                        open(spot.id)  // 按 id 打开
                    } label: {  // 胶囊外观
                        HStack(spacing: 4) {  // 图标 + 文字
                            Image(systemName: icon(for: spot.type))  // 按类型给图标
                                .font(.system(size: 11))  // 小图标
                            Text(spot.name).font(AppFont.captionStrong)  // 地点名
                        }  // 排列结束
                        .foregroundStyle(Color.textPrimary)  // 深色字
                        .padding(.horizontal, 11)  // 左右
                        .frame(height: 30)  // 高度
                        .background(Capsule().fill(Color.appCard))  // 白胶囊
                    }  // 外观结束
                    .buttonStyle(.plain)  // 去掉系统高亮
                }  // 遍历结束
            }  // 排列结束
            .padding(.vertical, 2)  // 上下留一点，投影不裁
        }  // 滚动结束
    }  // spotChips 结束

    private func icon(for type: RoamSpotType) -> String {  // 地点图标
        switch type {  // 按类型分支
        case .knowledge: "book.closed"  // 知识卡
        case .focus: "brain.head.profile"  // 专注
        case .readlog: "list.bullet.rectangle"  // 记录
        case .feed: "fork.knife"  // 投喂
        case .rest: "cup.and.saucer"  // 歇会儿
        case .buyFood: "bag"  // 换口粮
        case .buyAff: "leaf"  // 猫薄荷
        case .buySkin: "scarf"  // 围巾
        case .mood: "drop"  // 喷泉
        case .notes: "note.text"  // 留言
        case .greet: "hand.wave"  // 打招呼
        }  // 分支结束
    }  // icon 结束

    private var hintCard: some View {  // 玩法说明
        Text("点画布地面，猫会自己走过去；点地上那块发光的圆垫，走到跟前就会弹出能做的事。")  // 说明
            .font(AppFont.caption)  // 小字
            .foregroundStyle(Color.textTertiary)  // 弱化色
            .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
    }  // hintCard 结束

    // MARK: - 卡片                                                    // 分节：卡片

    @ViewBuilder  // 可能为空
    private var cardLayer: some View {  // 交互卡片
        if let spot = activeSpot {  // 有交互点才显示
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack {  // 标题行
                    Text(cardTitle(spot)).font(AppFont.bodyStrong)  // 标题
                    Spacer()  // 撑开
                    Text(spot.name).font(AppFont.caption).foregroundStyle(Color.textTertiary)  // 地点名
                }  // 排列结束
                cardBody(spot)  // 正文
                HStack(spacing: Space.s) {  // 按钮行
                    Button("关闭") { close() }  // 关掉
                        .font(AppFont.captionStrong)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                    Spacer()  // 撑开
                    if let title = cardButtonTitle(spot) {  // 有动作才给主按钮
                        Button { perform(spot) } label: {  // 点它执行
                            Text(title)  // 按钮文案
                                .font(AppFont.captionStrong)  // 小字
                                .foregroundStyle(Color.white)  // 白字
                                .padding(.horizontal, 16)  // 左右
                                .frame(height: 32)  // 高度
                                .background(Capsule().fill(Color.appBrand))  // 品牌色胶囊
                        }  // 外观结束
                        .buttonStyle(.plain)  // 去掉系统高亮
                    }  // 分支结束
                }  // 排列结束
            }  // 排列结束
            .padding(16)  // 内边距
            .background(  // 卡片底
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)  // 圆角
                    .fill(Color.appCard)  // 白底
                    .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)  // 投影
            )  // 背景结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右留白
            .padding(.bottom, 118)  // 抬到悬浮 TabBar 之上
        }  // 分支结束
    }  // cardLayer 结束

    private func cardTitle(_ spot: RoamSpot) -> String {  // 卡片标题
        switch spot.type {  // 按类型分支
        case .knowledge: knowledge.map { app.topicName($0.topic) } ?? "书架"  // 知识卡显示板块中文名
        case .focus: "阅览桌"  // 样板原话
        case .readlog: "服务台"  // 样板原话
        case .feed: "打饭窗口"  // 样板原话
        case .rest: "长桌"  // 样板原话
        case .buyFood: "口粮摊"  // 样板原话
        case .buyAff: "猫薄荷"  // 样板原话
        case .buySkin: "围巾摊"  // 样板原话
        case .mood: "喷泉"  // 样板原话
        case .notes: "公告板"  // 样板原话
        case .greet: "研友的猫"  // 样板原话
        }  // 分支结束
    }  // cardTitle 结束

    @ViewBuilder  // 分支较多
    private func cardBody(_ spot: RoamSpot) -> some View {  // 卡片正文
        switch spot.type {  // 按类型分支
        case .knowledge:  // 书架
            if let q = knowledge {  // 翻到了题
                VStack(alignment: .leading, spacing: 6) {  // 纵向排列
                    Text(q.stem).font(AppFont.body).fixedSize(horizontal: false, vertical: true)  // 题干
                    Text(shortExplain(q)).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 前两句解析
                }  // 排列结束
            } else {  // 没题
                Text("书架上的书都借出去了，明天再来翻。").font(AppFont.caption)  // 样板原话
            }  // 分支结束
        case .focus:  // 阅览桌
            Text("坐下来专注 5 分钟，猫趴在桌角陪着。当前精力 \(app.pet.energy)。")  // 样板同义
                .font(AppFont.caption)  // 小字
        case .readlog:  // 服务台
            Text("今天你在图书馆翻了 \(app.roamRead) 张知识卡。每翻一张，猫对知识点的印象就深一分。")  // 样板同义
                .font(AppFont.caption)  // 小字
        case .feed:  // 打饭窗口
            Text(app.pet.food > 0  // 有口粮
                 ? "还有 \(app.pet.food) 份口粮，喂一份给猫，亲密度 +6。"  // 样板原话
                 : "口粮空了。去副本战场闯关能赢口粮，集市也能用积分换。")  // 样板原话
                .font(AppFont.caption)  // 小字
        case .rest:  // 长桌
            Text("坐下歇一会儿，精力 +10。当前精力 \(app.pet.energy)。").font(AppFont.caption)  // 样板同义
        case .buyFood:  // 口粮摊
            Text("20 积分换 1 份口粮。你有 \(app.points) 积分。").font(AppFont.caption)  // 样板同义
        case .buyAff:  // 猫薄荷
            Text("30 积分换一点猫薄荷，亲密度 +8。你有 \(app.points) 积分。").font(AppFont.caption)  // 样板同义
        case .buySkin:  // 围巾摊
            Text("围巾样式还在打版。先把积分攒着，上架会通知你。").font(AppFont.caption)  // 样板原话
        case .mood:  // 喷泉
            Text("水声很轻，坐一会儿人会静下来。亲密度 +3。").font(AppFont.caption)  // 样板原话
        case .notes:  // 公告板
            VStack(alignment: .leading, spacing: 4) {  // 四条留言
                ForEach(RoamRooms.notes, id: \.self) { note in  // 逐条
                    Text("· \(note)").font(AppFont.caption)  // 一条留言
                }  // 遍历结束
            }  // 排列结束
        case .greet:  // 研友的猫
            Text("“你也是来税喵岛备考的？”打声招呼，亲密度 +2。").font(AppFont.caption)  // 样板原话
        }  // 分支结束
    }  // cardBody 结束

    private func cardButtonTitle(_ spot: RoamSpot) -> String? {  // 主按钮文案，nil 表示没有动作
        switch spot.type {  // 按类型分支
        case .knowledge: "记下来"  // 样板原话
        case .focus: "开始专注"  // 样板原话
        case .readlog: "知道了"  // 样板原话
        case .feed: app.pet.food > 0 ? "喂一份" : "知道了"  // 有口粮才给喂
        case .rest: "坐下"  // 样板原话
        case .buyFood: app.points >= 20 ? "换一份" : "积分不够"  // 够才给换
        case .buyAff: app.points >= 30 ? "买一包" : "积分不够"  // 够才给买
        case .buySkin: "知道了"  // 样板原话
        case .mood: "坐一会儿"  // 样板原话
        case .notes: "知道了"  // 样板原话
        case .greet: "打招呼"  // 样板原话
        }  // 分支结束
    }  // cardButtonTitle 结束

    private func shortExplain(_ q: Question) -> String {  // 解析取前两句（样板 split 取两段）
        let parts = q.explain.split(separator: "。")  // 按句号切
        return parts.prefix(2).joined(separator: "。") + "。"  // 拼回前两句
    }  // shortExplain 结束

    // MARK: - 动作                                                    // 分节：动作

    private func open(_ id: String) {  // 打开某个交互点
        guard let spot = room.spots.first(where: { $0.id == id }) else { return }  // 找不到就算
        if spot.type == .knowledge { knowledge = drawQuestion() }  // 书架：先抽一张卡
        withAnimation(.easeOut(duration: 0.18)) { activeSpot = spot }  // 弹出卡片
    }  // open 结束

    private func close() {  // 关掉卡片
        withAnimation(.easeOut(duration: 0.15)) { activeSpot = nil }  // 收起
    }  // close 结束

    private func drawQuestion() -> Question? {  // 从当前题库随机抽一题当知识卡
        guard let bank = app.bank, !bank.questions.isEmpty else { return nil }  // 题库没加载就给 nil
        return bank.questions.randomElement()  // 随机一张，样板也是随机
    }  // drawQuestion 结束

    private func perform(_ spot: RoamSpot) {  // 点主按钮
        switch spot.type {  // 按类型分支
        case .knowledge:  // 记下来
            app.noteRoamRead()  // 唯一写入口：翻卡数 +1、亲密度 +1
            show("记下了 · 亲密度 +1")  // 样板原话
        case .focus:  // 专注
            app.nudgePet(energy: 10, affinity: 2)  // 样板 patch：精力 +10 亲密度 +2
            show("专注 5 分钟 · 精力 +10")  // 样板原话
        case .readlog:  // 知道了
            break  // 只读，不改状态
        case .feed:  // 投喂
            if app.pet.food > 0 {  // 有口粮才喂
                switch app.feedPet() {  // 唯一写入口，按结果给提示
                case .ok(_, _): show("喂饱了 · 精力 +30")  // 样板原话
                case .alreadyFull: show("猫已经吃饱了")  // 样板原话
                case .noFood: show("口粮不够")  // 样板原话
                case .dead: show("伙伴饿着呢，先去伙伴页唤醒")  // 如实提示
                }  // 分支结束
            } else {  // 没口粮
                break  // 只能点知道了
            }  // 分支结束
        case .rest:  // 歇一会儿
            app.nudgePet(energy: 10)  // 精力 +10
            show("歇了一会儿 · 精力 +10")  // 样板原话
        case .buyFood:  // 换口粮
            if app.spendPoints(20) {  // 先扣积分
                app.addFood(1)  // 再加口粮
                show("换到 1 份口粮")  // 样板原话
            } else {  // 积分不够
                show("积分不够 · 答对题能攒积分")  // 如实说明来源
            }  // 分支结束
        case .buyAff:  // 买猫薄荷
            if app.spendPoints(30) {  // 先扣积分
                app.nudgePet(affinity: 8)  // 亲密度 +8
                show("猫薄荷下肚 · 亲密度 +8")  // 样板原话
            } else {  // 积分不够
                show("积分不够 · 答对题能攒积分")  // 如实说明来源
            }  // 分支结束
        case .buySkin:  // 围巾摊
            break  // 还没上架
        case .mood:  // 喷泉
            app.nudgePet(energy: 4, affinity: 3)  // 样板 patch
            show("心情好了 · 亲密度 +3")  // 样板原话
        case .notes:  // 公告板
            break  // 只读
        case .greet:  // 打招呼
            app.nudgePet(affinity: 2)  // 亲密度 +2
            show("交到朋友 · 亲密度 +2")  // 样板原话
        }  // 分支结束
        close()  // 做完就收起卡片
    }  // perform 结束

    private func show(_ text: String) {  // 轻提示
        withAnimation { toast = text }  // 显示
        Task {  // 2.2 秒后自动消失
            try? await Task.sleep(nanoseconds: 2_200_000_000)  // 等 2.2 秒
            withAnimation { if toast == text { toast = nil } }  // 只清掉自己这条
        }  // 任务结束
    }  // show 结束

    @ViewBuilder  // 可能为空
    private var toastLayer: some View {  // 顶部轻提示
        if let msg = toast {  // 有提示才显示
            Text(msg)  // 内容
                .font(.system(size: 12))  // 12 号
                .foregroundStyle(.white)  // 白字
                .padding(.horizontal, 14)  // 左右
                .padding(.vertical, 9)  // 上下
                .background(Capsule().fill(Color.black.opacity(0.78)))  // 深色胶囊
                .padding(.top, 8)  // 离顶部一点
                .transition(.opacity)  // 淡入淡出
        }  // 分支结束
    }  // toastLayer 结束
}  // RoamView 结束
