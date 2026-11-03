//  MockPaperBuilder.swift —— 院校模考出卷                          // 文件说明
//  算法照搬样板 public/js/mock.js 的 buildPaper：
//    同一院校 + 同一卷别 + 同一方向 → 每次抽到的题完全一致（种子决定）。
//  为什么要确定性：用户今天练「人大初试仿真卷 A」，明天再点开应该是同一套，
//  否则「这套卷我上次 62 分」这种话就没意义了。

import Foundation  // 基础库

/// 线性同余伪随机数（参数与样板 mock.js 的 rng 一致：1664525 / 1013904223）。
struct MockRNG {  // 可复现随机数
    private var state: UInt32  // 内部状态

    init(seed: UInt32) {  // 用种子初始化
        state = seed  // 记下种子
    }  // 初始化结束

    mutating func next() -> Double {  // 取下一个随机数，范围 0 到 1 之间
        state = state &* 1664525 &+ 1013904223  // 线性同余（溢出按 32 位回绕）
        return Double(state) / 4294967296.0  // 归一化到 0..<1
    }  // next 结束
}  // MockRNG 结束

enum MockPaperBuilder {  // 出卷器
    /// 各侧重方向的抽题权重，数值与样板 mock.js 的 FOCUS_W 逐条一致。
    /// 只有税务四块齐全时才按它分配，其余方向按知识点均分。
    private static let focusWeights: [String: [String: Double]] = [  // 侧重 → 权重表
        "vat": ["vat": 0.44, "income-tax": 0.24, "tax-system": 0.18, "admin": 0.14],  // 偏增值税
        "income": ["income-tax": 0.42, "vat": 0.24, "admin": 0.20, "tax-system": 0.14],  // 偏所得税
        "admin": ["admin": 0.42, "tax-system": 0.24, "vat": 0.20, "income-tax": 0.14],  // 偏征管
        "tax-system": ["tax-system": 0.40, "vat": 0.24, "admin": 0.20, "income-tax": 0.16],  // 偏税制
        "balanced": ["vat": 0.28, "income-tax": 0.26, "tax-system": 0.24, "admin": 0.22],  // 均衡
    ]  // 权重表结束

    /// FNV-1a 32 位哈希，用于把「院校 + 卷别 + 题量 + 方向」压成一个种子。
    /// 注意：样板用 charCodeAt（UTF-16 码元），这里用 utf8 字节，
    /// 所以中文字符串算出的哈希与 JS 不同 —— 但不影响「同一院校每次一致」，
    /// 因为同一串在 iOS 侧永远算出同一个值。
    static func hash(_ text: String) -> UInt32 {  // 字符串 → 种子
        var h: UInt32 = 2166136261  // FNV 偏移基数
        for byte in text.utf8 {  // 逐字节
            h ^= UInt32(byte)  // 异或
            h = h &* 16777619  // 乘 FNV 质数（溢出回绕）
        }  // 循环结束
        return h  // 返回哈希
    }  // hash 结束

    static func shuffled<T>(_ items: [T], rng: inout MockRNG) -> [T] {  // 洗牌（Fisher-Yates）
        var a = items  // 拷一份再动
        var i = a.count - 1  // 从末尾往前
        while i > 0 {  // 还没到开头
            let j = Int(rng.next() * Double(i + 1))  // 取 [0,i] 的下标
            a.swapAt(i, j)  // 交换
            i -= 1  // 前移一位
        }  // 循环结束
        return a  // 返回洗好的
    }  // shuffled 结束

    /// 出一套卷。
    /// - Parameters:
    ///   - school: 院校（用它的 id 与 focus 造种子和权重）
    ///   - kindKey: 卷别键，如 "initial-0" / "written-0" / "common"，同一卷别要固定
    ///   - count: 题量
    ///   - bank: 当前方向的题库
    ///   - trackID: 当前方向 id（参与种子，换方向出题不同）
    static func build(  // 出卷主逻辑
        school: School,  // 院校（通用模考用假院校）
        kindKey: String,  // 卷别键
        count: Int,  // 题量
        bank: QuestionBank,  // 题库
        trackID: String  // 方向 id
    ) -> [Question] {  // 返回抽好的题
        let all = bank.questions  // 全部题目
        guard !all.isEmpty, count > 0 else { return [] }  // 没题或题量为 0
        var rng = MockRNG(seed: hash("\(school.id)-\(kindKey)-\(count)-\(trackID)"))  // 造确定性随机源

        var byTopic: [String: [Question]] = [:]  // 按知识点分组
        for q in all { byTopic[q.topic, default: []].append(q) }  // 逐题归组
        let usable = bank.topics.map(\.id).filter { !(byTopic[$0]?.isEmpty ?? true) }  // 有题的知识点
        guard !usable.isEmpty else { return [] }  // 一个都没有就返回空

        let weights = focusWeights[school.focus] ?? [:]  // 该院校的侧重权重
        // 权重表只对税务四块有意义；方向的知识点数不是 4 就按均分
        let weightOf: (String) -> Double = { t in  // 单个知识点的权重
            if usable.count == 4, let w = weights[t] { return w }  // 四块齐全用侧重表
            return 1.0 / Double(usable.count)  // 否则均分
        }  // 闭包结束

        var want: [String: Int] = [:]  // 每个知识点要抽几题
        var used = 0  // 已分配总数
        for t in usable {  // 逐知识点分配
            let n = Int((weightOf(t) * Double(count)).rounded())  // 四舍五入
            want[t] = n  // 记下
            used += n  // 累加
        }  // 循环结束

        if used != count, let top = usable.max(by: { weightOf($0) < weightOf($1) }) {  // 取整有误差
            want[top] = max(0, (want[top] ?? 0) + (count - used))  // 误差补到权重最大的那块
        }  // 分支结束

        var pools: [String: [Question]] = [:]  // 各知识点的待抽池（已洗）
        for t in usable { pools[t] = shuffled(byTopic[t] ?? [], rng: &rng) }  // 各自洗一遍

        var picked: [Question] = []  // 已选出的题
        for t in usable {  // 按分配抽
            let need = want[t] ?? 0  // 这块要几题
            for _ in 0..<need {  // 逐题取
                guard var pool = pools[t], !pool.isEmpty else { break }  // 池空就停
                picked.append(pool.removeFirst())  // 取队首
                pools[t] = pool  // 写回剩余
            }  // 循环结束
        }  // 循环结束

        if picked.count < count {  // 还不够
            let pickedIDs = Set(picked.map(\.id))  // 已选 id
            var rest = shuffled(all.filter { !pickedIDs.contains($0.id) }, rng: &rng)  // 剩余题洗一遍
            while picked.count < count, !rest.isEmpty {  // 逐题补
                picked.append(rest.removeFirst())  // 补一题
            }  // 循环结束
        }  // 分支结束

        let final = shuffled(picked, rng: &rng)  // 最后整体再洗一次（题型不扎堆）
        return Array(final.prefix(count))  // 截到题量
    }  // build 结束

    /// 通用模考用的假院校：不分院校，四块均衡。
    /// 与样板 startCommon 一致（id 里带方向，换方向就是另一套题）。
    static func commonSchool(trackID: String) -> School {  // 造通用院校
        School(id: "common-\(trackID)", name: "通用模考", city: "全国",  // 基本字段
               tags: [], focus: "balanced", tier: "普通",  // 均衡侧重
               papers: SchoolPapers(initial: ["通用模考"], written: [], interview: []),  // 占位卷别
               hot: false)  // 不算热门
    }  // commonSchool 结束
}  // MockPaperBuilder 结束
