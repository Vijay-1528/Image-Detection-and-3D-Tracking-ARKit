//
//  ViewController.swift
//  AddModelToARKit
//
//  Created by VIJAY M on 17/01/23.
//

import UIKit
import ARKit
import RealityKit
import UIKit.UIGestureRecognizerSubclass
import NaturalLanguage
import Vision
import VisionKit
import VideoToolbox

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
    
    var nodeName = ""
    
    let nodeArray: [String] = ["Chappathi", "IdlySambar", "naanChanna"]
    
    var starImgView = UIImage()
    
    var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil)
    
    var singleTimeUpdation = Bool()
    
    var count = Int()
    
    //Store The Rotation Of The CurrentNode
    var currentAngleY: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        
        let configuration = ARWorldTrackingConfiguration()
        let referenceImg = ARReferenceImage.referenceImages(inGroupNamed: "Menu Resources", bundle: nil)
        configuration.detectionImages = referenceImg
        configuration.planeDetection = [.horizontal, .vertical]
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        //        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedAction(_:)))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didPan(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        self.sceneView.addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleObject(_:)))
        pinchGesture.delegate = self
        self.sceneView.addGestureRecognizer(pinchGesture)
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotateNode(_ :)))
        rotateGesture.delegate = self
        self.sceneView.addGestureRecognizer(rotateGesture)
        
        self.starImgView = self.customViewOfRating(nodeName: "").image
        
        //        statusViewController.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
        debugPrint("FIND A SURFACE TO PLACE AN OBJECT")
        selectedVirtualObjectRows.update(with: 2)
        self.textRecognizerConfig()
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
    
    func customViewOfRating(nodeName: String) -> UIView {
        let contentView = UIView()
        contentView.frame = CGRect(x: 0, y: 100, width: 250, height: 50)
        contentView.backgroundColor = .orange
        contentView.layer.cornerRadius = contentView.frame.size.height/2
        let ratingStar = StarRatingView()
        ratingStar.frame = CGRect(x: 50, y: 0, width: 150, height: 50)
        ratingStar.starColor = .white
        ratingStar.starRounding = .ceilToHalfStar
        
        do {
            if let bundlePath = Bundle.main.path(forResource: "RatingFile", ofType: "json"), let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) {
               let decoder = JSONDecoder()
                let result = try decoder.decode(RatingModel.self, from: jsonData)
                if nodeName == "Chappathi" {
                    ratingStar.rating = Float(result.chappathi.rating) ?? 0.0
                } else if nodeName == "naanChanna" {
                    ratingStar.rating = Float(result.naanChanna.rating) ?? 0.0
                } else {
                    ratingStar.rating = Float(result.idlySambar.rating) ?? 0.0
                }
            }
        } catch {
            print(error)
        }
        contentView.addSubview(ratingStar)
        let dummyView = contentView
        dummyView.tag = count
        self.view.addSubview(dummyView)
        self.view.sendSubviewToBack(dummyView)
        count += 1
        return contentView
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
    //    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    //
    //        let _ = virtualObjectLoader.loadedObjects.contains { object in
    //            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
    //        }
    //
    //        DispatchQueue.main.async {
    ////            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
    //
    //            // If the object selection menu is open, update availability of items
    //            if self.objectsViewController?.viewIfLoaded?.window != nil {
    //                self.objectsViewController?.updateObjectAvailability()
    //            }
    //        }
    //    }
    
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        let frameImg = frame.capturedImage
//        let convertedImg = UIImage(pixelBuffer: frameImg)
//        // Get the CGImage on which to perform requests.
//        guard let cgImage = convertedImg?.cgImage else { return }
//
//        let imageview = UIImageView()
//        if let image = convertedImg {
//            imageview.image = image
//        }
//        imageview.backgroundColor = .orange
//
//        // Create a new image-request handler.
//        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
//
//        // Create a new request to recognize text.
//        self.textRecognitionRequest = VNRecognizeTextRequest(completionHandler: { (request, error) in
//            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {return}
//                 let text = observations.compactMap({
//                 $0.topCandidates(1).first?.string
//                 }).joined(separator: ", ")
//                 print(text) // text we get from image
//        })
//
//        do {
//            // Perform the text-recognition request.
//            self.textRecognitionRequest.recognitionLevel = .accurate
//            try requestHandler.perform([self.textRecognitionRequest])
//        } catch {
//            print("Unable to perform the requests: \(error).")
//        }
//    }
    
    func textRecognizerConfig() {
        self.textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            DispatchQueue.main.async {
                let boundingRects: [CGRect] = observations.compactMap { observation in

                    // Find the top observation.
                    guard let candidate = observation.topCandidates(1).first else { return .zero }
                    
                    // Find the bounding-box observation for the string range.
                    let stringRange = candidate.string.startIndex..<candidate.string.endIndex
                    let boxObservation = try? candidate.boundingBox(for: stringRange)
                    
                    // Get the normalized CGRect value.
                    let boundingBox = boxObservation?.boundingBox ?? .zero
                    
                    debugPrint(boundingBox)
                    // Convert the rectangle from normalized coordinates to image coordinates.
                    let bound = VNImageRectForNormalizedRect(boundingBox, Int(self.sceneView.frame.size.width), Int(self.sceneView.frame.size.height))
                    return bound
                }
                debugPrint("bounding Rects : \(boundingRects.first)")
            }
        }
        
        self.textRecognitionRequest.recognitionLevel = .accurate
        self.textRecognitionRequest.recognitionLanguages = ["en-US", "en-GB"]
        self.textRecognitionRequest.usesLanguageCorrection = true
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        for item in self.sceneView.scene.rootNode.childNodes {
            if item.childNodes.count > 0 {
                for newItem in item.childNodes {
                    if newItem.childNodes.count > 0 {
                        for secondNewItem in newItem.childNodes {
                            if (secondNewItem.name ?? "").range(of: "star") != nil  {
                                DispatchQueue.main.async {
                                    let sepString = "\((secondNewItem.name ?? "").components(separatedBy: "_")[1])"
                                    let planeImg = self.customViewOfRating(nodeName: sepString).image
                                    secondNewItem.geometry?.firstMaterial?.diffuse.contents = planeImg
                                }
                            }
                        }
                    }
                }
            }
        }
        
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        
        if imageAnchor.referenceImage.name == "IMG_0509" {
            node.simdTransform = imageAnchor.transform
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let parentNode = SCNNode()
        let node = SCNNode()
        renderer.scene?.isPaused = false
        if let imageAnchor = anchor as? ARImageAnchor, self.nodeArray.contains(imageAnchor.name ?? "") {
            let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
            
            plane.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.0)
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.eulerAngles.x = -.pi / 2
            planeNode.name = "fine_\(imageAnchor.name ?? "")"
            
            node.position.x += 0.08
            
            var cupScene = SCNScene(named: "Models.scnassets/cup/cup.scn")!
            if imageAnchor.name ?? "" == "Chappathi" {
                cupScene = SCNScene(named: "Models.scnassets/candle/candle.scn")!
            } else if imageAnchor.name ?? "" == "naanChanna" {
                cupScene = SCNScene(named: "Models.scnassets/sticky note/sticky note.scn")!
            } else {
                guard let screen = SCNScene(named: "ice cream.obj") else { return node }
                cupScene = screen
            }
            let cupNode = cupScene.rootNode.childNodes.first!
            cupNode.position = SCNVector3Zero
            cupNode.position.z = 0.15
            
            cupNode.name = "not"
            debugPrint("node name == \(imageAnchor.name ?? "")")
            
            //            let starPlane = SCNPlane(width: 0.1, height: 0.1)
            //            starPlane.firstMaterial?.diffuse.contents = self.customViewOfRating(nodeName: imageAnchor.name ?? "")
            //            var starNode = SCNNode(geometry: starPlane)
            //            starNode.position = cupNode.position
            
            let starPlane = SCNPlane(width: 0.1, height: 0.02)
            starPlane.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 1.0)
            let starNode = SCNNode(geometry: starPlane)
            starNode.eulerAngles.x = -.pi / 2
            starNode.name = "star_\(imageAnchor.name ?? "")"
            starNode.position = planeNode.position
            starNode.position.z += 0.03
            if imageAnchor.name == "Chappathi" {
                starNode.position.z += 0.05
            } else if imageAnchor.name == "naanChanna" {
                starNode.position.z += 0.09
            }
            
            planeNode.addChildNode(cupNode)
            node.addChildNode(planeNode)
            node.addChildNode(starNode)
            parentNode.addChildNode(node)
            
            
        }
        
        return parentNode
    }
    
    //-------------------
    //MARK: Node Creation
    //-------------------
    
    /// Creates An SCNNode With An SCNTextGeometry
    ///
    /// - Parameter position: SCNVector3
    func createTextFromPosition(_ position: SCNVector3){
        
        let textNode = SCNNode()
        
        //1. Create The Text Geometry With String & Depth Parameters
        let textGeometry = SCNText(string: "StackOverFlow" , extrusionDepth: 1)
        
        //2. Set The Font With Our Set Font & Size
        textGeometry.font = UIFont(name: "Helvatica", size: 1)
        
        //3. Set The Flatness To Zero (This Makes The Text Look Smoother)
        textGeometry.flatness = 0
        
        //4. Set The Colour Of The Text
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        //5. Set The Text's Material
        textNode.geometry = textGeometry
        
        //6. Set The Pivot At The Center
        let min = textNode.boundingBox.min
        let max = textNode.boundingBox.max
        
        textNode.pivot = SCNMatrix4MakeTranslation(
            min.x + (max.x - min.x)/2,
            min.y + (max.y - min.y)/2,
            min.z + (max.z - min.z)/2
        )
        
        //7. Scale The Text So We Can Actually See It!
        textNode.scale = SCNVector3(0.005, 0.005 , 0.005)
        
        //8. Add It To The Hierachy & Position It
        self.sceneView.scene.rootNode.addChildNode(textNode)
        textNode.position = position
        
        //9. Set It As The Current Node
        //        currentNode = textNode
    }
    
    //    func add3DModel(text: String) {
    //      // Step 1: Use OCR to identify the text in your scene
    //      let detectedText = text
    //
    //      // Step 2: Use NLP to extract relevant information from the text
    //      let modelName = extractModelNameFromText(detectedText)
    //
    //      // Step 3: Load the appropriate 3D model based on the information extracted from the text
    //      let modelScene = SCNScene(named: "art.scnassets/\(modelName).scn")
    //
    //      // Step 4: Use ARKit's ARSCNView to display the 3D model in the scene and position it
    //      let node = SCNNode()
    //      node.addChildNode(modelScene.rootNode)
    //      node.position = SCNVector3(0, 0, -1)
    //      sceneView.scene.rootNode.addChildNode(node)
    //
    //      // Step 5: Add interactivity to the 3D model if desired
    //      node.isUserInteractionEnabled = true
    //      let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(360.degreeToRadians), z: 0, duration: 10)
    //      let repeatAction = SCNAction.repeatForever(rotateAction)
    //      node.runAction(repeatAction)
    //
    //      // Step 6: Track the text and update the 3D model node's position accordingly
    //      let referenceObject = ARReferenceObject(orientation: .portrait, center: CGPoint(x: 0.5, y: 0.5), extent: CGSize(width: 0.1, height: 0.1))
    //      sceneView.session.add(anchor: ARAnchor(transform: matrix_identity_float4x4))
    //      let configuration = ARWorldTrackingConfiguration()
    //      configuration.detectionObjects = [referenceObject]
    //      sceneView.session.run(configuration)
    //
    //      // Delegate method that is called when an object is detected
    //      func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    //        guard let objectAnchor = anchor as? ARObjectAnchor else { return }
    //        node.addChildNode(self.node)
    //        node.position = SCNVector3(objectAnchor.transform.columns.3.x, objectAnchor.transform.columns.3.y, objectAnchor.transform.columns.3.z)
    //      }
    //    }
    
    //    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    //        let node = SCNNode()
    //        guard let newAnchor = anchor as? ARImageAnchor else {return node}
    //        debugPrint("newAnchor \(newAnchor)")
    //        debugPrint("newAnchor width \(newAnchor.referenceImage.physicalSize.width) and height \(newAnchor.referenceImage.physicalSize.height)")
    //        let planeAnchor = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
    //        node.position = SCNVector3(anchor.transform.columns.3.x-0.5, anchor.transform.columns.3.y, 0.0)
    ////        let planeAnchor = SCNPlane(width: 0.5, height: 0.5)
    //
    ////        guard let container = self.sceneView.scene.rootNode.childNode(withName: "candle", recursively: false) else { return node }
    //        planeAnchor.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 1.0)
    //
    //        let planeNode = SCNNode(geometry: planeAnchor)
    //        planeNode.eulerAngles.x = -.pi / 2
    //
    ////        guard let screen = SCNScene(named: "Models.scnassets/sticky note/sticky note.scn") else { return node }
    //        guard let screen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
    //
    ////        guard let screens = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
    ////        guard let screen = SCNScene(named: "FRENCH_FRIES.obj") else { return node }
    ////        let reference = VirtualObject()
    ////        reference.addChildNode(screens.rootNode.childNodes.first!)
    //        let animeNode = screen.rootNode.childNodes.first!
    //        animeNode.name = "cup"
    //        animeNode.position = SCNVector3Zero
    //        animeNode.position.x = animeNode.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
    //        animeNode.position.z = 0.15
    //
    //
    //
    //        guard let screen2 = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
    //
    //        let animeNode2 = screen2.rootNode.childNodes.first!
    //        animeNode2.name = "cup2"
    //        animeNode2.position = SCNVector3Zero
    //        animeNode2.position.x = animeNode2.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
    //        animeNode2.position.y = animeNode.position.y+0.08
    //        animeNode2.position.z = 0.15
    //
    //
    //
    ////        self.sceneView.allowsCameraControl = true
    ////        self.sceneView.cameraControlConfiguration.allowsTranslation = false
    ////        DispatchQueue.main.async {
    //////            self.virtualObjectInteraction.selectedObject = reference
    ////            self.updateCurrentScreen()
    ////            self.virtualObjectSelectionViewController(didSelectObject: reference)
    ////        }
    //        planeNode.addChildNode(animeNode)
    //        planeNode.addChildNode(animeNode2)
    //
    //
    ////        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
    ////            let cellIsEnabled = self.enabledVirtualObjectRows.contains(2)
    ////            guard cellIsEnabled else { return }
    ////            self.updateCurrentScreen()
    ////            let object = self.virtualObjects[2]
    ////            object.anchor = anchor
    ////            self.virtualObjectSelectionViewController(didSelectObject: object)
    ////            if let anchor = object.anchor {
    ////                self.session.add(anchor: anchor)
    ////            }
    ////        }
    //
    //        node.addChildNode(planeNode)
    //
    //        let parentNode = SCNNode()
    //        var childNode = [SCNNode(), SCNNode()]
    //
    //        let firstNode = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
    //        firstNode.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
    //        let firstPlane = SCNNode(geometry: firstNode)
    //        firstPlane.position.x = firstPlane.position.x+0.08
    //        firstPlane.eulerAngles.x = -.pi / 2
    //        firstPlane.name = "cup"
    //
    //        guard let separateFirstScreen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
    //        let firstAnimeNode = separateFirstScreen.rootNode.childNodes.first!
    //        firstAnimeNode.name = "cup"
    //        firstAnimeNode.position = SCNVector3Zero
    ////        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
    ////        firstAnimeNode.physicsBody = physicsBody
    ////        firstAnimeNode.position.x = firstAnimeNode.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
    //        firstAnimeNode.position.z = 0.15
    //        let additionalFirstAnimeNode = SCNNode()
    //        additionalFirstAnimeNode.name = "cup"
    //        additionalFirstAnimeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
    //        additionalFirstAnimeNode.position = SCNVector3Zero
    //        additionalFirstAnimeNode.position.z = 0.15
    ////        firstPlane.addChildNode(additionalFirstAnimeNode)
    //        firstPlane.addChildNode(firstAnimeNode)
    //
    //        let secondNode = SCNPlane(width: newAnchor.referenceImage.physicalSize.width, height: newAnchor.referenceImage.physicalSize.width)
    //        secondNode.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
    //        let secondPlane = SCNNode(geometry: secondNode)
    //        secondPlane.position.x = secondPlane.position.x+0.08
    ////        secondPlane.position.y = secondPlane.position.y-0.05
    //        secondPlane.position.z = secondPlane.position.z+0.08
    //        secondPlane.eulerAngles.x = -.pi / 2
    //        secondPlane.name = "cup2"
    //
    ////        guard let separateSecondScreen = SCNScene(named: "Models.scnassets/cup/cup.scn") else { return node }
    //        guard let separateSecondScreen = SCNScene(named: "ice cream.obj") else { return node }
    //        let secondAnimeNode2 = separateSecondScreen.rootNode.childNodes.first!
    //        secondAnimeNode2.name = "cup2"
    //        secondAnimeNode2.position = SCNVector3Zero
    ////        secondAnimeNode2.position.x = secondAnimeNode2.position.x + Float(newAnchor.referenceImage.physicalSize.width-(newAnchor.referenceImage.physicalSize.width/2))
    ////        secondAnimeNode2.position.y = firstAnimeNode.position.y+0.08
    //        secondAnimeNode2.position.z = 0.15
    ////        secondPlane.addChildNode(secondAnimeNode2)
    //
    //
    //
    //        childNode.append(firstPlane)
    //        childNode.append(secondPlane)
    //        for item in childNode {
    //            parentNode.addChildNode(item)
    //        }
    //        return parentNode
    //    }
    
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let imgAnchor = anchor as? ARImageAnchor else {return}
            let referImg = imgAnchor.referenceImage
            debugPrint("referImg details width: \(referImg.physicalSize.width), height: \(referImg.physicalSize.height) and name: \(referImg.name ?? "")")
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                let cellIsEnabled = self.enabledVirtualObjectRows.contains(2)
                guard cellIsEnabled else { return }
                self.updateCurrentScreen()
                let object = self.virtualObjects[2]
                self.virtualObjectSelectionViewController(didSelectObject: object)
    //            let modelNode = self.sceneView.scene.rootNode.childNodes
    //            DispatchQueue.main.asyncAfter(deadline: .now()+3.0) {
    //                guard let objectIndex = self.virtualObjectLoader.loadedObjects.firstIndex(of: object) else {
    //                    fatalError("Programmer error: Failed to lookup virtual object in scene.")
    //                }
    //                self.virtualObjectLoader.removeVirtualObject(at: objectIndex)
    //                self.virtualObjectInteraction.selectedObject = nil
    //                if let anchor = object.anchor {
    //                    self.session.remove(anchor: anchor)
    //                }
    //            }
                debugPrint("self.sceneView.session.currentFrame?.geoTrackingStatus \(self.sceneView.session.currentFrame?.geoTrackingStatus)")
    //            self.sceneView.session.run(<#T##configuration: ARConfiguration##ARConfiguration#>)
            }
        }
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

extension ViewController: UIGestureRecognizerDelegate {
    // MARK: - Gesture Actions
    
    @objc
    func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
        case .began:
            // Check for an object at the touch location.
            //            if let object = objectInteracting(with: gesture, in: sceneView) {
            //                trackedObject = object
            //            }
            debugPrint("begin is working")
            break
            
        case .changed where gesture.isThresholdExceeded:
            //            guard let object = trackedObject else { return }
            //            // Move an object if the displacment threshold has been met.
            //            translate(object, basedOn: updatedTrackingPosition(for: object, from: gesture))
            //
            //            gesture.setTranslation(.zero, in: sceneView)
            debugPrint("changed is working")
            break
            
        case .changed:
            // Ignore the pan gesture until the displacment threshold is exceeded.
            break
            
        case .ended:
            // Update the object's position when the user stops panning.
            guard let tapSceneView = gesture.view as? SCNView else {return}
            let touchLocation = gesture.location(in: tapSceneView)
            let hitResult = tapSceneView.hitTest(touchLocation)
            if !(hitResult.isEmpty) {
                for nodes in hitResult {
                    if nodes.node.name == "cup" {
                        self.nodeName = nodes.node.name ?? ""
                        let node = hitResult[0].node
                        debugPrint("They have touch the 3D model node")
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Alert", message: "You have touched the cup 3D model node", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "Ok", style: .default)
                            alert.addAction(okAction)
                            self.present(alert, animated: true)
                        }
                    } else if nodes.node.name == "candle_holder" {
                        self.nodeName = nodes.node.name ?? ""
                        let node = hitResult[0].node
                        debugPrint("They have touch the candle 3D model node")
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Alert", message: "You have touched the candle 3D model node", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "Ok", style: .default)
                            alert.addAction(okAction)
                            self.present(alert, animated: true)
                        }
                    } else if nodes.node.name == "note" {
                        self.nodeName = nodes.node.name ?? ""
                        let node = hitResult[0].node
                        debugPrint("They have touch the note 3D model node")
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Alert", message: "You have touched the note 3D model node", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "Ok", style: .default)
                            alert.addAction(okAction)
                            self.present(alert, animated: true)
                        }
                    }
                }
            }
            break
        default:
            // Reset the current position tracking.
            debugPrint("default is working")
            break
        }
    }
    
    @objc func scaleObject(_ gesture: UIPinchGestureRecognizer) {
        guard let tapSceneView = gesture.view as? SCNView else {return}
        let touchLocation = gesture.location(in: tapSceneView)
        let hitResult = tapSceneView.hitTest(touchLocation)
        if !(hitResult.isEmpty) {
            for nodes in hitResult {
                if nodes.node.childNodes.count > 0, nodes.node.name ?? "" == "fine_IdlySambar" {
//                    guard let nodeToScale = nodes.node else { return }
                    let nodeToScale = nodes.node
                    if gesture.state == .changed {

                        let pinchScaleX: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.x))
                        let pinchScaleY: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.y))
                        let pinchScaleZ: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.z))
                        nodeToScale.scale = SCNVector3Make(Float(pinchScaleX), Float(pinchScaleY), Float(pinchScaleZ))
                        gesture.scale = 1

                    }
                    if gesture.state == .ended { }
                }
            }
        }
    }
    
    /// Rotates An SCNNode Around It's YAxis
    ///
    /// - Parameter gesture: UIRotationGestureRecognizer
    @objc func rotateNode(_ gesture: UIRotationGestureRecognizer){

        //1. Get The Current Rotation From The Gesture
        let rotation = Float(gesture.rotation)
        guard let tapSceneView = gesture.view as? SCNView else {return}
        let touchLocation = gesture.location(in: tapSceneView)
        let hitResult = tapSceneView.hitTest(touchLocation)
        if !(hitResult.isEmpty) {
            for nodes in hitResult {
                if nodes.node.childNodes.count > 0, nodes.node.childNodes[0].name ?? "" == "not" {
                    let currentNode = nodes.node.childNodes[0]
                    //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
                    if gesture.state == .changed{

                        currentNode.eulerAngles.y = currentAngleY + rotation
                    }

                    //3. If The Gesture Has Ended Store The Last Angle Of The Cube
                    if(gesture.state == .ended) {
                        currentAngleY = currentNode.eulerAngles.y

                    }
                }
            }
        }
    }
}


public extension UIView {
    @available(iOS 10.0, *)
    var image: UIImage {
        let width = 250.0
        let height = 50.0
        //     let rect = CGRect(x: CGFloat((width-100)/2.0), y: CGFloat((height-50)/2.0), width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width), height: CGFloat(height)))
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}


extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }

        self.init(cgImage: cgImage)
    }
}
