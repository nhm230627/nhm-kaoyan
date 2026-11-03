//  RitualView.swift —— 拨穗礼成证书页                              // 文件说明
//  严格照样板 page-ritual 与 world.js 的时序：出页面 260ms 后流苏从右拨到左，
//  同时撒彩带，再过 900ms 弹出礼成证书；「收下证书」亲密度 +8 并关闭。
//  帽子是 2D 矢量绘制，照抄样板 SVG 的 240 乘 200 坐标系，与 3D 宠物解耦。 // 设计说明

import SwiftUI  // 界面框架
import Foundation  // 三角函数

// MARK: - 彩带                                                        // 分节：彩带

private struct ConfettiPiece {  // 一片彩带
    let x: CGFloat  // 横向位置比例 0 到 1
    let color: Color  // 颜色
    let w: CGFloat  // 宽度基准
    let delay: Double  // 延迟秒
    let dur: Double  // 下落时长秒
}  // ConfettiPiece 结束

private struct SeededRNG: RandomNumberGenerator {  // 固定种子随机数，保证彩带布局稳定
    private var state: UInt64  // 内部状态
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }  // 种子为零换常量
    mutating func next() -> UInt64 {  // 产生下一个 64 位随机数
        state = state &* 6364136223846793005 &+ 1442695040888963407  // 线性同余推进
        var z = state  // 取当前状态
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9  // 混淆一
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB  // 混淆二
        return z ^ (z >> 31)  // 输出散列
    }  // next 结束
}  // SeededRNG 结束

private struct ConfettiView: View {  // 下落彩带层
    let start: Date  // 开始时间
    let pieces: [ConfettiPiece]  // 彩带集合
    var body: some View {  // 视图主体
        TimelineView(.animation) { timeline in  // 逐帧刷新
            Canvas { ctx, size in  // 用画布逐片绘制
                let t0 = timeline.date.timeIntervalSince(start)  // 已过秒数
                for p in pieces {  // 逐片
                    let t = t0 - p.delay  // 扣掉延迟
                    if t <= 0 { continue }  // 还没开始
                    let prog = t / p.dur  // 进度
                    if prog >= 1 { continue }  // 已落完
                    let y = -16 + CGFloat(prog) * (size.height + 32)  // 纵向位移
                    var c = ctx  // 拷贝上下文
                    c.translateBy(x: p.x * size.width, y: y)  // 移到落点
                    c.rotate(by: .degrees(Double(prog) * 520))  // 边落边转
                    let rect = CGRect(x: -p.w / 2, y: 0, width: p.w, height: p.w * 1.6)  // 单片矩形
                    let alpha = prog < 0.12 ? prog / 0.12 : (prog > 0.85 ? (1 - prog) / 0.15 : 1)  // 淡入淡出
                    c.fill(Path(rect), with: .color(p.color.opacity(alpha)))  // 填充
                }  // 遍历结束
            }  // 画布结束
        }  // 时间线结束
        .allowsHitTesting(false)  // 不挡点击
    }  // body 结束
}  // ConfettiView 结束

// MARK: - 学士帽                                                      // 分节：帽子

private struct GraduationCap: View {  // 2D 学士帽矢量图
    var angle: Double  // 流苏旋转角度 0 到 92
    var body: some View {  // 视图主体
        Color.clear  // 用透明色定尺寸
            .aspectRatio(240.0 / 200.0, contentMode: .fit)  // 固定 240 比 200
            .overlay(  // 覆盖画布
                Canvas { ctx, size in  // 画布绘制
                    draw(ctx, size: size)  // 交给绘制函数
                }  // 画布结束
            )  // 覆盖结束
    }  // body 结束

    private func draw(_ ctx: GraphicsContext, size: CGSize) {  // 绘制全部图层
        let s = size.width / 240  // 统一缩放
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }  // 坐标换算
        func rot(_ p: CGPoint, _ c: CGPoint, _ deg: Double) -> CGPoint {  // 绕点旋转
            let r = deg * .pi / 180  // 转弧度
            let dx = p.x - c.x  // 横差
            let dy = p.y - c.y  // 纵差
            return CGPoint(x: c.x + dx * cos(r) - dy * sin(r),  // 旋转后横
                           y: c.y + dx * sin(r) + dy * cos(r))  // 旋转后纵
        }  // rot 结束
        let capC = pt(120, 84)  // 帽顶纽扣中心
        let frC = pt(178, 140)  // 穗子转轴

        ctx.fill(Path(ellipseIn: CGRect(x: 48 * s, y: 167 * s, width: 144 * s, height: 22 * s)),  // 地面阴影
                 with: .color(Color(hex: 0x1E2846).opacity(0.10)))  // 淡蓝黑
        var band = Path()  // 帽箍路径
        band.move(to: pt(78, 132))  // 左端
        band.addQuadCurve(to: pt(162, 132), control: pt(120, 118))  // 上弧
        band.addLine(to: pt(162, 150))  // 右下
        band.addQuadCurve(to: pt(78, 150), control: pt(120, 164))  // 下弧
        band.closeSubpath()  // 闭合
        ctx.fill(band, with: .linearGradient(Gradient(colors: [Color(hex: 0x232C4C), Color(hex: 0x0F1526)]),  // 帽箍渐变
                                             startPoint: pt(0, 132), endPoint: pt(0, 150)))  // 上到下
        var board = Path()  // 帽板路径
        board.move(to: pt(120, 84))  // 顶点
        board.addLine(to: pt(192, 118))  // 右角
        board.addLine(to: pt(120, 152))  // 底点
        board.addLine(to: pt(48, 118))  // 左角
        board.closeSubpath()  // 闭合
        ctx.fill(board, with: .linearGradient(Gradient(colors: [Color(hex: 0x39456B), Color(hex: 0x141B30)]),  // 帽板渐变
                                              startPoint: pt(48, 84), endPoint: pt(192, 152)))  // 左上到右下
        ctx.stroke(board, with: .color(.white.opacity(0.10)), lineWidth: 1.2 * s)  // 细高光边
        ctx.fill(Path(ellipseIn: CGRect(x: 114.6 * s, y: 78.6 * s, width: 10.8 * s, height: 10.8 * s)),  // 帽顶纽扣
                 with: .color(Color(hex: 0xFFC93C)))  // 金色

        let r0 = rot(pt(120, 84), capC, angle)  // 杆起点
        let r1 = rot(pt(176, 112), capC, angle)  // 杆折点
        let r2 = rot(pt(178, 134), capC, angle)  // 杆末梢
        var rod = Path()  // 流苏杆
        rod.move(to: r0)  // 起点
        rod.addLine(to: r1)  // 折点
        rod.addLine(to: r2)  // 末梢
        ctx.stroke(rod, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFB020), Color(hex: 0xE03A2F)]),  // 金到红
                                              startPoint: r0, endPoint: r2),  // 沿杆方向
                   style: StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round))  // 圆头圆角

        func fringe(_ p: CGPoint) -> CGPoint { rot(rot(p, frC, -angle), capC, angle) }  // 穗子点：先反向再整体
        let ring = fringe(pt(178, 136))  // 金环中心
        ctx.fill(Path(ellipseIn: CGRect(x: ring.x - 4.4 * s, y: ring.y - 4.4 * s,  // 金环矩形
                                        width: 8.8 * s, height: 8.8 * s)),  // 尺寸
                 with: .color(Color(hex: 0xFFC93C)))  // 金色
        let ends: [(Double, Double)] = [(-7, 158), (-2.4, 159), (2.4, 159),  // 六根穗末端
                                        (7, 158), (-4.8, 159.5), (4.8, 159.5)]  // 后三根
        var strands = Path()  // 穗线
        let origin = fringe(pt(178, 140))  // 穗线起点
        for (dx, dy) in ends {  // 逐根
            strands.move(to: origin)  // 起点
            strands.addLine(to: fringe(pt(178 + dx, dy)))  // 终点
        }  // 遍历结束
        ctx.stroke(strands, with: .color(Color(hex: 0xE03A2F)),  // 红色
                   style: StrokeStyle(lineWidth: 3.6 * s, lineCap: .round))  // 圆头
    }  // draw 结束
}  // GraduationCap 结束

// MARK: - 礼成页                                                      // 分节：礼成页

struct RitualView: View {  // 拨穗礼成证书页
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 关闭

    @State private var swept = false  // 流苏是否已拨，控制文案
    @State private var angle: Double = 0  // 流苏旋转角度，驱动动画
    @State private var showCert = false  // 证书是否出现
    @State private var confettiAt: Date? = nil  // 彩带开始时间

    private var displayName: String { "备考中的你" }  // 证书名字，App 无姓名体系，照样板缺省
    private var examYear: Int { Calendar.current.component(.year, from: Date()) + 1 }  // 考试年份取次年
    private var certDate: String {  // 证书落款年月
        let c = Calendar.current.dateComponents([.year, .month], from: Date())  // 取年月
        return String(format: "%d-%02d", c.year ?? 2026, c.month ?? 6)  // 补零拼接
    }  // certDate 结束
    private var seed: Int {  // 编号种子，照 world.js 的 hash
        var h: Int32 = 0  // 累加器
        for u in displayName.utf16 { h = h &* 31 &+ Int32(bitPattern: UInt32(u)) }  // 31 进制
        return abs(Int(h)) % 9000 + 1000  // 取 1000 到 9999
    }  // seed 结束
    private var certNo: String { "MT-\(examYear)-\(seed)" }  // 证书编号

    private var pieces: [ConfettiPiece] {  // 26 片彩带，样板同量
        let colors: [Color] = [Color(hex: 0xFFB020), Color(hex: 0xE03A2F), Color(hex: 0x2B54E8),  // 配色前三
                               Color(hex: 0x0F9D58), Color(hex: 0x7C4DFF), Color(hex: 0xFF5C8A)]  // 配色后三
        var rng = SeededRNG(seed: 2027)  // 固定种子
        return (0..<26).map { i in  // 逐片生成
            ConfettiPiece(x: CGFloat.random(in: 0...1, using: &rng),  // 横向随机
                          color: colors[i % colors.count],  // 轮换配色
                          w: 4 + CGFloat.random(in: 0...4, using: &rng),  // 宽 4 到 8
                          delay: Double.random(in: 0...0.7, using: &rng),  // 延迟 0 到 0.7
                          dur: 2.1 + Double.random(in: 0...1.4, using: &rng))  // 时长 2.1 到 3.5
        }  // 映射结束
    }  // pieces 结束

    var body: some View {  // 视图主体
        ZStack {  // 叠放
            LinearGradient(colors: [Color(hex: 0xFFFDF7), Color(hex: 0xFBF7EF)],  // 米白底
                           startPoint: .top, endPoint: .bottom)  // 上到下
                .ignoresSafeArea()  // 铺满
            VStack(spacing: 0) {  // 纵向排列
                Spacer(minLength: 10)  // 顶部留白
                GraduationCap(angle: angle)  // 帽子
                    .frame(maxWidth: 260)  // 最宽 260
                    .padding(.horizontal, 24)  // 左右留白
                VStack(spacing: 3) {  // 标题区
                    Text(swept ? "恭喜上岸" : "拨穗礼成")  // 主标题
                        .font(.system(size: 26, weight: .heavy))  // 26 号加粗
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xB06A12), Color(hex: 0xE2402F), Color(hex: 0x7C4DFF)],  // 渐变字
                                                        startPoint: .leading, endPoint: .trailing))  // 左到右
                    Text(swept ? "\(examYear) 届 · \(app.currentTrack.name)" : "流苏自右拨至左，寓意学有所成")  // 副标题
                        .font(.system(size: 11.5))  // 小字
                        .foregroundStyle(Color(hex: 0x8A7A63))  // 暖灰
                }  // 标题区结束
                .padding(.top, 6)  // 与帽拉开
                certCard  // 证书
                    .opacity(showCert ? 1 : 0)  // 未到时间隐藏
                    .offset(y: showCert ? 0 : 14)  // 上浮
                    .scaleEffect(showCert ? 1 : 0.97)  // 微放大
                    .padding(.top, 16)  // 与标题拉开
                Spacer(minLength: 8)  // 底部留白
                footer  // 两个按钮
            }  // 排列结束
            if let confettiAt {  // 有彩带才开始
                ConfettiView(start: confettiAt, pieces: pieces)  // 彩带层
                    .ignoresSafeArea()  // 铺满
            }  // 分支结束
        }  // 叠放结束
        .onAppear { replay() }  // 进来就演一遍
    }  // body 结束

    private var certCard: some View {  // 礼成证书卡
        ZStack(alignment: .topTrailing) {  // 叠放印章
            VStack(alignment: .leading, spacing: 0) {  // 正文
                Text("\(examYear) 年全国硕士研究生招生考试")  // 抬头顶行
                    .font(.system(size: 9.5))  // 很小
                    .tracking(1.2)  // 字距
                    .foregroundStyle(Color(hex: 0xA98A5C))  // 金棕
                Text(displayName)  // 名字
                    .font(.system(size: 20, weight: .heavy))  // 20 号加粗
                    .foregroundStyle(Color(hex: 0x2B2F3A))  // 深墨
                    .padding(.top, 7)  // 上距
                    .padding(.bottom, 4)  // 下距
                certLine  // 授予学位行
                    .lineSpacing(2)  // 行距
                HStack {  // 编号与日期
                    Text("证书编号 \(certNo)")  // 编号
                    Spacer()  // 撑开
                    Text(certDate)  // 日期
                }  // 排列结束
                .font(.system(size: 9.5))  // 很小
                .foregroundStyle(Color(hex: 0xA98A5C))  // 金棕
                .padding(.top, 10)  // 上距
            }  // 正文结束
            .padding(EdgeInsets(top: 15, leading: 16, bottom: 13, trailing: 16))  // 内边距
            Text("上岸")  // 印章字
                .font(.system(size: 13, weight: .heavy))  // 13 号加粗
                .tracking(1)  // 字距
                .foregroundStyle(Color(hex: 0xD94A3A))  // 朱红
                .frame(width: 52, height: 52)  // 圆形尺寸
                .overlay(Circle().stroke(Color(hex: 0xD94A3A), lineWidth: 2))  // 圆边
                .rotationEffect(.degrees(-14))  // 斜盖
                .opacity(0.82)  // 略淡
                .padding(.trailing, 14)  // 右距
                .padding(.top, 42)  // 下移到正文右侧
        }  // 叠放结束
        .frame(maxWidth: 330)  // 最宽 330
        .background(  // 卡片底
            RoundedRectangle(cornerRadius: 16, style: .continuous)  // 圆角
                .fill(LinearGradient(colors: [Color(hex: 0xFFFDF7), .white],  // 暖白渐变
                                     startPoint: .topLeading, endPoint: .bottom))  // 对角
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)  // 描边
                    .stroke(Color(hex: 0xEEE2CB), lineWidth: 1))  // 米金边
        )  // 背景结束
        .shadow(color: Color(hex: 0x503C14).opacity(0.28), radius: 22, y: 14)  // 柔和投影
        .padding(.horizontal, 18)  // 左右留白
        .accessibilityElement(children: .combine)  // 证书整体朗读
    }  // certCard 结束

    private var certLine: Text {  // 授予学位行
        var s = AttributedString("经复试考核合格，授予 ")  // 前半
        s.foregroundColor = Color(hex: 0x5B5347)  // 褐灰
        var d = AttributedString(app.currentTrack.degree)  // 学位名跟方向走
        d.foregroundColor = Color(hex: 0x8A4B06)  // 深棕强调
        d.font = .system(size: 11.5, weight: .bold)  // 加粗
        var t = AttributedString(" 学位")  // 后半
        t.foregroundColor = Color(hex: 0x5B5347)  // 褐灰
        s.append(d)  // 接学位名
        s.append(t)  // 接后半
        return Text(s)  // 转成可拼接的 Text
    }  // certLine 结束

    private var footer: some View {  // 底部两按钮
        GeometryReader { g in  // 取宽度算 1 比 1.3
            let total = g.size.width - 10  // 减去间距
            HStack(spacing: 10) {  // 横排
                GhostButton(title: "再拨一次") { replay() }  // 重播
                    .frame(width: total / 2.3)  // 占 1 份
                PrimaryButton(title: "收下证书", systemImage: "checkmark.seal") { finish() }  // 收下
                    .frame(width: total * 1.3 / 2.3)  // 占 1.3 份
            }  // 排列结束
        }  // 几何结束
        .frame(height: 48)  // 固定高
        .padding(.horizontal, 18)  // 左右留白
    }  // footer 结束

    private func replay() {  // 再拨一次
        angle = 0  // 复位流苏角度
        swept = false  // 复位文案
        showCert = false  // 收起证书
        confettiAt = nil  // 清彩带
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {  // 260ms 后
            swept = true  // 切文案
            withAnimation(.spring(response: 1.15, dampingFraction: 0.55)) { angle = 92 }  // 拨穗动画
            confettiAt = Date()  // 起彩带
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {  // 再 900ms
                withAnimation(.easeOut(duration: 0.45)) { showCert = true }  // 亮证书
            }  // 内层结束
        }  // 外层结束
    }  // replay 结束

    private func finish() {  // 收下证书
        app.addAffinity(8)  // 亲密度 +8，照样板
        dismiss()  // 关掉
    }  // finish 结束
}  // RitualView 结束
