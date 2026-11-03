//  Community.swift —— 研友论坛的数据模型与种子帖                     // 文件说明
//  对照样板 public/js/community.js：分类、种子帖、点赞、评论、发帖      // 来源说明
//  这里只放「数据长什么样」，读写统一走 AppState（状态单一来源）        // 设计约束

import Foundation  // 基础库

// MARK: - 分类                                                          // 分节：分类

enum PostCategory: String, CaseIterable, Codable, Hashable {  // 帖子分类（样板 CATS 三个键）
    case exp  // 复试经验
    case qa  // 答疑
    case res  // 资料

    var title: String {  // 分类中文名（样板 CATS 的取值）
        switch self {  // 按分类分支
        case .exp: "复试经验"  // 经验帖
        case .qa: "答疑"  // 提问与解答
        case .res: "资料"  // 资料分享
        }  // 分支结束
    }  // title 结束

    var id: String { rawValue }  // 用原始值当 id
}  // PostCategory 结束

// MARK: - 评论                                                          // 分节：评论

struct PostComment: Codable, Identifiable, Hashable {  // 一条评论
    var id: String  // 唯一 id（种子评论手写，新评论用时间戳）
    var author: String  // 评论人昵称
    var text: String  // 评论正文
    var time: String  // 时间文案（样板直接写「8 分钟前」这类相对时间）
}  // PostComment 结束

// MARK: - 帖子                                                          // 分节：帖子

struct CommunityPost: Codable, Identifiable, Hashable {  // 一条帖子
    var id: String  // 唯一 id
    var author: String  // 作者昵称
    var cat: PostCategory  // 分类
    var time: String  // 时间文案
    var likes: Int  // 基础点赞数（不含「我」这一票）
    var text: String  // 正文，保留换行
    var comments: [PostComment]  // 评论列表
    var topHex: UInt32  // 头像渐变起始色（样板每个作者一套渐变）
    var bottomHex: UInt32  // 头像渐变结束色
    var isMine: Bool = false  // 是不是我发的（样板会加「· 我」后缀）

    var firstChar: String {  // 头像里的首字
        String(author.prefix(1))  // 取第一个字符
    }  // firstChar 结束
}  // CommunityPost 结束

// MARK: - 种子帖                                                        // 分节：种子帖

enum CommunitySeed {  // 样板里写死的四条帖子
    static let posts: [CommunityPost] = [  // 顺序与样板 SEED 一致
        CommunityPost(  // 第一条：经验帖
            id: "p1",  // 样板 id
            author: "上岸的橘子",  // 样板昵称
            cat: .exp,  // 复试经验
            time: "12 分钟前",  // 样板时间
            likes: 34,  // 样板点赞数
            text: "刚面完某财经院校税务专硕，四道题：① 自我介绍 ② 增值税视同销售有哪几种情形 ③ 怎么看待留抵退税 ④ 你说到征管效率，具体指什么。\n\n第三题一定要给判断而不是背政策，老师明显在听你的观点。",  // 样板原文
            comments: [  // 样板两条评论
                PostComment(id: "p1c1", author: "小林同学", text: "留抵退税那题我也被问了，追问了财政承受能力。", time: "8 分钟前"),  // 评论一
                PostComment(id: "p1c2", author: "上岸的橘子", text: "对，追问基本都是往「钱从哪来」引。", time: "5 分钟前"),  // 评论二
            ],  // 评论结束
            topHex: 0x2B54E8,  // 蓝
            bottomHex: 0x6B4BF0  // 紫蓝
        ),  // 第一条结束
        CommunityPost(  // 第二条：答疑帖
            id: "p2",  // 样板 id
            author: "二战的老陈",  // 样板昵称
            cat: .qa,  // 答疑
            time: "1 小时前",  // 样板时间
            likes: 12,  // 样板点赞数
            text: "请教一下：视同销售的进项税到底能不能抵扣？我看有的书写不能抵，有点乱。",  // 样板原文
            comments: [  // 样板一条评论
                PostComment(id: "p2c1", author: "税务小张", text: "自产货物用于集体福利是视同销售、计销项；同时这批货物的进项是可以抵扣的。不能抵的是「购进」用于集体福利的货物。", time: "40 分钟前"),  // 评论
            ],  // 评论结束
            topHex: 0xE8890C,  // 橙
            bottomHex: 0xF5B942  // 浅橙
        ),  // 第二条结束
        CommunityPost(  // 第三条：资料帖
            id: "p3",  // 样板 id
            author: "资料搬运工",  // 样板昵称
            cat: .res,  // 资料
            time: "3 小时前",  // 样板时间
            likes: 88,  // 样板点赞数
            text: "整理了一份《40 所院校税务专硕复试真题》目录版（只有题干不含答案），需要的评论区留邮箱，我统一发。",  // 样板原文
            comments: [  // 样板一条评论
                PostComment(id: "p3c1", author: "小满", text: "谢谢！已留言。", time: "2 小时前"),  // 评论
            ],  // 评论结束
            topHex: 0x0F9D58,  // 绿
            bottomHex: 0x3FD0AA  // 青绿
        ),  // 第三条结束
        CommunityPost(  // 第四条：英语答疑
            id: "p4",  // 样板 id
            author: "英语苦手",  // 样板昵称
            cat: .qa,  // 答疑
            time: "5 小时前",  // 样板时间
            likes: 7,  // 样板点赞数
            text: "英语面试老师问 \"Why taxation?\" 我答得特别干，有没有更好一点的思路？",  // 样板原文（内层引号保留原样）
            comments: [],  // 样板这条没人评论
            topHex: 0xE2402F,  // 红
            bottomHex: 0xFF8FA8  // 粉红
        ),  // 第四条结束
    ]  // 数组结束
}  // CommunitySeed 结束
