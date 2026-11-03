//  ProfileView.swift —— 「我的」页                                   // 文件说明
//  所有数字都能溯源到今天做了什么，不出现无来源的分数                   // 页面约束

import SwiftUI  // 界面框架
import UniformTypeIdentifiers  // 导出文件要声明类型

struct ExportDocument: Transferable {  // 可分享的数据文件
    let data: Data  // 文件内容

    static var transferRepresentation: some TransferRepresentation {  // 告诉系统怎么分享
        DataRepresentation(exportedContentType: .json) { item in  // 按 JSON 类型导出
            item.data  // 内容原样给出去
        }  // 导出定义结束
        .suggestedFileName("fushizhuan-data.json")  // 默认文件名
    }  // 传输定义结束
}  // ExportDocument 结束

struct ProfileView: View {  // 我的页
    @Environment(AppState.self) private var app  // 全局状态
    @State private var showResetConfirm = false  // 是否弹重置确认
    @AppStorage("app.pet.static3D") private var static3D = false  // 与伙伴页共用同一个键

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(spacing: Space.l) {  // 纵向排列
                identityCard  // 身份卡
                statsCard  // 统计卡
                growthCard  // 成长来源
                entitlementCard  // 权益卡
                settingsCard  // 显示与动效
                moreCard  // 学习地图 / 隐私协议
                merchantCard  // 商户入驻（占位）
                dataCard  // 数据卡
                aboutCard  // 关于
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, Space.xxl)  // 底部留白
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("我的")  // 标题
        .confirmationDialog(  // 二次确认弹窗
            "重置本地数据？",  // 标题
            isPresented: $showResetConfirm,  // 是否显示
            titleVisibility: .visible  // 标题可见
        ) {  // 按钮区
            Button("重置，清空全部学习记录", role: .destructive) {  // 危险按钮
                app.resetAll()  // 执行重置
            }  // 按钮结束
            Button("取消", role: .cancel) {}  // 取消
        } message: {  // 说明区
            Text("答题记录、错题本、闯关成绩、宠物状态都会被清空，无法恢复。")  // 后果说明
        }  // 弹窗结束
    }  // body 结束

    private var identityCard: some View {  // 身份卡
        Card {  // 卡片
            HStack(spacing: Space.m) {  // 横向排列
                ZStack {  // 叠放
                    Circle().fill(Color.appBrand.opacity(0.12)).frame(width: 52, height: 52)  // 圆形底
                    Text("\(app.growth)")  // 成长值
                        .font(AppFont.bodyStrong)  // 加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 叠放结束
                VStack(alignment: .leading, spacing: 2) {  // 文字区
                    Text(app.profile.nickname).font(AppFont.section)  // 昵称
                    Text("\(app.profile.venue.title) · \(app.profile.stage.title) · 距考试 \(app.profile.daysLeft) 天")  // 方向阶段倒计时
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                }  // 文字区结束
                Spacer()  // 撑开
            }  // 排列结束
        }  // 卡片结束
    }  // identityCard 结束

    private var statsCard: some View {  // 统计卡
        Card {  // 卡片
            HStack(spacing: 0) {  // 三个指标
                StatTile(value: "\(app.data.attempts.count)", title: "累计答题")  // 累计答题
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.unresolvedWrongs.count)", title: "错题", tint: .appErr)  // 错题数
                Divider().frame(height: 32)  // 分隔线
                StatTile(value: "\(app.stars(inChapter: "tax-system"))", title: "税制星数", tint: .appWarn)  // 章节星数
            }  // 排列结束
        }  // 卡片结束
    }  // statsCard 结束

    private var growthCard: some View {  // 成长来源卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack {  // 标题行
                    Text("成长来源").font(AppFont.section)  // 标题
                    Spacer()  // 撑开
                    Text("总计 \(app.growth)")  // 总计
                        .font(AppFont.captionStrong)  // 小字加粗
                        .foregroundStyle(Color.appBrand)  // 品牌色
                }  // 排列结束
                let notes = app.recentGrowthNotes()  // 取来源说明
                if notes.isEmpty {  // 没有记录
                    Text("今天还没有产生成长值。答对题目、通关、打卡都会有记录。")  // 提示
                        .font(AppFont.caption)  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                } else {  // 有记录
                    ForEach(notes, id: \.self) { note in  // 遍历
                        HStack(spacing: Space.xxs) {  // 横向排列
                            Image(systemName: "plus.circle.fill")  // 加号图标
                                .font(.system(size: 11))  // 小图标
                                .foregroundStyle(Color.appOK)  // 绿色
                            Text(note)  // 说明文字
                                .font(AppFont.caption)  // 小字
                                .foregroundStyle(Color.textSecondary)  // 次要色
                        }  // 排列结束
                    }  // 遍历结束
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // growthCard 结束

    private var moreCard: some View {  // 学习地图与法务入口
        Card {  // 卡片
            VStack(spacing: Space.m) {  // 纵向排列
                NavigationLink {  // 学习地图
                    WorldMapView()  // 地图页
                } label: {  // 行外观
                    linkRow(icon: "map", title: "学习地图", detail: "5 座考研岛与岛内地点")  // 行内容
                }  // 链接结束
                .buttonStyle(.plain)  // 不用默认高亮
                Divider()  // 分隔线
                NavigationLink {  // 隐私与协议
                    LegalView()  // 隐私政策与用户协议
                } label: {  // 行外观
                    linkRow(icon: "hand.raised.fill", title: "隐私与协议", detail: "我们收集什么、数据存在哪")  // 行内容
                }  // 链接结束
                .buttonStyle(.plain)  // 不用默认高亮
            }  // 排列结束
        }  // 卡片结束
    }  // moreCard 结束

    private func linkRow(icon: String, title: String, detail: String) -> some View {  // 通用入口行
        HStack(spacing: Space.m) {  // 横向排列
            Image(systemName: icon)  // 图标
                .font(.system(size: 16))  // 图标大小
                .foregroundStyle(Color.appBrand)  // 品牌色
                .frame(width: 26)  // 固定宽度对齐
            VStack(alignment: .leading, spacing: 2) {  // 文字区
                Text(title).font(AppFont.bodyStrong)  // 标题
                Text(detail).font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
            }  // 文字区结束
            Spacer()  // 撑开
            Image(systemName: "chevron.right")  // 箭头
                .font(.system(size: 11, weight: .semibold))  // 小箭头
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .contentShape(Rectangle())  // 整行可点
        .accessibilityElement(children: .combine)  // 合并朗读
    }  // linkRow 结束

    private var merchantCard: some View {  // 商户入驻入口（占位）
        Card {  // 卡片
            NavigationLink {  // 进占位页
                MerchantEntryView()  // 占位页
            } label: {  // 行外观
                HStack(spacing: Space.xs) {  // 横向排列
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text("商户入驻").font(AppFont.bodyStrong)  // 名称
                        Text("机构与合作方入驻，功能未开发")  // 说明
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                    }  // 文字区结束
                    Spacer()  // 撑开
                    Chip(text: "待开发", tint: .appWarn)  // 明确标记
                    Image(systemName: "chevron.right")  // 箭头
                        .font(.system(size: 12, weight: .semibold))  // 小箭头
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 排列结束
                .contentShape(Rectangle())  // 整行可点
            }  // 链接结束
            .buttonStyle(.plain)  // 不用默认高亮
        }  // 卡片结束
    }  // merchantCard 结束

    private var settingsCard: some View {  // 设置卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                Text("显示与动效").font(AppFont.section)  // 标题
                Toggle(isOn: $static3D) {  // 省电开关
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text("省电模式").font(AppFont.body)  // 名称
                        Text("关闭伙伴形象的动画。系统开启「减弱动态效果」时也会自动关闭。")  // 说明
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                            .fixedSize(horizontal: false, vertical: true)  // 允许换行
                    }  // 文字区结束
                }  // 开关结束
                .tint(.appBrand)  // 品牌色
            }  // 排列结束
        }  // 卡片结束
    }  // settingsCard 结束

    private var entitlementCard: some View {  // 权益卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                HStack {  // 标题行
                    VStack(alignment: .leading, spacing: 2) {  // 文字区
                        Text("当前版本").font(AppFont.caption).foregroundStyle(Color.textSecondary)  // 说明
                        Text(app.entitlement.isActive() ? app.entitlement.plan.title : "免费版")  // 有效显示档位否则免费
                            .font(AppFont.section)  // 区段字号
                    }  // 文字区结束
                    Spacer()  // 撑开
                    if app.entitlement.isActive(), let expires = app.entitlement.expiresAt {  // 订阅有到期
                        Text("\(expires.formatted(date: .numeric, time: .omitted)) 到期")  // 到期日
                            .font(AppFont.caption)  // 小字
                            .foregroundStyle(Color.textSecondary)  // 次要色
                    }  // 分支结束
                }  // 排列结束
                NavigationLink {  // 进入会员页
                    PaywallView()  // 付费墙
                } label: {  // 行外观
                    HStack {  // 横向排列
                        Text(app.entitlement.isActive() ? "查看会员权益" : "开通会员")  // 文案
                            .font(AppFont.bodyStrong)  // 加粗
                            .foregroundStyle(Color.appBrand)  // 品牌色
                        Spacer()  // 撑开
                        Image(systemName: "chevron.right")  // 箭头
                            .font(.system(size: 12, weight: .semibold))  // 小箭头
                            .foregroundStyle(Color.textTertiary)  // 弱化色
                    }  // 排列结束
                    .contentShape(Rectangle())  // 整行可点
                }  // 链接结束
                .buttonStyle(.plain)  // 不用默认高亮
            }  // 排列结束
        }  // 卡片结束
    }  // entitlementCard 结束

    private var dataCard: some View {  // 数据卡
        Card {  // 卡片
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
                Text("数据").font(AppFont.section)  // 标题
                Text("学习记录只存在这台设备上（appstate.json），不上传服务器。")  // 隐私说明
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
                if let doc = exportPayload {  // 有数据才给导出入口
                    ShareLink(item: doc) {  // 系统分享面板
                        HStack(spacing: Space.xs) {  // 横向排列
                            Image(systemName: "square.and.arrow.up")  // 导出图标
                                .font(.system(size: 13))  // 图标大小
                            Text("导出我的数据（JSON）")  // 按钮文字
                                .font(AppFont.captionStrong)  // 小字加粗
                        }  // 排列结束
                        .foregroundStyle(Color.appBrand)  // 品牌色
                    }  // 分享链接结束
                }  // 分支结束
                Button("重置本地数据", role: .destructive) {  // 重置按钮
                    showResetConfirm = true  // 弹确认
                }  // 按钮结束
                .font(AppFont.captionStrong)  // 小字加粗
            }  // 排列结束
        }  // 卡片结束
    }  // dataCard 结束

    private var exportPayload: ExportDocument? {  // 打包成可分享文件
        guard let data = app.exportJSON() else { return nil }  // 编码失败就不显示入口
        return ExportDocument(data: data)  // 交给 ShareLink
    }  // 属性结束

    private var aboutCard: some View {  // 关于区
        VStack(alignment: .leading, spacing: Space.xxs) {  // 纵向排列
            Text("复试专 · 0.1.0（骨架版）")  // 版本号
            Text("面试导师为 AI 模拟角色，非真实导师；评分是训练量表，不是院校官方评分。")  // 角色与量表声明
            Text("复试人数与时长要求依教育部《2026 年全国硕士研究生招生工作管理规定》。")  // 政策依据
        }  // 排列结束
        .font(AppFont.caption)  // 小字
        .foregroundStyle(Color.textTertiary)  // 弱化色
        .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐撑满
    }  // aboutCard 结束
}  // ProfileView 结束
