//  SnapshotStoreTests.swift —— 本地持久化测试                          // 文件说明
//  锁住三件事：写了能读回来、主文件坏了用备份、重置真的清干净             // 测试目标
//  存档一坏用户就丢全部学习记录，这是最不能出错的模块                    // 风险说明

import XCTest                       // 测试框架
@testable import FuShiZhuan         // 拿到被测模块的内部类型

final class SnapshotStoreTests: XCTestCase {  // 持久化测试

    private var directory: URL!      // 每次测试独立的临时目录
    private var store: SnapshotStore!  // 被测对象

    override func setUpWithError() throws {                                        // 每个测试前准备
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)  // 唯一临时目录
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)     // 建目录
        store = SnapshotStore(directory: directory)                                // 指向临时目录的存储
    }                                                                              // 准备结束

    override func tearDownWithError() throws {                                     // 每个测试后清理
        try? FileManager.default.removeItem(at: directory)                          // 删掉整个临时目录
        store = nil                                                                // 释放引用
        directory = nil                                                            // 释放引用
    }                                                                              // 清理结束

    /// 整秒时间戳，避免 ISO8601 编码丢掉毫秒导致比较失败
    private let fixedDate = Date(timeIntervalSince1970: 1_780_000_000)  // 固定时刻

    /// 轮询等待异步写盘完成
    private func waitUntil(_ seconds: TimeInterval = 3, _ condition: () -> Bool) -> Bool {  // 等待条件成立
        let deadline = Date().addingTimeInterval(seconds)                            // 最晚等到什么时候
        while Date() < deadline {                                                    // 在时限内反复检查
            if condition() { return true }                                           // 满足就返回
            Thread.sleep(forTimeInterval: 0.05)                                      // 歇 50 毫秒再来
        }                                                                            // 循环结束
        return condition()                                                           // 最后再检查一次
    }                                                                                // 方法结束

    /// 主文件路径，与 SnapshotStore 内部约定一致
    private var mainFile: URL { directory.appendingPathComponent("appstate.json") }  // 主文件
    private var backupFile: URL { directory.appendingPathComponent("appstate.backup.json") }  // 备份文件

    // MARK: - 读取                                                      // 分节：读取

    func testLoadReturnsNilWhenNoFile() throws {                        // 没有存档时返回 nil
        XCTAssertNil(try store.load())                                  // 首次安装的正常情况
    }                                                                   // 测试结束

    func testExportThrowsWhenNoFile() {                                 // 没有存档时导出报错
        XCTAssertThrowsError(try store.exportData())                    // 应抛错而不是返回空数据
    }                                                                   // 测试结束

    // MARK: - 写入与读回                                                // 分节：往返

    func testSaveAndLoadRoundTrip() throws {                            // 写进去能读回来
        var snapshot = AppSnapshot.fresh()                              // 全新档案
        snapshot.growth = 123                                           // 改成长值
        snapshot.streakDays = 3                                         // 改连签天数
        snapshot.pet.energy = 55                                        // 改宠物体力
        snapshot.pet.lastDecayDate = fixedDate                          // 固定结算时间
        snapshot.entitlement.usageDate = fixedDate                      // 固定额度日期
        snapshot.lastCheckInDate = fixedDate                            // 固定打卡时间

        store.save(snapshot)                                            // 异步写盘
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.mainFile.path) })  // 等文件出现

        let loaded = try store.load()                                   // 读回来
        XCTAssertNotNil(loaded)                                         // 应有内容
        XCTAssertEqual(loaded?.schemaVersion, AppSnapshot.currentVersion)  // 版本号一致
        XCTAssertEqual(loaded?.growth, 123)                             // 成长值一致
        XCTAssertEqual(loaded?.streakDays, 3)                           // 连签一致
        XCTAssertEqual(loaded?.pet.energy, 55)                          // 体力一致
        XCTAssertEqual(loaded?.pet.lastDecayDate, fixedDate)            // 日期一致
        XCTAssertEqual(loaded?.lastCheckInDate, fixedDate)              // 打卡时间一致
    }                                                                   // 测试结束

    func testSecondSaveCreatesBackup() throws {                         // 第二次写入会留一份备份
        var first = AppSnapshot.fresh()                                 // 第一份档案
        first.growth = 111                                              // 标记第一份
        store.save(first)                                               // 写第一份
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.mainFile.path) })  // 等主文件

        var second = AppSnapshot.fresh()                                // 第二份档案
        second.growth = 222                                             // 标记第二份
        store.save(second)                                              // 写第二份
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.backupFile.path) })  // 等备份出现
    }                                                                   // 测试结束

    // MARK: - 坏档恢复                                                  // 分节：恢复

    func testCorruptedMainFallsBackToBackup() throws {                  // 主文件坏了用备份
        var first = AppSnapshot.fresh()                                 // 第一份档案
        first.growth = 111                                              // 标记为 111
        store.save(first)                                               // 写第一份
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.mainFile.path) })  // 等主文件

        var second = AppSnapshot.fresh()                                // 第二份档案
        second.growth = 222                                             // 标记为 222
        store.save(second)                                              // 写第二份，此时备份是 111
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.backupFile.path) })  // 等备份

        try Data("这不是合法的 JSON".utf8).write(to: mainFile)              // 故意把主文件写坏
        let loaded = try store.load()                                   // 应从备份恢复
        XCTAssertEqual(loaded?.growth, 111)                             // 读到的是备份里的 111
    }                                                                   // 测试结束

    func testResetRemovesEverything() throws {                          // 重置会删干净
        var snapshot = AppSnapshot.fresh()                              // 空档案
        snapshot.growth = 1                                             // 随便改一个值
        store.save(snapshot)                                            // 写一次
        XCTAssertTrue(waitUntil { FileManager.default.fileExists(atPath: self.mainFile.path) })  // 等文件

        store.reset()                                                   // 重置
        XCTAssertNil(try store.load())                                  // 读不到了
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.mainFile.path))  // 主文件已删
    }                                                                   // 测试结束
}                                                                      // 测试类结束
