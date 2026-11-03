//  AvatarStudioView.swift —— 换装工坊                              // 文件说明
//  左边看猫、下边挑配件；点一下就穿上，退出重进还是这身（数据写在 AppState）  // 交互说明
//  解锁只看成长值：不抽卡、不开箱、不做概率掉落                        // 产品约束

import SwiftUI  // 界面框架
import UIKit  // UIColor → Color

struct AvatarStudioView: View {  // 换装页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var slot: OutfitSlot = .hat  // 当前在挑哪个部位
    @State private var hint: String?  // 轻提示

    private var catalog: OutfitCatalog { OutfitCatalog.shared }  // 配件总表

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                previewCard  // 3D 预览
                slotPicker  // 部位切换
                itemGrid  // 配件格子
                ruleCard  // 解锁规则说明
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("换装工坊")  // 标题
        .overlay(alignment: .bottom) {  // 底部浮层提示
            if let hint {  // 有提示才显示
                Text(hint)  // 提示文字
                    .font(AppFont.captionStrong)  // 小字加粗
                    .padding(.horizontal, Space.l)  // 左右内边距
                    .padding(.vertical, Space.s)  // 上下内边距
                    .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃胶囊
                    .padding(.bottom, Space.xxl)  // 距底边
                    .transition(.opacity)  // 淡入淡出
            }  // 分支结束
        }  // 浮层结束
    }  // body 结束

    // MARK: - 预览                                                    // 分节：预览

    private var previewCard: some View {  // 预览卡
        Card {  // 卡片
            VStack(spacing: Space.s) {  // 纵向排列
                ZStack(alignment: .topTrailing) {  // 叠放：猫 + 已解锁计数
                    PetSceneView(stage: app.stage, outfit: app.outfit)  // 只用穿戴驱动，不播动画
                        .frame(height: 290)  // 固定高度
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角裁切
                    Text(verbatim: "已解锁 \(unlockedCount)/\(catalog.items.count)")  // 解锁进度
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                        .padding(.horizontal, Space.s)  // 左右内边距
                        .padding(.vertical, 4)  // 上下内边距
                        .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃底
                        .padding(Space.m)  // 距角
                }  // 叠放结束
                HStack {  // 底部一行
                    Text(verbatim: "成长值 \(app.growth)")  // 当前成长值
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                    Spacer()  // 撑开
                    Text("当前毛色：\(currentFurName)")  // 当前毛色名
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 排列结束
            }  // 排列结束
        }  // 卡片结束
    }  // previewCard 结束

    private var currentFurName: String {  // 当前毛色显示名
        let id = app.outfit.id(for: .fur) ?? ""  // 当前毛色 id
        return catalog.item(id: id)?.name ?? "奶白"  // 查不到就兜底
    }  // 属性结束

    private var unlockedCount: Int {  // 已解锁件数
        catalog.items.filter { app.isUnlocked($0) }.count  // 按成长值筛
    }  // 属性结束

    // MARK: - 部位切换                                                // 分节：部位

    private var slotPicker: some View {  // 部位切换条
        ScrollView(.horizontal, showsIndicators: false) {  // 横向滚动
            HStack(spacing: Space.xs) {  // 横向排列
                ForEach(OutfitSlot.allCases) { item in  // 五个部位
                    Button {  // 点击切换
                        withAnimation(.easeInOut(duration: 0.18)) { slot = item }  // 换选中部位
                    } label: {  // 胶囊外观
                        Text(item.title)  // 部位名
                            .font(AppFont.captionStrong)  // 小字加粗
                            .foregroundStyle(slot == item ? Color.white : Color.textSecondary)  // 选中白字
                            .padding(.horizontal, Space.m)  // 左右内边距
                            .padding(.vertical, Space.xs)  // 上下内边距
                            .background(  // 背景
                                Capsule().fill(slot == item ? Color.appBrand : Color.appCard)  // 选中品牌色
                            )  // 背景结束
                    }  // 外观结束
                    .buttonStyle(.plain)  // 不用默认高亮
                }  // 遍历结束
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 与卡片对齐
        }  // 滚动结束
        .scrollClipDisabled()  // 允许边缘溢出
    }  // slotPicker 结束

    // MARK: - 配件格子                                                // 分节：格子

    private var itemGrid: some View {  // 配件网格
        let items = catalog.items(in: slot)  // 当前部位的配件
        return Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                HStack {  // 标题行
                    Text(slot.title).font(AppFont.section)  // 部位名
                    Spacer()  // 撑开
                    Text(verbatim: "\(items.count) 件")  // 数量
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.s)], spacing: Space.s) {  // 自适应网格
                    ForEach(items) { item in  // 逐件
                        itemCell(item)  // 一件格子
                    }  // 遍历结束
                }  // 网格结束
            }  // 排列结束
        }  // 卡片结束
    }  // itemGrid 结束

    private func itemCell(_ item: OutfitItem) -> some View {  // 单件配件格
        let unlocked = app.isUnlocked(item)  // 是否已解锁
        let selected = app.outfit.id(for: item.slot) == item.id  // 是否正在穿
        return Button {  // 点击
            guard unlocked else {  // 没解锁
                show("还差 \(item.minGrowth - app.growth) 点成长值，先去答题或闯关")  // 告诉他怎么解锁
                return  // 不改穿戴
            }  // 分支结束
            app.equip(item.id, slot: item.slot)  // 唯一写入口
        } label: {  // 格子外观
            VStack(spacing: Space.xxs) {  // 纵向排列
                ZStack {  // 色块
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 底
                        .fill(Color(uiColor: UIColor(hex: item.hex)))  // 用配件主色
                        .frame(height: 46)  // 固定高度
                    if !unlocked {  // 未解锁
                        Image(systemName: "lock.fill")  // 锁图标
                            .font(.system(size: 14))  // 图标大小
                            .foregroundStyle(Color.white.opacity(0.9))  // 白锁
                    } else if selected {  // 正在穿
                        Image(systemName: "checkmark")  // 勾
                            .font(.system(size: 15, weight: .bold))  // 图标大小
                            .foregroundStyle(Color.white)  // 白勾
                    }  // 分支结束
                }  // 叠放结束
                .overlay(  // 描边
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)  // 同形
                        .stroke(selected ? Color.appBrand : Color.clear, lineWidth: 2)  // 选中亮边
                )  // 描边结束
                Text(item.name)  // 名称
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(unlocked ? Color.textPrimary : Color.textTertiary)  // 未解锁灰
                    .lineLimit(1)  // 单行
                Text(unlocked ? item.detail : "成长 \(item.minGrowth) 解锁")  // 说明或解锁条件
                    .font(.system(size: 10))  // 更小的字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .lineLimit(2)  // 最多两行
                    .multilineTextAlignment(.center)  // 居中
                    .frame(height: 26, alignment: .top)  // 固定高度防跳动
            }  // 排列结束
            .frame(maxWidth: .infinity)  // 撑满格子
            .contentShape(Rectangle())  // 整格可点
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
        .accessibilityLabel("\(item.name)，\(unlocked ? (selected ? "正在穿" : "点击穿上") : "未解锁")")  // 朗读文案
    }  // itemCell 结束

    // MARK: - 规则                                                    // 分节：规则

    private var ruleCard: some View {  // 规则说明
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
                Text("解锁规则").font(AppFont.section)  // 标题
                Text("配件只按成长值解锁，成长值来自答题、闯关和打卡，没有别的获取途径。")  // 唯一来源
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                Text("这里没有抽卡、没有开箱、没有概率掉落，也没有付费解锁的外观。")  // 反赌博声明
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
            }  // 排列结束
        }  // 卡片结束
    }  // ruleCard 结束

    private func show(_ text: String) {  // 弹提示
        withAnimation { hint = text }  // 淡入
        Task {  // 异步延时
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 等 1.8 秒
            withAnimation { hint = nil }  // 淡出
        }  // 任务结束
    }  // show 结束
}  // AvatarStudioView 结束
