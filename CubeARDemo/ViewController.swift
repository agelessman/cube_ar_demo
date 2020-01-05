//
//  ViewController.swift
//  CubeARDemo
//
//  Created by MC on 2019/12/26.
//  Copyright © 2019 MC. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

struct CollisionCategory {
    let rawValue: Int
    
    static let bottom = CollisionCategory(rawValue: 1 << 0)
    static let cube = CollisionCategory(rawValue: 1 << 1)
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    /// 保存所有平面
    var planes = [UUID: Plane]()
    /// 保存立方体
    var boxes = [SCNNode]()
    
    var arConfig: ARWorldTrackingConfiguration!
    let spotLight = SCNLight()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupRecognizers()
        insertSpotLight(SCNVector3Make(0, 0, 0))
        
        arConfig = ARWorldTrackingConfiguration()
        arConfig.isLightEstimationEnabled = true
        arConfig.planeDetection = .horizontal
        
    }
    
    func setupScene() {
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        /// 开启自动光照
        sceneView.autoenablesDefaultLighting = true
        
        /// 开启调试模式
        sceneView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        /// 在世界原点之下，创建一个较大的平面，用来接收掉落的几何体，然后把他们删除
        let bottomPlane = SCNBox(width: 1000, height: 0.5, length: 1000, chamferRadius: 0)
        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = UIColor(white: 1, alpha: 0)
        bottomPlane.materials = [bottomMaterial]
        
        let bottomNode = SCNNode(geometry: bottomPlane)
        bottomNode.position = SCNVector3Make(0, -10, 0)
        bottomNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        bottomNode.physicsBody?.categoryBitMask = CollisionCategory.bottom.rawValue
        bottomNode.physicsBody?.contactTestBitMask = CollisionCategory.cube.rawValue
        sceneView.scene.rootNode.addChildNode(bottomNode)
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    func setupSession() {
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    func setupRecognizers() {
        /// 手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapFrom(ges:)))
        tapGesture.numberOfTapsRequired = 1
        sceneView.addGestureRecognizer(tapGesture)
        
        /// 长按就会发射冲击波
        let explsionGes = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldFrom(ges:)))
        explsionGes.minimumPressDuration = 0.5
        sceneView.addGestureRecognizer(explsionGes)
        
        let hidePlanesGes = UILongPressGestureRecognizer(target: self, action: #selector(handleHidePlaneFrom(ges:)))
        hidePlanesGes.minimumPressDuration = 1
        hidePlanesGes.numberOfTouchesRequired = 2
        sceneView.addGestureRecognizer(hidePlanesGes)
    }
    
    @objc func handleTapFrom(ges: UITapGestureRecognizer) {
        /// 获取屏幕坐标
        let tapPoint = ges.location(in: sceneView)
        /// hit test
        let result = sceneView.hitTest(tapPoint, types: .existingPlaneUsingExtent)
        
        /// 命中可能会有对此，使用最近的
        if let hitResult = result.first {
            insertGeometry(hitResult)
        }
    }
    
    @objc func handleHoldFrom(ges: UILongPressGestureRecognizer) {
        if ges.state != .began {
            return
        }
        /// 获取屏幕坐标
        let holdPoint = ges.location(in: sceneView)
        /// hit test
        let result = sceneView.hitTest(holdPoint, types: .existingPlaneUsingExtent)
        
        /// 命中可能会有对此，使用最近的
        if let hitResult = result.first {
            DispatchQueue.main.async {
                self.explode(hitResult)
            }
        }
    }
    
    @objc func handleHidePlaneFrom(ges: UILongPressGestureRecognizer) {
        if ges.state != .began {
            return
        }
        
        /// 隐藏所有平面
        for (_, plane) in planes {
            plane.hide()
        }
        
        /// 停止检测新平面或更新当前平面
        if let config = sceneView.session.configuration as? ARWorldTrackingConfiguration {
            config.planeDetection = .init(rawValue: 0)
            sceneView.session.run(config)
        }
        
        sceneView.debugOptions = []
    }
    
    func explode(_ hitResult: ARHitTestResult) {
        /// 发射冲击波(explosion)，需要发射的世界位置和世界中每个几何体的位置。然后获得这两点之间的距离，离发射处越近，几何体被冲击的力量就越强
        
        /// hitReuslt 是某个平面上的点，将发射处向平面下方移动一点以便几何体从平面上飞出去
        let explosionYOffset: Float = 0.1
        
        let position = SCNVector3Make(hitResult.worldTransform.columns.3.x,
                                      hitResult.worldTransform.columns.3.y - explosionYOffset,
                                      hitResult.worldTransform.columns.3.z)
        
        /// 需要找到所有受冲击波影响的几何体，理想情况下最好有一些类似八叉树的空间数据结构，以便快速找出冲击波附近的所有几何体
        /// 但由于我们的物体个数不多，只要遍历一遍当前所有几何体即可
        for cubeNode in boxes {
            /// 计算每个node跟冲击波的距离
            var distance = SCNVector3Make(cubeNode.worldPosition.x - position.x,
                                          cubeNode.worldPosition.y - position.y,
                                          cubeNode.worldPosition.z - position.z)
            let len = sqrt(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
            
            /// 设置影响范围
            let maxDistance: Float = 2
            var scale = max(0, (maxDistance - len))
            scale = scale * scale * 2
            
            /// 将距离适量调整至合适的比例
            distance.x = distance.x / len * scale
            distance.y = distance.y / len * scale
            distance.z = distance.z / len * scale
            
            /// 给几何体施加力，将此力施加到小方块的一角而不是重心来让其旋转
            cubeNode.physicsBody?.applyForce(distance, at: SCNVector3Make(0.05, 0.05, 0.05), asImpulse: true)
        }
    }
    
    /// 插入几何体
    func insertGeometry(_ hitResult: ARHitTestResult) {
        let dimension: CGFloat = 0.1
        /// 立方体
        let cube = SCNBox(width: dimension, height: dimension, length: dimension, chamferRadius: 0)
        let node = SCNNode(geometry: cube)
        
        /// 物理特性
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.mass = 2
        
        /// 设置分类掩码
        node.physicsBody?.categoryBitMask = CollisionCategory.cube.rawValue
        
        /// 计算几何体的起始位置
        let insertionYOffset: Float = 0.5
        node.position = SCNVector3Make(hitResult.worldTransform.columns.3.x,
                                       hitResult.worldTransform.columns.3.y + insertionYOffset,
                                       hitResult.worldTransform.columns.3.z)
        sceneView.scene.rootNode.addChildNode(node)
        boxes.append(node)
    }
    
    func insertSpotLight(_ position: SCNVector3) {
        spotLight.type = .spot
        spotLight.spotInnerAngle = 45
        spotLight.spotOuterAngle = 45
        spotLight.intensity = 1000
        
        let spotNode = SCNNode()
        spotNode.light = spotLight
        spotNode.position = position
        
        spotNode.eulerAngles = SCNVector3Make(-.pi/2.0, 0, 0)
        sceneView.scene.rootNode.addChildNode(spotNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let estimate = sceneView.session.currentFrame?.lightEstimate else {
            return
        }
        
        spotLight.intensity = estimate.ambientIntensity
    }
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        /// 检测到新平面
        let plane = Plane(withAnchor: planeAnchor, isHidden: false)
        
        /// 添加到字典中
        planes[planeAnchor.identifier] = plane
        
        /// 添加到node
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        /// 只更新存在的已有平面
        guard let plane = planes[anchor.identifier] else {
            return
        }
        
        plane.update(anchor: anchor as! ARPlaneAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        planes.removeValue(forKey: anchor.identifier)
    }
}
