//  World3D.swift —— 世界地图：三座浮空岛（RealityKit）                  // 文件说明
//  逐条移植 Web 样板 public/js/world3d.js 的 makeIsland 与三个建筑函数。   // 移植来源
//  坐标系与样板一致：+X 右、+Y 上、+Z 朝相机，所以坐标可以照抄不用换算。   // 坐标系
//  样板用 three.js，这里只用 RealityKit 的球 / 圆柱 / 圆锥 / 方块四种网格。 // 网格约束
//  RealityKit 没有半环与环面：选中光晕改用一圈小球串成，视觉差别很小。     // 替代方案

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor

// MARK: - 配色                                                        // 分节：配色

enum WorldPalette {  // 样板 world3d.js 的 C 常量表
    static let grass = UIColor(hex: "8AD066")  // 草皮
    static let grassDark = UIColor(hex: "6FB84F")  // 草皮侧沿
    static let soil = UIColor(hex: "D6A97A")  // 土层
    static let rock = UIColor(hex: "E8D8C2")  // 岩石底
    static let cloud = UIColor(hex: "FFFFFF")  // 云
    static let tree = UIColor(hex: "5CB84A")  // 树冠
    static let treeLight = UIColor(hex: "76CC5C")  // 亮树冠
    static let trunk = UIColor(hex: "A9713F")  // 树干
    static let white = UIColor(hex: "F8F6F2")  // 白墙
    static let roof = UIColor(hex: "8FA3C4")  // 屋顶
    static let stone = UIColor(hex: "EFE9E0")  // 石材
    static let taxBlue = UIColor(hex: "3F7DF6")  // 税务蓝
    static let gold = UIColor(hex: "FFC93C")  // 金
    static let lawBrown = UIColor(hex: "8D5F3C")  // 法槌棕
    static let steel = UIColor(hex: "A8B6CC")  // 幕墙
    static let steelDark = UIColor(hex: "7F90AB")  // 深幕墙
    static let halo = UIColor(hex: "6BFFB8")  // 选中光晕
    static let sky = UIColor(hex: "EAF4FF")  // 天空底色
}  // WorldPalette 结束

// MARK: - 岛的定义                                                    // 分节：岛屿

struct WorldIsland: Identifiable {  // 一座岛
    let id: String  // 方向 id：tax / fin / law
    let name: String  // 岛名
    let people: Int  // 样板写死的样例人数
    let radius: Float  // 岛半径
    let position: SIMD3<Float>  // 岛心坐标
    let kind: Kind  // 岛上的建筑类型
    var active: Bool  // 是不是「你在这里」

    enum Kind {  // 建筑类型
        case tax  // 税务局
        case fin  // 金融高楼
        case law  // 法院
    }  // Kind 结束

    /// 与样板 world3d.js 的 LAYOUT 完全一致的三座岛
    static func layout(track: String) -> [WorldIsland] {  // 按方向拼布局
        [  // 数组开始
            WorldIsland(id: "fin", name: "金融喵岛", people: 842, radius: 1.42,  // 金融岛
                        position: [-2.45, 0.6, -2.1], kind: .fin, active: track == "fin"),  // 位置照样板
            WorldIsland(id: "law", name: "法喵岛", people: 613, radius: 1.36,  // 法喵岛
                        position: [2.45, 0.45, -1.75], kind: .law, active: track == "law"),  // 位置照样板
            WorldIsland(id: "tax", name: "税喵岛", people: 1286, radius: 1.9,  // 税喵岛
                        position: [0, 0, 1.35], kind: .tax, active: track == "tax")  // 位置照样板
        ]  // 数组结束
    }  // layout 结束
}  // WorldIsland 结束

// MARK: - 建模                                                        // 分节：建模

enum World3DBuilder {  // 浮空岛建模器

    /// 搭一整张地图，返回根节点；每座岛命名为 island.<id> 供点击命中后识别
    static func build(islands: [WorldIsland]) -> Entity {  // 搭地图
        let root = Entity()  // 根节点
        root.name = "world.root"  // 便于调试
        for cfg in islands {  // 逐座岛
            let group = island(cfg)  // 造岛
            group.generateCollisionShapes(recursive: true)  // 加碰撞体，点击才能命中
            root.addChild(group)  // 挂上
        }  // 循环结束
        root.addChild(farClouds())  // 远处几朵云
        return root  // 返回整张图
    }  // build 结束

    /// 装相机：位置与视角照抄样板（32° / (0,8.2,12.6) / 看向 (0,0.55,-0.3)）
    static func installCamera(on view: ARView) {  // 装相机
        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = 32  // 与样板 fov 32 一致
        camera.camera.near = 0.1  // 与样板一致
        camera.camera.far = 120  // 与样板一致
        let eye = SIMD3<Float>(0, 8.2, 12.6)  // 样板里的 camera.position
        let target = SIMD3<Float>(0, 0.55, -0.3)  // 样板里的 lookAt
        let forward = simd_normalize(target - eye)  // 视线方向
        let holder = AnchorEntity(world: eye)  // 相机锚点放在眼睛位置
        holder.addChild(camera)  // 挂上相机
        holder.orientation = simd_quatf(from: [0, 0, -1], to: forward)  // 把相机的 -Z 对齐视线
        view.scene.addAnchor(holder)  // 加入场景
    }  // installCamera 结束

    // MARK: - 单座岛                                                  // 分节：岛体

    static func island(_ cfg: WorldIsland) -> Entity {  // 造一座浮空岛
        let group = Entity()  // 岛根节点
        group.name = "island.\(cfg.id)"  // 命名，点击命中后按它识别
        group.position = cfg.position  // 与样板 group.position 一致
        let r = cfg.radius  // 半径简写

        let top = cylinder(radius: r, height: 0.18, color: WorldPalette.grass)  // 草皮顶
        top.position = [0, -0.02, 0]  // 与样板一致
        group.addChild(top)  // 挂上

        let rim = cylinder(radius: r * 0.96, height: 0.14, color: WorldPalette.grassDark)  // 草皮侧沿
        rim.position = [0, -0.16, 0]  // 与样板一致
        group.addChild(rim)  // 挂上

        let soil = cylinder(radius: r * 0.9, height: r * 0.45, color: WorldPalette.soil)  // 土层
        soil.position = [0, -0.23 - r * 0.22, 0]  // 接在侧沿下方
        group.addChild(soil)  // 挂上

        let rock = cone(radius: r * 0.56, height: r * 0.66, color: WorldPalette.rock)  // 岩石底
        rock.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])  // 尖朝下
        rock.position = [0, -0.44 - r * 0.55, 0]  // 顶端顶住土层
        group.addChild(rock)  // 挂上

        for i in 0..<5 {  // 岛底挂五朵云
            let angle = Float(i) / 5 * .pi * 2 + 0.4  // 均匀分布在圆周
            let cloud = makeCloud(size: r * 0.26)  // 一朵云
            cloud.position = [cos(angle) * r * 0.82, -0.2 - r * 0.62, sin(angle) * r * 0.82]  // 与样板一致
            group.addChild(cloud)  // 挂上
        }  // 循环结束

        group.addChild(building(cfg, r: r))  // 岛上的标志建筑
        group.addChild(trees(r: r))  // 四棵树
        let halo = haloRing(radius: r * 1.11)  // 选中光晕
        halo.isEnabled = cfg.active  // 只有当前岛亮
        halo.name = "island.halo.\(cfg.id)"  // 命名，切换方向时要改显隐
        group.addChild(halo)  // 挂上
        return group  // 返回
    }  // island 结束

    /// 岛上的建筑：整体放大 1.32 倍，小屏也认得出是什么
    static func building(_ cfg: WorldIsland, r: Float) -> Entity {  // 造建筑
        let group = Entity()  // 建筑组
        group.scale = [1.32, 1.32, 1.32]  // 与样板 bgroup.scale 1.32 一致
        switch cfg.kind {  // 按种类分支
        case .tax: group.addChild(taxTemple())  // 税务局
        case .fin: group.addChild(financeTowers())  // 金融高楼
        case .law: group.addChild(lawCourt())  // 法院
        }  // 分支结束
        return group  // 返回
    }  // building 结束

    // MARK: - 税务局                                                  // 分节：税务局

    static func taxTemple() -> Entity {  // 台阶 + 柱廊 + 山花 + 税牌
        let group = Entity()  // 组
        let base = box(width: 1.5, height: 0.16, depth: 1.05, color: WorldPalette.stone)  // 台基
        base.position = [0, 0.18, 0]  // 与样板一致
        group.addChild(base)  // 挂上

        let step = box(width: 1.7, height: 0.12, depth: 1.22, color: WorldPalette.stone)  // 台阶
        step.position = [0, 0.08, 0]  // 与样板一致
        group.addChild(step)  // 挂上

        let body = box(width: 1.2, height: 0.5, depth: 0.8, color: WorldPalette.white)  // 主体
        body.position = [0, 0.5, 0]  // 与样板一致
        group.addChild(body)  // 挂上

        for x in [-0.46, -0.28, -0.1, 0.08, 0.26, 0.44] as [Float] {  // 六根柱
            let col = cylinder(radius: 0.052, height: 0.56, color: WorldPalette.stone)  // 柱子
            col.position = [x, 0.51, 0.5]  // 与样板一致
            group.addChild(col)  // 挂上
        }  // 循环结束

        let cornice = box(width: 1.34, height: 0.09, depth: 0.94, color: WorldPalette.white)  // 檐口
        cornice.position = [0, 0.77, 0]  // 与样板一致
        group.addChild(cornice)  // 挂上

        let roof = pyramid(radius: 0.92, height: 0.40, color: WorldPalette.roof)  // 四坡屋顶
        roof.position = [0, 0.9, 0]  // 与样板一致，落在柱廊顶上
        group.addChild(roof)  // 挂上

        group.addChild(signPlate(color: WorldPalette.taxBlue, at: [-0.92, 1.12, 0.42]))  // 悬浮税牌
        for spot in [[0.72, 0.2, 0.42], [0.82, 0.2, 0.26], [0.77, 0.29, 0.34]] as [[Float]] {  // 金币堆
            let coin = cylinder(radius: 0.1, height: 0.035, color: WorldPalette.gold)  // 一枚币
            coin.position = [spot[0], spot[1], spot[2]]  // 与样板一致
            group.addChild(coin)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // taxTemple 结束

    // MARK: - 金融岛                                                  // 分节：金融

    static func financeTowers() -> Entity {  // 三栋高低错落的楼 + 漂浮金币
        let group = Entity()  // 组
        let pad = cylinder(radius: 0.62, height: 0.1, color: WorldPalette.stone)  // 地坪
        pad.position = [0, 0.12, 0]  // 与样板一致
        group.addChild(pad)  // 挂上

        let towers: [(Float, Float, Float, Float, Float, Float)] = [  // x / z / dz / w / h / d
            (-0.26, 0.2, 0, 0.32, 1.02, 0.32),  // 主楼
            (0.22, 0.16, 0.12, 0.26, 0.74, 0.26),  // 副楼
            (0.3, 0.14, -0.28, 0.23, 1.24, 0.23)  // 后楼
        ]  // 数组结束
        for (index, tower) in towers.enumerated() {  // 逐栋
            let (x, z, dz, w, h, d) = tower  // 拆元组
            let color = index == 1 ? WorldPalette.steelDark : WorldPalette.steel  // 中间那栋深一点
            let body = box(width: w, height: h, depth: d, color: color)  // 楼体
            body.position = [x, 0.1 + h / 2, z + dz]  // 与样板一致
            group.addChild(body)  // 挂上
            for f in 1...3 {  // 三道楼层带
                let band = box(width: w * 1.04, height: 0.035, depth: d * 1.04, color: WorldPalette.stone)  // 带
                band.position = [x, 0.1 + h * Float(f) / 4, z + dz]  // 与样板一致
                group.addChild(band)  // 挂上
            }  // 循环结束
            let cap = cone(radius: 0.05, height: 0.16, color: WorldPalette.gold)  // 楼顶小尖
            cap.position = [x, 0.1 + h + 0.08, z + dz]  // 与样板一致
            group.addChild(cap)  // 挂上
        }  // 循环结束

        let coins: [(Float, Float, Float, Float)] = [  // 漂浮金币
            (-0.62, 0.95, 0.28, 0.18),  // 左
            (0.66, 1.15, -0.1, 0.16),  // 右
            (0.02, 1.72, 0.34, 0.15)  // 顶
        ]  // 数组结束
        for coin in coins {  // 逐枚
            let mesh = cylinder(radius: coin.3, height: 0.05, color: WorldPalette.gold)  // 币身
            mesh.position = [coin.0, coin.1, coin.2]  // 与样板一致
            mesh.orientation = simd_quatf(angle: .pi / 2.4, axis: [1, 0, 0])  // 立起来一点
            group.addChild(mesh)  // 挂上
        }  // 循环结束
        group.addChild(signPlate(color: UIColor(hex: "E8A516"), at: [-0.78, 1.28, 0.44]))  // 悬浮 ¥ 牌
        return group  // 返回
    }  // financeTowers 结束

    // MARK: - 法喵岛                                                  // 分节：法院

    static func lawCourt() -> Entity {  // 法院门廊 + 天平 + 法槌
        let group = Entity()  // 组
        let base = box(width: 1.3, height: 0.14, depth: 0.95, color: WorldPalette.stone)  // 台基
        base.position = [0, 0.17, 0]  // 与样板一致
        group.addChild(base)  // 挂上

        let body = box(width: 1.05, height: 0.44, depth: 0.72, color: WorldPalette.white)  // 主体
        body.position = [0, 0.46, 0]  // 与样板一致
        group.addChild(body)  // 挂上

        for x in [-0.36, -0.18, 0, 0.18, 0.36] as [Float] {  // 五根柱
            let col = cylinder(radius: 0.045, height: 0.44, color: WorldPalette.stone)  // 柱
            col.position = [x, 0.49, 0.46]  // 与样板一致
            group.addChild(col)  // 挂上
        }  // 循环结束

        let roof = pyramid(radius: 0.80, height: 0.34, color: WorldPalette.roof)  // 四坡顶
        roof.position = [0, 0.78, 0]  // 与样板一致，压在五根柱顶上
        group.addChild(roof)  // 挂上

        let beam = box(width: 0.5, height: 0.03, depth: 0.03, color: WorldPalette.gold)  // 天平横梁
        beam.position = [-0.74, 0.78, 0.44]  // 与样板一致
        group.addChild(beam)  // 挂上
        for dx in [-0.24, 0.24] as [Float] {  // 两个秤盘
            let pan = cylinder(radius: 0.09, height: 0.02, color: WorldPalette.gold)  // 盘
            pan.position = [-0.74 + dx, 0.6, 0.44]  // 与样板一致
            group.addChild(pan)  // 挂上
            let wire = cylinder(radius: 0.006, height: 0.16, color: WorldPalette.gold)  // 吊线
            wire.position = [-0.74 + dx, 0.69, 0.44]  // 与样板一致
            group.addChild(wire)  // 挂上
        }  // 循环结束
        let pole = cylinder(radius: 0.014, height: 0.34, color: WorldPalette.gold)  // 立柱
        pole.position = [-0.74, 0.62, 0.44]  // 与样板一致
        group.addChild(pole)  // 挂上

        let head = cylinder(radius: 0.1, height: 0.2, color: WorldPalette.lawBrown)  // 法槌头
        head.position = [0.66, 0.34, 0.5]  // 与样板一致
        head.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 横放
        group.addChild(head)  // 挂上
        let handle = cylinder(radius: 0.03, height: 0.32, color: WorldPalette.lawBrown)  // 法槌柄
        handle.position = [0.76, 0.46, 0.42]  // 与样板一致
        handle.orientation = simd_quatf(angle: -0.5, axis: [0, 0, 1])  // 斜放
        group.addChild(handle)  // 挂上

        group.addChild(signPlate(color: WorldPalette.lawBrown, at: [0.86, 0.98, 0.42]))  // 悬浮法牌
        return group  // 返回
    }  // lawCourt 结束

    // MARK: - 树与云                                                  // 分节：点缀

    static func trees(r: Float) -> Entity {  // 四棵树
        let group = Entity()  // 组
        for i in 0..<4 {  // 逐棵
            let angle = -0.6 + Float(i) * (.pi * 1.5 / 3) + 0.15  // 与样板的角度分布一致
            let rr = r * (0.62 + 0.08 * Float(i % 2))  // 半径略有变化
            let tree = makeTree(size: r * 0.15)  // 一棵树
            tree.position = [cos(angle) * rr, 0.09, sin(angle) * rr]  // 与样板一致
            group.addChild(tree)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // trees 结束

    static func makeTree(size: Float) -> Entity {  // 树干 + 两层树冠
        let group = Entity()  // 组
        let trunk = cylinder(radius: size * 0.18, height: size * 1.1, color: WorldPalette.trunk)  // 树干
        trunk.position = [0, size * 0.55, 0]  // 与样板一致
        group.addChild(trunk)  // 挂上
        let ball = sphere(radius: size, color: WorldPalette.tree)  // 主树冠
        ball.position = [0, size * 1.55, 0]  // 与样板一致
        group.addChild(ball)  // 挂上
        let ball2 = sphere(radius: size * 0.72, color: WorldPalette.treeLight)  // 亮树冠
        ball2.position = [size * 0.42, size * 1.95, size * 0.18]  // 与样板一致
        group.addChild(ball2)  // 挂上
        return group  // 返回
    }  // makeTree 结束

    static func makeCloud(size: Float) -> Entity {  // 三球一朵云
        let group = Entity()  // 组
        for i in 0..<3 {  // 三团
            let part = sphere(radius: size * (1 - Float(i) * 0.12), color: WorldPalette.cloud)  // 一团
            part.scale = [1, 0.74, 0.9]  // 压扁
            part.position = [Float(i - 1) * size * 1.05, i == 1 ? size * 0.34 : 0, 0]  // 与样板一致
            group.addChild(part)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // makeCloud 结束

    static func farClouds() -> Entity {  // 远处四朵云
        let group = Entity()  // 组
        let spots: [(Float, Float, Float)] = [(-5.2, 3.4, -7.2), (-1.6, 4.3, -6.8), (2.4, 3.1, -7.4), (5.6, 4.1, -6.4)]  // 样板是随机，这里定四个位置
        for (index, spot) in spots.enumerated() {  // 逐朵
            let cloud = makeCloud(size: 0.26 + Float(index % 2) * 0.08)  // 一朵
            cloud.position = [spot.0, spot.1, spot.2]  // 放在远处
            group.addChild(cloud)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // farClouds 结束

    /// 选中光晕：样板是 RingGeometry，这里用一圈小球串出来
    static func haloRing(radius: Float) -> Entity {  // 光晕
        let group = Entity()  // 组
        let count = 28  // 小球数量，够多就看不出断点
        for i in 0..<count {  // 逐个
            let angle = Float(i) / Float(count) * .pi * 2  // 圆周角
            let dot = ModelEntity(mesh: .generateSphere(radius: radius * 0.045),  // 一颗小球
                                  materials: [SimpleMaterial(color: WorldPalette.halo, roughness: .float(0.2), isMetallic: false)])  // 亮面材质，像光环
            dot.position = [cos(angle) * radius, 0.06, sin(angle) * radius]  // 摆在圆周上
            group.addChild(dot)  // 挂上
        }  // 循环结束
        return group  // 返回
    }  // haloRing 结束

    /// 悬浮牌：样板把「税 / ¥ / 法」画到 Canvas 上做成贴图
    /// RealityKit 造中文贴图要绕一大圈，这里用「牌面 + 白点」抽象表示，名字交给页面上的胶囊标签
    static func signPlate(color: UIColor, at position: SIMD3<Float>) -> Entity {  // 悬浮牌
        let group = Entity()  // 组
        let board = box(width: 0.5, height: 0.5, depth: 0.04, color: color)  // 牌面
        group.addChild(board)  // 挂上
        let dot = sphere(radius: 0.11, color: UIColor(hex: "FFFFFF"))  // 白色标记
        dot.position = [0, 0, 0.04]  // 贴在正面
        group.addChild(dot)  // 挂上
        group.position = position  // 放到样板位置
        group.orientation = simd_quatf(angle: -0.36, axis: [0, 1, 0])  // 稍微侧一点，跟样板角度一致
        return group  // 返回
    }  // signPlate 结束

    // MARK: - 小工具                                                  // 分节：网格

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

    static func cone(radius: Float, height: Float, color: UIColor, sides: Int = 24) -> ModelEntity {  // 圆锥
        let mesh = MeshResource.generateCone(height: height, radius: radius)  // 造圆锥，分段数由引擎固定，sides 仅供参考不生效
        return ModelEntity(mesh: mesh, materials: [material(color)])  // 上材质
    }  // cone 结束

    /// 四棱锥屋顶（四坡顶）
    /// 样板用 ConeGeometry(半径, 高, 4) 画屋顶，但 RealityKit 的 generateCone 不认分段数，出来是圆锥，
    /// 叠加后像一顶扁帽子扣在柱廊上。这里手写网格：底面四角 + 顶点，四个坡面 + 底面两个三角形。
    /// 样板的高只有半径的 0.22 倍，平得像块板；这里抬到 0.45 倍左右，才看得出是坡顶。
    /// 正反两种绕序各存一遍：RealityKit 的背面剔除策略在不同版本里不一致，双份最稳，代价仅 12 个三角形。
    static func pyramid(radius: Float, height: Float, color: UIColor) -> ModelEntity {  // 四棱锥
        let half = radius * 0.70710678  // 半边长 = 外接半径 ÷ √2，四角正好落在正方形角上
        let corners: [SIMD3<Float>] = [  // 底面四角
            [half, 0, half],  // 右前
            [half, 0, -half],  // 右后
            [-half, 0, -half],  // 左后
            [-half, 0, half]  // 左前
        ]  // 数组结束
        let apex = SIMD3<Float>(0, height, 0)  // 顶点

        var positions: [SIMD3<Float>] = []  // 顶点表
        var normals: [SIMD3<Float>] = []  // 法线表，逐面平直着色
        var indices: [UInt32] = []  // 索引表

        func face(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {  // 追加一个三角面
            let n = simd_normalize(simd_cross(b - a, c - a))  // 面朝外的法线
            let base = UInt32(positions.count)  // 这批顶点的起始下标
            for v in [a, b, c] {  // 三个顶点各存一份
                positions.append(v)  // 记位置
                normals.append(n)  // 记法线
            }  // 循环结束
            indices.append(contentsOf: [base, base + 1, base + 2])  // 一种绕序
            indices.append(contentsOf: [base + 2, base + 1, base])  // 反向绕序，防被剔除
        }  // face 结束

        for i in 0..<4 {  // 四个坡面
            face(corners[i], corners[(i + 1) % 4], apex)  // 相邻两角 + 顶点
        }  // 循环结束
        face(corners[0], corners[2], corners[1])  // 底面第一半
        face(corners[0], corners[3], corners[2])  // 底面第二半

        var desc = MeshDescriptor(name: "pyramid")  // 网格描述
        desc.positions = MeshBuffers.Positions(positions)  // 灌位置
        desc.normals = MeshBuffers.Normals(normals)  // 灌法线
        desc.primitives = .triangles(indices)  // 按三角形拼
        guard let mesh = try? MeshResource.generate(from: [desc]) else {  // 生成网格
            return box(width: radius, height: height, depth: radius, color: color)  // 万一失败退回方块，功能不丢
        }  // 生成判断结束
        return ModelEntity(mesh: mesh, materials: [material(color)])  // 上材质
    }  // pyramid 结束

    static func material(_ color: UIColor) -> SimpleMaterial {  // 统一材质
        SimpleMaterial(color: color, roughness: .float(0.78), isMetallic: false)  // 哑光，像草与土
    }  // material 结束
}  // World3DBuilder 结束

// MARK: - 视图入口                                                    // 分节：视图

/// 3D 浮空岛地图。点岛回调 islandID（tax / fin / law）
struct World3DView: UIViewRepresentable {  // 3D 地图
    let track: String  // 当前考试方向，决定哪座岛亮着
    var animationsOff: Bool  // 省电：关掉浮动动画
    let onPick: (String) -> Void  // 点中岛的回报

    func makeUIView(context: Context) -> ARView {  // 建场景
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)  // 不启用相机
        view.environment.background = .color(WorldPalette.sky)  // 天空底色
        view.renderOptions.insert(.disableMotionBlur)  // 关动态模糊
        World3DBuilder.installCamera(on: view)  // 固定相机
        let islands = WorldIsland.layout(track: track)  // 三座岛的布局
        let root = World3DBuilder.build(islands: islands)  // 搭地图
        let anchor = AnchorEntity()  // 世界原点
        anchor.addChild(root)  // 挂上
        view.scene.addAnchor(anchor)  // 入场
        context.coordinator.root = root  // 存引用，动画要用
        context.coordinator.baseY = Dictionary(uniqueKeysWithValues: islands.map { ("island.\($0.id)", $0.position.y) })  // 记下每座岛的基准高度
        context.coordinator.activeTrack = track  // 记下当前方向
        context.coordinator.onPick = onPick  // 存回调
        let tap = UITapGestureRecognizer(target: context.coordinator,  // 点一下
                                         action: #selector(Coordinator.handleTap(_:)))  // 交给协调器
        view.addGestureRecognizer(tap)  // 挂到视图上
        context.coordinator.view = view  // 存视图引用，命中测试要用
        if !animationsOff { context.coordinator.startFloating() }  // 开浮动
        return view  // 返回
    }  // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {  // 状态变化
        context.coordinator.onPick = onPick  // 更新回调
        context.coordinator.setActive(track: track)  // 换「你在这里」的岛
        if animationsOff { context.coordinator.stopFloating() }  // 关浮动
        else { context.coordinator.startFloating() }  // 开浮动
    }  // updateUIView 结束

    func makeCoordinator() -> Coordinator { Coordinator() }  // 建协调器

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {  // 视图销毁
        coordinator.stopFloating()  // 停定时器，别泄漏
    }  // dismantleUIView 结束

    final class Coordinator: NSObject {  // 协调器
        var root: Entity?  // 地图根节点
        weak var view: ARView?  // 场景视图
        var onPick: ((String) -> Void)?  // 点岛回调
        private var timer: Timer?  // 浮动动画定时器
        private var elapsed: Float = 0  // 已累计秒数
        var activeTrack = ""  // 当前亮着的方向
        var baseY: [String: Float] = [:]  // 每座岛的基准高度

        func startFloating() {  // 开始浮动
            guard timer == nil else { return }  // 已经在跑
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in  // 30 帧
                self?.step()  // 走一帧
            }  // 定时器结束
        }  // startFloating 结束

        func stopFloating() {  // 停止浮动
            timer?.invalidate()  // 停掉
            timer = nil  // 清引用
        }  // stopFloating 结束

        private func step() {  // 一帧
            elapsed += 1.0 / 30.0  // 累计时间
            guard let root else { return }  // 没根节点就退出
            for child in root.children where child.name.hasPrefix("island.") && !child.name.contains("halo") {  // 只动岛本体
                let base = baseY[child.name] ?? 0  // 这座岛的基准高度
                let phase = Float(child.name.count % 7) * 0.6  // 用名字长度当相位，省一个字段
                child.position.y = base + sin(elapsed * 0.7 + phase) * 0.05  // 样板同幅度上下浮动
            }  // 循环结束
        }  // step 结束

        func setActive(track: String) {  // 切换「你在这里」
            guard track != activeTrack else { return }  // 没变就不动
            activeTrack = track  // 记下
            guard let root else { return }  // 没根节点就退出
            for id in ["tax", "fin", "law"] {  // 三座岛逐个
                root.findEntity(named: "island.halo.\(id)")?.isEnabled = (id == track)  // 只亮对应的那座
            }  // 循环结束
        }  // setActive 结束

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {  // 处理点击
            guard let view else { return }  // 没视图就退出
            let point = gesture.location(in: view)  // 点在哪
            guard let hit = view.hitTest(point, query: .nearest, mask: .all).first else { return }  // 命中最前面的物体
            var node: Entity? = hit.entity  // 从命中的实体往上找
            while let current = node {  // 逐层向上
                if current.name.hasPrefix("island.") && !current.name.contains("halo") {  // 找到岛
                    let id = current.name.replacingOccurrences(of: "island.", with: "")  // 取方向 id
                    onPick?(id)  // 回报
                    return  // 结束
                }  // 分支结束
                node = current.parent  // 继续往上
            }  // 循环结束
        }  // handleTap 结束
    }  // Coordinator 结束
}  // World3DView 结束
