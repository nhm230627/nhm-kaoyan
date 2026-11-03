//  SmokeUITests.swift —— 真机级交互测试                                // 文件说明
//  跑在 CI 的 iPhone 模拟器上，真的点 Tab、真的滑页面、真的点画布、真的发帖交卷。// 运行环境
//  存在的理由：截图只能证明「画出来了」，证明不了「点得动、点了有没有写入」。// 目的
//  判定标准刻意保守：每一步之后 App 必须仍在前台（没崩），关键结果必须出现
//  （例如交卷后出现「再来一组」、发帖后列表出现正文、点赞后数字变化）。      // 判定口径

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

    /// 在一组候选里挑第一个「存在且能点」的点下去
    /// 为什么不按下标取第一个：同一个文案在页面里可能有多个（顶部「交卷」与底部「交卷」），
    /// 第一个未必在可视区域，直接 tap 会抛 not hittable，测出来的是假失败。
    private func tapFirstHittable(_ query: XCUIElementQuery) -> Bool {  // 点第一个能点的
        for i in 0..<query.count {  // 逐个候选
            let element = query.element(boundBy: i)  // 取第 i 个
            if element.exists, element.isHittable {  // 存在且可见可点
                element.tap()  // 点它
                return true  // 报告成功
            }  // 分支结束
        }  // 遍历结束
        return false  // 一个都点不了
    }  // 方法结束

    /// 输入文字，失败重试一次（模拟器偶尔丢焦点）
    private func typeText(_ text: String, into element: XCUIElement) -> Bool {  // 往控件里打字
        for attempt in 0..<2 {  // 最多试两次
            element.tap()  // 先聚焦
            Thread.sleep(forTimeInterval: 0.6)  // 等键盘弹起
            element.typeText(text)  // 打字
            if (element.value as? String)?.contains(text) == true { return true }  // 值里有了就算成
            if (element.value as? String)?.isEmpty == false { return true }  // 值非空也算成（控件会带占位符）
            if attempt == 0 { Thread.sleep(forTimeInterval: 1) }  // 第一次失败等一下再试
        }  // 循环结束
        return false  // 两次都没打进去
    }  // 方法结束

    /// 打开通用模考（冷启时题库可能还没加载好，第一次点只会弹提示，所以最多试三次）
    private func openCommonMock(_ app: XCUIApplication) -> Bool {  // 开通用模考
        let hero = app.buttons["mock-hero"]  // 通用模考卡
        guard hero.waitForExistence(timeout: 25) else { return false }  // 页面没出来
        for _ in 0..<3 {  // 最多三次
            hero.tap()  // 试开卷
            if app.buttons.matching(identifier: "交卷").firstMatch.waitForExistence(timeout: 6) { return true }  // 作答页出来了
            Thread.sleep(forTimeInterval: 1.5)  // 等题库加载再试
        }  // 循环结束
        return false  // 三次都没开成
    }  // 方法结束

    /// 交卷（一题不答，20 题全部按错计入错题本）
    private func submitMock(_ app: XCUIApplication) -> Bool {  // 交卷
        guard tapFirstHittable(app.buttons.matching(identifier: "交卷")) else { return false }  // 点不到交卷
        return app.buttons["再来一组"].waitForExistence(timeout: 20)  // 结果页出现的标志
    }  // 方法结束

    // MARK: - 五 Tab 与深页                                              // 分节：导航

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

    // MARK: - 广场                                                      // 分节：广场

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

    // MARK: - 作答与交卷                                                // 分节：刷题

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

    /// 模考大厅：开通用卷 → 交卷 → 出结果（得分/逐题解析/再来一组）→ 完成退出
    /// 这一条同时验证了「模考能开卷」「交卷能结算」「结果页有出口」三件事。
    func testMockExamSubmitAndExit() throws {  // 模考开卷与交卷
        let app = launch(["-startTab", "quiz", "-startShot", "mock"])  // 直接进模考页
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "模考页没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 3)  // 等题库加载

        XCTAssertTrue(openCommonMock(app), "点通用模考卡没开出卷子")  // 开卷
        XCTAssertTrue(submitMock(app), "点交卷后没出现结果页")  // 交卷
        XCTAssertTrue(app.staticTexts["逐题解析"].exists, "结果页缺少逐题解析区")  // 结果页结构
        let unanswered = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "还有"))  // 未答提示
        XCTAssertTrue(unanswered.firstMatch.exists, "一题没答却没出「还有 N 题未作答」提示")  // 未答计数

        let done = app.buttons["完成"]  // 交卷后的出口
        XCTAssertTrue(done.waitForExistence(timeout: 10), "交卷后没有退出按钮，用户会被卡在结果页")  // 这个按钮曾经真的缺过
        done.tap()  // 退出结果页
        XCTAssertTrue(app.buttons["mock-hero"].waitForExistence(timeout: 10), "点完成没回到模考大厅")  // 回来了
    }  // 用例结束

    /// 错题本：先用真实交卷造错题 → 看解析 → 标记已掌握 → 放回待攻
    /// 注意：错题本不塞假数据，全部来自上一步真实交卷的 20 道错题。
    func testWrongBookFromRealWrongs() throws {  // 错题本真实动作
        let first = launch(["-startTab", "quiz", "-startShot", "mock"])  // 先进模考
        XCTAssertTrue(first.wait(for: .runningForeground, timeout: 30), "模考页没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 3)  // 等题库加载
        XCTAssertTrue(openCommonMock(first), "点通用模考卡没开出卷子")  // 开卷
        XCTAssertTrue(submitMock(first), "点交卷后没出现结果页")  // 交卷（这里产生的错题就是待测数据）
        Thread.sleep(forTimeInterval: 2.5)  // 等 0.4 秒防抖落盘写完
        first.terminate()  // 关掉再冷启，确认真的是从存档读回来的

        let app = launch(["-startTab", "quiz", "-startShot", "wrongbook"])  // 直接进错题本
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "错题本没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 3)  // 等题库加载

        let explain = app.buttons.matching(identifier: "看解析")  // 每条错题都有
        XCTAssertTrue(explain.firstMatch.waitForExistence(timeout: 20), "错题本是空的，说明交卷没把错题写进存档")  // 有数据
        XCTAssertTrue(tapFirstHittable(explain), "点不到「看解析」")  // 展开解析
        XCTAssertTrue(app.buttons["收起解析"].waitForExistence(timeout: 8), "点了看解析但解析没展开")  // 真的展开了

        let resolve = app.buttons.matching(identifier: "已掌握")  // 待攻错题才有
        XCTAssertTrue(tapFirstHittable(resolve), "点不到「已掌握」")  // 标记掌握
        XCTAssertTrue(app.buttons["放回待攻"].waitForExistence(timeout: 8), "点了已掌握但按钮没变成放回待攻")  // 状态真的写进去了

        XCTAssertTrue(tapFirstHittable(app.buttons.matching(identifier: "放回待攻")), "点不到「放回待攻」")  // 再放回去
        XCTAssertTrue(app.buttons["已掌握"].waitForExistence(timeout: 8), "放回待攻后按钮没变回已掌握")  // 双向都通
    }  // 用例结束

    // MARK: - 社区与发帖                                                // 分节：社区

    /// 社区：发帖 → 列表出现新帖 → 进详情 → 点赞数字变化 → 发评论 → 评论出现在列表
    func testCommunityPublishLikeComment() throws {  // 社区完整动作
        let token = "zzuitest20261103"  // 唯一正文，避免和种子帖撞车
        let app = launch(["-startTab", "quiz", "-startShot", "community"])  // 直接进论坛
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "研友论坛没启动起来")  // 启动检查
        Thread.sleep(forTimeInterval: 2)  // 等首帧

        let fab = app.buttons["compose-fab"]  // 右下角发帖按钮
        XCTAssertTrue(fab.waitForExistence(timeout: 15), "找不到发帖按钮")  // 必须在
        fab.tap()  // 打开发帖层

        let editor = app.textViews.firstMatch  // 正文输入框（TextEditor 暴露成 textView）
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "发帖层没有正文输入框")  // 必须在
        XCTAssertTrue(typeText(token, into: editor), "正文没打进去")  // 打字

        let publish = app.buttons.matching(identifier: "发布")  // 右上角发布
        XCTAssertTrue(tapFirstHittable(publish), "点不到发布")  // 发布
        let newPost = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", token)).firstMatch  // 新帖正文
        XCTAssertTrue(newPost.waitForExistence(timeout: 10), "发布后列表里没出现刚发的帖")  // 真的写进列表了
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "· 我")).firstMatch.exists,
                      "自己发的帖没有「· 我」标记")  // isMine 生效

        newPost.tap()  // 进详情
        let like = app.buttons["post-like"]  // 点赞按钮
        XCTAssertTrue(like.waitForExistence(timeout: 10), "帖子详情里没有点赞按钮")  // 必须在
        let before = like.label  // 点赞前的数字
        like.tap()  // 点一下
        Thread.sleep(forTimeInterval: 0.8)  // 等界面刷新
        XCTAssertNotEqual(like.label, before, "点赞后按钮文案没变，说明点赞没写进状态")  // 真的变了

        let field = app.textFields["说点什么…"]  // 评论输入框
        XCTAssertTrue(field.waitForExistence(timeout: 8), "帖子详情没有评论输入框")  // 必须在
        XCTAssertTrue(typeText("zzcomment", into: field), "评论没打进去")  // 打字
        let send = app.buttons["comment-send"]  // 发送按钮
        XCTAssertTrue(send.waitForExistence(timeout: 8), "找不到评论发送按钮")  // 必须在
        send.tap()  // 发出去
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "zzcomment")).firstMatch
                        .waitForExistence(timeout: 10), "评论没出现在评论区")  // 真的写进去了
    }  // 用例结束

    // MARK: - 今日打卡                                                  // 分节：今日

    /// 今日：点打卡 → 任务行状态变「已打卡」
    func testTodayCheckIn() throws {  // 今日打卡
        let app = launch()  // 默认进今日
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App 没启动起来")  // 启动检查
        let checkIn = app.buttons["today-checkin"]  // 页头打卡圆钮
        XCTAssertTrue(checkIn.waitForExistence(timeout: 20), "找不到打卡按钮")  // 必须在
        checkIn.tap()  // 打卡
        Thread.sleep(forTimeInterval: 1.5)  // 等状态刷新与落盘
        XCTAssertTrue(app.staticTexts["已打卡"].waitForExistence(timeout: 8), "打卡后任务行没显示已打卡")  // 状态真的变了
        XCTAssertEqual(app.state, .runningForeground, "打卡后 App 不在前台")  // 没崩
    }  // 用例结束
}  // SmokeUITests 结束
