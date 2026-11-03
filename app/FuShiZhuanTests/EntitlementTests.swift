//  EntitlementTests.swift —— 权益判定的边界测试                      // 文件说明
//  锁住三件事：免费额度会用完、跨天会重置、付费后不再受限              // 测试目标
//  这些规则一旦算错，用户就会撞到「明明买了还被拦」或「不买也能无限用」    // 风险说明

import XCTest                       // 测试框架
@testable import FuShiZhuan         // 拿到被测模块的内部类型

final class EntitlementTests: XCTestCase {  // 权益判定测试

    /// 固定为「某天中午」，避免测试恰好跨零点时随机失败
    private var noon: Date {                          // 固定时刻
        var c = DateComponents()                      // 构造日期分量
        c.year = 2026                                 // 年
        c.month = 6                                   // 月
        c.day = 15                                    // 日
        c.hour = 12                                   // 时
        return Calendar.current.date(from: c)!        // 本地时区中午
    }                                                 // 属性结束

    /// 次日中午，用来测跨天重置
    private var nextNoon: Date { noon.addingTimeInterval(86_400) }  // 加整整一天

    // MARK: - 会员是否有效                                              // 分节：有效性

    func testFreePlanIsNotActive() {                              // 免费档不算会员
        XCTAssertFalse(Entitlement.default.isActive(now: noon))   // 默认就是免费档
    }                                                             // 测试结束

    func testLifetimeIsAlwaysActive() {                                               // 永久档永远有效
        var e = Entitlement.default                                                   // 从默认档起步
        e.apply(plan: .lifetime, expiresAt: nil, transactionID: "t1")                 // 写入购买结果
        XCTAssertTrue(e.isActive(now: noon))                                          // 现在有效
        XCTAssertTrue(e.isActive(now: noon.addingTimeInterval(86_400 * 3650)))         // 十年后仍有效
    }                                                                                 // 测试结束

    func testMonthlyWithoutExpiryIsInactive() {                        // 月付没到期时间算过期
        var e = Entitlement.default                                    // 默认档
        e.plan = .monthly                                              // 直接改成月付
        e.expiresAt = nil                                              // 故意不填到期
        XCTAssertFalse(e.isActive(now: noon))                          // 应判无效
    }                                                                  // 测试结束

    func testMonthlyExpiredIsInactive() {                                  // 过期的月付不算会员
        var e = Entitlement.default                                        // 默认档
        e.plan = .monthly                                                  // 月付
        e.expiresAt = noon.addingTimeInterval(-1)                          // 一秒前刚过期
        XCTAssertFalse(e.isActive(now: noon))                              // 应判无效
    }                                                                      // 测试结束

    func testMonthlyValidIsActive() {                       // 未过期的月付有效
        var e = Entitlement.default                         // 默认档
        e.plan = .monthly                                   // 月付
        e.expiresAt = noon.addingTimeInterval(86_400)       // 明天到期
        XCTAssertTrue(e.isActive(now: noon))                // 应判有效
    }                                                       // 测试结束

    // MARK: - 免费额度                                                  // 分节：额度

    func testFreeQuotaStartsFull() {                                            // 免费额度一开始是满的
        XCTAssertEqual(Entitlement.default.remaining(.interviewDaily, now: noon), 1)  // 面试每天 1 场
        XCTAssertEqual(Entitlement.default.remaining(.quizUnlimited, now: noon), 30)  // 刷题每天 30 题
    }                                                                           // 测试结束

    func testZeroQuotaFeatureIsBlocked() {                                   // 额度为 0 的能力直接拦
        XCTAssertEqual(Entitlement.default.remaining(.reportDetail, now: noon), 0)  // 详细报告免费不给
        XCTAssertFalse(Entitlement.default.canUse(.reportDetail, now: noon))        // 应判不能用
    }                                                                        // 测试结束

    func testUnlimitedFeatureIgnoresQuota() {                            // 本就不限的能力永远能用
        XCTAssertNil(Entitlement.default.remaining(.plazaFull, now: noon))  // 广场返回 nil 表示不限
        XCTAssertTrue(Entitlement.default.canUse(.plazaFull, now: noon))    // 应判能用
    }                                                                    // 测试结束

    func testConsumeUntilQuotaRunsOut() {                                // 用完为止
        var e = Entitlement.default                                     // 默认免费档
        XCTAssertTrue(e.consume(.interviewDaily, now: noon))            // 第 1 次扣成功
        XCTAssertEqual(e.remaining(.interviewDaily, now: noon), 0)      // 额度已归零
        XCTAssertFalse(e.consume(.interviewDaily, now: noon))           // 第 2 次应被拒
    }                                                                   // 测试结束

    func testQuotaResetsNextDay() {                                          // 跨天额度重置
        var e = Entitlement.default                                         // 默认档
        XCTAssertTrue(e.consume(.interviewDaily, now: noon))                // 今天用掉
        XCTAssertFalse(e.canUse(.interviewDaily, now: noon))                // 今天不能再用了
        XCTAssertTrue(e.canUse(.interviewDaily, now: nextNoon))             // 第二天应恢复
        XCTAssertEqual(e.remaining(.interviewDaily, now: nextNoon), 1)      // 额度回到 1
    }                                                                       // 测试结束

    func testConsumeDoesNotGoNegative() {                              // 记录不会变成负数
        var e = Entitlement.default                                   // 默认档
        for _ in 0..<5 { e.consume(.interviewDaily, now: noon) }      // 连扣五次
        XCTAssertEqual(e.remaining(.interviewDaily, now: noon), 0)    // 剩余最小为 0
        XCTAssertEqual(e.dailyUsage[Feature.interviewDaily.rawValue], 1)  // 只记到 1 次，超出不记
    }                                                                 // 测试结束

    func testPaidPlanIgnoresQuota() {                                    // 付费后不再受额度限制
        var e = Entitlement.default                                     // 默认档
        e.apply(plan: .yearly, expiresAt: nextNoon, transactionID: "t2")  // 开通年付
        XCTAssertNil(e.remaining(.interviewDaily, now: noon))           // 付费后返回 nil 表示不限
        for _ in 0..<10 {                                               // 连扣十次
            XCTAssertTrue(e.consume(.interviewDaily, now: noon))        // 每次都应成功
        }                                                               // 循环结束
        XCTAssertTrue(e.dailyUsage.isEmpty)                             // 且一分钱都不记
    }                                                                   // 测试结束

    // MARK: - 写入与回退                                                // 分节：状态变更

    func testApplyClearsUsage() {                                    // 开通会员时清空当天计数
        var e = Entitlement.default                                  // 默认档
        e.consume(.interviewDaily, now: noon)                        // 先用掉一次
        e.apply(plan: .monthly, expiresAt: nextNoon, transactionID: "t3")  // 开通月付
        XCTAssertTrue(e.dailyUsage.isEmpty)                          // 计数应被清空
        XCTAssertEqual(e.plan, .monthly)                             // 档位已更新
        XCTAssertEqual(e.originalTransactionID, "t3")                // 交易号已记下
    }                                                                // 测试结束

    func testRevokeFallsBackToFree() {                               // 退款后回落免费档
        var e = Entitlement.default                                  // 默认档
        e.apply(plan: .yearly, expiresAt: nextNoon, transactionID: "t4")  // 先开通
        e.revoke()                                                   // 再撤销
        XCTAssertEqual(e.plan, .free)                                // 回到免费
        XCTAssertNil(e.expiresAt)                                    // 到期时间清空
        XCTAssertFalse(e.isActive(now: noon))                        // 不再是会员
    }                                                                // 测试结束
}                                                                    // 测试类结束
