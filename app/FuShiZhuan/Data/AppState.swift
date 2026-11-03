//  AppState.swift —— 全局唯一状态源（single source of truth）          // 文件说明
//  规则 1：页面不许自己算成长值、加减口粮、判权益，只能调这里的方法        // 使用约束
//  规则 2：每个字段只有一个写入口，写完统一 scheduleSave()               // 使用约束
//  规则 3：派生数据（薄弱点/星级/今日进度）用只读计算属性，不落盘          // 使用约束

import Foundation  // 基础库
import Observation  // 观察框架

// MARK: - 落盘快照                                                    // 分节：快照

struct AppSnapshot: Codable, Equatable {  // 持久化单位
    var schemaVersion: Int  // 结构版本号
    var profile: PrepProfile  // 备考档案
    var pet: Pet  // 宠物状态
    var growth: Int  // 成长值
    var attempts: [Attempt]  // 答题记录
    var wrongs: [WrongItem]  // 错题本
    var levelResults: [LevelResult]  // 闯关成绩
    var sessions: [InterviewSession]  // 面试场次
    var entitlement: Entitlement  // 权益状态
    var lastCheckInDate: Date?  // 最后打卡时间
    var streakDays: Int  // 连续打卡天数
    var outfit: CatOutfit = .default  // 猫当前穿戴（有默认值，旧快照能直接解码）
    var diy: [Question] = []  // 我的题库（自己录的题，有默认值，旧快照能直接解码）
    var track: String = "tax"  // 当前考试方向 id（有默认值，旧快照能直接解码）

    static let currentVersion = 1  // 当前结构版本

    static func fresh() -> AppSnapshot {  // 新装用户的全新档案
        AppSnapshot(  // 构造快照
            schemaVersion: currentVersion,  // 版本号
            profile: .default,  // 默认档案
            pet: .default,  // 默认宠物
            growth: 0,  // 成长值归零
            attempts: [],  // 无答题记录
            wrongs: [],  // 无错题
            levelResults: [],  // 无战绩
            sessions: [],  // 无面试
            entitlement: .default,  // 免费档
            lastCheckInDate: nil,  // 未打卡
            streakDays: 0  // 连签 0 天
        )  // 构造结束
    }  // fresh 结束

    init(from decoder: Decoder) throws {  // 手写解码，兼容旧数据
        let c = try decoder.container(keyedBy: CodingKeys.self)  // 取容器
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1  // 缺省版本 1
        profile = try c.decodeIfPresent(PrepProfile.self, forKey: .profile) ?? .default  // 缺省档案
        pet = try c.decodeIfPresent(Pet.self, forKey: .pet) ?? .default  // 缺省宠物
        growth = try c.decodeIfPresent(Int.self, forKey: .growth) ?? 0  // 缺省成长值
        attempts = try c.decodeIfPresent([Attempt].self, forKey: .attempts) ?? []  // 缺省空数组
        wrongs = try c.decodeIfPresent([WrongItem].self, forKey: .wrongs) ?? []  // 缺省空错题
        levelResults = try c.decodeIfPresent([LevelResult].self, forKey: .levelResults) ?? []  // 缺省空战绩
        sessions = try c.decodeIfPresent([InterviewSession].self, forKey: .sessions) ?? []  // 缺省空面试
        entitlement = try c.decodeIfPresent(Entitlement.self, forKey: .entitlement) ?? .default  // 缺省免费
        lastCheckInDate = try c.decodeIfPresent(Date.self, forKey: .lastCheckInDate)  // 可为空
        streakDays = try c.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0  // 缺省 0
        outfit = try c.decodeIfPresent(CatOutfit.self, forKey: .outfit) ?? .default  // 缺省默认穿戴
        diy = try c.decodeIfPresent([Question].self, forKey: .diy) ?? []  // 缺省空自建题库
        track = try c.decodeIfPresent(String.self, forKey: .track) ?? "tax"  // 缺省税务方向
    }  // 解码结束

    init(  // 全参构造器
        schemaVersion: Int,  // 版本号
        profile: PrepProfile,  // 档案
        pet: Pet,  // 宠物
        growth: Int,  // 成长值
        attempts: [Attempt],  // 答题记录
        wrongs: [WrongItem],  // 错题
        levelResults: [LevelResult],  // 战绩
        sessions: [InterviewSession],  // 面试记录
        entitlement: Entitlement,  // 权益
        lastCheckInDate: Date?,  // 打卡时间
        streakDays: Int  // 连签天数
    ) {  // 构造体开始
        self.schemaVersion = schemaVersion  // 赋值版本号
        self.profile = profile  // 赋值档案
        self.pet = pet  // 赋值宠物
        self.growth = growth  // 赋值成长值
        self.attempts = attempts  // 赋值答题记录
        self.wrongs = wrongs  // 赋值错题
        self.levelResults = levelResults  // 赋值战绩
        self.sessions = sessions  // 赋值面试记录
        self.entitlement = entitlement  // 赋值权益
        self.lastCheckInDate = lastCheckInDate  // 赋值打卡时间
        self.streakDays = streakDays  // 赋值连签天数
    }  // 构造结束
}  // AppSnapshot 结束

// MARK: - 状态                                                        // 分节：状态

@Observable  // 可观察，视图自动刷新
final class AppState {  // 全局状态类
    private(set) var data: AppSnapshot  // 唯一可变状态，外部只读
    private(set) var banks: [String: QuestionBank] = [:]  // 各考试方向的题库，key 是方向 id
    private(set) var loadError: AppError?  // 加载错误，nil 为正常
    private let store: SnapshotStore  // 落盘器
    private var saveTask: Task<Void, Never>?  // 防抖任务句柄

    init(store: SnapshotStore = SnapshotStore()) {  // 初始化，可注入存储
        self.store = store  // 保存存储依赖
        do {  // 尝试读盘
            self.data = try store.load() ?? .fresh()  // 读到了就用，没有就新建
        } catch {  // 读盘失败
            self.data = .fresh()  // 降级到全新档案
            self.loadError = .dataCorrupted(String(describing: error))  // 记录错误给 UI
        }  // 分支结束
    }  // 初始化结束

    // MARK: - 便捷访问（只读）                                        // 分节：只读访问

    var profile: PrepProfile { data.profile }  // 档案快捷方式
    var pet: Pet { data.pet }  // 宠物快捷方式
    var growth: Int { data.growth }  // 成长值快捷方式
    var entitlement: Entitlement { data.entitlement }  // 权益快捷方式
    var stage: PetStage { PetStage.stage(for: data.growth) }  // 由成长值推阶段
    var outfit: CatOutfit { data.outfit }  // 猫当前穿戴快捷方式
    var currentTrack: Track { Track.meta(data.track) }  // 当前考试方向
    var bank: QuestionBank? { banks[data.track] }  // 当前方向的题库，未加载为 nil

    func isUnlocked(_ item: OutfitItem) -> Bool {  // 配件是否已解锁
        data.growth >= item.minGrowth  // 只看成长值，不搞抽卡、不搞概率掉落
    }  // 方法结束

    func equip(_ itemID: String, slot: OutfitSlot) {  // 换上一件配件
        guard let item = OutfitCatalog.shared.item(id: itemID) else { return }  // 配件必须在表里
        guard isUnlocked(item) else { return }  // 没解锁不给穿
        var snap = data  // 拷贝一份再改
        snap.outfit.set(itemID, for: slot)  // 写入该槽位
        data = snap  // 一次性替换，页面自动刷新
        scheduleSave()  // 落盘，重进 App 还是这身
    }  // 方法结束

    var todayAnswered: Int {  // 今日已答题数
        let cal = Calendar.current  // 取日历
        return data.attempts.filter { cal.isDateInToday($0.at) }.count  // 过滤今天再计数
    }  // 属性结束

    var todayAccuracy: Double? {  // 今日正确率
        let cal = Calendar.current  // 取日历
        let today = data.attempts.filter { cal.isDateInToday($0.at) }  // 今日记录
        guard !today.isEmpty else { return nil }  // 没答过返回 nil
        return Double(today.filter(\.isCorrect).count) / Double(today.count)  // 正确数/总数
    }  // 属性结束

    var unresolvedWrongs: [WrongItem] {  // 未消除的错题
        data.wrongs.filter { !$0.resolved }.sorted { $0.lastWrongAt > $1.lastWrongAt }  // 按时间倒序
    }  // 属性结束

    // MARK: - 初始化流程                                              // 分节：初始化

    func loadBank() {  // 加载题库（五个方向一次读完，切方向不用等）
        guard banks.isEmpty else { return }  // 已加载就不重复读
        var loaded: [String: QuestionBank] = [:]  // 临时收集
        for track in Track.all {  // 逐个方向
            if let one = try? BankRepository.load(track) { loaded[track.id] = one }  // 读成功就收下
        }  // 循环结束
        banks = loaded  // 一次性写回，视图刷新一次
        loadError = loaded.isEmpty ? .dataCorrupted("题库文件读取失败，请重装 App") : nil  // 一个都没读到才算错
    }  // loadBank 结束

    func setTrack(_ id: String) {  // 切换考试方向（题库、模考、面试间都跟着变）
        let target = Track.meta(id)  // 解析成方向对象
        guard data.track != target.id else { return }  // 没变就不用写盘
        var snap = data  // 拷一份改
        snap.track = target.id  // 写入方向
        data = snap  // 一次性替换，页面自动刷新
        scheduleSave()  // 落盘，重进 App 还是这个方向
    }  // setTrack 结束

    func topicName(_ id: String) -> String {  // 知识点名字（跨方向查）
        BankRepository.topicName(id, in: banks)  // 交给仓库统一查
    }  // topicName 结束

    func dailyTick() {  // 每日结算，幂等
        var snap = data  // 拷一份改
        snap.pet.settle()  // 宠物按自然日掉体力
        if snap != data {  // 有变化才写回
            data = snap  // 写回状态
            scheduleSave()  // 安排落盘
        }  // 分支结束
    }  // dailyTick 结束

    // MARK: - 档案                                                    // 分节：档案

    func updateProfile(_ transform: (inout PrepProfile) -> Void) {  // 改档案的唯一入口
        var snap = data  // 拷一份
        transform(&snap.profile)  // 就地修改
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    // MARK: - 答题                                                    // 分节：答题

    @discardableResult  // 返回值可忽略
    func recordAnswer(question: Question, picked: Set<Int>, inLevel: Bool = false) -> Bool {  // 记录一次作答
        let correct = question.isCorrect(picked)  // 判定对错
        var snap = data  // 拷一份改
        snap.attempts.append(  // 追加记录
            Attempt(  // 构造记录
                questionID: question.id,  // 题目 id
                topic: question.topic,  // 所属板块
                picked: picked.sorted(),  // 已排序选项
                isCorrect: correct,  // 是否正确
                inLevel: inLevel  // 是否闯关模式
            )  // 构造结束
        )  // 追加结束

        if correct {  // 答对
            snap.growth += GrowthReason.answerCorrect.delta  // 加成长值
        } else {  // 答错
            if let idx = snap.wrongs.firstIndex(where: { $0.questionID == question.id }) {  // 已有错题
                snap.wrongs[idx].wrongCount += 1  // 错次加一
                snap.wrongs[idx].lastWrongAt = .now  // 更新最近错时
                snap.wrongs[idx].resolved = false  // 重新标为未掌握
            } else {  // 新错题
                snap.wrongs.append(  // 追加错题
                    WrongItem(  // 构造错题
                        questionID: question.id,  // 题目 id
                        topic: question.topic,  // 板块
                        wrongCount: 1,  // 错 1 次
                        lastWrongAt: .now,  // 时间
                        resolved: false  // 未掌握
                    )  // 构造结束
                )  // 追加结束
            }  // 分支结束
        }  // 对错分支结束

        if snap.attempts.count > 500 {  // 记录过多会拖慢
            snap.attempts = Array(snap.attempts.suffix(500))  // 只留最近 500 条
        }  // 分支结束

        data = snap  // 写回状态
        scheduleSave()  // 落盘
        return correct  // 返回是否答对
    }  // recordAnswer 结束

    func resolveWrong(questionID: String) {  // 错题重做答对后标记掌握
        guard let idx = data.wrongs.firstIndex(where: { $0.questionID == questionID }) else { return }  // 找不到就退出
        var snap = data  // 拷一份
        snap.wrongs[idx].resolved = true  // 标记已掌握
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    func reopenWrong(questionID: String) {  // 把已掌握的错题放回待攻
        guard let idx = data.wrongs.firstIndex(where: { $0.questionID == questionID }) else { return }  // 找不到就退出
        var snap = data  // 拷一份
        snap.wrongs[idx].resolved = false  // 改回未掌握
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    // MARK: - 我的题库                                                // 分节：自建题库

    var diyQuestions: [Question] { data.diy }  // 自建题目（只读）

    func addDiy(_ question: Question) {  // 加一道自建题
        var snap = data  // 拷一份
        snap.diy.insert(question, at: 0)  // 新的排最前
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // addDiy 结束

    func removeDiy(id: String) {  // 删一道自建题
        var snap = data  // 拷一份
        snap.diy.removeAll { $0.id == id }  // 删掉同 id 的
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // removeDiy 结束

    // MARK: - 闯关                                                    // 分节：闯关

    @discardableResult  // 返回值可忽略
    func finishLevel(id: String, correct: Int, total: Int) -> LevelResult {  // 结算一关
        let firstClear = !data.levelResults.contains { $0.id == id }  // 必须在写盘前判首通（坑 P-14）
        let stars = LevelResult.judgeStars(correct: correct, total: total)  // 算星级

        var snap = data  // 拷一份
        if let idx = snap.levelResults.firstIndex(where: { $0.id == id }) {  // 已有成绩
            if stars > snap.levelResults[idx].stars {  // 只升不降
                snap.levelResults[idx].stars = stars  // 覆盖成更高星
            }  // 分支结束
        } else {  // 首次通关
            snap.levelResults.append(  // 追加成绩
                LevelResult(id: id, correct: correct, total: total, stars: stars, clearedAt: .now)  // 构造成绩
            )  // 追加结束
        }  // 分支结束

        let foodGained = firstClear ? 2 : 1  // 首通 2 颗，重复 1 颗
        snap.pet.addFood(foodGained)  // 发口粮，唯一产出途径

        if firstClear && stars > 0 {  // 首次且过了
            snap.growth += GrowthReason.levelClear.delta  // 加通关成长值
        }  // 分支结束

        data = snap  // 写回
        scheduleSave()  // 落盘

        return LevelResult(  // 返回本次成绩
            id: id,  // 关卡 id
            correct: correct,  // 答对数
            total: total,  // 总题数
            stars: stars,  // 星级
            clearedAt: .now  // 时间
        )  // 构造结束
    }  // finishLevel 结束

    func levelResult(for id: String) -> LevelResult? {  // 查某关成绩
        data.levelResults.first { $0.id == id }  // 取第一条匹配
    }  // 方法结束

    /// 分拣关卡结算：星级由剩余命数决定（样板 sortgame.js：stars = pass ? max(1, lives) : 0）
    @discardableResult  // 返回值可忽略
    func finishSortLevel(id: String, cleared: Int, total: Int, stars: Int) -> LevelResult {  // 结算一关分拣
        let firstClear = !data.levelResults.contains { $0.id == id }  // 首通判断要在写盘前（坑 P-14）

        var snap = data  // 拷一份
        if let idx = snap.levelResults.firstIndex(where: { $0.id == id }) {  // 已有成绩
            if stars > snap.levelResults[idx].stars {  // 只升不降
                snap.levelResults[idx].stars = stars  // 覆盖成更高星
            }  // 分支结束
        } else {  // 首次通关
            snap.levelResults.append(  // 追加成绩
                LevelResult(id: id, correct: cleared, total: total, stars: stars, clearedAt: .now)  // 归位数当答对数
            )  // 追加结束
        }  // 分支结束

        let foodGained = firstClear ? 2 : 1  // 首通 2 份，重复 1 份（与样板一致）
        snap.pet.addFood(foodGained)  // 发口粮，唯一产出途径

        if firstClear && stars > 0 {  // 首次且过了
            snap.growth += GrowthReason.levelClear.delta  // 加通关成长值
        }  // 分支结束

        data = snap  // 写回
        scheduleSave()  // 落盘

        return LevelResult(id: id, correct: cleared, total: total, stars: stars, clearedAt: .now)  // 返回本次成绩
    }  // finishSortLevel 结束

    func stars(inChapter chapterID: String) -> Int {  // 某章总星数
        data.levelResults  // 全部成绩
            .filter { Chapter.chapterID(from: $0.id) == chapterID }  // 只留本章
            .reduce(0) { $0 + $1.stars }  // 累加星数
    }  // 方法结束

    // MARK: - 宠物                                                    // 分节：宠物

    @discardableResult  // 返回值可忽略
    func feedPet() -> FeedOutcome {  // 投喂一次
        var snap = data  // 拷一份
        let outcome = snap.pet.feed()  // 调宠物逻辑
        if case .ok = outcome {  // 成功才写回
            data = snap  // 写回
            scheduleSave()  // 落盘
        }  // 分支结束
        return outcome  // 返回结果给 UI 提示
    }  // 方法结束

    func revivePet() {  // 唤醒饿死的宠物
        var snap = data  // 拷一份
        snap.pet.revive()  // 复活
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    func claimPet() {  // 认领伙伴
        var snap = data  // 拷一份
        snap.pet.claimed = true  // 标记已认领
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    // MARK: - 打卡                                                    // 分节：打卡

    @discardableResult  // 返回值可忽略
    func checkIn() -> Bool {  // 每日打卡
        let cal = Calendar.current  // 取日历
        if let last = data.lastCheckInDate, cal.isDateInToday(last) { return false }  // 今天已打过

        var snap = data  // 拷一份
        if let last = snap.lastCheckInDate,  // 有上次记录
           let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now)),  // 算昨天
           cal.isDate(last, inSameDayAs: yesterday) {  // 上次就是昨天
            snap.streakDays += 1  // 连签加一
        } else {  // 断了
            snap.streakDays = 1  // 重新计 1
        }  // 分支结束
        snap.lastCheckInDate = .now  // 记下时间
        snap.growth += GrowthReason.checkIn.delta  // 加打卡成长值
        data = snap  // 写回
        scheduleSave()  // 落盘
        return true  // 返回成功
    }  // 方法结束

    // MARK: - 面试                                                    // 分节：面试

    func saveSession(_ session: InterviewSession) {  // 保存一场面试
        var snap = data  // 拷一份
        if let idx = snap.sessions.firstIndex(where: { $0.id == session.id }) {  // 已有则覆盖
            snap.sessions[idx] = session  // 覆盖旧记录
        } else {  // 没有则新增
            snap.sessions.append(session)  // 追加记录
        }  // 分支结束
        if session.state == .archived,  // 本场已归档
           snap.sessions.filter({ $0.state == .archived }).count == 1 {  // 且是第一场
            snap.growth += GrowthReason.interviewDone.delta  // 加面试成长值
        }  // 分支结束
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    // MARK: - 权益                                                    // 分节：权益

    @discardableResult  // 返回值可忽略
    func consume(_ feature: Feature) -> Bool {  // 消费一次额度
        var snap = data  // 拷一份
        let ok = snap.entitlement.consume(feature)  // 尝试扣额度
        if ok {  // 扣成功才写回
            data = snap  // 写回
            scheduleSave()  // 落盘
        }  // 分支结束
        return ok  // 返回是否可继续
    }  // 方法结束

    func applyPurchase(plan: Plan, expiresAt: Date?, transactionID: String?) {  // 写入购买结果
        var snap = data  // 拷一份
        snap.entitlement.apply(plan: plan, expiresAt: expiresAt, transactionID: transactionID)  // 更新权益
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    func revokePurchase() {  // 退款/到期回落免费
        var snap = data  // 拷一份
        snap.entitlement.revoke()  // 撤销权益
        data = snap  // 写回
        scheduleSave()  // 落盘
    }  // 方法结束

    // MARK: - 派生统计                                                // 分节：派生

    func weakTopics(minAttempts: Int = 3) -> [(topic: Topic, accuracy: Double, total: Int)] {  // 薄弱点
        guard let bank else { return [] }  // 题库没加载就返回空
        let grouped = Dictionary(grouping: data.attempts, by: \.topic)  // 按板块分组
        return bank.topics.compactMap { topic -> (Topic, Double, Int)? in  // 逐个板块算
            guard let list = grouped[topic.id], list.count >= minAttempts else { return nil }  // 样本不足就跳过
            let acc = Double(list.filter(\.isCorrect).count) / Double(list.count)  // 算正确率
            return (topic, acc, list.count)  // 返回三项
        }  // 映射结束
        .sorted { $0.1 < $1.1 }  // 正确率升序
    }  // 方法结束

    func recentGrowthNotes(limit: Int = 10) -> [String] {  // 成长值来源说明
        var notes: [String] = []  // 结果容器
        let cal = Calendar.current  // 取日历
        let today = data.attempts.filter { cal.isDateInToday($0.at) }  // 今日记录
        let right = today.filter(\.isCorrect).count  // 今日答对数
        if right > 0 {  // 有答对
            notes.append("今日答对 \(right) 题 · +\(right * GrowthReason.answerCorrect.delta)")  // 记一条
        }  // 分支结束
        let clearedToday = data.levelResults.filter { cal.isDateInToday($0.clearedAt) }  // 今日通关
        if !clearedToday.isEmpty {  // 有通关
            notes.append("今日通关 \(clearedToday.count) 关 · +\(clearedToday.count * GrowthReason.levelClear.delta)")  // 记一条
        }  // 分支结束
        if let last = data.lastCheckInDate, cal.isDateInToday(last) {  // 今天打过卡
            notes.append("今日已打卡 · +\(GrowthReason.checkIn.delta)")  // 记一条
        }  // 分支结束
        return Array(notes.prefix(limit))  // 最多返回 limit 条
    }  // 方法结束

    // MARK: - 落盘                                                    // 分节：落盘

    private func scheduleSave() {  // 防抖写入
        saveTask?.cancel()  // 取消上一次未完成的
        let snapshot = data  // 固定当前快照
        let store = self.store  // 捕获存储引用
        saveTask = Task {  // 起异步任务
            try? await Task.sleep(nanoseconds: 400_000_000)  // 等 0.4 秒
            guard !Task.isCancelled else { return }  // 被取消就不写
            store.save(snapshot)  // 真正落盘
        }  // 任务结束
    }  // 方法结束

    func flush() {  // 立即落盘
        saveTask?.cancel()  // 取消待执行的
        store.save(data)  // 马上写
    }  // 方法结束

    func exportJSON() -> Data? {  // 导出当前内存里的全部数据
        let encoder = JSONEncoder()  // 建编码器
        encoder.dateEncodingStrategy = .iso8601  // 与落盘格式保持一致
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]  // 好读且稳定
        return try? encoder.encode(data)  // 编码失败就返回空
    }  // 方法结束

    func resetAll() {  // 重置全部本地数据
        store.reset()  // 删文件
        data = .fresh()  // 回到全新档案
        scheduleSave()  // 写一份新的
    }  // 方法结束
}  // AppState 结束
