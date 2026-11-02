//  CompanionHomeView.swift —— 伙伴（电子宠物）页                      // 文件说明
//  口粮只能靠闯关产出，这里不卖口粮、不做抽卡                         // 产品约束
//  3D 形象用程序化几何体实现在 PetSceneView，投喂会跳、硕士可拨穗        // 范围说明

import SwiftUI  // 界面框架

struct CompanionHomeView: View {  // 伙伴页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var toast: String?  // 轻提示文案
    @State private var jumpToken = 0  // 每 +1 让宠物跳一下
    @State private var flipToken = 0  // 每 +1 拨一次穗

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                statusCard  // 状态卡
                actionCard  // 操作卡
                ruleCard  // 规则说明
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("我的伙伴")  // 标题
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
    }  // body 结束

    private var statusCard: some View {  // 状态卡
        Card {  // 卡片
            VStack(spacing: Space.m) {  // 纵向排列
                ZStack(alignment: .bottom) {  // 叠放：3D 宠物 + 阶段标签
                    PetSceneView(stage: app.stage, jumpToken: jumpToken, flipToken: flipToken)  // 3D 形象
                        .frame(height: 200)  // 固定高度，别撑满整页
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角裁切
                    Text(app.stage.title)  // 阶段名
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                        .padding(.horizontal, Space.s)  // 左右内边距
                        .padding(.vertical, Space.xxs)  // 上下内边距
                        .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃底
                        .padding(.bottom, Space.xs)  // 距底
                }  // 叠放结束

                Text(app.pet.statusText)  // 状态文案
                    .font(AppFont.bodyStrong)  // 加粗
                    .foregroundStyle(statusColor)  // 按状态上色

                Meter(  // 体力条
                    value: Double(app.pet.energy) / Double(Pet.maxEnergy),  // 比例
                    tint: statusColor,  // 按状态上色
                    label: "体力 \(app.pet.energy) / \(Pet.maxEnergy)"  // 语义标签
                )  // 体力条结束

                HStack(spacing: 0) {  // 三个指标
                    StatTile(value: "\(app.pet.food)", title: "口粮", tint: .appOK)  // 口粮
                    Divider().frame(height: 32)  // 分隔线
                    StatTile(value: "\(app.pet.affinity)", title: "好感", tint: .appErr)  // 好感
                    Divider().frame(height: 32)  // 分隔线
                    StatTile(value: "\(app.growth)", title: "成长值", tint: .appBrand)  // 成长值
                }  // 排列结束
            }  // 排列结束
        }  // 卡片结束
    }  // statusCard 结束

    private var statusColor: Color {  // 状态配色
        if app.pet.starved { return .appErr }  // 饿死红
        if app.pet.isHungry { return .appWarn }  // 濒危橙
        return .appOK  // 正常绿
    }  // 属性结束

    private var actionCard: some View {  // 操作卡
        Card {  // 卡片
            VStack(spacing: Space.s) {  // 纵向排列
                if app.pet.starved {  // 已饿死
                    PrimaryButton(title: "唤醒伙伴（消耗 1 颗口粮）", systemImage: "heart.fill") {  // 唤醒按钮
                        if app.pet.food > 0 {  // 有口粮
                            app.revivePet()  // 复活
                            show("伙伴已唤醒")  // 提示
                        } else {  // 没口粮
                            show("没有口粮，先去闯关")  // 提示
                        }  // 分支结束
                    }  // 按钮结束
                } else {  // 还活着
                    PrimaryButton(  // 投喂按钮
                        title: app.pet.food > 0 ? "投喂一次" : "没有口粮，去闯关",  // 文案随口粮变
                        systemImage: "leaf.fill",  // 叶子图标
                        enabled: app.pet.food > 0  // 没口粮禁用
                    ) {  // 点击
                        handleFeed()  // 处理投喂
                    }  // 按钮结束
                }  // 分支结束

                if !app.pet.claimed {  // 未认领
                    GhostButton(title: "认领这个伙伴", systemImage: "hand.raised") {  // 认领按钮
                        app.claimPet()  // 标记认领
                        jumpToken += 1  // 跳到人面前
                        show("认领成功")  // 提示
                    }  // 按钮结束
                }  // 分支结束

                if app.stage == .master {  // 到硕士阶段
                    GhostButton(title: "拨穗仪式", systemImage: "graduationcap.fill") {  // 拨穗按钮
                        flipToken += 1  // 流苏转半圈
                        show("拨穗完成 · 从右拨到左")  // 提示
                    }  // 按钮结束
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // actionCard 结束

    private func handleFeed() {  // 处理投喂
        switch app.feedPet() {  // 调唯一写入口
        case let .ok(energy, affinity):  // 成功
            jumpToken += 1  // 吃到东西跳一下
            show("投喂成功 · 体力 \(energy)，好感 \(affinity)")  // 提示结果
        case .noFood:  // 没口粮
            show("口粮不够了，去闯关就能拿到")  // 提示
        case .alreadyFull:  // 已吃饱
            show("已经吃饱了，别浪费口粮")  // 提示
        case .dead:  // 已饿死
            show("伙伴已经饿死，先点唤醒")  // 提示
        }  // 分支结束
    }  // handleFeed 结束

    private var ruleCard: some View {  // 规则说明卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
                Text("养成规则").font(AppFont.section)  // 标题
                rule("口粮只能靠闯关获得：首通 2 颗，重复通关 1 颗。")  // 口粮来源
                rule("每天自然日结算一次，体力 -\(Pet.dailyDecay)，不投喂就会饿死。")  // 衰减规则
                rule("饿死后每天掉 \(Pet.starveAffinityLoss) 点好感，好感归零不会删除任何学习记录。")  // 惩罚边界
                rule("这里不卖口粮、不做抽卡，养成的唯一来源是学习。")  // 反赌博声明
            }  // 排列结束
        }  // 卡片结束
    }  // ruleCard 结束

    private func rule(_ text: String) -> some View {  // 单条规则
        HStack(alignment: .top, spacing: Space.xxs) {  // 横向排列
            Text("·").foregroundStyle(Color.textTertiary)  // 圆点
            Text(text)  // 规则正文
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次要色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
    }  // rule 结束

    private func show(_ text: String) {  // 弹提示
        withAnimation { toast = text }  // 淡入
        Task {  // 异步延时
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 等 1.8 秒
            withAnimation { toast = nil }  // 淡出
        }  // 任务结束
    }  // show 结束
}  // CompanionHomeView 结束
