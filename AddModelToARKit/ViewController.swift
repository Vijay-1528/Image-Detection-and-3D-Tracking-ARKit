//
//  ViewController.swift
//  AddModelToARKit
//
//  Created by VIJAY M on 17/01/23.
//

import UIKit
import ARKit
import RealityKit

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: VirtualObjectARView!
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    /// Coordinates the loading and unloading of reference nodes for virtual objects.
    let virtualObjectLoader = VirtualObjectLoader()
    
    /// The view controller that displays the virtual object selection menu.
    var objectsViewController: VirtualObjectSelectionViewController?
    
    /// The rows of the 'VirtualObject's that are currently allowed to be placed.
    var enabledVirtualObjectRows = Set<Int>()
    
    /// The rows of the currently selected `VirtualObject`s.
    var selectedVirtualObjectRows = IndexSet()
    
    /// The collection of `VirtualObject`s to select from.
    var virtualObjects = [VirtualObject]()
    
    /// A type which manages gesture manipulation of virtual content in the scene.
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView, viewController: self)
    
    /// A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.example.apple-samplecode.arkitexample.serialSceneKitQueue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        
        let configuration = ARWorldTrackingConfiguration()
        let referenceImg = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.detectionImages = referenceImg
        configuration.planeDetection = [.horizontal, .vertical]
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedAction(_:)))
        self.sceneView.addGestureRecognizer(tapGesture)

//        statusViewController.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
        debugPrint("FIND A SURFACE TO PLACE AN OBJECT")
        selectedVirtualObjectRows.update(with: 2)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+3.0) {
            var newEnabledVirtualObjectRows = Set<Int>()
            for (row, object) in VirtualObject.availableObjects.enumerated() {
                // Enable row always if item is already placed, in order to allow the user to remove it.
                if self.selectedVirtualObjectRows.contains(row) {
                    newEnabledVirtualObjectRows.insert(row)
                }
                
                // Enable row if item can be placed at the current location
                if let query = self.sceneView.getRaycastQuery(for: object.allowedAlignment),
                   let result = self.sceneView.castRay(for: query).first {
                    object.mostRecentInitialPlacementResult = result
                    object.raycastQuery = query
                    newEnabledVirtualObjectRows.insert(row)
                } else {
                    object.mostRecentInitialPlacementResult = nil
                    object.raycastQuery = nil
                }
            }
            
            // Only reload changed rows
            let changedRows = newEnabledVirtualObjectRows.symmetricDifference(self.enabledVirtualObjectRows)
            self.enabledVirtualObjectRows = newEnabledVirtualObjectRows
            let indexPaths = changedRows.map { row in IndexPath(row: row, section: 0) }
            self.virtualObjects = VirtualObject.availableObjects
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now()+5.0) {
//            let cellIsEnabled = self.enabledVirtualObjectRows.contains(0)
//            guard cellIsEnabled else { return }
//
//            let object = self.virtualObjects[0]
//
//            self.virtualObjectSelectionViewController(didSelectObject: object)
//        }
    }
    
    @objc func tappedAction(_ recogonizer: UIGestureRecognizer) {
        guard let tapSceneView = recogonizer.view as? SCNView else {return}
        let touchLocation = recogonizer.location(in: tapSceneView)
        let hitResult = tapSceneView.hitTest(touchLocation)
        if !(hitResult.isEmpty) {
            for nodes in hitResult[0].node.childNodes {
                if nodes.name == "cup" {
                    let node = hitResult[0].node
                    debugPrint("They have touch the cup node")
                } else if nodes.name == "cup2" {
                    let node = hitResult[0].node
                    debugPrint("They have touch the cup2 node")
                }
            }
        }
    }
    
    func updateCurrentScreen() {
        var newEnabledVirtualObjectRows = Set<Int>()
        for (row, object) in VirtualObject.availableObjects.enumerated() {
            // Enable row always if item is already placed, in order to allow the user to remove it.
            if self.selectedVirtualObjectRows.contains(row) {
                newEnabledVirtualObjectRows.insert(row)
            }
            
            // Enable row if item can be placed at the current location
            if let query = self.sceneView.getRaycastQuery(for: object.allowedAlignment),
               let result = self.sceneView.castRay(for: query).first {
                object.mostRecentInitialPlacementResult = result
                object.raycastQuery = query
                newEnabledVirtualObjectRows.insert(row)
            } else {
                object.mostRecentInitialPlacementResult = nil
                object.raycastQuery = nil
            }
        }
        
        // Only reload changed rows
        let changedRows = newEnabledVirtualObjectRows.symmetricDifference(self.enabledVirtualObjectRows)
        self.enabledVirtualObjectRows = newEnabledVirtualObjectRows
        let indexPaths = changedRows.map { row in IndexPath(row: row, section: 0) }
        self.virtualObjects = VirtualObject.availableObjects
    }
    
    // MARK: - VirtualObjectSelectionViewControllerDelegate
    // - Tag: PlaceVirtualContent
    func virtualObjectSelectionViewController(didSelectObject object: VirtualObject) {
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            
//            do {
//                let scene = try SCNScene(url: object.referenceURL, options: nil)
//                self.sceneView.prepare([scene], completionHandler: { _ in
//                    DispatchQueue.main.async {
//                        self.placeVirtualObject(loadedObject)
//                    }
//                })
//            } catch {
//                fatalError("Failed to load SCNScene from object.referenceURL")
//            }
            do {
                let scene = try SCNScene(url: object.referenceURL, options: nil)
                self.sceneView.prepare([scene], completionHandler: { _ in
//                    DispatchQueue.main.async {
//                        self.placeVirtualObject(loadedObject)
//                    }
                })
            } catch {
                fatalError("Failed to load SCNScene from object.referenceURL")
            }
            
        })
//        displayObjectLoadingUI()
    }
    
    /** Adds the specified virtual object to the scene, placed at the world-space position
     estimated by a hit test from the center of the screen.
     - Tag: PlaceVirtualObject */
    func placeVirtualObject(_ virtualObject: VirtualObject) {
        debugPrint("virtualObject.raycastQuery \(virtualObject.raycastQuery ?? ARRaycastQuery(origin: simd_float3(0.0, 0.0, 0.0), direction: simd_float3(0.0, 0.0, 0.0), allowing: .estimatedPlane, alignment: .any))")
        guard let query = virtualObject.raycastQuery else {
            if let controller = self.objectsViewController {
                self.virtualObjectSelectionViewController(controller, didDeselectObject: virtualObject)
            }
            return
        }
       debugPrint("query \(query)")
        let trackedRaycast = createTrackedRaycastAndSet3DPosition(of: virtualObject, from: query,
                                                                  withInitialResult: virtualObject.mostRecentInitialPlacementResult)
        
        virtualObject.raycast = trackedRaycast
        virtualObjectInteraction.selectedObject = virtualObject
        virtualObject.isHidden = false
    }
    
    // - Tag: GetTrackedRaycast
    func createTrackedRaycastAndSet3DPosition(of virtualObject: VirtualObject, from query: ARRaycastQuery,
                                              withInitialResult initialResult: ARRaycastResult? = nil) -> ARTrackedRaycast? {
        if let initialResult = initialResult {
            self.setTransform(of: virtualObject, with: initialResult)
        }
        
        return session.trackedRaycast(query) { (results) in
            self.setVirtualObject3DPosition(results, with: virtualObject)
        }
    }
    
    func setTransform(of virtualObject: VirtualObject, with result: ARRaycastResult) {
        virtualObject.simdWorldTransform = result.worldTransform
    }
    
    // - Tag: ProcessRaycastResults
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with virtualObject: VirtualObject) {
        
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        
        self.setTransform(of: virtualObject, with: result)
        
        // If the virtual object is not yet in the scene, add it.
        if virtualObject.parent == nil {
            self.sceneView.scene.rootNode.addChildNode(virtualObject)
            virtualObject.shouldUpdateAnchor = true
        }
        
        if virtualObject.shouldUpdateAnchor {
            virtualObject.shouldUpdateAnchor = false
            self.updateQueue.async {
                self.sceneView.addOrUpdateAnchor(for: virtualObject)
            }
        }
    }
    
    func createRaycastAndUpdate3DPosition(of virtualObject: VirtualObject, from query: ARRaycastQuery) {
        guard let result = session.raycast(query).first else {
            return
        }
        
        if virtualObject.allowedAlignment == .any && self.virtualObjectInteraction.trackedObject == virtualObject {
            
            // If an object that's aligned to a surface is being dragged, then
            // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
            virtualObject.simdWorldPosition = result.worldTransform.translation
            
            let previousOrientation = virtualObject.simdWorldTransform.orientation
            let currentOrientation = result.worldTransform.orientation
            virtualObject.simdWorldOrientation = simd_slerp(previousOrientation, currentOrientation, 0.1)
        } else {
            self.setTransform(of: virtualObject, with: result)
        }
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didDeselectObject object: VirtualObject) {
        guard let objectIndex = virtualObjectLoader.loadedObjects.firstIndex(of: object) else {
            fatalError("Programmer error: Failed to lookup virtual object in scene.")
        }
        virtualObjectLoader.removeVirtualObject(at: objectIndex)
        virtualObjectInteraction.selectedObject = nil
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
    }
}

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        let _ = virtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        DispatchQueue.main.async {
//            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
            
            // If the object selection menu is open, update availability of items
            if self.objectsViewController?.viewIfLoaded?.window != nil {
                self.objectsViewController?.updateObjectAvailability()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        
        if imageAnchor.referenceImage.name == "IMG_0509" {
            node.simdTransform = imageAnchor.transform
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        guard let newAnchor = anchor as? ARImageAnchor else {return node}
        debugPrint("newAnchor \(newAnchor)")
        debugPrint("newAnchor width \(newAnchor.referenceImage.physicalSize.width) and height \(newAnchor.referenceImage.physicalSize.height)")
        let planeAnchor = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
        node.position = SCNVector3(anchor.transform.columns.3.x-0.5, anchor.transform.columns.3.y, 0.0)
//        let planeAnchor = SCNPlane(width: 0.5, height: 0.5)
        
//        guard let container = self.sceneView.scene.rootNode.childNode(withName: "candle", recursively: false) else { return node }
        planeAnchor.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 1.0)
        
        let planeNode = SCNNode(geometry: planeAnchor)
        planeNode.eulerAngles.x = -.pi / 2
        
//        guard let screen = SCNScene(named: "Models.scnassets/sticky note/sticky note.scn") else { return node }
        guard let screen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
        
//        guard let screens = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
//        guard let screen = SCNScene(named: "FRENCH_FRIES.obj") else { return node }
//        let reference = VirtualObject()
//        reference.addChildNode(screens.rootNode.childNodes.first!)
        let animeNode = screen.rootNode.childNodes.first!
        animeNode.name = "cup"
        animeNode.position = SCNVector3Zero
        animeNode.position.x = animeNode.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
        animeNode.position.z = 0.15
        
        
        
        guard let screen2 = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
        
        let animeNode2 = screen2.rootNode.childNodes.first!
        animeNode2.name = "cup2"
        animeNode2.position = SCNVector3Zero
        animeNode2.position.x = animeNode2.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
        animeNode2.position.y = animeNode.position.y+0.08
        animeNode2.position.z = 0.15
        
        
        
//        self.sceneView.allowsCameraControl = true
//        self.sceneView.cameraControlConfiguration.allowsTranslation = false
//        DispatchQueue.main.async {
////            self.virtualObjectInteraction.selectedObject = reference
//            self.updateCurrentScreen()
//            self.virtualObjectSelectionViewController(didSelectObject: reference)
//        }
        planeNode.addChildNode(animeNode)
        planeNode.addChildNode(animeNode2)
        
        
//        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
//            let cellIsEnabled = self.enabledVirtualObjectRows.contains(2)
//            guard cellIsEnabled else { return }
//            self.updateCurrentScreen()
//            let object = self.virtualObjects[2]
//            object.anchor = anchor
//            self.virtualObjectSelectionViewController(didSelectObject: object)
//            if let anchor = object.anchor {
//                self.session.add(anchor: anchor)
//            }
//        }
        
        node.addChildNode(planeNode)
        
        let parentNode = SCNNode()
        var childNode = [SCNNode(), SCNNode()]
        
        let firstNode = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
        firstNode.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
        let firstPlane = SCNNode(geometry: firstNode)
        firstPlane.position.x = firstPlane.position.x+0.08
        firstPlane.eulerAngles.x = -.pi / 2
        firstPlane.name = "cup"
        
        guard let separateFirstScreen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
        let firstAnimeNode = separateFirstScreen.rootNode.childNodes.first!
        firstAnimeNode.name = "cup"
        firstAnimeNode.position = SCNVector3Zero
//        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
//        firstAnimeNode.physicsBody = physicsBody
//        firstAnimeNode.position.x = firstAnimeNode.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
        firstAnimeNode.position.z = 0.15
        firstPlane.addChildNode(firstAnimeNode)
        
        let secondNode = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
        secondNode.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
        let secondPlane = SCNNode(geometry: secondNode)
        secondPlane.position.x = secondPlane.position.x+0.08
//        secondPlane.position.y = secondPlane.position.y-0.05
        secondPlane.position.z = secondPlane.position.z+0.08
        secondPlane.eulerAngles.x = -.pi / 2
        secondPlane.name = "cup2"
        
//        guard let separateSecondScreen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
        guard let separateSecondScreen = SCNScene(named: "ice cream.obj") else { return node }
        let secondAnimeNode2 = separateSecondScreen.rootNode.childNodes.first!
        secondAnimeNode2.name = "cup2"
        secondAnimeNode2.position = SCNVector3Zero
//        secondAnimeNode2.position.x = secondAnimeNode2.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
//        secondAnimeNode2.position.y = firstAnimeNode.position.y+0.08
        secondAnimeNode2.position.z = 0.15
        secondPlane.addChildNode(secondAnimeNode2)
        
        
        
        childNode.append(firstPlane)
        childNode.append(secondPlane)
        for item in childNode {
            parentNode.addChildNode(item)
        }
        return parentNode
    }
    
//    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//        guard let imgAnchor = anchor as? ARImageAnchor else {return}
//        let referImg = imgAnchor.referenceImage
//        debugPrint("referImg details width: \(referImg.physicalSize.width), height: \(referImg.physicalSize.height) and name: \(referImg.name ?? "")")
//        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
//            let cellIsEnabled = self.enabledVirtualObjectRows.contains(2)
//            guard cellIsEnabled else { return }
//            self.updateCurrentScreen()
//            let object = self.virtualObjects[2]
//            self.virtualObjectSelectionViewController(didSelectObject: object)
////            let modelNode = self.sceneView.scene.rootNode.childNodes
////            DispatchQueue.main.asyncAfter(deadline: .now()+3.0) {
////                guard let objectIndex = self.virtualObjectLoader.loadedObjects.firstIndex(of: object) else {
////                    fatalError("Programmer error: Failed to lookup virtual object in scene.")
////                }
////                self.virtualObjectLoader.removeVirtualObject(at: objectIndex)
////                self.virtualObjectInteraction.selectedObject = nil
////                if let anchor = object.anchor {
////                    self.session.remove(anchor: anchor)
////                }
////            }
//            debugPrint("self.sceneView.session.currentFrame?.geoTrackingStatus \(self.sceneView.session.currentFrame?.geoTrackingStatus)")
////            self.sceneView.session.run(<#T##configuration: ARConfiguration##ARConfiguration#>)
//        }
//    }
    // MARK: - Focus Square
//    func updateFocusSquare(isObjectVisible: Bool) {
//        if isObjectVisible || coachingOverlay.isActive {
//            focusSquare.hide()
//        } else {
//            focusSquare.unhide()
//            statusViewController.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
//        }
//
//        // Perform ray casting only when ARKit tracking is in a good state.
//        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
//            let query = sceneView.getRaycastQuery(),
//            let result = sceneView.castRay(for: query).first {
//
//            updateQueue.async {
//                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
//                self.focusSquare.state = .detecting(raycastResult: result, camera: camera)
//            }
//            if !coachingOverlay.isActive {
//                addObjectButton.isHidden = false
//            }
//            statusViewController.cancelScheduledMessage(for: .focusSquare)
//        } else {
//            updateQueue.async {
//                self.focusSquare.state = .initializing
//                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
//            }
//            addObjectButton.isHidden = true
//            objectsViewController?.dismiss(animated: false, completion: nil)
//        }
//    }
}

