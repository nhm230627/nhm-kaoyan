//  RoamScene.swift —— 岛内漫游的 3D 引擎（RealityKit）                   // 文件说明
//  逐条移植 public/js/roam.js：房间盒子 + 家具 + 交互点 + 一只会走路的猫。  // 移植来源
//  交互：点地面猫走过去；点交互点则走到它面前并开卡片（样板 bindPick 同逻辑）。// 交互说明
//  猫直接复用 PetSceneBuilder，跟伙伴页是同一只，不另做一套模型。          // 复用说明

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor 与手势

// MARK: - 建模                                                        // 分节：建模

enum RoamBuilder {  // 房间建模器

    static let floorName = "roam.floor"  // 地板节点名，点击命中后按它算落点
    static let spotPrefix = "spot."  // 交互点节点名前缀
    static let catScale: Float = 0.38  // 与样板 cat.group.scale 0.38 一致

    /// 搭一整间房：地板 + 三面墙 + 天花板 + 踢脚线 + 家具 + 交互点
    static func build(room: RoamRoom) -> Entity {  // 搭房间
        let root = Entity()  // 根节点
        root.name = "roam.root"  // 便于调试
        let floor = UIColor(hex: room.floorHex)  // 地板色
        let wall = UIColor(hex: room.wallHex)  // 墙色
        let accent = UIColor(hex: room.accentHex)  // 主题色

        let floorEntity = box(width: 9.0, height: 0.1, depth: 7.6, color: floor)  // 地板
        floorEntity.name = floorName  // 命名，点地面靠它
        floorEntity.position = [0, -0.05, 0.3]  // 与样板 floor.position.z 一致
        floorEntity.generateCollisionShapes(recursive: false)  // 只有地板要碰撞，点地面才能算落点
        root.addChild(floorEntity)  // 挂上

        let wallHeight: Float = 3.3  // 样板墙高 H
        let back = box(width: 9.0, height: wallHeight, depth: 0.16, color: wall)  // 后墙
        back.position = [0, wallHeight / 2, -3.5]  // 与样板一致
        root.addChild(back)  // 挂上
        for x in [-4.5, 4.5] as [Float] {  // 左右两面墙
            let side = box(width: 0.16, height: wallHeight, depth: 7.6, color: wall)  // 侧墙
            side.position = [x, wallHeight / 2, 0.3]  // 与样板一致
            root.addChild(side)  // 挂上
        }  // 循环结束
        let ceiling = box(width: 9.0, height: 0.05, depth: 7.6, color: UIColor(hex: "F7F2E7"))  // 天花板
        ceiling.position = [0, wallHeight, 0.3]  // 与样板一致
        root.addChild(ceiling)  // 挂上
        let skirt = box(width: 9.0, height: 0.1, depth: 0.06, color: UIColor(hex: "D9CFBD"))  // 踢脚线
        skirt.position = [0, 0.05, -3.41]  // 与样板一致
        root.addChild(skirt)  // 挂上

        for prop in room.props {  // 按配置摆家具
            root.addChild(props(prop))  // 逐件挂上
        }  // 循环结束
        root.addChild(wallDecor())  // 窗户与挂钟，每个房间都有

        for spot in room.spots {  // 交互点
            let marker = spotMarker(spot, accent: accent)  // 造一个可点的地标
            marker.generateCollisionShapes(recursive: true)  // 加碰撞，手指点得到
            root.addChild(marker)  // 挂上
        }  // 循环结束
        return root  // 返回整间房
    }  // build 结束

    /// 装相机：样板是 42° / (0,1.6,4.6) / 看向 (0,0.6,-1.6)
    /// 这里把机位压低一点、往后退一点：手机竖屏里画面更宽，能同时看见服务台与猫的正脸
    static func installCamera(on view: ARView, wall: UIColor) {  // 装相机
        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = 44  // 比样板 42 略广，窄屏才装得下整间房
        camera.camera.near = 0.1  // 样板近平面
        camera.camera.far = 60  // 样板远平面
        let eye = SIMD3<Float>(0, 1.62, 5.9)  // 视觉改良：样板 (0,1.6,4.6) 桌子会糊住画面，后撤但保持接近平视（俯角大了猫只剩个大头）
        let target = SIMD3<Float>(0, 0.6, -1.0)  // 视线略压，地板与家具层次刚好
        let forward = simd_normalize(target - eye)  // 视线方向
        let holder = AnchorEntity(world: eye)  // 相机放在房间里
        holder.addChild(camera)  // 挂上
        holder.orientation = simd_quatf(from: [0, 0, -1], to: forward)  // 把相机 -Z 对齐视线
        view.scene.addAnchor(holder)  // 入场
        view.environment.background = .color(wall)  // 墙色当底色，接缝处看不出是画布
    }  // installCamera 结束

    // MARK: - 家具                                                    // 分节：家具

    static func props(_ prop: RoamProp) -> Entity {  // 造一组家具
        switch prop {  // 按类型分支
        case .shelves: shelves()  // 书架
        case .desks: desks()  // 阅览桌
        case .counter: counter()  // 服务台
        case .window: dinerWindow()  // 打饭窗口
        case .tables: tables()  // 长桌
        case .stalls: stalls()  // 摊位
        case .crates: crates()  // 木箱
        case .fountain: fountain()  // 喷泉
        case .board: board()  // 公告板
        case .npcs: npcs()  // 研友的猫
        }  // 分支结束
    }  // props 结束

    static func shelves() -> Entity {  // 三组书架，每组三层书
        let group = Entity()  // 组
        let wood = UIColor(hex: "B98A5A")  // 木色
        let boardColor = UIColor(hex: "D8B184")  // 隔板
        let bookColors = [UIColor(hex: "E2402F"), UIColor(hex: "2B54E8"), UIColor(hex: "0F9D58"),  // 书脊色
                          UIColor(hex: "E8890C"), UIColor(hex: "7C4DFF"), UIColor(hex: "0B84A8")]  // 青与紫
        for (index, x) in ([-2.5, 0.1, 2.5] as [Float]).enumerated() {  // 三组
            let unit = Entity()  // 一组书架
            unit.position = [x, 0, -2.62]  // 与样板一致
            let back = box(width: 1.32, height: 1.62, depth: 0.06, color: wood)  // 背板（样板是一整个实心柜体，实心会把书全遮住）
            back.position = [0, 0.81, -0.12]  // 靠后一档，给书留出可见空间
            unit.addChild(back)  // 挂上
            for side in [-0.63, 0.63] as [Float] {  // 两块侧板
                let panel = box(width: 0.06, height: 1.62, depth: 0.3, color: wood)  // 侧板
                panel.position = [side, 0.81, 0]  // 与样板柜体同宽
                unit.addChild(panel)  // 挂上
            }  // 循环结束
            let cap = box(width: 1.32, height: 0.06, depth: 0.3, color: wood)  // 顶板
            cap.position = [0, 1.62, 0]  // 压在最上面
            unit.addChild(cap)  // 挂上
            for level in 0..<3 {  // 三层
                let shelfY = 0.38 + Float(level) * 0.44  // 该层高度
                let plank = box(width: 1.24, height: 0.05, depth: 0.26, color: boardColor)  // 隔板
                plank.position = [0, shelfY, 0]  // 与样板一致
                unit.addChild(plank)  // 挂上
                var bx: Float = -0.52  // 书从左边摆起
                var bookIndex = index * 7 + level * 3  // 用固定序号取色，保证每次一样
                while bx < 0.5 {  // 一直摆到右边
                    let width = 0.05 + Float(bookIndex % 3) * 0.02  // 书厚按序号变化
                    let height = 0.2 + Float(bookIndex % 2) * 0.08  // 书高按序号变化
                    let book = box(width: width, height: height, depth: 0.16,  // 一本
                                   color: bookColors[bookIndex % bookColors.count])  // 取色
                    book.position = [bx + width / 2, shelfY + height / 2 + 0.02, 0.02]  // 立在隔板前侧，正面看得见
                    unit.addChild(book)  // 挂上
                    bx += width + 0.02  // 往右挪
                    bookIndex += 1  // 换下一本
                }  // 循环结束
            }  // 循环结束
            group.addChild(unit)  // 挂上这一组
        }  // 循环结束
        return group  // 返回
    }  // shelves 结束

    static func desks() -> Entity {  // 两张阅览桌，带台灯
        let group = Entity()  // 组
        let wood = UIColor(hex: "C79A68")  // 桌面木色
        let metal = UIColor(hex: "9AA3B2")  // 金属腿
        for (x, z) in ([(Float(0.6), Float(0.5)), (2.6, 1.2)] as [(Float, Float)]) {  // 两张桌
            let unit = Entity()  // 一张桌
            unit.position = [x, 0, z]  // 与样板一致
            unit.orientation = simd_quatf(angle: .pi / 9, axis: [0, 1, 0])  // 与样板 rotation.y 一致
            let top = box(width: 1.5, height: 0.09, depth: 0.8, color: wood)  // 桌面
            top.position = [0, 0.68, 0]  // 与样板一致
            unit.addChild(top)  // 挂上
            for dx in [-0.62, 0.62] as [Float] {  // 两条腿
                let leg = box(width: 0.07, height: 0.66, depth: 0.7, color: metal)  // 腿板
                leg.position = [dx, 0.33, 0]  // 与样板一致
                unit.addChild(leg)  // 挂上
            }  // 循环结束
            let post = cylinder(radius: 0.03, height: 0.36, color: metal)  // 台灯杆
            post.position = [0.46, 0.9, -0.16]  // 与样板一致
            unit.addChild(post)  // 挂上
            let shade = cone(radius: 0.16, height: 0.14, color: UIColor(hex: "F6C66A"))  // 灯罩
            shade.position = [0.46, 1.12, -0.16]  // 与样板一致
            unit.addChild(shade)  // 挂上
            group.addChild(unit)  // 挂上这张桌
        }  // 循环结束
        return group  // 返回
    }  // desks 结束

    static func counter() -> Entity {  // 服务台
        let group = Entity()  // 组
        group.position = [-3.0, 0, 1.3]  // 与样板一致
        let body = box(width: 1.6, height: 0.9, depth: 0.6, color: UIColor(hex: "D8C3A2"))  // 柜体
        body.position = [0, 0.45, 0]  // 与样板一致
        group.addChild(body)  // 挂上
        let top = box(width: 1.7, height: 0.08, depth: 0.7, color: UIColor(hex: "B98A5A"))  // 台面
        top.position = [0, 0.94, 0]  // 与样板一致
        group.addChild(top)  // 挂上
        return group  // 返回
    }  // counter 结束

    static func dinerWindow() -> Entity {  // 打饭窗口：台面 + 红雨棚 + 三个餐盆
        let group = Entity()  // 组
        group.position = [0, 0, -2.75]  // 与样板一致
        let counter = box(width: 6.4, height: 0.9, depth: 0.7, color: UIColor(hex: "E8DCC8"))  // 台面
        counter.position = [0, 0.45, 0]  // 与样板一致
        group.addChild(counter)  // 挂上
        let awning = box(width: 6.4, height: 0.1, depth: 1.0, color: UIColor(hex: "E2603F"))  // 红雨棚
        awning.position = [0, 2.0, 0.35]  // 与样板一致
        awning.orientation = simd_quatf(angle: 0.16, axis: [1, 0, 0])  // 与样板 rotation.x 一致
        group.addChild(awning)  // 挂上
        let stripe = box(width: 6.4, height: 0.18, depth: 0.04, color: UIColor(hex: "FFFFFF"))  // 白边条
        stripe.position = [0, 1.93, 0.86]  // 与样板一致
        group.addChild(stripe)  // 挂上
        for x in [-1.6, 0, 1.6] as [Float] {  // 三个餐盆
            let pot = cylinder(radius: 0.26, height: 0.16, color: UIColor(hex: "B9C2CC"))  // 盆
            pot.position = [x, 0.98, 0]  // 与样板一致
            group.addChild(pot)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // dinerWindow 结束

    static func tables() -> Entity {  // 两张圆桌，各两只圆凳
        let group = Entity()  // 组
        let wood = UIColor(hex: "D2A678")  // 桌面
        let stoolColor = UIColor(hex: "C08F5E")  // 圆凳
        for (x, z) in ([(Float(-1.7), Float(0.3)), (1.7, 0.5)] as [(Float, Float)]) {  // 两张桌
            let unit = Entity()  // 一张桌
            unit.position = [x, 0, z]  // 与样板一致
            let top = cylinder(radius: 0.72, height: 0.09, color: wood)  // 桌面
            top.position = [0, 0.72, 0]  // 与样板一致
            unit.addChild(top)  // 挂上
            let leg = cylinder(radius: 0.1, height: 0.7, color: wood)  // 桌腿
            leg.position = [0, 0.36, 0]  // 与样板一致
            unit.addChild(leg)  // 挂上
            for side in [-1.0, 1.0] as [Float] {  // 两只凳
                let stool = cylinder(radius: 0.19, height: 0.34, color: stoolColor)  // 圆凳
                stool.position = [side * 0.96, 0.17, 0]  // 与样板一致
                unit.addChild(stool)  // 挂上
            }  // 循环结束
            group.addChild(unit)  // 挂上这张桌
        }  // 循环结束
        return group  // 返回
    }  // tables 结束

    static func stalls() -> Entity {  // 三个摊位：桌面 + 支杆 + 条纹雨棚 + 三件货
        let group = Entity()  // 组
        let awningColors = [UIColor(hex: "4A90E2"), UIColor(hex: "0F9D58"), UIColor(hex: "E8890C")]  // 三色棚
        let goodsColors = [UIColor(hex: "FFD166"), UIColor(hex: "F07A5A"), UIColor(hex: "6BBF7A")]  // 三色货
        for (index, spot) in ([(Float(-2.2), Float(-1.9)), (0.2, -2.0), (2.4, -1.7)] as [(Float, Float)]).enumerated() {  // 三个摊
            let unit = Entity()  // 一个摊
            unit.position = [spot.0, 0, spot.1]  // 与样板一致
            let table = box(width: 1.5, height: 0.16, depth: 0.9, color: UIColor(hex: "D8B184"))  // 桌面
            table.position = [0, 0.82, 0]  // 与样板一致
            unit.addChild(table)  // 挂上
            for dx in [-0.62, 0.62] as [Float] {  // 两根支杆
                let post = cylinder(radius: 0.045, height: 0.82, color: UIColor(hex: "A9713F"))  // 杆
                post.position = [dx, 0.41, 0.34]  // 与样板一致
                unit.addChild(post)  // 挂上
            }  // 循环结束
            let awning = box(width: 1.7, height: 0.08, depth: 1.15, color: awningColors[index])  // 雨棚
            awning.position = [0, 1.86, 0.1]  // 与样板一致
            awning.orientation = simd_quatf(angle: 0.12, axis: [1, 0, 0])  // 与样板 rotation.x 一致
            unit.addChild(awning)  // 挂上
            for k in 0..<3 {  // 三件货
                let goods = box(width: 0.26, height: 0.2, depth: 0.26, color: goodsColors[k])  // 货
                goods.position = [-0.4 + Float(k) * 0.4, 1.0, 0]  // 与样板一致
                unit.addChild(goods)  // 挂上
            }  // 循环结束
            group.addChild(unit)  // 挂上这个摊
        }  // 循环结束
        return group  // 返回
    }  // stalls 结束

    static func crates() -> Entity {  // 三个木箱，其中一个摞起来
        let group = Entity()  // 组
        let spots: [(Float, Float)] = [(-3.3, 2.0), (-3.3, 1.2), (3.3, 2.1)]  // 位置
        for (index, spot) in spots.enumerated() {  // 逐个
            let crate = box(width: 0.5, height: 0.5, depth: 0.5, color: UIColor(hex: "C79A68"))  // 箱子
            let lift: Float = index == 1 ? 0.5 : 0  // 第二个摞上去；不显式标 Float 会被推断成 Double
            crate.position = [spot.0, 0.25 + lift, spot.1]  // 与样板一致
            group.addChild(crate)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // crates 结束

    static func fountain() -> Entity {  // 喷泉：水池 + 水面 + 中柱 + 上盆
        let group = Entity()  // 组
        group.position = [0, 0, 0.1]  // 与样板一致
        let stone = UIColor(hex: "E8E2D4")  // 石材
        let basin = cylinder(radius: 1.5, height: 0.36, color: stone)  // 水池
        basin.position = [0, 0.18, 0]  // 与样板一致
        group.addChild(basin)  // 挂上
        let water = cylinder(radius: 1.34, height: 0.06, color: UIColor(hex: "5EB8E8"))  // 水面
        water.position = [0, 0.37, 0]  // 与样板一致
        group.addChild(water)  // 挂上
        let pillar = cylinder(radius: 0.3, height: 0.9, color: stone)  // 中柱
        pillar.position = [0, 0.8, 0]  // 与样板一致
        group.addChild(pillar)  // 挂上
        let bowl = cylinder(radius: 0.52, height: 0.16, color: stone)  // 上盆
        bowl.position = [0, 1.3, 0]  // 与样板一致
        group.addChild(bowl)  // 挂上
        return group  // 返回
    }  // fountain 结束

    static func board() -> Entity {  // 公告板 + 六张便签
        let group = Entity()  // 组
        group.position = [-2.6, 0, -2.2]  // 与样板一致
        let wood = UIColor(hex: "A9713F")  // 立柱
        for dx in [-0.55, 0.55] as [Float] {  // 两根立柱
            let post = box(width: 0.08, height: 1.5, depth: 0.08, color: wood)  // 柱
            post.position = [dx, 0.75, 0]  // 与样板一致
            group.addChild(post)  // 挂上
        }  // 循环结束
        let boardEntity = box(width: 1.4, height: 0.9, depth: 0.06, color: UIColor(hex: "E0D3BD"))  // 板面
        boardEntity.position = [0, 1.1, 0]  // 与样板一致
        group.addChild(boardEntity)  // 挂上
        let noteColors = [UIColor(hex: "FFE066"), UIColor(hex: "9BE59B"),  // 便签色
                          UIColor(hex: "9BC8F5"), UIColor(hex: "FFB3BA")]  // 蓝与粉
        for i in 0..<6 {  // 六张
            let note = box(width: 0.2, height: 0.2, depth: 0.01, color: noteColors[i % 4])  // 便签
            note.position = [-0.44 + Float(i % 3) * 0.44, 1.28 - Float(i / 3) * 0.34, 0.04]  // 与样板一致
            group.addChild(note)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // board 结束

    static func npcs() -> Entity {  // 两只研友的猫（样板的 NPC 就是猫）
        let group = Entity()  // 组
        let fur = UIColor(hex: "B9A89A")  // 灰毛
        let dark = UIColor(hex: "2B3040")  // 眼睛
        let rows: [(Float, Float, UIColor)] = [  // x / z / 袍色
            (2.1, 0.5, UIColor(hex: "3B5BDB")),  // 蓝袍
            (-1.5, -1.0, UIColor(hex: "8D5F3C"))  // 棕袍
        ]  // 数组结束
        for row in rows {  // 逐只
            let unit = Entity()  // 一只
            unit.position = [row.0, 0, row.1]  // 与样板一致
            unit.orientation = simd_quatf(angle: -0.4, axis: [0, 1, 0])  // 与样板 rotation.y 一致
            let body = cylinder(radius: 0.2, height: 0.42, color: row.2)  // 身体（样板是胶囊，用圆柱近似）
            body.position = [0, 0.34, 0]  // 与样板一致
            unit.addChild(body)  // 挂上
            let head = sphere(radius: 0.28, color: fur)  // 头
            head.position = [0, 0.78, 0]  // 与样板一致
            unit.addChild(head)  // 挂上
            for side in [-1.0, 1.0] as [Float] {  // 两只耳朵与两只眼睛
                let ear = cone(radius: 0.1, height: 0.17, color: fur)  // 耳朵
                ear.position = [side * 0.17, 1.0, 0]  // 与样板一致
                ear.orientation = simd_quatf(angle: -side * 0.3, axis: [0, 0, 1])  // 与样板 rotation.z 一致
                unit.addChild(ear)  // 挂上
                let eye = sphere(radius: 0.045, color: dark)  // 眼睛
                eye.position = [side * 0.1, 0.79, 0.25]  // 与样板一致
                unit.addChild(eye)  // 挂上
            }  // 循环结束
            group.addChild(unit)  // 挂上这只
        }  // 循环结束
        return group  // 返回
    }  // npcs 结束

    static func wallDecor() -> Entity {  // 两扇窗 + 一个挂钟
        let group = Entity()  // 组
        let frameColor = UIColor(hex: "FFFFFF")  // 白框
        let sky = UIColor(hex: "CFE8FF")  // 窗外天空
        for x in [-1.62, 1.62] as [Float] {  // 两扇窗
            let unit = Entity()  // 一扇
            unit.position = [x, 2.46, -3.42]  // 与样板一致
            let frame = box(width: 1.06, height: 0.82, depth: 0.1, color: frameColor)  // 窗框
            unit.addChild(frame)  // 挂上
            let glass = box(width: 0.92, height: 0.68, depth: 0.02, color: sky)  // 玻璃
            glass.position = [0, 0, 0.06]  // 贴在框前面
            unit.addChild(glass)  // 挂上
            let barV = box(width: 0.045, height: 0.68, depth: 0.02, color: frameColor)  // 竖棂
            barV.position = [0, 0, 0.08]  // 与样板一致
            unit.addChild(barV)  // 挂上
            let barH = box(width: 0.92, height: 0.045, depth: 0.02, color: frameColor)  // 横棂
            barH.position = [0, 0, 0.08]  // 与样板一致
            unit.addChild(barH)  // 挂上
            group.addChild(unit)  // 挂上这扇窗
        }  // 循环结束

        let clock = Entity()  // 挂钟
        clock.position = [0, 2.6, -3.41]  // 与样板一致
        let rim = cylinder(radius: 0.29, height: 0.03, color: UIColor(hex: "8D97AB"))  // 外圈（样板是圆环，用薄盘代替）
        rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 立起来贴在墙上
        clock.addChild(rim)  // 挂上
        let face = cylinder(radius: 0.26, height: 0.04, color: frameColor)  // 表盘
        face.position = [0, 0, 0.02]  // 压在外圈前面
        face.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 立起来
        clock.addChild(face)  // 挂上
        let hour = box(width: 0.012, height: 0.16, depth: 0.01, color: UIColor(hex: "39435C"))  // 时针
        hour.position = [0, 0.06, 0.05]  // 从盘心往上
        hour.orientation = simd_quatf(angle: -0.5, axis: [0, 0, 1])  // 与样板角度一致
        clock.addChild(hour)  // 挂上
        let minute = box(width: 0.016, height: 0.1, depth: 0.01, color: UIColor(hex: "39435C"))  // 分针
        minute.position = [0, 0.03, 0.05]  // 从盘心往上
        minute.orientation = simd_quatf(angle: 1.1, axis: [0, 0, 1])  // 与样板角度一致
        clock.addChild(minute)  // 挂上
        group.addChild(clock)  // 挂上挂钟
        return group  // 返回
    }  // wallDecor 结束

    // MARK: - 交互点                                                  // 分节：交互点

    /// 交互点：地上一块圆垫 + 上方一颗浮球，球会轻轻上下浮，远看就知道能点
    static func spotMarker(_ spot: RoamSpot, accent: UIColor) -> Entity {  // 造地标
        let group = Entity()  // 组
        group.name = spotPrefix + spot.id  // 命名，点击命中后按它识别是哪个点
        group.position = [spot.at.x, 0, spot.at.y]  // 放在样板坐标
        let pad = cylinder(radius: 0.42, height: 0.04, color: accent)  // 地上圆垫
        pad.position = [0, 0.03, 0]  // 贴地
        group.addChild(pad)  // 挂上
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.09),  // 浮球
                               materials: [SimpleMaterial(color: accent, roughness: .float(0.2), isMetallic: false)])  // 亮面材质，暗处也看得见
        ball.name = "spot.ball"  // 命名，动画会找它
        ball.position = [0, 0.55, 0]  // 悬在半空
        group.addChild(ball)  // 挂上
        return group  // 返回
    }  // spotMarker 结束

    // MARK: - 网格                                                    // 分节：网格

    static func sphere(radius: Float, color: UIColor) -> ModelEntity {  // 球
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])  // 直接返回
    }  // sphere 结束

    static func box(width: Float, height: Float, depth: Float, color: UIColor) -> ModelEntity {  // 方块
        ModelEntity(mesh: .generateBox(width: width, height: height, depth: depth),  // 按尺寸造方块
                    materials: [material(color)])  // 上材质
    }  // box 结束

    static func cylinder(radius: Float, height: Float, color: UIColor) -> ModelEntity {  // 圆柱
        ModelEntity(mesh: .generateCylinder(height: height, radius: radius),  // 按尺寸造圆柱
                    materials: [material(color)])  // 上材质
    }  // cylinder 结束

    static func cone(radius: Float, height: Float, color: UIColor) -> ModelEntity {  // 圆锥
        ModelEntity(mesh: .generateCone(height: height, radius: radius),  // 造圆锥
                    materials: [material(color)])  // 上材质
    }  // cone 结束

    static func material(_ color: UIColor) -> SimpleMaterial {  // 统一材质
        SimpleMaterial(color: color, roughness: .float(0.82), isMetallic: false)  // 室内都偏哑光
    }  // material 结束
}  // RoamBuilder 结束

// MARK: - 视图入口                                                    // 分节：视图

/// 3D 漫游场景：点地面走过去，点交互点走到它面前并回调
struct RoamSceneView: UIViewRepresentable {  // 漫游视图
    let room: RoamRoom  // 当前房间
    let stage: PetStage  // 猫的成长阶段
    let outfit: CatOutfit  // 猫的穿戴
    var animationsOff: Bool  // 省电开关
    let onSpot: (String) -> Void  // 走到交互点后回调

    func makeUIView(context: Context) -> ARView {  // 建场景
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)  // 不启用相机
        view.renderOptions.insert(.disableMotionBlur)  // 关动态模糊
        RoamBuilder.installCamera(on: view, wall: UIColor(hex: room.wallHex))  // 装相机
        let anchor = AnchorEntity()  // 世界原点
        let root = RoamBuilder.build(room: room)  // 搭房间
        anchor.addChild(root)  // 挂上
        let wrapper = Entity()  // 猫的移动容器（只改它，猫本体在里面做呼吸）
        wrapper.position = [0, 0, 1.15]  // 与样板 catWrap.position 一致
        wrapper.orientation = simd_quatf(angle: 0.42, axis: [0, 1, 0])  // 视觉改良：样板转 180° 只给背影、看着像个罐子；略侧身朝镜头才认得出是猫
        wrapper.scale = [RoamBuilder.catScale, RoamBuilder.catScale, RoamBuilder.catScale]  // 与样板 0.38 一致
        let cat = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 复用伙伴页那只猫
        wrapper.addChild(cat)  // 挂进容器
        anchor.addChild(wrapper)  // 猫入场
        view.scene.addAnchor(anchor)  // 锚点入场
        context.coordinator.root = root  // 存房间根
        context.coordinator.anchor = anchor  // 存内容锚点，换房间要挂回这里（不能挂到相机锚点上）
        context.coordinator.wrapper = wrapper  // 存猫容器
        context.coordinator.cat = cat  // 存猫本体
        context.coordinator.roomID = room.id  // 记下房间 id
        context.coordinator.view = view  // 存视图，命中测试要用
        context.coordinator.onSpot = onSpot  // 存回调
        let tap = UITapGestureRecognizer(target: context.coordinator,  // 点一下
                                         action: #selector(Coordinator.handleTap(_:)))  // 交给协调器
        view.addGestureRecognizer(tap)  // 挂到视图
        if !animationsOff { context.coordinator.startTicking() }  // 开呼吸与浮球
        return view  // 返回
    }  // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {  // 状态变化
        context.coordinator.onSpot = onSpot  // 更新回调
        if animationsOff { context.coordinator.stopTicking() } else { context.coordinator.startTicking() }  // 跟着省电开关走
        guard context.coordinator.roomID != room.id else { return }  // 房间没换就不动
        context.coordinator.rebuild(room: room, stage: stage, outfit: outfit, on: view)  // 换房间
    }  // updateUIView 结束

    func makeCoordinator() -> Coordinator { Coordinator() }  // 建协调器

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {  // 视图销毁
        coordinator.stopTicking()  // 停定时器
    }  // dismantleUIView 结束

    final class Coordinator: NSObject {  // 协调器
        var root: Entity?  // 房间根节点
        var anchor: AnchorEntity?  // 内容锚点
        var wrapper: Entity?  // 猫的移动容器
        var cat: Entity?  // 猫本体
        weak var view: ARView?  // 场景视图
        var onSpot: ((String) -> Void)?  // 走到交互点后的回调
        var roomID = ""  // 当前房间 id
        private var timer: Timer?  // 呼吸与浮球定时器
        private var elapsed: Float = 0  // 已累计秒数
        private var walkToken = 0  // 走路批次，用来丢弃过期的到达回调

        func startTicking() {  // 开始逐帧
            guard timer == nil else { return }  // 已经在跑
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in  // 30 帧
                self?.tick()  // 走一帧
            }  // 定时器结束
        }  // startTicking 结束

        func stopTicking() {  // 停止逐帧
            timer?.invalidate()  // 停掉
            timer = nil  // 清引用
        }  // stopTicking 结束

        private func tick() {  // 一帧
            elapsed += 1.0 / 30.0  // 累计时间
            if let cat { cat.position.y = 0.02 + sin(elapsed * 1.7) * 0.02 }  // 与样板呼吸同幅度
            guard let root else { return }  // 没房间就不动浮球
            for spot in root.children where spot.name.hasPrefix(RoamBuilder.spotPrefix) {  // 每个交互点
                spot.findEntity(named: "spot.ball")?.position.y = 0.55 + sin(elapsed * 2.2) * 0.06  // 浮球轻轻上下
            }  // 循环结束
        }  // tick 结束

        func rebuild(room: RoamRoom, stage: PetStage, outfit: CatOutfit, on view: ARView) {  // 换房间
            root?.removeFromParent()  // 拆掉旧房间
            cat?.removeFromParent()  // 拆掉旧猫
            walkToken += 1  // 让在途的到达回调作废
            let newRoot = RoamBuilder.build(room: room)  // 搭新房间
            anchor?.addChild(newRoot)  // 挂回内容锚点
            let newCat = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 重建猫（阶段可能变了）
            wrapper?.addChild(newCat)  // 挂回容器
            wrapper?.position = [0, 0, 1.15]  // 回到起点
            root = newRoot  // 更新引用
            cat = newCat  // 更新引用
            roomID = room.id  // 记下房间
        }  // rebuild 结束

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {  // 处理点击
            guard let view, let wrapper else { return }  // 没准备好就退出
            let point = gesture.location(in: view)  // 点在哪
            let hits = view.hitTest(point, query: .all, mask: .all)  // 所有命中，按距离排好
            for hit in hits {  // 由近到远
                var node: Entity? = hit.entity  // 从命中的实体往上找
                while let current = node {  // 逐层向上
                    if current.name.hasPrefix(RoamBuilder.spotPrefix) {  // 命中了交互点
                        let id = current.name.replacingOccurrences(of: RoamBuilder.spotPrefix, with: "")  // 取 id
                        let target = SIMD2<Float>(current.position.x, current.position.z + 0.95)  // 站在它前面（样板 +0.95）
                        walk(to: target, spotID: id)  // 走过去再开卡片
                        return  // 结束
                    }  // 分支结束
                    if current.name == RoamBuilder.floorName {  // 命中了地板
                        let p = hit.position  // 落点
                        let clamped = SIMD2<Float>(min(3.4, max(-3.4, p.x)), min(2.2, max(-1.9, p.z)))  // 样板同范围
                        walk(to: clamped, spotID: nil)  // 只走过去
                        return  // 结束
                    }  // 分支结束
                    node = current.parent  // 继续往上
                }  // 循环结束
            }  // 循环结束
        }  // handleTap 结束

        private func walk(to target: SIMD2<Float>, spotID: String?) {  // 走向目标点
            guard let wrapper else { return }  // 没猫就走不了
            let current = SIMD2<Float>(wrapper.position.x, wrapper.position.z)  // 当前位置
            let dx = target.x - current.x  // x 差
            let dz = target.y - current.y  // z 差
            let distance = sqrt(dx * dx + dz * dz)  // 直线距离
            guard distance > 0.02 else {  // 已经在目标点附近
                if let spotID { onSpot?(spotID) }  // 直接开卡片
                return  // 结束
            }  // 分支结束
            let yaw = atan2(dx, dz)  // 朝向：样板 facing = atan2(dx, dz)
            wrapper.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])  // 先转身
            var target4 = wrapper.transform  // 目标姿态
            target4.translation = [target.x, 0, target.y]  // 只改水平位置
            let duration = Double(distance / 2.3)  // 样板速度 2.3 米每秒
            walkToken += 1  // 新一批走路
            let token = walkToken  // 记下这一批
            if let anim = try? AnimationResource.generate(with: FromToByAnimation<Transform>(from: wrapper.transform,  // 起点
                                                                                            to: target4,  // 终点
                                                                                            duration: duration,  // 时长按距离算
                                                                                            timing: .linear,  // 匀速走，不像被弹出去
                                                                                            bindTarget: .transform)) {  // 作用在变换上
                wrapper.playAnimation(anim)  // 播这段走路
            } else {  // 动画生成失败
                wrapper.transform = target4  // 直接瞬移到位，功能不丢
            }  // 分支结束
            guard let spotID else { return }  // 没有交互点就不用等到达
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in  // 到达后再开卡片
                guard let self, self.walkToken == token else { return }  // 期间又点了别处就作废
                self.onSpot?(spotID)  // 开卡片
            }  // 延时结束
        }  // walk 结束
    }  // Coordinator 结束
}  // RoamSceneView 结束
