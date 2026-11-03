//  PlazaView.swift —— 广场（宠物公共空间，对齐样板 page-plaza / plaza.js）    // 文件说明
//  这里不是帖子流，是一张「在场」的画布：多只宠物同场走动、搭话、组队刷副本。
//  结构照样板：画布 + 顶部在线/返回/论坛/地图 + 世界频道跑马灯 + 点宠物出卡片 +
//  底部发言条 + 组队弹层。数值与几何全部照 plaza.js 抄（地平线 40%、透视 0.62~1.24）。// 设计说明
//  ⚠️ 诚实边界：画布里的 11 位研友是样板写死的样例数据（plaza.js 的 BOTS），
//     不是真实在线用户；真要让「别人的宠物」上线，需要阶段 6 的服务端同场同步。
//     所以顶部写的是「样例研友」，不写「128 人在线」这种假数字。            // 诚实边界

import SwiftUI  // 界面框架
import Foundation  // 时间与数学
import Observation  // @Observable 宏

// MARK: - 数据                                                          // 分节：数据

private struct PlazaPalette {  // 一只宠物的配色
    let body: UInt32  // 身体
    let belly: UInt32  // 肚皮
    let cap: UInt32  // 帽子
    let ear: UInt32  // 耳朵与尾巴
}  // PlazaPalette 结束

private struct PlazaPet: Identifiable {  // 广场里的一只宠物
    let id: String  // 唯一 id
    let name: String  // 昵称
    let school: String  // 院校方向
    let lv: Int  // 等级
    var today: Int  // 今日题数
    var days: Int  // 连续天数
    var frd: Int  // 好友数
    let say: String  // 一句话
    var lines: [String]  // 闲聊库
    var help: String?  // 求助内容（有就优先展示）
    let pal: PlazaPalette  // 配色
    var mine = false  // 是不是我自己
    var x: Double = 0  // 当前横坐标
    var y: Double = 0  // 当前纵坐标（脚底）
    var tx: Double = 0  // 目标横坐标
    var ty: Double = 0  // 目标纵坐标
    var sp: Double = 20  // 速度（点每秒）
    var scale: Double = 1  // 透视缩放
    var phase: Double = 0  // 呼吸相位
    var moving = false  // 是否在走
    var wait: Double = 1  // 发呆剩余秒
    var bubble = ""  // 头顶气泡文字
    var until: Double = 0  // 气泡到期时间
}  // PlazaPet 结束

// MARK: - 世界                                                          // 分节：世界

@Observable  // 画布状态变化要驱动重绘
private final class PlazaWorld {  // 广场世界
    var pets: [PlazaPet] = []  // 所有宠物
    var now: Double = 0  // 世界时钟秒
    var selectedID: String?  // 当前选中的宠物
    var tickWho = "上岸的橘子"  // 跑马灯：谁
    var tickText = "增值税那章有没有人一起刷"  // 跑马灯：说了什么
    var toast: String?  // 底部轻提示
    var teamPicks: [String] = []  // 组队弹层里显示的三个人名
    var showTeam = false  // 组队弹层是否打开
    var online = 0  // 画布里的宠物数（真实数量，不是编的在线人数）
    private var feedIndex = 0  // 跑马灯游标
    private var tickAcc = 0.0  // 跑马灯计时
    private var spawned = false  // 是否已经铺过宠物

    static let feed: [(String, String)] = [  // 世界频道文案，照样板 FEED
        ("上岸的橘子", "增值税那章有没有人一起刷"),  // 喊人刷题
        ("二战的老陈", "刚面完模拟面试，被追问留抵退税"),  // 分享经历
        ("税务小张", "视同销售的进项到底能不能抵，求人"),  // 求助
        ("资料搬运工", "42 所院校复试真题目录已更新"),  // 资料
        ("阿May", "海关的题偏实务，关税要单独过"),  // 经验
        ("小林同学", "线上复试千万别用耳机麦"),  // 提醒
        ("小满", "错题按知识点归类后正确率涨了"),  // 方法
        ("复试陪跑", "每天陪练一场面试，坚持 30 天了"),  // 打卡
        ("北方的雪", "吉大综合面试占 40 分，别只准备专业课"),  // 情报
        ("夜猫子阿哲", "在职备考的兄弟在哪"),  // 同类
    ]  // feed 结束

    static let replies = ["一起加油！", "你好，我在这片广场转了好久了", "要不要一起刷一章？", "你题刷得真快"]  // 打招呼回复库

    static let bots: [PlazaPet] = [  // 11 位样例研友，资料照抄样板 BOTS
        PlazaPet(id: "b0", name: "上岸的橘子", school: "西南财经 · 税务专硕", lv: 12, today: 38, days: 26, frd: 9,  // 第一位
                 say: "复试问了我留抵退税，钱从哪来一定要说清楚。", lines: ["有人一起刷增值税那章吗", "今天第 38 题，稳住了"],  // 台词
                 pal: PlazaPalette(body: 0xFFB257, belly: 0xFFE0B8, cap: 0x7A3FF0, ear: 0xF39A3C)),  // 配色
        PlazaPet(id: "b1", name: "二战的老陈", school: "中央财经 · 税务专硕", lv: 15, today: 61, days: 88, frd: 21,  // 第二位
                 say: "去年败在英语听说，今年每天早读 20 分钟。", lines: ["英语听说真的能练出来", "别背模板，老师一听就知道"],  // 台词
                 pal: PlazaPalette(body: 0x9FB4D8, belly: 0xDBE5F6, cap: 0x2B54E8, ear: 0x8299C2)),  // 配色
        PlazaPet(id: "b2", name: "税务小张", school: "中南财经政法 · 税务", lv: 9, today: 24, days: 12, frd: 6,  // 第三位
                 say: "视同销售和进项转出老是搞混，谁帮我理一下。", lines: ["视同销售的进项到底能不能抵", "求一份消费税的税率表"],  // 台词
                 help: "企业把自产货物用于集体福利，进项还能抵扣吗？",  // 求助
                 pal: PlazaPalette(body: 0x8FD6B4, belly: 0xD8F3E6, cap: 0x0F9D58, ear: 0x6EC29B)),  // 配色
        PlazaPet(id: "b3", name: "小林同学", school: "东北财经 · 财政学", lv: 7, today: 19, days: 9, frd: 4,  // 第四位
                 say: "刚面完线上复试，摄像头一定要提前试。", lines: ["线上复试千万别用耳机麦", "自我介绍控制在 2 分钟"],  // 台词
                 pal: PlazaPalette(body: 0xF2A0C0, belly: 0xFFD9E7, cap: 0xE8487F, ear: 0xDD87AB)),  // 配色
        PlazaPet(id: "b4", name: "资料搬运工", school: "江西财经 · 税务专硕", lv: 20, today: 72, days: 120, frd: 58,  // 第五位
                 say: "40 所院校复试真题目录整理好了，缺答案自己补。", lines: ["真题目录已更新到 42 所", "要资料的报一下院校"],  // 台词
                 pal: PlazaPalette(body: 0xA9B0F0, belly: 0xDDE0FB, cap: 0x5433C9, ear: 0x8F96DD)),  // 配色
        PlazaPet(id: "b5", name: "阿May", school: "上海海关学院 · 税务", lv: 11, today: 33, days: 31, frd: 14,  // 第六位
                 say: "海关的题偏实务，关税那部分要单独过一遍。", lines: ["关税完税价格这题谁会", "组队吗，我要刷所得税"],  // 台词
                 pal: PlazaPalette(body: 0xFFD166, belly: 0xFFF0C4, cap: 0xE8890C, ear: 0xE8B93F)),  // 配色
        PlazaPet(id: "b6", name: "夜猫子阿哲", school: "山东财经 · 税务专硕", lv: 6, today: 15, days: 7, frd: 3,  // 第七位
                 say: "凌晨两点还在刷题，白天上班真的顶不住。", lines: ["在职备考的兄弟在哪", "每天只能挤两小时"],  // 台词
                 pal: PlazaPalette(body: 0xB8C0CC, belly: 0xE6EBF2, cap: 0x3B4157, ear: 0x9AA3B1)),  // 配色
        PlazaPet(id: "b7", name: "小满", school: "浙江财经 · 税务专硕", lv: 10, today: 29, days: 21, frd: 11,  // 第八位
                 say: "把错题按知识点归类后，正确率涨了 15 个点。", lines: ["错题一定要归类", "重复错的题才是真不会"],  // 台词
                 pal: PlazaPalette(body: 0xFFC9A3, belly: 0xFFE7D6, cap: 0xFF6B4A, ear: 0xF0AB7D)),  // 配色
        PlazaPet(id: "b8", name: "复试陪跑", school: "首都经贸 · 税务专硕", lv: 8, today: 21, days: 15, frd: 8,  // 第九位
                 say: "每天陪练一场模拟面试，坚持 30 天了。", lines: ["有人来互练面试吗", "面试完一定要复盘"],  // 台词
                 pal: PlazaPalette(body: 0x9FD8E8, belly: 0xDCF3F9, cap: 0x0B84A8, ear: 0x7FC2D6)),  // 配色
        PlazaPet(id: "b9", name: "北方的雪", school: "吉林大学 · 税务专硕", lv: 13, today: 44, days: 40, frd: 17,  // 第十位
                 say: "吉大综合面试 100 分，综合素质占 40，别只准备专业课。", lines: ["综合素质那 40 分最好拿", "政审问题也要提前想"],  // 台词
                 pal: PlazaPalette(body: 0xC9D4FF, belly: 0xE8ECFF, cap: 0x4B5BD6, ear: 0xA5B3F5)),  // 配色
        PlazaPet(id: "b10", name: "深圳小老板", school: "暨南大学 · 税务专硕", lv: 5, today: 11, days: 5, frd: 2,  // 第十一位
                 say: "边看店边备考，一天能刷十道就算赢。", lines: ["时间不够就先抓专业课", "真题比教材有用"],  // 台词
                 help: "工作证明和社保证明到底要不要一起交？",  // 求助
                 pal: PlazaPalette(body: 0xFFB3B3, belly: 0xFFDEDE, cap: 0xC0392B, ear: 0xEA9090)),  // 配色
    ]  // bots 结束

    func pet(_ id: String?) -> PlazaPet? {  // 按 id 找宠物
        guard let id else { return nil }  // 没 id
        return pets.first { $0.id == id }  // 找到就返回
    }  // pet 结束

    var me: PlazaPet? { pets.first { $0.mine } }  // 我自己

    func scaleAt(_ y: Double, height: Double) -> Double {  // 透视缩放，照样板
        let a = height * 0.40 + 30  // 地平线下 30
        let b = height - 6  // 屏幕底
        let k = max(0, min(1, (y - a) / max(1, b - a)))  // 归一位置
        return 0.62 + k * 0.62  // 0.62 到 1.24
    }  // scaleAt 结束

    func spawn(size: CGSize, myName: String, todayAnswered: Int, streak: Int) {  // 铺开宠物
        guard !spawned, size.width > 0 else { return }  // 只铺一次
        spawned = true  // 标记
        let h = Double(size.height)  // 高度（转 Double，后面全是浮点运算）
        let w = Double(size.width)  // 宽度
        let horizon = h * 0.40  // 地平线
        var list: [PlazaPet] = []  // 结果
        var mePet = PlazaPet(id: "me", name: myName, school: "我的宠物 · 小税", lv: 1,  // 造我
                             today: todayAnswered, days: max(1, streak), frd: 0,  // 真实数据
                             say: "我在广场里，点我一下试试。", lines: [],  // 台词
                             pal: PlazaPalette(body: 0xFFD166, belly: 0xFFF1C9, cap: 0xD23B3B, ear: 0xE8B93F))  // 配色
        mePet.mine = true  // 标记是我
        mePet.x = w * 0.5  // 站中间
        mePet.y = h * 0.82  // 站近处
        mePet.tx = mePet.x  // 目标同点
        mePet.ty = mePet.y  // 目标同点
        mePet.sp = 32  // 走得快
        mePet.scale = scaleAt(mePet.y, height: h)  // 透视
        list.append(mePet)  // 加进来

        let cols = 4  // 四列
        let rows = 3  // 三行
        let top = horizon + 56  // 最远一排
        let bottom = h - 70  // 最近一排
        let cellW = (w - 40) / Double(cols)  // 格宽
        let cellH = (bottom - top) / Double(rows)  // 格高
        for (i, var b) in Self.bots.enumerated() {  // 逐个摆位
            let cc = i % cols  // 第几列
            let rr = (i / cols) % rows  // 第几行
            let jitterX = Double.random(in: -0.21...0.21) * cellW * 2  // 横向抖动
            let jitterY = Double.random(in: -0.17...0.17) * cellH * 2  // 纵向抖动
            b.x = min(w - 24, max(24, 20 + cellW * (Double(cc) + 0.5) + jitterX))  // 落位
            b.y = min(bottom, max(top, top + cellH * (Double(rr) + 0.5) + jitterY))  // 落位
            b.tx = b.x  // 目标同点
            b.ty = b.y  // 目标同点
            b.sp = Double.random(in: 12...28)  // 速度随机
            b.phase = Double.random(in: 0...6.28)  // 相位随机
            b.wait = Double.random(in: 0...2.4)  // 初始发呆
            b.scale = scaleAt(b.y, height: h)  // 透视
            list.append(b)  // 加进来
        }  // 遍历结束
        pets = list  // 写入
        online = list.count  // 真实数量
    }  // spawn 结束

    func step(_ dt: Double, size: CGSize) {  // 推进一帧
        now += dt  // 世界时钟
        let w = Double(size.width)  // 宽（转 Double）
        let h = Double(size.height)  // 高（转 Double）
        let horizon = h * 0.40  // 地平线
        for i in pets.indices {  // 逐只更新
            let dx = pets[i].tx - pets[i].x  // 横向差
            let dy = pets[i].ty - pets[i].y  // 纵向差
            let dist = (dx * dx + dy * dy).squareRoot()  // 距离
            if dist > 3 {  // 还没到
                pets[i].moving = true  // 标记在走
                let k = pets[i].sp * dt / dist  // 步进比例
                pets[i].x += dx * k  // 前进
                pets[i].y += dy * k  // 前进
                pets[i].scale = scaleAt(pets[i].y, height: h)  // 更新透视
            } else {  // 到了
                pets[i].moving = false  // 站住
                pets[i].wait -= dt  // 发呆倒计时
                if pets[i].wait <= 0 {  // 到点换目标
                    pets[i].wait = Double.random(in: 1.4...5.0)  // 下次发呆
                    pets[i].tx = Double.random(in: 24...max(25, w - 24))  // 新目标横向
                    pets[i].ty = Double.random(in: (horizon + 34)...max(horizon + 35, h - 18))  // 新目标纵向
                }  // 分支结束
            }  // 分支结束
            if pets[i].until > 0 && now > pets[i].until {  // 气泡到期
                pets[i].bubble = ""  // 清掉
                pets[i].until = 0  // 复位
            }  // 分支结束
        }  // 遍历结束
        tickAcc += dt  // 跑马灯计时
        if tickAcc >= 4.2 {  // 每 4.2 秒换一条
            tickAcc = 0  // 复位
            feedIndex = (feedIndex + 1) % Self.feed.count  // 下一条
            tickWho = Self.feed[feedIndex].0  // 换人
            tickText = Self.feed[feedIndex].1  // 换话
        }  // 分支结束
    }  // step 结束

    func tap(_ point: CGPoint, size: CGSize) {  // 点画布
        let x = Double(point.x)  // 横坐标
        let y = Double(point.y)  // 纵坐标
        let h = Double(size.height)  // 高度（转 Double）
        var hit: PlazaPet?  // 命中的宠物
        for p in pets {  // 逐个测
            let s = p.scale  // 缩放
            let x0 = p.x - 15 * s  // 左边界
            let x1 = p.x + 15 * s  // 右边界
            let y0 = p.y - 62 * s  // 上边界（含头顶气泡）
            let y1 = p.y + 4 * s  // 下边界
            if x >= x0 && x <= x1 && y >= y0 && y <= y1 {  // 落在这个盒子里
                if hit == nil || p.y > (hit?.y ?? 0) { hit = p }  // 取更靠前的那只
            }  // 分支结束
        }  // 遍历结束
        if let hit {  // 点到宠物
            selectedID = hit.id  // 选中
            if !hit.mine {  // 别人就应一声
                say(id: hit.id, text: "嗯？找我吗", seconds: 2.2)  // 头顶气泡
            }  // 分支结束
        } else {  // 点空地
            selectedID = nil  // 收起卡片
            if y > h * 0.40 + 20 {  // 地平线以下才走
                setMyTarget(x: x, y: y, size: size)  // 我的宠物走过去
            }  // 分支结束
        }  // 分支结束
    }  // tap 结束

    func setMyTarget(x: Double, y: Double, size: CGSize) {  // 让我的宠物走过去
        guard let i = pets.firstIndex(where: { $0.mine }) else { return }  // 找自己
        let w = Double(size.width)  // 宽
        let h = Double(size.height)  // 高
        pets[i].tx = max(24, min(w - 24, x))  // 目标横向
        pets[i].ty = max(h * 0.40 + 30, min(h - 22, y))  // 目标纵向
        pets[i].wait = 0  // 立刻走
    }  // setMyTarget 结束

    func say(id: String, text: String, seconds: Double) {  // 头顶气泡
        guard let i = pets.firstIndex(where: { $0.id == id }) else { return }  // 找宠物
        pets[i].bubble = text  // 写文字
        pets[i].until = now + seconds  // 到期时间
    }  // say 结束

    func greet() {  // 打个招呼
        guard let p = pet(selectedID), let i = pets.firstIndex(where: { $0.id == p.id }) else { return }  // 找选中的
        let line = p.mine ? "自己跟自己打了个招呼" : (Self.replies.randomElement() ?? "一起加油！")  // 随机回复
        pets[i].bubble = line  // 气泡
        pets[i].until = now + 3.2  // 3.2 秒
        toast = p.mine ? "你跟自己打了个招呼" : "已跟 \(p.name) 打招呼"  // 提示
        tickWho = "你"  // 世界频道
        tickText = "跟 \(p.mine ? "自己" : p.name) 打了个招呼"  // 世界频道
    }  // greet 结束

    func openTeam(with id: String?) {  // 打开组队弹层
        let pool = pets.filter { !$0.mine }  // 可组队的人
        let first = pet(id).flatMap { $0.mine ? nil : $0 } ?? pool.randomElement()  // 首选
        let rest = pool.filter { $0.id != first?.id }  // 剩下的人
        var picks = ["你"]  // 队长是我
        if let f = first { picks.append(f.name) }  // 第一位队友
        if let r = rest.randomElement() { picks.append(r.name) }  // 第二位队友
        teamPicks = picks  // 写入
        showTeam = true  // 打开
    }  // openTeam 结束

    func sendMine(_ text: String, size: CGSize) {  // 我在广场发言
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 去空白
        guard !v.isEmpty else { return }  // 空的不管
        if let i = pets.firstIndex(where: { $0.mine }) {  // 我说话
            pets[i].bubble = v  // 我的气泡
            pets[i].until = now + 4.2  // 4.2 秒
            let near = pets.filter { !$0.mine }.min { a, b in  // 最近的一位研友
                hypot(a.x - pets[i].x, a.y - pets[i].y) < hypot(b.x - pets[i].x, b.y - pets[i].y)  // 比距离
            }  // 找最近
            if let near, let j = pets.firstIndex(where: { $0.id == near.id }) {  // 有人接话
                pets[j].bubble = Self.replies.randomElement() ?? "一起加油！"  // 回一句
                pets[j].until = now + 3.6  // 3.6 秒
                pets[j].tx = pets[i].x + (Bool.random() ? 34 : -34)  // 走近一点
                pets[j].ty = pets[i].y + 8  // 走近一点
                pets[j].wait = 0  // 立刻走
                tickWho = near.name  // 世界频道换人
                tickText = pets[j].bubble  // 世界频道换话
            }  // 分支结束
        }  // 分支结束
        tickWho = "你"  // 我先上频道
        tickText = v  // 我说的话
    }  // sendMine 结束
}  // PlazaWorld 结束

// MARK: - 主界面                                                        // 分节：界面

struct PlazaView: View {  // 广场
    @Environment(AppState.self) private var app  // 全局状态
    @Environment(\.dismiss) private var dismiss  // 返回

    @State private var world = PlazaWorld()  // 画布世界
    @State private var stage: CGSize = .zero  // 画布尺寸
    @State private var draft = ""  // 输入框内容
    @State private var goDungeon = false  // 是否进副本

    private var selected: PlazaPet? { world.pet(world.selectedID) }  // 选中的宠物

    var body: some View {  // 视图主体
        GeometryReader { geo in  // 取整屏尺寸
            ZStack(alignment: .top) {  // 叠放
                stageCanvas(size: geo.size)  // 画布
                topBar  // 顶部条
                ticker  // 世界频道
                if let p = selected {  // 选中才出卡片
                    petCard(p)  // 宠物卡
                }  // 分支结束
                VStack {  // 底部对齐
                    Spacer()  // 撑开
                    bottomBar  // 发言条
                }  // 排列结束
                if world.showTeam {  // 组队弹层
                    teamSheet  // 弹层
                }  // 分支结束
                if let toast = world.toast {  // 轻提示
                    Text(toast)  // 文案
                        .font(.system(size: 12))  // 12 号
                        .foregroundStyle(.white)  // 白字
                        .padding(.horizontal, 14)  // 左右
                        .padding(.vertical, 9)  // 上下
                        .background(Capsule().fill(Color.black.opacity(0.78)))  // 深底
                        .frame(maxHeight: .infinity, alignment: .center)  // 居中
                        .transition(.opacity)  // 淡入淡出
                }  // 分支结束
            }  // 叠放结束
            .onAppear {  // 首次出现
                stage = geo.size  // 记尺寸
                world.spawn(size: geo.size, myName: app.profile.nickname.isEmpty ? "你" : app.profile.nickname,  // 铺宠物
                            todayAnswered: app.todayAnswered, streak: app.streakDays)  // 用真实数据
            }  // 出现结束
            .onChange(of: geo.size) { _, size in  // 尺寸变化
                stage = size  // 更新
                world.spawn(size: size, myName: app.profile.nickname.isEmpty ? "你" : app.profile.nickname,  // 铺宠物
                            todayAnswered: app.todayAnswered, streak: app.streakDays)  // 用真实数据
            }  // 监听结束
            .task {  // 物理循环
                while !Task.isCancelled {  // 一直跑
                    try? await Task.sleep(nanoseconds: 50_000_000)  // 20 帧每秒
                    if stage.width > 0 { world.step(0.05, size: stage) }  // 推进
                }  // 循环结束
            }  // 任务结束
            .onChange(of: world.toast) { _, value in  // 提示自动消失
                guard value != nil else { return }  // 空的不管
                Task {  // 异步清
                    try? await Task.sleep(nanoseconds: 1_900_000_000)  // 1.9 秒
                    world.toast = nil  // 清掉
                }  // 任务结束
            }  // 监听结束
        }  // 几何结束
        .navigationBarBackButtonHidden(true)  // 用自己的返回键
        .fullScreenCover(isPresented: $goDungeon) {  // 进副本
            NavigationStack {  // 套栈
                if let level = SortCatalog.level(SortCatalog.order.first ?? "") {  // 第一关
                    SortGameView(level: level)  // 分拣副本
                        .environment(app)  // 传状态源
                } else {  // 数据没读到
                    EmptyState(icon: "square.grid.3x3", title: "副本数据缺失", message: "sort-levels.json 没打进包里。")  // 空态
                }  // 分支结束
            }  // 栈结束
        }  // 覆盖层结束
    }  // body 结束

    // MARK: 画布                                                       // 分节：画布

    private func stageCanvas(size: CGSize) -> some View {  // 画布本体
        TimelineView(.animation) { _ in  // 每帧重画
            Canvas { ctx, canvasSize in  // 逐层绘制
                draw(ctx, size: canvasSize)  // 交给绘制函数
            }  // 画布结束
        }  // 时间线结束
        .contentShape(Rectangle())  // 整块可点
        .gesture(  // 点击与拖动
            DragGesture(minimumDistance: 0)  // 最短距离 0 即点击
                .onEnded { value in  // 结束时判定
                    world.tap(value.location, size: size)  // 交给世界
                }  // 结束回调
        )  // 手势结束
        .ignoresSafeArea()  // 铺满整屏
        .accessibilityLabel("广场画布，点宠物可以打招呼、加好友、组队")  // 无障碍
    }  // stageCanvas 结束

    private func draw(_ ctx: GraphicsContext, size: CGSize) {  // 分层绘制
        let w = size.width  // 宽
        let h = size.height  // 高
        let horizon = h * 0.40  // 地平线
        drawSky(ctx, w: w, h: h, horizon: horizon)  // 天空
        drawCity(ctx, w: w, horizon: horizon)  // 城市剪影
        drawGround(ctx, w: w, h: h, horizon: horizon)  // 地面
        drawProps(ctx, w: w, h: h, horizon: horizon)  // 树、长椅、路灯
        for pet in world.pets.sorted(by: { $0.y < $1.y }) {  // 由远到近画
            drawPet(ctx, pet: pet)  // 一只
        }  // 遍历结束
    }  // draw 结束

    private func drawSky(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {  // 天空
        let rect = CGRect(x: 0, y: 0, width: w, height: horizon + 22)  // 天空范围
        ctx.fill(Path(rect), with: .linearGradient(  // 渐变填充
            Gradient(colors: [Color(hex: 0x9FD9F6), Color(hex: 0xE8F4FB)]),  // 上蓝下白
            startPoint: CGPoint(x: 0, y: 0),  // 起点
            endPoint: CGPoint(x: 0, y: horizon + 22)))  // 终点
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.16, 0.11, 1.0), (0.55, 0.06, 0.72), (0.86, 0.16, 0.55)]  // 三朵云的位置与缩放
        for (x, y, k) in spots {  // 逐朵
            drawCloud(ctx, x: w * x, y: horizon * y, k: k)  // 一朵
        }  // 遍历结束
    }  // drawSky 结束

    private func drawCloud(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, k: CGFloat) {  // 一朵云
        let white = Color.white.opacity(0.85)  // 云色
        for (dx, dy, r) in [(0.0, 0.0, 16.0), (14.0, 3.0, 12.0), (-14.0, 3.0, 11.0), (4.0, -7.0, 11.0)] {  // 四个圆拼
            let rect = CGRect(x: x + dx * k - r * k, y: y + dy * k - r * k, width: r * 2 * k, height: r * 2 * k)  // 圆范围
            ctx.fill(Path(ellipseIn: rect), with: .color(white))  // 填充
        }  // 遍历结束
    }  // drawCloud 结束

    private func drawCity(_ ctx: GraphicsContext, w: CGFloat, horizon: CGFloat) {  // 城市剪影
        let widths: [CGFloat] = [0.10, 0.08, 0.12, 0.07, 0.11, 0.09, 0.13, 0.08, 0.10, 0.12]  // 楼宽比例
        let heights: [CGFloat] = [0.55, 0.78, 0.42, 0.66, 0.9, 0.5, 0.74, 0.38, 0.62, 0.84]  // 楼高比例
        var x: CGFloat = -10  // 起始横坐标
        for i in 0..<widths.count {  // 逐栋
            let bw = w * widths[i] * 0.9  // 楼宽
            let bh = horizon * heights[i] * 0.9  // 楼高
            let rect = CGRect(x: x, y: horizon - bh, width: bw, height: bh)  // 楼体
            let tone = 0.55 + 0.12 * CGFloat(i % 3)  // 深浅轮换
            ctx.fill(Path(rect), with: .color(Color(hex: 0xB9CBE0).opacity(Double(tone))))  // 填充
            x += bw + w * 0.012  // 下一栋
            if x > w { break }  // 出界就停
        }  // 遍历结束
    }  // drawCity 结束

    private func drawGround(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {  // 地面
        let rect = CGRect(x: 0, y: horizon, width: w, height: h - horizon)  // 地面范围
        ctx.fill(Path(rect), with: .linearGradient(  // 渐变
            Gradient(colors: [Color(hex: 0xDCE8CF), Color(hex: 0xB9CFA6)]),  // 远浅近深
            startPoint: CGPoint(x: 0, y: horizon),  // 起点
            endPoint: CGPoint(x: 0, y: h)))  // 终点
        var line = Path()  // 一条步道
        line.move(to: CGPoint(x: w * 0.42, y: horizon))  // 远处窄
        line.addLine(to: CGPoint(x: w * 0.58, y: horizon))  // 远处窄
        line.addLine(to: CGPoint(x: w * 0.92, y: h))  // 近处宽
        line.addLine(to: CGPoint(x: w * 0.08, y: h))  // 近处宽
        line.closeSubpath()  // 闭合
        ctx.fill(line, with: .color(Color(hex: 0xEFE6D2).opacity(0.9)))  // 铺装
    }  // drawGround 结束

    private func drawProps(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {  // 场景道具
        drawTree(ctx, x: w * 0.10, y: horizon + (h - horizon) * 0.18, k: 0.8)  // 树一
        drawTree(ctx, x: w * 0.90, y: horizon + (h - horizon) * 0.12, k: 0.7)  // 树二
        drawTree(ctx, x: w * 0.78, y: horizon + (h - horizon) * 0.62, k: 1.05)  // 树三
        drawBench(ctx, x: w * 0.20, y: horizon + (h - horizon) * 0.55, k: 0.95)  // 长椅
        drawLamp(ctx, x: w * 0.08, y: horizon + (h - horizon) * 0.78, k: 1.0)  // 路灯
        drawLamp(ctx, x: w * 0.94, y: horizon + (h - horizon) * 0.70, k: 0.95)  // 路灯
    }  // drawProps 结束

    private func drawTree(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, k: CGFloat) {  // 一棵树
        let trunk = CGRect(x: x - 4 * k, y: y - 22 * k, width: 8 * k, height: 22 * k)  // 树干
        ctx.fill(Path(roundedRect: trunk, cornerRadius: 3 * k), with: .color(Color(hex: 0x8A6A45)))  // 填充
        let crown = CGRect(x: x - 20 * k, y: y - 52 * k, width: 40 * k, height: 34 * k)  // 树冠
        ctx.fill(Path(ellipseIn: crown), with: .color(Color(hex: 0x6FBF73)))  // 填充
        let crown2 = CGRect(x: x - 14 * k, y: y - 62 * k, width: 28 * k, height: 26 * k)  // 上层树冠
        ctx.fill(Path(ellipseIn: crown2), with: .color(Color(hex: 0x7FD183)))  // 填充
    }  // drawTree 结束

    private func drawBench(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, k: CGFloat) {  // 一张长椅
        let seat = CGRect(x: x - 22 * k, y: y - 12 * k, width: 44 * k, height: 7 * k)  // 座板
        ctx.fill(Path(roundedRect: seat, cornerRadius: 3 * k), with: .color(Color(hex: 0xC49A6C)))  // 填充
        let back = CGRect(x: x - 22 * k, y: y - 22 * k, width: 44 * k, height: 5 * k)  // 靠背
        ctx.fill(Path(roundedRect: back, cornerRadius: 2 * k), with: .color(Color(hex: 0xC49A6C)))  // 填充
        for dx in [-16.0, 16.0] {  // 两条腿
            let leg = CGRect(x: x + CGFloat(dx) * k - 2 * k, y: y - 6 * k, width: 4 * k, height: 10 * k)  // 腿
            ctx.fill(Path(roundedRect: leg, cornerRadius: 1.5 * k), with: .color(Color(hex: 0x8E6C46)))  // 填充
        }  // 遍历结束
    }  // drawBench 结束

    private func drawLamp(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, k: CGFloat) {  // 一盏路灯
        let pole = CGRect(x: x - 1.5 * k, y: y - 46 * k, width: 3 * k, height: 46 * k)  // 灯杆
        ctx.fill(Path(roundedRect: pole, cornerRadius: 1.5 * k), with: .color(Color(hex: 0x5B6069)))  // 填充
        let head = CGRect(x: x - 7 * k, y: y - 56 * k, width: 14 * k, height: 11 * k)  // 灯罩
        ctx.fill(Path(roundedRect: head, cornerRadius: 4 * k), with: .color(Color(hex: 0xFFE9A8)))  // 暖光
    }  // drawLamp 结束

    private func drawPet(_ ctx: GraphicsContext, pet: PlazaPet) {  // 画一只猫
        let s = CGFloat(pet.scale)  // 缩放
        let bob = pet.moving ? sin(world.now * 6.6 + pet.phase) * 2.2 : sin(world.now * 1.4 + pet.phase) * 0.9  // 呼吸与走动起伏
        let x = CGFloat(pet.x)  // 横向
        let y = CGFloat(pet.y + bob)  // 纵向
        let body = Color(hex: pet.pal.body)  // 身体色
        let belly = Color(hex: pet.pal.belly)  // 肚皮色
        let ear = Color(hex: pet.pal.ear)  // 耳朵色
        let cap = Color(hex: pet.pal.cap)  // 帽色

        if pet.id == world.selectedID {  // 选中的虚线光圈
            let ring = CGRect(x: x - 20 * s, y: CGFloat(pet.y) - 4.4 * s, width: 40 * s, height: 12.8 * s)  // 光圈范围
            ctx.stroke(Path(ellipseIn: ring), with: .color(Color.appBrand.opacity(0.85)),  // 描边
                       style: StrokeStyle(lineWidth: 2, dash: [4, 4]))  // 虚线
        } else if pet.mine {  // 自己的实心淡光圈
            let ring = CGRect(x: x - 20 * s, y: CGFloat(pet.y) - 4.4 * s, width: 40 * s, height: 12.8 * s)  // 光圈范围
            ctx.fill(Path(ellipseIn: ring), with: .color(Color.appBrand.opacity(0.10)))  // 填充
        }  // 分支结束

        let shadow = CGRect(x: x - 13 * s, y: CGFloat(pet.y) - 2 * s, width: 26 * s, height: 8 * s)  // 影子
        ctx.fill(Path(ellipseIn: shadow), with: .color(Color.black.opacity(0.16)))  // 填充

        let tail = CGRect(x: x + 8 * s, y: y - 19 * s, width: 10 * s, height: 6.5 * s)  // 尾巴
        ctx.fill(Path(ellipseIn: tail), with: .color(ear))  // 填充

        let bodyRect = CGRect(x: x - 12 * s, y: y - 26 * s, width: 24 * s, height: 26 * s)  // 身体
        ctx.fill(Path(roundedRect: bodyRect, cornerRadius: 11 * s), with: .color(body))  // 填充
        let bellyRect = CGRect(x: x - 8 * s, y: y - 20.4 * s, width: 16 * s, height: 16.8 * s)  // 肚皮
        ctx.fill(Path(ellipseIn: bellyRect), with: .color(belly))  // 填充

        for dx in [-6.0, 6.0] {  // 两只脚
            let foot = CGRect(x: x + CGFloat(dx) * s - 4.4 * s, y: y - 4 * s, width: 8.8 * s, height: 6 * s)  // 脚
            ctx.fill(Path(ellipseIn: foot), with: .color(ear))  // 填充
        }  // 遍历结束

        for dx in [-9.0, 9.0] {  // 两只耳朵
            let e = CGRect(x: x + CGFloat(dx) * s - 4.4 * s, y: y - 44.4 * s, width: 8.8 * s, height: 8.8 * s)  // 耳朵
            ctx.fill(Path(ellipseIn: e), with: .color(ear))  // 填充
        }  // 遍历结束

        let head = CGRect(x: x - 13 * s, y: y - 45 * s, width: 26 * s, height: 26 * s)  // 头
        ctx.fill(Path(ellipseIn: head), with: .color(body))  // 填充
        let capRect = CGRect(x: x - 11 * s, y: y - 47 * s, width: 22 * s, height: 9 * s)  // 帽子
        ctx.fill(Path(ellipseIn: capRect), with: .color(cap))  // 填充

        let blink = (world.now + pet.phase).truncatingRemainder(dividingBy: 4) > 3.55  // 眨眼
        for dx in [-4.6, 3.0] {  // 两只眼睛
            let eye = blink ? CGRect(x: x + CGFloat(dx) * s, y: y - 34 * s, width: 4.2 * s, height: 1.1 * s)  // 闭眼
                            : CGRect(x: x + CGFloat(dx) * s, y: y - 35.4 * s, width: 2.6 * s, height: 2.6 * s)  // 睁眼
            ctx.fill(Path(ellipseIn: eye), with: .color(Color(hex: 0x2F2B28)))  // 填充
        }  // 遍历结束

        let name = pet.mine ? "你" : pet.name  // 名字
        ctx.draw(Text(name).font(.system(size: 9 * s, weight: .semibold)).foregroundStyle(Color(hex: 0x3B4157)),  // 名字标签
                 at: CGPoint(x: x, y: y - 50 * s), anchor: .center)  // 头顶居中

        if !pet.bubble.isEmpty {  // 有气泡
            let text = Text(pet.bubble).font(.system(size: 9.5 * s)).foregroundStyle(Color(hex: 0x2B2F3A))  // 气泡文字
            let width = max(46 * s, CGFloat(pet.bubble.count) * 10 * s + 12 * s)  // 气泡宽
            let box = CGRect(x: x - width / 2, y: y - 86 * s, width: width, height: 24 * s)  // 气泡框
            ctx.fill(Path(roundedRect: box, cornerRadius: 9 * s), with: .color(Color.white.opacity(0.95)))  // 填底
            ctx.stroke(Path(roundedRect: box, cornerRadius: 9 * s), with: .color(Color(hex: 0xD8DEE8)), lineWidth: 1)  // 描边
            ctx.draw(text, at: CGPoint(x: x, y: y - 74 * s), anchor: .center)  // 文字
        }  // 分支结束
    }  // drawPet 结束

    // MARK: 覆盖层                                                     // 分节：覆盖层

    private var topBar: some View {  // 顶部条
        HStack(spacing: Space.s) {  // 横排
            Button {  // 返回
                dismiss()  // 关掉
            } label: {  // 外观
                Circle().fill(Color.white.opacity(0.86))  // 白圆底
                    .frame(width: 32, height: 32)  // 尺寸
                    .overlay(Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))  // 箭头
                        .foregroundStyle(Color(hex: 0x2B2F3A)))  // 深色
            }  // 外观结束
            .buttonStyle(.plain)  // 去高亮
            .accessibilityLabel("返回")  // 无障碍

            HStack(spacing: 5) {  // 人数
                Circle().fill(Color.appOK).frame(width: 6, height: 6)  // 绿点
                Text(verbatim: "\(world.online) 位样例研友")  // 真实数量，不编在线人数
                    .font(.system(size: 11.5, weight: .medium))  // 11.5 号
                    .foregroundStyle(Color(hex: 0x2B2F3A))  // 深色
            }  // 横排结束
            .padding(.horizontal, 10)  // 左右
            .padding(.vertical, 5)  // 上下
            .background(Capsule().fill(Color.white.opacity(0.86)))  // 白胶囊

            Spacer()  // 撑开

            NavigationLink {  // 论坛
                CommunityView()  // 研友论坛
            } label: {  // 外观
                Text("论坛").font(.system(size: 11.5, weight: .semibold))  // 文案
                    .foregroundStyle(Color(hex: 0x2B54E8))  // 品牌蓝
                    .padding(.horizontal, 10)  // 左右
                    .padding(.vertical, 5)  // 上下
                    .background(Capsule().fill(Color.white.opacity(0.86)))  // 白胶囊
            }  // 外观结束
            .buttonStyle(.plain)  // 去高亮
        }  // 横排结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右留白
        .padding(.top, Space.xs)  // 顶部留白
    }  // topBar 结束

    private var ticker: some View {  // 世界频道
        HStack(spacing: 6) {  // 横排
            Text(world.tickWho).font(.system(size: 10.5, weight: .semibold))  // 谁
                .foregroundStyle(Color(hex: 0x8A5A00))  // 暖棕
            Text(world.tickText).font(.system(size: 10.5))  // 说了什么
                .foregroundStyle(Color(hex: 0x5B5347))  // 褐灰
                .lineLimit(1)  // 单行
            Spacer(minLength: 0)  // 撑开
        }  // 横排结束
        .padding(.horizontal, 10)  // 左右
        .padding(.vertical, 6)  // 上下
        .background(Capsule().fill(Color(hex: 0xFFF3D6).opacity(0.94)))  // 浅黄胶囊
        .padding(.horizontal, Metrics.pagePadding)  // 左右留白
        .padding(.top, 52)  // 顶到顶部条下面
        .accessibilityElement(children: .combine)  // 合并朗读
    }  // ticker 结束

    private func petCard(_ p: PlazaPet) -> some View {  // 宠物卡
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向
            HStack(spacing: Space.s) {  // 头部
                Circle()  // 头像
                    .fill(LinearGradient(colors: [Color(hex: p.pal.body), Color(hex: p.pal.ear)],  // 双色渐变
                                         startPoint: .topLeading, endPoint: .bottomTrailing))  // 对角
                    .frame(width: 38, height: 38)  // 尺寸
                    .overlay(Text(String(p.name.prefix(1))).font(.system(size: 15, weight: .bold))  // 首字
                        .foregroundStyle(.white))  // 白字
                VStack(alignment: .leading, spacing: 2) {  // 名字区
                    Text(p.mine ? "\(p.name)（你）" : p.name)  // 名字
                        .font(.system(size: 14, weight: .semibold))  // 14 号
                        .foregroundStyle(Color.textPrimary)  // 主色
                    Text(verbatim: "\(p.school) · Lv.\(p.lv)")  // 院校与等级
                        .font(.system(size: 10.5))  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 排列结束
                Spacer(minLength: 0)  // 撑开
                Button {  // 关闭
                    world.selectedID = nil  // 取消选中
                } label: {  // 外观
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))  // 叉
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                        .frame(width: 28, height: 28)  // 点击区
                }  // 外观结束
                .buttonStyle(.plain)  // 去高亮
                .accessibilityLabel("关闭卡片")  // 无障碍
            }  // 横排结束
            Text(p.help.map { "求助：\($0)" } ?? p.say)  // 一句话或求助
                .font(.system(size: 12))  // 12 号
                .foregroundStyle(Color(hex: 0x5B5347))  // 褐灰
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
            HStack(spacing: Space.l) {  // 三格统计
                cardStat(value: "\(p.today)", title: "今日题")  // 今日题
                cardStat(value: "\(p.days)", title: "连续天")  // 连续天
                cardStat(value: "\(p.frd)", title: "好友")  // 好友
            }  // 横排结束
            HStack(spacing: Space.s) {  // 三个动作
                cardAction("打个招呼") { world.greet() }  // 打招呼
                if !p.mine {  // 别人的才有加好友
                    cardAction("加好友") {  // 加好友
                        if app.addPlazaFriend(p.name) {  // 真加进数据层
                            world.toast = "已添加 \(p.name) 为好友"  // 提示
                        } else {  // 已加过
                            world.toast = "已经是好友了"  // 提示
                        }  // 分支结束
                    }  // 加好友结束
                }  // 分支结束
                if !p.mine {  // 别人的才有组队
                    cardAction("邀请组队", primary: true) { world.openTeam(with: p.id) }  // 组队
                }  // 分支结束
            }  // 横排结束
        }  // 排列结束
        .padding(Space.m)  // 内边距
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)  // 卡片底
            .fill(Color.white.opacity(0.97)))  // 近白
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)  // 投影
        .padding(.horizontal, Metrics.pagePadding)  // 左右留白
        .padding(.top, 92)  // 顶到频道下面
    }  // petCard 结束

    private func cardStat(value: String, title: String) -> some View {  // 一格统计
        HStack(spacing: 3) {  // 横排
            Text(verbatim: value).font(.system(size: 13, weight: .bold))  // 数值
                .foregroundStyle(Color.textPrimary)  // 主色
            Text(title).font(.system(size: 10))  // 标题
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 横排结束
        .accessibilityElement(children: .combine)  // 合并朗读
    }  // cardStat 结束

    private func cardAction(_ title: String, primary: Bool = false, run: @escaping () -> Void) -> some View {  // 卡片动作
        Button(action: run) {  // 点
            Text(title)  // 文案
                .font(.system(size: 12, weight: .semibold))  // 12 号
                .foregroundStyle(primary ? Color.white : Color(hex: 0x2B54E8))  // 主次配色
                .frame(maxWidth: .infinity)  // 等分
                .frame(height: 32)  // 高 32
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)  // 圆角
                    .fill(primary ? Color(hex: 0x2B54E8) : Color(hex: 0xEDF1FB)))  // 主次底色
        }  // 外观结束
        .buttonStyle(.plain)  // 去高亮
    }  // cardAction 结束

    private var bottomBar: some View {  // 底部发言条
        HStack(spacing: Space.xs) {  // 横排
            TextField("在广场上说点什么…", text: $draft)  // 输入
                .font(.system(size: 12.5))  // 字号
                .submitLabel(.send)  // 键盘回车是发送
                .onSubmit { send() }  // 回车发送
                .padding(.horizontal, 10)  // 左右
                .frame(height: 36)  // 高 36
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)  // 圆角输入框
                    .fill(Color.white.opacity(0.94)))  // 近白
            Button {  // 发送
                send()  // 发出去
            } label: {  // 外观
                Text("发送").font(.system(size: 12, weight: .semibold))  // 文案
                    .foregroundStyle(.white)  // 白字
                    .frame(width: 52, height: 36)  // 尺寸
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x2B54E8)))  // 蓝底
            }  // 外观结束
            .buttonStyle(.plain)  // 去高亮
            Button {  // 组队刷副本
                world.openTeam(with: nil)  // 开弹层
            } label: {  // 外观
                Text("组队刷副本").font(.system(size: 12, weight: .semibold))  // 文案
                    .foregroundStyle(Color(hex: 0x2B54E8))  // 蓝字
                    .frame(height: 36)  // 高 36
                    .padding(.horizontal, 10)  // 左右
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)  // 圆角
                        .fill(Color.white.opacity(0.94)))  // 近白
            }  // 外观结束
            .buttonStyle(.plain)  // 去高亮
        }  // 横排结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右留白
        .padding(.bottom, Space.s)  // 底部留白
    }  // bottomBar 结束

    private var teamSheet: some View {  // 组队弹层
        ZStack {  // 叠放
            Color.black.opacity(0.32).ignoresSafeArea()  // 遮罩
                .onTapGesture { world.showTeam = false }  // 点遮罩关掉
            VStack(alignment: .leading, spacing: Space.s) {  // 卡片
                HStack {  // 标题行
                    Text("组队刷副本").font(.system(size: 14, weight: .semibold))  // 标题
                        .foregroundStyle(Color.textPrimary)  // 主色
                    Spacer()  // 撑开
                    Text("增值税巨兽 · 3 题").font(.system(size: 10.5))  // 副标题
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 横排结束
                HStack(spacing: Space.s) {  // 三个位
                    ForEach(Array(world.teamPicks.enumerated()), id: \.offset) { i, name in  // 逐位
                        VStack(spacing: 3) {  // 纵向
                            Circle().fill(i == 0 ? Color(hex: 0x2B54E8) : Color(hex: 0xB9C6E8))  // 圆底
                                .frame(width: 34, height: 34)  // 尺寸
                                .overlay(Text(String(name.prefix(1))).font(.system(size: 13, weight: .bold))  // 首字
                                    .foregroundStyle(.white))  // 白字
                            Text(name).font(.system(size: 10.5, weight: .medium))  // 名字
                                .lineLimit(1)  // 单行
                                .foregroundStyle(Color.textPrimary)  // 主色
                            Text(i == 0 ? "队长" : "Lv.\(9 + i * 3)")  // 身份
                                .font(.system(size: 9))  // 极小
                                .foregroundStyle(Color.textTertiary)  // 弱化色
                        }  // 排列结束
                        .frame(maxWidth: .infinity)  // 等分
                    }  // 遍历结束
                }  // 横排结束
                Text("答错即当场拆解知识点，答对连击加伤害")  // 说明
                    .font(.system(size: 10.5))  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                HStack(spacing: Space.s) {  // 两个按钮
                    Button {  // 再逛逛
                        world.showTeam = false  // 关掉
                    } label: {  // 外观
                        Text("再逛逛").font(.system(size: 12, weight: .semibold))  // 文案
                            .foregroundStyle(Color(hex: 0x2B54E8))  // 蓝字
                            .frame(maxWidth: .infinity).frame(height: 36)  // 尺寸
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0xEDF1FB)))  // 淡蓝底
                    }  // 外观结束
                    .buttonStyle(.plain)  // 去高亮
                    Button {  // 进副本
                        world.showTeam = false  // 关掉弹层
                        goDungeon = true  // 进分拣副本
                    } label: {  // 外观
                        Text("进入副本").font(.system(size: 12, weight: .semibold))  // 文案
                            .foregroundStyle(.white)  // 白字
                            .frame(maxWidth: .infinity).frame(height: 36)  // 尺寸
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0x2B54E8)))  // 蓝底
                    }  // 外观结束
                    .buttonStyle(.plain)  // 去高亮
                }  // 横排结束
            }  // 排列结束
            .padding(Space.l)  // 内边距
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))  // 白卡
            .padding(.horizontal, 28)  // 左右留白
        }  // 叠放结束
    }  // teamSheet 结束

    private func send() {  // 发送我的发言
        world.sendMine(draft, size: stage)  // 交给世界
        draft = ""  // 清空输入
    }  // send 结束
}  // PlazaView 结束
