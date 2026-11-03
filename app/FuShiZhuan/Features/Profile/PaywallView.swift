//  PaywallView.swift —— 会员购买页                                    // 文件说明
//  只展示真实商品与真实价格，拉不到商品就明说，不做假价格表              // 诚实约束
//  法律文本只写能兑现的：自动续期、取消路径；没备案的链接不放             // 合规约束

import StoreKit                                                    // 商品类型
import SwiftUI                                                     // 界面框架

struct PaywallView: View {                                         // 会员页
    @Environment(AppState.self) private var app                    // 全局状态
    @StateObject private var purchase = PurchaseService()          // 内购服务

    var body: some View {                                          // 视图主体
        ScrollView {                                               // 可滚动
            VStack(spacing: Space.l) {                             // 纵向排列
                statusCard                                         // 当前档位
                planSection                                        // 商品列表
                featureTable                                       // 权益对比
                restoreRow                                         // 恢复购买
                legalText                                          // 法律与合规
            }                                                      // 排列结束
            .padding(Metrics.pagePadding)                          // 内边距
            .padding(.bottom, Space.xxl)                           // 底部留白
        }                                                          // 滚动结束
        .background(Color.appBG)                                   // 底色
        .navigationTitle("会员")                                    // 标题
        .navigationBarTitleDisplayMode(.inline)                    // 小标题
        .task {                                                    // 进入页面
            await purchase.loadProducts()                          // 拉商品
            purchase.startObserving { outcome in                   // 监听续期与退款
                app.applyPurchase(plan: outcome.plan,              // 落库档位
                                  expiresAt: outcome.expiresAt,    // 到期
                                  transactionID: outcome.transactionID) // 交易号
            }                                                      // 监听结束
        }                                                          // 任务结束
        .onDisappear { purchase.stopObserving() }                  // 离开停止监听
    }                                                              // body 结束

    // MARK: - 当前档位                                                  // 分节：当前

    private var statusCard: some View {                            // 状态卡
        Card {                                                     // 卡片
            HStack(spacing: Space.s) {                             // 横向排列
                VStack(alignment: .leading, spacing: 2) {           // 文字区
                    Text("当前档位").font(AppFont.caption).foregroundStyle(Color.textSecondary) // 说明
                    Text(app.entitlement.plan.title)                // 档位名
                        .font(AppFont.section)                      // 区段字号
                        .foregroundStyle(app.entitlement.isActive() ? Color.appBrand : Color.textSecondary) // 有效才高亮
                }                                                   // 文字区结束
                Spacer()                                            // 撑开
                if let expires = app.entitlement.expiresAt, app.entitlement.isActive() { // 有到期时间
                    Text("\(expires.formatted(date: .numeric, time: .omitted)) 到期") // 到期日
                        .font(AppFont.caption)                      // 小字
                        .foregroundStyle(Color.textSecondary)       // 次要色
                }                                                   // 分支结束
            }                                                       // 排列结束
            if let message = stateMessage {                         // 有状态提示
                Text(message)                                       // 提示
                    .font(AppFont.caption)                          // 小字
                    .foregroundStyle(stateColor)                    // 按结果上色
                    .frame(maxWidth: .infinity, alignment: .leading) // 左对齐
                    .padding(.top, Space.xs)                        // 与上方拉开
                    .fixedSize(horizontal: false, vertical: true)   // 允许换行
            }                                                       // 分支结束
        }                                                           // 卡片结束
    }                                                               // statusCard 结束

    private var stateMessage: String? {                            // 状态文案
        switch purchase.state {                                    // 按状态分支
        case .idle: return nil                                     // 空闲不提示
        case .loading: return "正在获取商品信息…"                     // 加载
        case .purchasing: return "正在支付，请不要退出…"                // 支付中
        case .success(let plan): return "已开通：\(plan.title)"       // 成功
        case .cancelled: return "已取消支付，没有扣款"                   // 取消
        case .failed(let reason): return reason                     // 失败原因
        }                                                           // 分支结束
    }                                                               // 属性结束

    private var stateColor: Color {                                // 状态配色
        switch purchase.state {                                    // 按状态分支
        case .success: return .appOK                               // 成功绿
        case .failed: return .appErr                               // 失败红
        default: return .textSecondary                             // 其它灰
        }                                                           // 分支结束
    }                                                               // 属性结束

    // MARK: - 商品                                                      // 分节：商品

    private var planSection: some View {                           // 商品区
        VStack(spacing: Space.s) {                                 // 纵向排列
            if purchase.products.isEmpty {                          // 没拉到商品
                Card {                                              // 说明卡
                    VStack(alignment: .leading, spacing: Space.xs) { // 纵向排列
                        Text("暂时没有可购买的商品").font(AppFont.section) // 标题
                        Text("商品需要在 App Store Connect 里创建，并在这里拉到才会显示。现在不显示假价格。") // 说明
                            .font(AppFont.caption)                   // 小字
                            .foregroundStyle(Color.textSecondary)    // 次要色
                            .fixedSize(horizontal: false, vertical: true) // 允许换行
                    }                                            // 排列结束
                }                                                // 卡片结束
            } else {                                            // 有商品
                ForEach(purchase.products, id: \.id) { product in // 逐个商品
                    productCard(product)                        // 单张卡
                }                                                // 遍历结束
            }                                                    // 分支结束
        }                                                        // 排列结束
    }                                                            // planSection 结束

    private func productCard(_ product: Product) -> some View {    // 商品卡
        let plan = PurchaseService.plan(for: product.id) ?? .yearly // 对应档位
        let owned = app.entitlement.plan == plan && app.entitlement.isActive() // 已经是这一档
        return Card {                                              // 卡片
            VStack(alignment: .leading, spacing: Space.s) {         // 纵向排列
                HStack {                                           // 标题行
                    Text(plan.title).font(AppFont.section)          // 档位名
                    Spacer()                                       // 撑开
                    Text(product.displayPrice)                     // 真实价格
                        .font(AppFont.metric)                      // 指标字号
                        .foregroundStyle(Color.appBrand)           // 品牌色
                }                                                  // 排列结束
                Text(product.description)                          // 商品说明
                    .font(AppFont.caption)                         // 小字
                    .foregroundStyle(Color.textSecondary)          // 次要色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
                PrimaryButton(title: owned ? "当前就是这一档" : "购买 \(plan.title)", // 按钮文案
                              systemImage: owned ? "checkmark.circle.fill" : "creditcard.fill", // 图标
                              enabled: !owned && purchase.state != .purchasing) { // 已购或支付中禁用
                    buy(product)                                   // 发起购买
                }                                                  // 按钮结束
            }                                                      // 排列结束
        }                                                          // 卡片结束
    }                                                              // productCard 结束

    private func buy(_ product: Product) {                         // 发起购买
        Task {                                                     // 异步
            guard let outcome = await purchase.purchase(product) else { return } // 没买成就结束
            app.applyPurchase(plan: outcome.plan,                  // 落库档位
                              expiresAt: outcome.expiresAt,        // 到期
                              transactionID: outcome.transactionID) // 交易号
        }                                                          // 任务结束
    }                                                              // buy 结束

    // MARK: - 权益对比                                                  // 分节：权益

    private var featureTable: some View {                          // 权益表
        Card {                                                     // 卡片
            VStack(alignment: .leading, spacing: Space.s) {         // 纵向排列
                Text("会员权益").font(AppFont.section)                // 标题
                ForEach(Feature.allCases) { feature in             // 逐项
                    HStack(spacing: Space.xs) {                    // 横向排列
                        Text(feature.title).font(AppFont.body)     // 能力名
                        Spacer()                                   // 撑开
                        Text(freeText(feature))                    // 免费额度
                            .font(AppFont.caption)                 // 小字
                            .foregroundStyle(Color.textTertiary)   // 弱化色
                            .frame(width: 88, alignment: .trailing) // 对齐
                        Text("不限")                                // 会员
                            .font(AppFont.captionStrong)           // 小字加粗
                            .foregroundStyle(Color.appBrand)       // 品牌色
                            .frame(width: 44, alignment: .trailing) // 对齐
                    }                                              // 排列结束
                }                                                  // 遍历结束
                Text("「免费」列是每天或每次的额度，「会员」列不限。额度每天零点重置。") // 口径
                    .font(AppFont.caption)                         // 小字
                    .foregroundStyle(Color.textTertiary)           // 弱化色
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行
            }                                                      // 排列结束
        }                                                          // 卡片结束
    }                                                              // featureTable 结束

    private func freeText(_ feature: Feature) -> String {          // 免费额度文案
        if let quota = feature.freeQuota {                         // 有额度
            return "\(quota)"                                      // 数字
        }                                                          // 分支结束
        return "不限"                                               // 本身不限
    }                                                              // freeText 结束

    // MARK: - 恢复与法律                                                // 分节：恢复

    private var restoreRow: some View {                            // 恢复购买
        VStack(spacing: Space.xs) {                                // 纵向排列
            GhostButton(title: "恢复购买", systemImage: "arrow.clockwise") { // 按钮
                Task {                                             // 异步
                    guard let outcome = await purchase.restore() else { return } // 没恢复成就结束
                    app.applyPurchase(plan: outcome.plan,           // 落库
                                      expiresAt: outcome.expiresAt, // 到期
                                      transactionID: outcome.transactionID) // 交易号
                }                                                  // 任务结束
            }                                                      // 按钮结束
            Text("换了手机、重装 App 后点这里找回已购买的会员。")              // 说明
                .font(AppFont.caption)                             // 小字
                .foregroundStyle(Color.textTertiary)               // 弱化色
        }                                                          // 排列结束
    }                                                              // restoreRow 结束

    private var legalText: some View {                             // 法律文本
        VStack(alignment: .leading, spacing: Space.xxs) {           // 纵向排列
            Text("· 连续订阅会自动续期，价格与周期以上面的商品信息为准。")      // 续期
            Text("· 取消路径：设置 → Apple ID → 订阅 → 选择「复试专」→ 取消订阅。") // 取消
            Text("· 取消后当前周期内仍可使用，到期不再扣款。")               // 到期
            Text("· 退款请走 Apple 官方渠道：reportaproblem.apple.com。") // 退款
            NavigationLink {                                       // 进法律页
                LegalView()                                        // 隐私政策与用户协议
            } label: {                                             // 链接外观
                Text("· 查看隐私政策与用户协议 →")                        // 入口文案
                    .foregroundStyle(Color.appBrand)               // 品牌色
            }                                                      // 链接结束
        }                                                          // 排列结束
        .font(AppFont.caption)                                     // 小字
        .foregroundStyle(Color.textTertiary)                       // 弱化色
        .frame(maxWidth: .infinity, alignment: .leading)           // 左对齐
    }                                                              // legalText 结束
}                                                                  // PaywallView 结束
