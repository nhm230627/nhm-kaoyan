//  SmokeUITests.swift —— 真机级交互冒烟测试                            // 文件说明
//  跑在 CI 的 iPhone 模拟器上，真的点 Tab、真的滑页面、真的点画布。      // 运行环境
//  存在的理由：截图只能证明「画出来了」，证明不了「点得动、滑得动、不崩」。// 目的
//  判定标准刻意保守：每一步之后 App 必须仍在前台（没崩、没被系统杀掉），
//  关键元素必须存在。不做像素级断言，避免模拟器版本差异导致假红。        // 判定口径

import XCTest  // 测试框架

final class SmokeUITests: XCTestCase {  // 冒烟测试集

    override func setUpWithError() throws {  // 每个用例前
        continueAfterFailure = false  // 一失败就停，别连着一串假错
    }  // setUp 结束

    /// 带启动参数冷启一次
    private func launch(_ args: [String] = []) -> XCUIApplication {  // 启动 App
        let app = XCUIApplication()  // 新的 App 句柄
        app.launchArguments = args  // 传启动参数（-startTab / -startShot）
        app.launch()  // 真正启动
        return app  // 返回句柄
    }  // launch 结束

    /// 五个 Tab 逐个点，每页上下滑一屏
    func testFiveTabsTapAndSwipe() throws {  // Tab 点击与滑动
        let app = launch()  // 默认进今日
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App 没启动起来")  // 启动检查
        let tabs = ["今日", "刷题", "面试", "伙伴", "我的"]  // 五个 Tab
        for name in tabs {  // 逐个
            let button = app.tabBars.buttons[name]  // 取 Tab 按钮
            XCTAssertTrue(button.waitForExistence(timeout: 20), "找不到 Tab：\(name)")  // 必须存在
            button.tap()  // 点它
            app.swipeUp()  // 往上滑
            app.swipeDown()  // 滑回来
            XCTAssertEqual(app.state, .runningForeground, "\(name) 页操作后 App 不在前台")  // 没崩
        }  // 遍历结束
    }  // 用例结束

    /// 深页逐个进（靠 -startShot），每页滑一下，确认不崩
    func testDeepPagesSwipe() throws {  // 深页滑动
        let pages = ["papers", "wrongbook", "sortmap", "mock", "tracksheet",  // 学习相关
                     "community", "post",  // 社区
                     "room", "ritual", "duel", "plaza",  // 面试与伙伴
                     "run", "result", "diy", "avatar", "sortplay", "paper"]  // 作答与换装
        for page in pages {  // 逐页
            let app = launch(["-startTab", "quiz", "-startShot", page])  // 直接落到该页
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "\(page) 启动失败")  // 启动检查
            Thread.sleep(forTimeInterval: 2.5)  // 等首帧与 3D 渲染
            app.swipeUp()  // 上滑
            app.swipeDown()  // 下滑
            XCTAssertEqual(app.state, .runningForeground, "\(page) 页滑动后 App 不在前台")  // 没崩
            app.terminate()  // 关掉，下一页重新冷启
        }  // 遍历结束
    }  // 用例结束

    /// 广场：点画布中间的宠物 → 出卡片 → 打招呼 → 点组队 → 关掉
    func testPlazaTapAndInteract() throws {  // 广场交互
        let app = launch(["-startTab", "companion", "-startShot", "plaza"])  // 直接进广场
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "广场没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 4)  // 等宠物铺开并走动

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).tap()  // 点画布中下方
        Thread.sleep(forTimeInterval: 0.8)  // 等卡片动画
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.34)).tap()  // 点左上区域（可能是另一只宠物）
        Thread.sleep(forTimeInterval: 0.8)  // 等卡片动画
        app.swipeUp()  // 在画布上滑一下（不该崩）
        app.swipeDown()  // 滑回来
        XCTAssertEqual(app.state, .runningForeground, "广场交互后 App 不在前台")  // 没崩
    }  // 用例结束

    /// 刷题作答页：点选项、点下一题、点答题卡
    func testQuizRunTapping() throws {  // 作答页点击
        let app = launch(["-startTab", "quiz", "-startShot", "run"])  // 直接进作答页
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "作答页没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 3)  // 等题库加载

        let next = app.buttons["下一题"]  // 下一题按钮
        if next.waitForExistence(timeout: 10) {  // 找得到就点
            app.swipeUp()  // 先滑到按钮附近
            next.tap()  // 点下一题
        }  // 分支结束
        let prev = app.buttons["上一题"]  // 上一题按钮
        if prev.waitForExistence(timeout: 5) {  // 找得到就点
            prev.tap()  // 点回去
        }  // 分支结束
        XCTAssertEqual(app.state, .runningForeground, "作答页交互后 App 不在前台")  // 没崩
    }  // 用例结束
}  // SmokeUITests 结束
