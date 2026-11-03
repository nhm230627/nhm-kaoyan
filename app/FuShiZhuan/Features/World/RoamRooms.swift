//  RoamRooms.swift —— 岛内漫游的四间房配置                           // 文件说明
//  逐条照抄 Web 样板 public/js/roam.js 的 ROOMS：图书馆 / 食堂 / 集市 / 公共广场。
//  一个引擎 + 四份配置，加新地点只要往 all 里加一条，不改场景代码。      // 扩展方式
//  坐标沿用样板：x 向右、z 向里（-z 是房间深处），单位是米。            // 坐标系

import Foundation  // 基础类型

// MARK: - 交互点类型                                                    // 分节：类型

enum RoamSpotType {  // 走到地点旁边能做什么（样板 openSpot 的分支）
    case knowledge  // 书架：翻一张知识卡
    case focus  // 阅览桌：专注 5 分钟，精力 +10
    case readlog  // 服务台：报今天翻了几张卡
    case feed  // 打饭窗口：投喂
    case rest  // 长桌：歇一会儿，精力 +10
    case buyFood  // 口粮摊：20 积分换 1 份口粮
    case buyAff  // 猫薄荷：30 积分换亲密度 +8
    case buySkin  // 围巾摊：还没上架
    case mood  // 喷泉：亲密度 +3
    case notes  // 公告板：四条留言
    case greet  // 研友的猫：打招呼，亲密度 +2
}  // RoamSpotType 结束

// MARK: - 地点与房间                                                    // 分节：模型

struct RoamSpot: Identifiable {  // 一个可交互点
    let id: String  // id，同时用作 3D 节点名
    let name: String  // 地点名
    let type: RoamSpotType  // 交互类型
    let at: SIMD2<Float>  // 在地面上的位置 x / z
}  // RoamSpot 结束

enum RoamProp {  // 房间里摆什么（样板的 props 数组）
    case shelves  // 书架
    case desks  // 阅览桌
    case counter  // 服务台
    case window  // 打饭窗口
    case tables  // 长桌与圆凳
    case stalls  // 摊位
    case crates  // 木箱
    case fountain  // 喷泉
    case board  // 公告板
    case npcs  // 研友的猫
}  // RoamProp 结束

struct RoamRoom: Identifiable {  // 一间房
    let id: String  // lib / diner / market / plaza
    let name: String  // 房间名
    let sub: String  // 顶部副标题（样板原话）
    let floorHex: String  // 地板色
    let wallHex: String  // 墙色
    let accentHex: String  // 该房间的主题色，用来给交互点配色
    let props: [RoamProp]  // 摆什么
    let spots: [RoamSpot]  // 交互点
}  // RoamRoom 结束

// MARK: - 四间房                                                        // 分节：配置

enum RoamRooms {  // 配置表

    static let all: [RoamRoom] = [  // 四间房，顺序与样板一致
        RoamRoom(  // 图书馆
            id: "lib",  // 样板 key
            name: "图书馆",  // 房间名
            sub: "点地面让猫走过去 · 靠近书架就能翻一张知识卡",  // 样板原话
            floorHex: "DCC7A6",  // 样板 floor
            wallHex: "FBF7EE",  // 样板 wall
            accentHex: "2B54E8",  // 样板 accent
            props: [.shelves, .desks, .counter],  // 家具
            spots: [  // 五个交互点，坐标照样板
                RoamSpot(id: "shelf1", name: "书架", type: .knowledge, at: [-2.5, -2.2]),  // 左书架
                RoamSpot(id: "shelf2", name: "书架", type: .knowledge, at: [0.1, -2.2]),  // 中书架
                RoamSpot(id: "shelf3", name: "书架", type: .knowledge, at: [2.5, -2.2]),  // 右书架
                RoamSpot(id: "desk", name: "阅览桌", type: .focus, at: [0.6, 0.5]),  // 阅览桌
                RoamSpot(id: "counter", name: "服务台", type: .readlog, at: [-2.9, 1.3])  // 服务台
            ]  // 地点结束
        ),  // 图书馆结束
        RoamRoom(  // 食堂
            id: "diner",  // 样板 key
            name: "食堂",  // 房间名
            sub: "打饭窗口能投喂 · 长桌上坐一会儿回精力",  // 样板原话
            floorHex: "E6DCC8",  // 样板 floor
            wallHex: "FDF9F1",  // 样板 wall
            accentHex: "E8890C",  // 样板 accent
            props: [.window, .tables],  // 家具
            spots: [  // 三个交互点
                RoamSpot(id: "win", name: "打饭窗口", type: .feed, at: [0, -2.1]),  // 打饭窗口
                RoamSpot(id: "table1", name: "长桌", type: .rest, at: [-1.7, 0.3]),  // 左长桌
                RoamSpot(id: "table2", name: "长桌", type: .rest, at: [1.7, 0.5])  // 右长桌
            ]  // 地点结束
        ),  // 食堂结束
        RoamRoom(  // 集市
            id: "market",  // 样板 key
            name: "集市",  // 房间名
            sub: "摊位能用积分换东西 · 积分从刷题和闯关来",  // 样板原话
            floorHex: "D9CDB4",  // 样板 floor
            wallHex: "FAF5EA",  // 样板 wall
            accentHex: "0F9D58",  // 样板 accent
            props: [.stalls, .crates],  // 家具
            spots: [  // 三个摊位
                RoamSpot(id: "stallA", name: "口粮摊", type: .buyFood, at: [-2.2, -1.5]),  // 口粮
                RoamSpot(id: "stallB", name: "猫薄荷", type: .buyAff, at: [0.2, -1.7]),  // 猫薄荷
                RoamSpot(id: "stallC", name: "围巾摊", type: .buySkin, at: [2.4, -1.4])  // 围巾
            ]  // 地点结束
        ),  // 集市结束
        RoamRoom(  // 公共广场
            id: "plaza",  // 样板 key
            name: "公共广场",  // 房间名
            sub: "喷泉边坐坐 · 公告板上有研友留言",  // 样板原话
            floorHex: "CFDCC0",  // 样板 floor
            wallHex: "F3F8EC",  // 样板 wall
            accentHex: "7C4DFF",  // 样板 accent
            props: [.fountain, .board, .npcs],  // 家具
            spots: [  // 三个交互点
                RoamSpot(id: "fountain", name: "喷泉", type: .mood, at: [0, 0.1]),  // 喷泉
                RoamSpot(id: "board", name: "公告板", type: .notes, at: [-2.5, -1.9]),  // 公告板
                RoamSpot(id: "npc1", name: "研友的猫", type: .greet, at: [2.1, 0.5])  // 研友的猫
            ]  // 地点结束
        )  // 广场结束
    ]  // 四间房结束

    static func room(_ id: String) -> RoamRoom {  // 按 id 取房，取不到给图书馆
        all.first { $0.id == id } ?? all[0]  // 样板 open() 的兜底逻辑
    }  // room 结束

    /// 公告板上的四条留言，逐条照样板 NOTES
    static let notes: [String] = [  // 留言
        "9 月 25 号开始预报名，别错过缴费",  // 第一条
        "本周三晚 8 点：增值税专题模考，通用卷",  // 第二条
        "图书馆新增 40 套院校真题解析，可借阅",  // 第三条
        "有人的猫走丢在集市，看到的私信泡面"  // 第四条
    ]  // 留言结束
}  // RoamRooms 结束
