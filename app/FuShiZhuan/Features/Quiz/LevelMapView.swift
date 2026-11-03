//  LevelMapView.swift —— 闯关关卡入口（4 章 × 3 关）                      // 文件说明
//  ⚠️ 与样板的一处已知偏离：样板真正的关卡入口是 3D 星海地图（game3d.js 里点水晶进关），
//     它的「降级列表」只是只读的章名 + BOSS 名，写着「关卡仍可在刷题中练习」，不可玩。
//     用户 2026-11-03 明确要求「先别动 3D 整体」，所以这里做的是可玩的列表入口，
//     玩法规格（分拣）严格照样板，只有「入口形态」与 3D 地图不同，等用户确认是否改回 3D。// 偏离说明
//  解锁规则照样板 game.js：第一关默认开，之后需要前一关 star > 0                // 解锁约定

import SwiftUI  // 界面框架

struct LevelMapView: View {  // 关卡地图（列表形态）
    @Environment(AppState.self) private var app  // 读成绩
    @State private var activeLevel: SortLevel?  // 正在玩的关卡

    private var starsByLevel: [String: Int] {  // 各关星数
        Dictionary(uniqueKeysWithValues: app.data.levelResults.map { ($0.id, $0.stars) })  // 成绩转字典
    }  // starsByLevel 结束

    private var totalStars: Int {  // 累计星数
        app.data.levelResults.reduce(0) { $0 + $1.stars }  // 累加
    }  // totalStars 结束

    private var clearedCount: Int {  // 通关数
        app.data.levelResults.filter { $0.stars > 0 }.count  // 有星才算过
    }  // clearedCount 结束

    private var bestCombo: Int {  // 最高连击（历史最好一次，取已通关里最大）
        app.data.levelResults.map(\.correct).max() ?? 0  // 用归位数近似展示，不虚构
    }  // bestCombo 结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                hud  // 三格战绩
                duelNotice  // 1V1 竞赛：如实说明没接
                ForEach(SortCatalog.chapters) { chapter in  // 逐章
                    chapterBlock(chapter)  // 一章一块
                }  // 遍历结束
                Text("拖动分拣考点卡片，把知识点放进正确的分类槽。")  // 底部说明（样板提示的可玩化改写）
                    .font(.system(size: 11))  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("闯关模式")  // 标题
        .navigationBarTitleDisplayMode(.inline)  // 内联
        .fullScreenCover(item: $activeLevel) { level in  // 打开分拣
            NavigationStack {  // 套栈才有标题栏
                SortGameView(level: level, onNext: { advance(from: level) })  // 分拣页
                    .id(level.id)  // 换关时强制重建状态
            }  // 栈结束
        }  // 覆盖层结束
    }  // body 结束

    private var hud: some View {  // 三格战绩（样板 .gm-hud）
        HStack(spacing: Space.s) {  // 横向三等分
            hudCell(value: "\(totalStars)", title: "星数")  // 星数
            hudCell(value: "\(clearedCount)", title: "通关")  // 通关数
            hudCell(value: "\(bestCombo)", title: "归位")  // 最好一次归位数
        }  // 排列结束
    }  // hud 结束

    private var duelNotice: some View {  // 1V1 竞赛的缺口说明
        // 样板 page-game 右下角有一个「1V1 竞赛」按钮，它靠 /api/duel/* 配对两个
        // 同时在等的人（duel.js 注释原话：「和真人打这件事必须有服务端」）。
        // 本工程 BFF 还没有这组接口，所以这里不放一个点了没反应的按钮，
        // 而是把缺口摆在明面上，等接口接上再把按钮换成真的。
        HStack(spacing: Space.s) {  // 横向排列
            Image(systemName: "person.2.slash")  // 双人划掉的图标
                .font(.system(size: 13, weight: .semibold))  // 图标大小
                .foregroundStyle(Color.textTertiary)  // 弱化色
            Text("1V1 知识竞赛需要配对服务（两个真人同题对决），服务端接口尚未接入")  // 如实说明
                .font(.system(size: 11))  // 11 号
                .foregroundStyle(Color.textTertiary)  // 弱化色
                .fixedSize(horizontal: false, vertical: true)  // 允许多行
            Spacer(minLength: 0)  // 撑开
        }  // 横排结束
        .padding(.horizontal, Space.m)  // 左右
        .padding(.vertical, Space.s)  // 上下
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 圆角胶囊卡
            .fill(Color(hex: 0xF4F5F9)))  // 浅灰底
    }  // duelNotice 结束

    private func hudCell(value: String, title: String) -> some View {  // 一格战绩
        VStack(spacing: 3) {  // 上数字下标题
            Text(verbatim: value)  // 数值
                .font(.system(size: 19, weight: .bold, design: .rounded))  // 圆体加粗
                .foregroundStyle(Color.textPrimary)  // 主色
                .monospacedDigit()  // 等宽
            Text(title)  // 标题
                .font(.system(size: 10.5))  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 等分
        .padding(.vertical, 9)  // 上下内边距
        .background(  // 白底
            RoundedRectangle(cornerRadius: 15, style: .continuous)  // 圆角 15（样板同）
                .fill(Color.appCard)  // 卡片色
        )  // 背景结束
    }  // hudCell 结束

    private func chapterBlock(_ chapter: SortChapter) -> some View {  // 一章
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack(spacing: Space.xs) {  // 章标题行
                Text(chapter.name)  // 章名
                    .font(AppFont.section)  // 区段标题
                    .foregroundStyle(color(chapter.color))  // 用章节主题色
                Text(verbatim: "BOSS · \(chapter.boss)")  // 守关名（与样板降级列表同写法）
                    .font(.system(size: 10.5))  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束

            VStack(spacing: Space.xs) {  // 三关
                ForEach(1...SortCatalog.perChapter, id: \.self) { i in  // 逐关
                    levelRow("\(chapter.id)-\(i)", index: i, tint: color(chapter.color))  // 关卡行
                }  // 遍历结束
            }  // 排列结束
        }  // 排列结束
    }  // chapterBlock 结束

    private func levelRow(_ id: String, index: Int, tint: Color) -> some View {  // 一关
        let stars = starsByLevel[id] ?? 0  // 已有星数
        let unlocked = isUnlocked(id)  // 是否解锁
        let level = SortCatalog.level(id)  // 关卡数据
        return Button {  // 点进关
            if let level, unlocked { activeLevel = level }  // 解锁才开
        } label: {  // 行外观
            HStack(spacing: Space.s) {  // 横向排列
                Text(verbatim: "\(index)")  // 关序号
                    .font(.system(size: 13, weight: .bold))  // 加粗
                    .foregroundStyle(unlocked ? .white : Color.textTertiary)  // 解锁白字
                    .frame(width: 26, height: 26)  // 小圆
                    .background(Circle().fill(unlocked ? tint : Color.separator.opacity(0.4)))  // 解锁实心

                VStack(alignment: .leading, spacing: 1) {  // 关名与提示
                    Text(level?.title ?? id)  // 关名
                        .font(AppFont.bodyStrong)  // 正文加重
                        .foregroundStyle(unlocked ? Color.textPrimary : Color.textTertiary)  // 锁定变灰
                    Text(level?.hint ?? "")  // 玩法提示
                        .font(.system(size: 10.5))  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                        .lineLimit(1)  // 一行
                }  // 排列结束

                Spacer(minLength: 0)  // 撑开

                if unlocked {  // 已解锁显示星
                    HStack(spacing: 1) {  // 三颗星
                        ForEach(0..<3, id: \.self) { i in  // 逐个
                            Text("★")  // 星
                                .font(.system(size: 12))  // 小星
                                .foregroundStyle(i < stars ? Color.appWarn : Color.separator.opacity(0.6))  // 亮或灰
                        }  // 遍历结束
                    }  // 排列结束
                } else {  // 未解锁显示锁
                    Image(systemName: "lock.fill")  // 锁
                        .font(.system(size: 12))  // 小图标
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 分支结束
            }  // 排列结束
            .padding(Space.s)  // 内边距
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满
            .background(  // 白底
                RoundedRectangle(cornerRadius: 12, style: .continuous)  // 圆角
                    .fill(Color.appCard)  // 卡片色
            )  // 背景结束
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
        .disabled(!unlocked)  // 锁住不能点
    }  // levelRow 结束

    private func isUnlocked(_ id: String) -> Bool {  // 解锁判定（照样板）
        guard let i = SortCatalog.order.firstIndex(of: id) else { return false }  // 不在表里
        if i == 0 { return true }  // 第一关默认开
        let prev = SortCatalog.order[i - 1]  // 前一关
        return (starsByLevel[prev] ?? 0) > 0  // 前一关过了才开
    }  // isUnlocked 结束

    private func advance(from level: SortLevel) {  // 下一关
        guard let next = SortCatalog.nextLevel(after: level.id),  // 有下一关
              let nextLevel = SortCatalog.level(next),  // 数据存在
              isUnlocked(next) else { activeLevel = nil; return }  // 没解锁就回地图
        activeLevel = nextLevel  // 换到下一关
    }  // advance 结束

    private func color(_ hex: String) -> Color {  // "#4a6bff" 转 Color
        let cleaned = hex.replacingOccurrences(of: "#", with: "")  // 去掉井号
        let value = UInt32(cleaned, radix: 16) ?? 0x6B8CFF  // 转成数值
        return Color(hex: value)  // 交给设计系统扩展
    }  // color 结束
}  // LevelMapView 结束
