//  PurchaseService.swift —— 内购（StoreKit 2）                        // 文件说明
//  只做「拿商品 / 买 / 校验 / 恢复 / 监听交易」，不碰界面                // 职责约束
//  铁律：只认 verified 的交易，校验不过一律不发货                        // 安全约束

import Combine                                                    // ObservableObject
import Foundation                                                 // 基础库
import StoreKit                                                   // 内购

/// 一次成功购买的结果，交给 AppState 落库
struct PurchaseOutcome: Equatable {                               // 购买结果
    let plan: Plan                                                // 买到了哪一档
    let expiresAt: Date?                                          // 订阅到期时间，永久为 nil
    let transactionID: String                                     // 交易号，用于对账
}                                                                 // PurchaseOutcome 结束

/// 界面要显示的状态
enum PurchaseState: Equatable {                                   // 购买状态
    case idle                                                     // 空闲
    case loading                                                  // 加载商品中
    case purchasing                                               // 支付中
    case success(Plan)                                            // 成功
    case cancelled                                                // 用户取消
    case failed(String)                                           // 失败，带原因
}                                                                 // PurchaseState 结束

@MainActor                                                        // 全部在主线程操作，界面直接用
final class PurchaseService: ObservableObject {                   // 内购服务
    /// 三个商品 id，必须与 App Store Connect 里建的一字不差
    static let monthlyID = "com.fushizhuan.app.monthly"           // 连续月付
    static let yearlyID = "com.fushizhuan.app.yearly"             // 连续年付
    static let lifetimeID = "com.fushizhuan.app.lifetime"         // 永久
    static let productIDs = [monthlyID, yearlyID, lifetimeID]     // 全部商品

    @Published private(set) var products: [Product] = []          // 拉到的商品
    @Published private(set) var state: PurchaseState = .idle       // 当前状态

    private var observer: Task<Void, Never>?                      // 交易更新监听

    // MARK: - 商品                                                      // 分节：商品

    /// 拉商品。失败不崩，把原因写进 state 让界面显示
    func loadProducts() async {                                    // 加载商品
        state = .loading                                          // 进入加载
        do {                                                       // 尝试拉取
            let items = try await Product.products(for: Self.productIDs) // 真实商品
            products = items.sorted { $0.price < $1.price }        // 便宜的在前面
            state = products.isEmpty ? .failed("没有拉到商品，检查 App Store Connect 是否已创建并放行") : .idle // 空就是没配好
        } catch {                                                  // 拉取失败
            state = .failed("商品加载失败：\(error.localizedDescription)") // 记录原因
        }                                                          // 分支结束
    }                                                              // loadProducts 结束

    /// 商品 id → 档位
    static func plan(for productID: String) -> Plan? {             // 映射档位
        switch productID {                                         // 按 id 分支
        case monthlyID: return .monthly                            // 月付
        case yearlyID: return .yearly                              // 年付
        case lifetimeID: return .lifetime                          // 永久
        default: return nil                                        // 不认识就不认
        }                                                          // 分支结束
    }                                                              // plan 结束

    // MARK: - 购买                                                      // 分节：购买

    /// 发起购买。返回 nil 表示没买成（取消、待确认、校验失败都算）
    func purchase(_ product: Product) async -> PurchaseOutcome? {   // 购买
        state = .purchasing                                        // 进入支付中
        do {                                                       // 尝试支付
            let result = try await product.purchase()               // 拉起系统支付
            switch result {                                        // 分情况处理
            case .success(let verification):                       // 拿到结果
                guard case .verified(let transaction) = verification else { // 校验不通过
                    state = .failed("交易校验未通过，已拒绝开通")        // 明确提示
                    return nil                                     // 不发货
                }                                                  // 分支结束
                await transaction.finish()                          // 告诉系统这笔已完成
                guard let plan = Self.plan(for: transaction.productID) else { // 认不出档位
                    state = .failed("未知商品，已拒绝开通")              // 兜底
                    return nil                                     // 不发货
                }                                                  // 分支结束
                state = .success(plan)                              // 记成功
                return PurchaseOutcome(plan: plan,                  // 返回结果
                                       expiresAt: transaction.expirationDate, // 订阅到期
                                       transactionID: String(transaction.id)) // 交易号
            case .userCancelled:                                   // 用户取消
                state = .cancelled                                  // 记取消
                return nil                                         // 没买成
            case .pending:                                         // 待确认（家长控制等）
                state = .failed("支付待确认，完成后会自动开通")            // 如实说明
                return nil                                         // 先不发货
            @unknown default:                                      // 未来新增的分支
                state = .failed("未知的购买结果")                       // 兜底
                return nil                                         // 不发货
            }                                                      // 分支结束
        } catch {                                                  // 抛错
            state = .failed("购买失败：\(error.localizedDescription)") // 记录原因
            return nil                                             // 没买成
        }                                                          // 分支结束
    }                                                              // purchase 结束

    // MARK: - 恢复                                                      // 分节：恢复

    /// 恢复购买：先同步账号，再遍历当前有效权益，取最高一档
    func restore() async -> PurchaseOutcome? {                      // 恢复购买
        state = .loading                                           // 进入加载
        do {                                                       // 尝试同步
            try await AppStore.sync()                              // 让系统重新校验账号
        } catch {                                                  // 同步失败
            state = .failed("恢复失败：\(error.localizedDescription)") // 记录原因
            return nil                                             // 结束
        }                                                          // 分支结束
        var best: PurchaseOutcome?                                 // 最好的那条
        for await result in Transaction.currentEntitlements {       // 遍历有效权益
            guard case .verified(let transaction) = result else { continue } // 只要校验过的
            guard let plan = Self.plan(for: transaction.productID), plan.isPaid else { continue } // 只认付费档
            if plan == .lifetime {                                  // 永久最高
                best = PurchaseOutcome(plan: plan, expiresAt: nil, transactionID: String(transaction.id)) // 直接取
                break                                               // 不用再看
            }                                                       // 分支结束
            if best == nil {                                        // 还没有更好的
                best = PurchaseOutcome(plan: plan,                  // 记下
                                       expiresAt: transaction.expirationDate, // 到期
                                       transactionID: String(transaction.id)) // 交易号
            }                                                       // 分支结束
        }                                                          // 遍历结束
        if let best {                                              // 找到了
            state = .success(best.plan)                            // 记成功
        } else {                                                   // 没找到
            state = .failed("这个 Apple ID 下没有可恢复的购买")          // 如实说明
        }                                                          // 分支结束
        return best                                                // 返回
    }                                                              // restore 结束

    // MARK: - 监听                                                      // 分节：监听

    /// 监听交易更新：续期、退款、跨设备购买都会走这里
    func startObserving(onUpdate: @escaping (PurchaseOutcome) -> Void) { // 开始监听
        guard observer == nil else { return }                      // 只起一次
        observer = Task { [weak self] in                           // 后台任务
            for await result in Transaction.updates {               // 交易流
                guard case .verified(let transaction) = result else { continue } // 只要校验过的
                guard let plan = Self.plan(for: transaction.productID) else { continue } // 认得的商品才处理
                await transaction.finish()                          // 标记已完成
                let outcome = PurchaseOutcome(plan: plan,           // 组装结果
                                              expiresAt: transaction.expirationDate, // 到期
                                              transactionID: String(transaction.id)) // 交易号
                self?.state = .success(plan)                        // 更新状态
                onUpdate(outcome)                                   // 通知上层落库
            }                                                       // 循环结束
        }                                                           // 任务结束
    }                                                              // startObserving 结束

    /// 停止监听
    func stopObserving() {                                          // 停止
        observer?.cancel()                                         // 取消任务
        observer = nil                                             // 清引用
    }                                                              // stopObserving 结束
}                                                                  // PurchaseService 结束
