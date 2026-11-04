//  CompanionHomeView.swift —— 伙伴（电子宠物）页                      // 文件说明
//  结构严格照样板 page-pet：3D 舞台（铺满、圆角、径向渐变）+ 面板
//  面板 = 三条进度条（亲密度 / 精力 / 今日陪伴）→ 口粮条 → 三个按钮
//        → 广场入口 → 拨穗入口 → 严选好物入口
//  口粮只能靠闯关产出，这里不卖口粮、不做抽卡                         // 产品约束

import SwiftUI  // 界面框架
import UIKit  // 用到 UIBezierPath 切指定圆角

struct CompanionHomeView: View {  // 伙伴页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var toast: String?  // 轻提示文案
    @State private var jumpToken = 0  // 每 +1 让宠物跳一下
    @State private var flipToken = 0  // 每 +1 拨一次穗
    @State private var showRitual = false  // 是否打开礼成证书页
    @State private var enteredAt = Date()  // 进入本页的时间（算今日陪伴）

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: 0) {  // 纵向排列：舞台 + 面板
                stage  // 3D 舞台
                panel  // 下方面板
                    .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
            }  // 排列结束
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .toolbar(.hidden, for: .navigationBar)  // 样板这页没有标题栏，舞台顶到状态栏
        .overlay(alignment: .bottom) {  // 底部浮层
            if let toast {  // 有提示才显示
                Text(toast)  // 提示文字
                    .font(AppFont.captionStrong)  // 小字加粗
                    .padding(.horizontal, Space.l)  // 左右内边距
                    .padding(.vertical, Space.s)  // 上下内边距
                    .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃胶囊
                    .padding(.bottom, Space.xxl)  // 距底边
                    .transition(.opacity)  // 淡入淡出
            }  // 分支结束
        }  // 浮层结束
        .onAppear { enteredAt = Date() }  // 进来记时间
        .onDisappear { app.addCompanion(minutes: minutesSinceEnter) }  // 离开时把停留时长记进今日
        .fullScreenCover(isPresented: $showRitual) {  // 礼成证书页全屏
            RitualView()  // 拨穗礼成
                .environment(app)  // 传全局状态
        }  // 全屏结束
    }  // body 结束

    // MARK: - 3D 舞台                                                  // 分节：舞台

    private var stage: some View {  // 3D 舞台（照样板 .pet-stage）
        ZStack(alignment: .topLeading) {  // 叠放
            LinearGradient(colors: [Color(hex: 0xEEF2FF), Color(hex: 0xF7F8FC), Color(hex: 0xEEF0F6)],  // 径向渐变的近似
                           startPoint: .top, endPoint: .bottom)  // 上亮下灰

            PetSceneView(stage: app.stage,  // 3D 形象
                         outfit: app.outfit,  // 当前穿戴
                         jumpToken: jumpToken,  // 跳跃令牌
                         flipToken: flipToken)  // 拨穗令牌
                .frame(maxWidth: .infinity)  // 撑满宽度
                .frame(height: 300)  // 舞台高度（样板 46vh，iPhone 上约 300）
                .allowsHitTesting(false)  // 别挡住上面的文字

            VStack(alignment: .leading, spacing: 7) {  // 左上角：名字 + 气泡
                HStack(spacing: 4) {  // 名字行
                    Text("小税")  // 宠物名（照样板）
                        .font(.system(size: 14, weight: .bold))  // 14 加粗
                        .foregroundStyle(Color.textPrimary)  // 主色
                    Text("Lv.\(app.stage.level)")  // 等级
                        .font(.system(size: 10.5, weight: .semibold))  // 10.5 号
                        .foregroundStyle(Color.appBrand)  // 品牌蓝
                }  // 名字行结束

                Text(bubbleText)  // 气泡文案
                    .font(.system(size: 12))  // 12 号
                    .foregroundStyle(Color(hex: 0x48484A))  // 深灰
                    .lineSpacing(2)  // 行距
                    .padding(.horizontal, 11)  // 左右
                    .padding(.vertical, 7)  // 上下
                    .frame(maxWidth: 232, alignment: .leading)  // 最宽 78% 左右
                    .background(  // 白气泡
                        RoundedCorner(radius: 13, corners: [.topLeft, .topRight, .bottomRight])  // 左上角尖
                            .fill(Color.white.opacity(0.94))  // 白 94%
                    )  // 背景结束
            }  // 竖排结束
            .padding(.leading, 16)  // 左边距
            .padding(.top, 14)  // 上边距

            HStack {  // 右上角心情胶囊
                Spacer()  // 推到右边
                Text(app.pet.statusText)  // 状态（待机 / 饿 / 饱）
                    .font(.system(size: 10.5))  // 10.5 号
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .padding(.horizontal, 9)  // 左右
                    .padding(.vertical, 3)  // 上下
                    .background(Capsule().fill(Color.white.opacity(0.9)))  // 白胶囊
            }  // 横排结束
            .padding(.trailing, 14)  // 右边距
            .padding(.top, 14)  // 上边距
        }  // 叠放结束
        .frame(height: 300)  // 整体高度
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))  // 圆角 22（样板同）
        .padding(.horizontal, Metrics.pagePadding)  // 左右内边距
    }  // stage 结束

    private var bubbleText: String {  // 气泡里说的话
        if app.pet.starved { return "我饿瘦了……去副本战场赚点口粮吧。" }  // 饿死
        if app.pet.isHungry { return "有点饿了，闯关能拿到口粮。" }  // 濒危
        if app.stage == .master { return "今天也要一起复习哦。" }  // 硕士阶段
        return "今天也要一起复习哦。"  // 默认（样板原话）
    }  // bubbleText 结束

    private var minutesSinceEnter: Int {  // 本次停留几分钟（不足 1 分钟不计）
        max(0, Int(Date().timeIntervalSince(enteredAt) / 60))  // 取整分钟
    }  // minutesSinceEnter 结束

    // MARK: - 面板                                                    // 分节：面板

    private var panel: some View {  // 面板（照样板 .pet-panel）
        VStack(spacing: 0) {  // 纵向排列
            meter(label: "亲密度", value: affinityRatio, text: "\(app.pet.affinity)")  // 亲密度
            meter(label: "精力", value: energyRatio, text: "\(app.pet.energy)")  // 精力
            meter(label: "今日陪伴", value: todayRatio, text: "\(app.data.todayCompanion) 分钟")  // 今日陪伴

            foodBar  // 口粮条

            actions  // 三个按钮

            NavigationLink {  // 广场入口
                PlazaView()  // 广场（画布版，多宠物同场）
            } label: {  // 入口外观
                entryRow(icon: "bubble.left.and.bubble.right.fill",  // 图标
                         title: "广场 · 研友都在这里",  // 主标题（样板原话）
                         subtitle: "宠物同场 · 可组队刷副本",  // 副标题
                         tint: Color.appBrand,  // 图标底色
                         bg: [Color(hex: 0xEEF4FF), Color(hex: 0xF4F0FF)])  // 渐变底
            }  // 链接结束
            .buttonStyle(.plain)  // 去掉系统样式

            Button {  // 拨穗入口
                if app.stage == .master {  // 到硕士了才能拨
                    flipToken += 1  // 3D 流苏也转半圈
                    showRitual = true  // 打开礼成证书页
                } else {  // 还没到
                    show("到「硕士」阶段才能拨穗，现在差 \(max(0, PetStage.master.threshold - app.growth)) 成长值")  // 如实说明
                }  // 分支结束
            } label: {  // 入口外观
                entryRow(icon: "graduationcap.fill",  // 学士帽
                         title: "拨穗仪式",  // 主标题（样板原话）
                         subtitle: "上岸后，把流苏从右拨到左",  // 副标题（样板原话）
                         tint: Color(hex: 0xB06A12),  // 棕
                         bg: [Color(hex: 0xFFF5E4), Color(hex: 0xFFFAF2)])  // 米黄渐变
            }  // 按钮结束
            .buttonStyle(.plain)  // 去掉系统样式

            NavigationLink {  // 严选好物（商店）
                ShopView()  // 真实商店页，对齐样板 page-shop
            } label: {  // 入口外观
                entryRow(icon: "bag.fill",  // 购物袋
                         title: "严选好物",  // 主标题（样板原话）
                         subtitle: "备考资料 · 商家入驻中",  // 副标题（样板原话）
                         tint: Color.appViolet,  // 紫
                         bg: [Color.appCard, Color.appCard])  // 白底
            }  // 链接结束
            .buttonStyle(.plain)  // 去掉系统样式
        }  // 排列结束
        .padding(.top, 14)  // 面板上边距（样板 14）
    }  // panel 结束

    private var affinityRatio: Double {  // 亲密度比例（满 100）
        min(1, Double(app.pet.affinity) / 100.0)  // 别超 1
    }  // affinityRatio 结束

    private var energyRatio: Double {  // 精力比例
        min(1, Double(app.pet.energy) / Double(Pet.maxEnergy))  // 别超 1
    }  // energyRatio 结束

    private var todayRatio: Double {  // 今日陪伴比例（满 60 分钟算满）
        min(1, Double(app.data.todayCompanion) / 60.0)  // 别超 1
    }  // todayRatio 结束

    private func meter(label: String, value: Double, text: String) -> some View {  // 一条进度条（照样板 .meter）
        HStack(spacing: 10) {  // 三列：标签 50 / 条 / 数值 46
            Text(label)  // 标签
                .font(.system(size: 11.5))  // 11.5 号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .frame(width: 50, alignment: .leading)  // 固定 50 宽

            GeometryReader { geo in  // 拿到可用宽度
                ZStack(alignment: .leading) {  // 左对齐叠放
                    Capsule().fill(Color(hex: 0xE6E6EB))  // 灰底
                    Capsule().fill(barTint(label))  // 彩色进度
                        .frame(width: max(6, geo.size.width * value))  // 至少 6 宽，别看不见
                }  // 叠放结束
            }  // 几何读取结束
            .frame(height: 6)  // 条高 6（样板同）

            Text(text)  // 数值文本
                .font(.system(size: 11, weight: .semibold))  // 11 号
                .foregroundStyle(Color.textSecondary)  // 次要色
                .frame(width: 46, alignment: .trailing)  // 固定 46 宽右对齐
                .monospacedDigit()  // 数字等宽
        }  // 横排结束
        .padding(.bottom, 10)  // 行距（样板 margin-bottom 10）
    }  // meter 结束

    private func barTint(_ label: String) -> Color {  // 进度条颜色
        switch label {  // 按条目分支
        case "亲密度": Color(hex: 0xFF6B8A)  // 粉红
        case "精力": Color.appOK  // 绿色
        default: Color.appBrand  // 品牌蓝
        }  // 分支结束
    }  // barTint 结束

    private var foodBar: some View {  // 口粮条（照样板 .pet-food）
        HStack(spacing: 8) {  // 横向排列
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")  // 食物图标
                .font(.system(size: 13))  // 图标大小
                .foregroundStyle(Color(hex: 0xB06A12))  // 棕
                .frame(width: 26, height: 26)  // 26 方块
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)  // 圆角 9
                    .fill(Color(hex: 0xFFE9C2)))  // 浅黄

            HStack(spacing: 0) {  // 文案
                Text("口粮 ")  // 前缀
                Text("\(app.pet.food)")  // 份数
                    .font(.system(size: 15, weight: .bold))  // 放大
                    .foregroundStyle(Color(hex: 0x8A4B06))  // 深棕
                Text(" 份")  // 后缀
                Text("只靠闯关赚 · 断粮会饿瘦")  // 说明（样板原话）
                    .font(.system(size: 9.5))  // 更小
                    .foregroundStyle(Color(hex: 0xA98A5C))  // 浅棕
                    .padding(.leading, 4)  // 与前文分开
            }  // 横排结束
            .font(.system(size: 11.5))  // 11.5 号
            .foregroundStyle(Color(hex: 0x7A5A2A))  // 棕

            Spacer(minLength: 0)  // 撑开

            NavigationLink {  // 去赚口粮
                LevelMapView()  // 关卡地图
            } label: {  // 按钮外观
                Text("去赚")  // 文案（样板原话）
                    .font(.system(size: 11, weight: .semibold))  // 11 号
                    .foregroundStyle(Color(hex: 0x8A4B06))  // 深棕
                    .padding(.horizontal, 10)  // 左右
                    .frame(height: 24)  // 高 24
                    .background(Capsule().fill(Color(hex: 0xFFE0A8)))  // 橙黄胶囊
            }  // 按钮结束
            .buttonStyle(.plain)  // 去掉系统样式
        }  // 横排结束
        .padding(.horizontal, 11)  // 左右内边距
        .padding(.vertical, 9)  // 上下内边距
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)  // 圆角 13
            .fill(LinearGradient(colors: [Color(hex: 0xFFF7E8), Color(hex: 0xFFFDF8)],  // 米黄渐变
                                 startPoint: .leading, endPoint: .trailing)))  // 左到右
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)  // 内描边
            .strokeBorder(Color(hex: 0xF3E3C8), lineWidth: 1))  // 浅金边
        .padding(.bottom, 10)  // 下间距
    }  // foodBar 结束

    private var actions: some View {  // 三个按钮（照样板 .pet-actions 的 1.4 : 1 : 1）
        GeometryReader { geo in  // 拿整行宽度自己分配，避免 layoutPriority 把后两个压成 0
            let gap: CGFloat = 8  // 按钮间距（样板 gap 8）
            let usable = geo.size.width - gap * 2  // 减掉两个间距
            let mainW = usable * (1.4 / 3.4)  // 主按钮占 1.4 份
            let sideW = usable * (1.0 / 3.4)  // 次按钮各占 1 份

            HStack(spacing: gap) {  // 横排
                Button {  // 打卡陪伴
                    if app.checkIn() {  // 打卡成功
                        jumpToken += 1  // 跳一下
                        show("打卡成功 · 连续 \(app.data.streakDays) 天")  // 提示
                    } else {  // 今天已经打过
                        show("今天已经陪过了")  // 提示
                    }  // 分支结束
                } label: {  // 主按钮外观
                    Text("打卡陪伴")  // 文案（样板原话）
                        .font(.system(size: 13, weight: .semibold))  // 13 号
                        .foregroundStyle(.white)  // 白字
                        .frame(width: mainW, height: 40)  // 固定宽高
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                            .fill(LinearGradient(colors: [Color.appBrand, Color(hex: 0x4A72F5)],  // 品牌蓝渐变
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))  // 对角
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式

                Button {  // 投喂
                    handleFeed()  // 走唯一写入口
                } label: {  // 按钮外观
                    Text("投喂 · 1 份")  // 文案（样板原话）
                        .font(.system(size: 13, weight: .semibold))  // 13 号
                        .foregroundStyle(app.pet.food > 0 ? Color.appBrand : Color.textTertiary)  // 没口粮变灰
                        .frame(width: sideW, height: 40)  // 固定宽高
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                            .fill(Color.appCard))  // 白底
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 描边
                            .strokeBorder(Color.separator, lineWidth: 1))  // 细线
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式

                Button {  // 逗一下
                    jumpToken += 1  // 跳一下
                    show("它跳了一下")  // 提示
                } label: {  // 按钮外观
                    Text("逗一下")  // 文案（样板原话）
                        .font(.system(size: 13, weight: .semibold))  // 13 号
                        .foregroundStyle(Color.appBrand)  // 品牌蓝
                        .frame(width: sideW, height: 40)  // 固定宽高
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
                            .fill(Color.appCard))  // 白底
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 描边
                            .strokeBorder(Color.separator, lineWidth: 1))  // 细线
                }  // 按钮结束
                .buttonStyle(.plain)  // 去掉系统样式
            }  // 横排结束
            .padding(.vertical, 2)  // 上下微调
        }  // 几何读取结束
        .frame(height: 44)  // 整行高度
    }  // actions 结束

    private func entryRow(icon: String, title: String, subtitle: String,  // 入口行
                          tint: Color, bg: [Color]) -> some View {  // 图标色与渐变底
        HStack(spacing: 11) {  // 横向排列
            Image(systemName: icon)  // 图标
                .font(.system(size: 15))  // 图标大小
                .foregroundStyle(tint == Color.appBrand ? .white : tint)  // 品牌蓝用白图标
                .frame(width: 34, height: 34)  // 34 方块（样板 .ce-icon）
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)  // 圆角 11
                    .fill(tint == Color.appBrand ? Color.appBrand : tint.opacity(0.14)))  // 品牌蓝实底
            VStack(alignment: .leading, spacing: 1) {  // 文字区
                Text(title)  // 主标题
                    .font(.system(size: 12.5, weight: .semibold))  // 12.5 号
                    .foregroundStyle(Color.textPrimary)  // 主色
                Text(subtitle)  // 副标题
                    .font(.system(size: 10))  // 10 号
                    .foregroundStyle(Color.textSecondary)  // 次要色
            }  // 竖排结束
            Spacer(minLength: 0)  // 撑开
            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 12, weight: .semibold))  // 图标
                .foregroundStyle(Color(hex: 0xC9C9CE))  // 浅灰
        }  // 横排结束
        .padding(.horizontal, 13)  // 左右
        .padding(.vertical, 11)  // 上下
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角 14
            .fill(LinearGradient(colors: bg, startPoint: .leading, endPoint: .trailing)))  // 渐变底
        .padding(.top, 8)  // 与上一块留 8
    }  // entryRow 结束

    private func handleFeed() {  // 处理投喂
        if app.pet.starved {  // 已经饿死
            if app.pet.food > 0 {  // 还有口粮
                app.revivePet()  // 先唤醒
                jumpToken += 1  // 跳一下
                show("伙伴已唤醒")  // 提示
            } else {  // 没口粮
                show("没有口粮，先去闯关")  // 提示
            }  // 分支结束
            return  // 结束
        }  // 分支结束
        switch app.feedPet() {  // 调唯一写入口
        case let .ok(energy, affinity):  // 成功
            jumpToken += 1  // 吃到东西跳一下
            show("投喂成功 · 精力 \(energy)，亲密度 \(affinity)")  // 提示结果
        case .noFood:  // 没口粮
            show("口粮不够了，去闯关就能拿到")  // 提示
        case .alreadyFull:  // 已吃饱
            show("已经吃饱了，别浪费口粮")  // 提示
        case .dead:  // 已饿死
            show("伙伴已经饿死，先投喂唤醒")  // 提示
        }  // 分支结束
    }  // handleFeed 结束

    private func show(_ text: String) {  // 弹提示
        withAnimation { toast = text }  // 淡入
        Task {  // 异步延时
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 等 1.8 秒
            withAnimation { toast = nil }  // 淡出
        }  // 任务结束
    }  // show 结束
}  // CompanionHomeView 结束

// MARK: - 圆角只切指定角                                                // 分节：工具

/// SwiftUI 的 RoundedRectangle 四角一样圆，样板气泡是「左上角尖」，
/// 所以这里用 UIBezierPath 自己切三个角。
struct RoundedCorner: Shape {  // 只圆指定角
    var radius: CGFloat  // 圆角半径
    var corners: UIRectCorner  // 要圆的角

    func path(in rect: CGRect) -> Path {  // 生成路径
        let path = UIBezierPath(roundedRect: rect,  // 矩形
                                byRoundingCorners: corners,  // 指定角
                                cornerRadii: CGSize(width: radius, height: radius))  // 半径
        return Path(path.cgPath)  // 转成 SwiftUI 路径
    }  // path 结束
}  // RoundedCorner 结束
