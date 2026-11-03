//  PetTests.swift —— 宠物饥饿与投喂规则测试                          // 文件说明
//  这是产品的核心约束：口粮只能靠闯关产出，不投喂就会饿死               // 测试目标
//  算错的后果是「学了一天宠物却饿死了」，比不给功能更伤人               // 风险说明

import XCTest                       // 测试框架
@testable import FuShiZhuan         // 拿到被测模块的内部类型

final class PetTests: XCTestCase {  // 宠物规则测试

    /// 固定为「某天中午」，避免跨零点导致的随机失败
    private var noon: Date {                          // 固定时刻
        var c = DateComponents()                      // 构造日期分量
        c.year = 2026                                 // 年
        c.month = 6                                   // 月
        c.day = 15                                    // 日
        c.hour = 12                                   // 时
        return Calendar.current.date(from: c)!        // 本地时区中午
    }                                                 // 属性结束

    /// 第 n 天后的中午
    private func day(_ n: Int) -> Date { noon.addingTimeInterval(Double(n) * 86_400) }  // 顺延 n 天

    // MARK: - 每日结算                                                  // 分节：结算

    func testFirstSettleDoesNotDecay() {                                // 第一次结算不扣体力
        var pet = Pet.default                                          // 默认体力 80
        pet.settle(now: noon)                                          // 首次结算
        XCTAssertEqual(pet.energy, Pet.default.energy)                 // 体力不变
        XCTAssertEqual(pet.lastDecayDate, noon)                        // 但记下了结算时间
    }                                                                  // 测试结束

    func testSameDayDoesNotDecay() {                             // 同一天多次打开不扣
        var pet = Pet.default                                   // 默认宠物
        pet.lastDecayDate = noon                                // 今天已结算过
        pet.settle(now: noon.addingTimeInterval(3_600))          // 一小时后
        XCTAssertEqual(pet.energy, 80)                          // 体力不变
    }                                                           // 测试结束

    func testOneDayDecay() {                                     // 隔一天扣 22
        var pet = Pet.default                                   // 默认宠物
        pet.lastDecayDate = noon                                // 上次结算在中午
        pet.settle(now: day(1))                                 // 第二天中午
        XCTAssertEqual(pet.energy, 58)                           // 写死 58：不能引用 Pet.dailyDecay，否则常量改坏了测试也跟着改
    }                                                           // 测试结束

    func testThreeDayDecay() {                                    // 隔三天扣 66
        var pet = Pet.default                                     // 默认宠物
        pet.lastDecayDate = noon                                  // 上次结算
        pet.settle(now: day(3))                                   // 三天后
        XCTAssertEqual(pet.energy, 14)                             // 写死 14：同上，断言必须独立于实现
    }                                                             // 测试结束

    func testEnergyNeverGoesNegative() {                          // 体力不会变负数
        var pet = Pet.default                                     // 默认宠物
        pet.energy = 20                                           // 只剩 20
        pet.lastDecayDate = noon                                  // 上次结算
        pet.settle(now: day(5))                                   // 五天后（该扣 110）
        XCTAssertEqual(pet.energy, 0)                             // 最低就是 0
    }                                                             // 测试结束

    // MARK: - 饿死规则                                                  // 分节：饿死

    func testStarvedWhenEnergyHitsZero() {                         // 体力归零就算饿死
        var pet = Pet.default                                      // 默认宠物
        pet.energy = 22                                            // 只够一天
        pet.lastDecayDate = noon                                   // 上次结算
        pet.settle(now: day(1))                                    // 一天后
        XCTAssertEqual(pet.energy, 0)                              // 体力归零
        XCTAssertTrue(pet.starved)                                 // 标记饿死
        XCTAssertEqual(pet.starvedDays, 1)                         // 饿了一天
    }                                                              // 测试结束

    func testNoAffinityLossOnFirstStarvedDay() {                   // 刚饿的当天不掉好感
        var pet = Pet.default                                      // 默认宠物
        pet.energy = 22                                            // 只够一天
        pet.affinity = 50                                          // 好感设为 50
        pet.lastDecayDate = noon                                   // 上次结算
        pet.settle(now: day(1))                                    // 一天后归零
        XCTAssertEqual(pet.affinity, 50)                           // 好感不掉
    }                                                              // 测试结束

    func testAffinityLossFromSecondStarvedDay() {                  // 从第二天起每天掉好感
        var pet = Pet.default                                      // 默认宠物
        pet.energy = 22                                            // 只够一天
        pet.affinity = 50                                          // 好感 50
        pet.lastDecayDate = noon                                   // 上次结算
        pet.settle(now: day(1))                                    // 第一天：归零但不掉好感
        pet.settle(now: day(2))                                    // 第二天：开始掉
        XCTAssertEqual(pet.affinity, 46)                            // 写死 46：饿死第二天掉 4 点好感
        XCTAssertEqual(pet.starvedDays, 2)                          // 已饿两天
    }                                                              // 测试结束

    func testReviveClearsStarvedFlag() {                           // 复活能清掉饿死状态
        var pet = Pet.default                                      // 默认宠物
        pet.starved = true                                         // 已饿死
        pet.starvedDays = 3                                        // 饿了三天
        pet.energy = 0                                             // 体力为 0
        pet.revive()                                               // 复活
        XCTAssertFalse(pet.starved)                                // 不再是饿死
        XCTAssertEqual(pet.starvedDays, 0)                         // 天数清零
        XCTAssertEqual(pet.energy, 30)                             // 给回 30 体力
    }                                                              // 测试结束

    // MARK: - 投喂                                                      // 分节：投喂

    func testFeedSucceeds() {                                              // 正常投喂
        var pet = Pet.default                                              // 默认宠物
        pet.energy = 40                                                    // 体力 40
        let outcome = pet.feed(now: noon)                                  // 喂一颗
        XCTAssertEqual(outcome, .ok(energy: 70, affinity: 14))              // 加 30 体力、4 好感
        XCTAssertEqual(pet.food, 1)                                        // 口粮少一颗
    }                                                                      // 测试结束

    func testFeedCapsEnergyAtMax() {                             // 体力不超过上限
        var pet = Pet.default                                   // 默认宠物
        pet.energy = 90                                         // 体力 90
        pet.feed(now: noon)                                     // 喂一颗
        XCTAssertEqual(pet.energy, 100)                         // 写死 100：体力上限
    }                                                           // 测试结束

    func testFeedWithoutFood() {                                // 没口粮喂不了
        var pet = Pet.default                                   // 默认宠物
        pet.food = 0                                            // 口粮清零
        XCTAssertEqual(pet.feed(now: noon), .noFood)            // 返回没口粮
        XCTAssertEqual(pet.food, 0)                             // 不会被扣成负数
    }                                                           // 测试结束

    func testFeedWhenFull() {                                   // 吃饱了不能喂
        var pet = Pet.default                                   // 默认宠物
        pet.energy = 100                                        // 写死 100：模拟体力已满
        XCTAssertEqual(pet.feed(now: noon), .alreadyFull)       // 返回已吃饱
        XCTAssertEqual(pet.food, 2)                             // 口粮不扣
    }                                                           // 测试结束

    func testFeedWhenDead() {                                   // 饿死状态下喂不了
        var pet = Pet.default                                   // 默认宠物
        pet.starved = true                                      // 已饿死
        XCTAssertEqual(pet.feed(now: noon), .dead)              // 返回已饿死
    }                                                           // 测试结束

    func testAddFoodIgnoresNonPositive() {                      // 加口粮只接受正数
        var pet = Pet.default                                   // 默认宠物
        pet.addFood(0)                                          // 加 0
        pet.addFood(-3)                                         // 加负数
        XCTAssertEqual(pet.food, 2)                             // 数量不变
        pet.addFood(5)                                          // 加 5
        XCTAssertEqual(pet.food, 7)                             // 应为 7
    }                                                           // 测试结束

    // MARK: - 成长阶段                                                  // 分节：阶段

    func testStageThresholds() {                                  // 成长值到阶段的映射
        XCTAssertEqual(PetStage.stage(for: 0), .seed)             // 0 是幼体
        XCTAssertEqual(PetStage.stage(for: 199), .seed)           // 未到 200 仍是幼体
        XCTAssertEqual(PetStage.stage(for: 200), .growing)        // 200 进入成长
        XCTAssertEqual(PetStage.stage(for: 599), .growing)        // 未到 600 仍是成长
        XCTAssertEqual(PetStage.stage(for: 600), .mature)         // 600 进入成熟
        XCTAssertEqual(PetStage.stage(for: 1_199), .mature)       // 未到 1200 仍是成熟
        XCTAssertEqual(PetStage.stage(for: 1_200), .master)       // 1200 进入硕士
    }                                                             // 测试结束

    func testHungryFlagBoundary() {                              // 濒危提示的边界
        var pet = Pet.default                                    // 默认宠物
        pet.energy = 31                                          // 略高于阈值
        XCTAssertFalse(pet.isHungry)                             // 不算濒危
        pet.energy = 30                                          // 正好到阈值
        XCTAssertTrue(pet.isHungry)                              // 算濒危
    }                                                            // 测试结束
}                                                                // 测试类结束
