//
//  Plane.swift
//  CubeARDemo
//
//  Created by MC on 2019/12/30.
//  Copyright © 2019 MC. All rights reserved.
//

import UIKit
import ARKit
import SceneKit

class Plane: SCNNode {
    let anchor: ARPlaneAnchor!
    let planeGeometry: SCNBox!
    
    init(withAnchor anchor: ARPlaneAnchor, isHidden hidden: Bool) {
        self.anchor = anchor
        
        let width = anchor.extent.x
        let length = anchor.extent.z
        
        let planeHeight: Float = 0.01
        planeGeometry = SCNBox(width: CGFloat(width),
                               height: CGFloat(planeHeight),
                               length: CGFloat(length),
                               chamferRadius: 0)
        
        
        /// 添加网格
        let material = SCNMaterial()
        let img = UIImage(named: "tron_grid")
        material.diffuse.contents = img
        
        /// 由于正在使用立方体，但却只需要渲染表面的网格，所以让其他几条边都透明
        let transparentMaterial = SCNMaterial()
        transparentMaterial.diffuse.contents = UIColor(white: 1, alpha: 0)
        
        if hidden {
            planeGeometry.materials = [transparentMaterial, transparentMaterial,
                                       transparentMaterial, transparentMaterial,
                                       transparentMaterial, transparentMaterial]
        } else {
            planeGeometry.materials = [transparentMaterial, transparentMaterial,
                                       transparentMaterial, transparentMaterial,
                                       material, transparentMaterial]
        }
    
        
        /// 添加node
        let planeNode = SCNNode(geometry: planeGeometry)
        
        planeNode.position = SCNVector3Make(0, -planeHeight / 2.0, 0)
        
        
        /// 设置物理表面
        planeNode.physicsBody = SCNPhysicsBody(type: .kinematic,
                                               shape: SCNPhysicsShape(geometry: planeGeometry, options: nil))
        
        super.init()
        
        setTextureScale()
        addChildNode(planeNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("error")
    }
    
    func update(anchor: ARPlaneAnchor) {
        planeGeometry.width = CGFloat(anchor.extent.x)
        planeGeometry.length = CGFloat(anchor.extent.z)
        
        let node = childNodes.first
        node?.physicsBody = SCNPhysicsBody(type: .kinematic,
                                           shape: SCNPhysicsShape(geometry: planeGeometry, options: nil))
        
        setTextureScale()
    }
    
    func setTextureScale() {
        let width = planeGeometry.width
        let height = planeGeometry.length
        
        /// 更新网格
        let material = planeGeometry.materials[4]
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(width), Float(height), 1)
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
    }
    
    func hide() {
        let transparentMaterial = SCNMaterial()
        transparentMaterial.diffuse.contents = UIColor(white: 1, alpha: 0)
        planeGeometry.materials = [transparentMaterial, transparentMaterial,
                                   transparentMaterial, transparentMaterial,
                                   transparentMaterial, transparentMaterial]
    }
}
