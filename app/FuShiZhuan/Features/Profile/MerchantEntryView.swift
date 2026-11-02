//  MerchantEntryView.swift —— 商户入驻（占位页，功能未开发）            // 文件说明
//  只占个位置，不写任何假流程：没有表单、没有提交、没有"预计上线"的承诺     // 诚实约束
//  等真要做的时候，把这一页换成真正的入驻流程即可，入口不用再找             // 后续说明

import SwiftUI                                                     // 界面框架

struct MerchantEntryView: View {                                   // 入驻占位页
    var body: some View {                                          // 视图主体
        ScrollView {                                               // 可滚动
            VStack(spacing: Space.l) {                             // 纵向排列
                statusCard                                         // 现状说明
                scopeCard                                          // 以后要做什么（待定）
            }                                                      // 排列结束
            .padding(Metrics.pagePadding)                          // 内边距
            .padding(.bottom, Space.xxl)                           // 底部留白
        }                                                          // 滚动结束
        .background(Color.appBG)                                   // 底色
        .navigationTitle("商户入驻")                                // 标题
        .navigationBarTitleDisplayMode(.inline)                    // 小标题
    }                                                              // body 结束

    // MARK: - 现状                                                      // 分节：现状

    private var statusCard: some View {                            // 状态卡
        Card {                                                     // 卡片
            VStack(alignment: .leading, spacing: Space.s) {         // 纵向排列
                HStack(spacing: Space.xs) {                        // 标题行
                    Text("还没开发").font(AppFont.section)          // 标题
                    Chip(text: "占位", tint: .appWarn)              // 明确标记
                }                                                  // 排列结束
                Text("这里先占个入口，防止以后加功能时到处找位置。点进来不会提交任何资料，也不会有人联系你。") // 如实说明
                    .font(AppFont.caption)                         // 小字
                    .foregroundStyle(Color.textSecondary)          // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
            }                                                      // 排列结束
        }                                                      // 卡片结束
    }                                                              // statusCard 结束

    // MARK: - 待定范围                                                  // 分节：待定

    private var scopeCard: some View {                             // 范围卡
        Card {                                                     // 卡片
            VStack(alignment: .leading, spacing: Space.s) {         // 纵向排列
                Text("以后要做的（都还没定）").font(AppFont.section)   // 标题
                item("谁能入驻", "机构、老师个人，还是只开放给合作方，未定。") // 主体
                item("要交什么材料", "营业执照、办学许可、课程资质，按入驻主体再定。") // 资质
                item("怎么结算", "分成比例、结算周期、发票，一律未定。")      // 结算
                item("内容怎么审", "上架的课程与模考由谁审核、出了问题谁负责，未定。") // 审核
                Text("在上面的问题有答案之前，这一页不会出现任何「立即入驻」的按钮。") // 底线
                    .font(AppFont.caption)                         // 小字
                    .foregroundStyle(Color.textTertiary)           // 弱化色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
            }                                                      // 排列结束
        }                                                          // 卡片结束
    }                                                              // scopeCard 结束

    private func item(_ title: String, _ detail: String) -> some View { // 单条
        VStack(alignment: .leading, spacing: 2) {                   // 纵向排列
            Text(title).font(AppFont.bodyStrong)                    // 小标题
            Text(detail)                                            // 说明
                .font(AppFont.caption)                              // 小字
                .foregroundStyle(Color.textSecondary)               // 次要色
                .fixedSize(horizontal: false, vertical: true)       // 允许换行
        }                                                          // 排列结束
    }                                                              // item 结束
}                                                                  // MerchantEntryView 结束
