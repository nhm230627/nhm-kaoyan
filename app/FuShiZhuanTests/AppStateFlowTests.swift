//  AppStateFlowTests.swift —— 状态层写入与旧档兼容测试                // 文件说明
//  锁住四件事：旧快照缺新字段能读、错题进出闭环、发帖评论点赞真的写进去、
//  1V1 结算按胜负记分。这些全是「页面点了没反应」类 bug 的源头。        // 测试目标
//  刻意不 mock 网络：这一层本来就是纯本地状态，测的就是落盘数据本身。   // 边界说明

import XCTest  // 测试框架
@testable import FuShiZhuan  // 拿到被测模块的内部类型

final class AppStateFlowTests: XCTestCase {  // 状态层测试

    private var directory: URL!  // 临时存档目录
    private var state: AppState!  // 被测状态

    override func setUpWithError() throws {  // 每个用例前
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)  // 唯一目录
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)  // 建目录
        state = AppState(store: SnapshotStore(directory: directory))  // 指向临时目录的状态
    }  // 准备结束

    override func tearDownWithError() throws {  // 每个用例后
        try? FileManager.default.removeItem(at: directory)  // 删掉临时目录
        state = nil  // 释放
        directory = nil  // 释放
    }  // 清理结束

    /// 造一道单选题：正确答案是 A，选 B 必错
    private func sampleQuestion(_ id: String = "q1") -> Question {  // 样例题
        Question(id: id,  // 题号
                 topic: "tax-vat",  // 板块
                 type: .single,  // 单选
                 stem: "增值税的征税对象是什么？",  // 题干
                 options: ["货物和劳务", "仅货物", "仅服务", "仅无形资产"],  // 四个选项
                 answer: [0],  // 正确答案是 A
                 explain: "增值税对销售货物、劳务、服务、无形资产和不动产普遍征收。",  // 解析
                 source: "考纲重构")  // 来源
    }  // 方法结束

    // MARK: - 旧档兼容                                                  // 分节：兼容

    /// 旧版本快照没有后加的字段，必须能正常解码并落到默认值
    /// 为什么重要：用户升级 App 后如果读不出旧档，等于全部学习记录清零。
    func testOldSnapshotWithoutNewFieldsDecodes() throws {  // 旧档缺字段
        let full = AppSnapshot.fresh()  // 全字段档案
        let encoded = try JSONEncoder().encode(full)  // 编成 JSON
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])  // 转字典
        let addedLater = ["outfit", "diy", "track", "todayCompanion", "companionDate",  // 后加字段
                          "communityPosts", "communityLikes", "communitySeedComments",  // 社区
                          "plazaFriends", "duelGames", "duelWins"]  // 广场与 1V1
        for key in addedLater { dict.removeValue(forKey: key) }  // 全部删掉，模拟旧版本存档
        let stripped = try JSONSerialization.data(withJSONObject: dict)  // 重新编码

        let decoded = try JSONDecoder().decode(AppSnapshot.self, from: stripped)  // 解码旧档
        XCTAssertEqual(decoded.track, "tax", "缺 track 时应回到默认方向 tax")  // 默认方向
        XCTAssertEqual(decoded.plazaFriends, [], "缺 plazaFriends 时应为空数组")  // 默认空
        XCTAssertEqual(decoded.duelGames, 0, "缺 duelGames 时应为 0")  // 默认 0
        XCTAssertEqual(decoded.communityPosts.count, 0, "缺 communityPosts 时应为空")  // 默认空
        XCTAssertEqual(decoded.outfit, CatOutfit.default, "缺 outfit 时应回到默认穿戴")  // 默认穿戴
    }  // 用例结束

    // MARK: - 错题闭环                                                  // 分节：错题

    /// 答错 → 进错题本 → 标记掌握 → 放回待攻，全程走同一个写入口
    func testWrongItemFlow() throws {  // 错题流转
        let question = sampleQuestion()  // 样例题
        let correct = state.recordAnswer(question: question, picked: [1])  // 故意选错
        XCTAssertFalse(correct, "选 B 应判错")  // 判定
        XCTAssertEqual(state.unresolvedWrongs.count, 1, "答错后应有 1 条待攻错题")  // 进错题本
        XCTAssertEqual(state.data.wrongs.first?.wrongCount, 1, "首次答错错次应为 1")  // 错次

        _ = state.recordAnswer(question: question, picked: [2])  // 再错一次
        XCTAssertEqual(state.data.wrongs.first?.wrongCount, 2, "再答错一次错次应累加到 2")  // 同题不新增条目

        state.resolveWrong(questionID: question.id)  // 标记已掌握
        XCTAssertEqual(state.unresolvedWrongs.count, 0, "标记掌握后待攻应为 0")  // 移出待攻
        XCTAssertEqual(state.data.wrongs.filter(\.resolved).count, 1, "已掌握应为 1")  // 进已掌握

        state.reopenWrong(questionID: question.id)  // 放回待攻
        XCTAssertEqual(state.unresolvedWrongs.count, 1, "放回后待攻应回到 1")  // 放回成功
    }  // 用例结束

    /// 答对不应该进错题本，而且要加成长值
    func testCorrectAnswerAddsGrowthAndNoWrong() throws {  // 答对
        let before = state.growth  // 记录原成长值
        let correct = state.recordAnswer(question: sampleQuestion(), picked: [0])  // 选对
        XCTAssertTrue(correct, "选 A 应判对")  // 判定
        XCTAssertTrue(state.data.wrongs.isEmpty, "答对不该进错题本")  // 不留错题
        XCTAssertGreaterThan(state.growth, before, "答对应该加成长值")  // 成长值上涨
    }  // 用例结束

    // MARK: - 社区                                                      // 分节：社区

    /// 发帖：不到 5 个字不发，发了要排在最前面并标记为「我」
    func testPublishPostRules() throws {  // 发帖规则
        XCTAssertFalse(state.publishCommunityPost(text: "  ", category: .exp), "空白正文不该发出去")  // 空
        XCTAssertFalse(state.publishCommunityPost(text: "四个字啊", category: .exp), "不足 5 个字不该发出去")  // 太短
        XCTAssertTrue(state.publishCommunityPost(text: "这是一条足够长的测试帖", category: .exp), "正常正文应该发得出去")  // 正常

        let first = try XCTUnwrap(state.communityAllPosts.first)  // 列表第一条
        XCTAssertEqual(first.text, "这是一条足够长的测试帖", "新帖应排在最前面")  // 顺序
        XCTAssertTrue(first.isMine, "自己发的帖要标记 isMine")  // 标记
    }  // 用例结束

    /// 评论：空评论不发，发到种子帖上要能被读回来
    func testCommentOnSeedPost() throws {  // 评论种子帖
        let seed = try XCTUnwrap(state.communityAllPosts.first { !$0.isMine })  // 找一条种子帖
        XCTAssertFalse(state.addCommunityComment("   ", to: seed), "空评论不该发出去")  // 空拒绝
        XCTAssertTrue(state.addCommunityComment("测试评论", to: seed), "正常评论应该发得出去")  // 正常

        let refreshed = try XCTUnwrap(state.communityAllPosts.first { $0.id == seed.id })  // 重新取
        XCTAssertTrue(refreshed.comments.contains { $0.text == "测试评论" }, "评论没被写回这条帖子")  // 读得回来
    }  // 用例结束

    /// 点赞：点一下加一，再点一下回到原值
    func testLikeToggle() throws {  // 点赞来回
        let post = try XCTUnwrap(state.communityAllPosts.first)  // 任取一条
        let base = state.communityLikeCount(post)  // 原点赞数
        state.toggleCommunityLike(post.id)  // 点赞
        XCTAssertTrue(state.communityLiked(post.id), "点过赞应标记成已赞")  // 标记
        XCTAssertEqual(state.communityLikeCount(post), base + 1, "点赞后数字应加一")  // 加一
        state.toggleCommunityLike(post.id)  // 取消
        XCTAssertFalse(state.communityLiked(post.id), "取消后应不再标记")  // 取消标记
        XCTAssertEqual(state.communityLikeCount(post), base, "取消后数字应回到原值")  // 回到原值
    }  // 用例结束

    // MARK: - 1V1 与打卡                                                // 分节：结算

    /// 1V1 结算：胜 20 / 平 8 / 负 5，胜场只在赢的时候加
    func testFinishDuelScoring() throws {  // 1V1 记分
        XCTAssertEqual(state.finishDuel(win: true, draw: false), 20, "赢应该加 20")  // 胜
        XCTAssertEqual(state.data.duelWins, 1, "赢一场胜场加一")  // 胜场
        XCTAssertEqual(state.finishDuel(win: false, draw: true), 8, "平应该加 8")  // 平
        XCTAssertEqual(state.data.duelWins, 1, "平局不加减胜场")  // 胜场不变
        XCTAssertEqual(state.finishDuel(win: false, draw: false), 5, "输应该加 5")  // 负
        XCTAssertEqual(state.data.duelGames, 3, "三场都应计入总场次")  // 场次
    }  // 用例结束

    /// 打卡：一天只能打一次，连签从 1 开始
    func testCheckInOncePerDay() throws {  // 打卡
        XCTAssertTrue(state.checkIn(), "今天第一次打卡应成功")  // 第一次
        XCTAssertEqual(state.data.streakDays, 1, "首次打卡连签应为 1")  // 连签
        XCTAssertFalse(state.checkIn(), "同一天第二次打卡应失败")  // 第二次
        XCTAssertEqual(state.data.streakDays, 1, "重复打卡不该加连签")  // 连签不变
    }  // 用例结束
}  // AppStateFlowTests 结束
