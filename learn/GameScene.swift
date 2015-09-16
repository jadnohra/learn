//
//  AppDelegate.swift
//  learn
//
//  Created by Jad Nohra on 13/09/15.
//  Copyright (c) 2015 Jad Nohra. All rights reserved.
//


import SpriteKit
//
func randf() -> Float {
    return Float(arc4random()) /  Float(UInt32.max)
}
func randf2(low:Float, up:Float) -> Float {
    return low+2.0*randf()*(up-low)
}
class PreRelInfo {
    var to: String = ""
    var resolved: Bool = false
}
class RelInfo {
    var from :LrnEntity = LrnEntity()
    var to :LrnEntity = LrnEntity()
    var node :SKShapeNode = SKShapeNode()
}
class LrnEntity {
    var id : Int = 0
    var fn : String = ""
    var fp : String = ""
    var node : SKNode = SKNode()
    var type : String = ""
    var load_rel_to = Array<PreRelInfo>()
    var rel = Array<RelInfo>()
    var ocr : String = ""
    var modif : NSDate = NSDate()
    var scl : CGFloat = 1.0
    var node_scl_add : CGFloat = 0.0
    var text : String = ""
    var fntName : String = "PilGI"
    var fntSize: CGFloat = 14.0
    var fntCol: NSColor = NSColor.blackColor()
}
class Note {
    var txt : String = "test"
    var node : SKLabelNode = SKLabelNode()
}
class GameScene: SKScene {
    var dirPath = ""
    let fntNames = ["PilGI", "Arial", "Deutsche Zierschrift"]
    var id_gen :Int = 1
    var rroot : SKNode = SKNode()
    var root : SKNode = SKNode()
    var sel : SKNode = SKNode()
    var sel_ent : LrnEntity?
    var drag_sel : SKNode = SKNode()
    var entities = Array<LrnEntity>()
    var entities_by_fn = Dictionary<String, LrnEntity>()
    var state : String = ""
    var note : Note = Note()
    var auto_note_index = 1
    var last_mouse_evt = NSEvent()
    var time : CFTimeInterval = CFTimeInterval()
    var last_evt_time : CFTimeInterval = CFTimeInterval()
    func write() {
        for ent in entities {
            var cfg = ""
            cfg = cfg + String(format: "pos.x\n%f\n", Float(ent.node.position.x))
            cfg = cfg + String(format: "pos.y\n%f\n", Float(ent.node.position.y))
            cfg = cfg + String(format: "scl\n%f\n", Float(ent.scl))
            cfg = cfg + String(format: "fntSize\n%f\n", Float(ent.fntSize))
            cfg = cfg + "fntName\n" + ent.fntName + "\n"
            cfg = cfg + "fntCol\n" + (ent.fntCol == NSColor.blackColor() ? "black":"red") + "\n"
            for rel in ent.rel {
                if rel.from.fn == ent.fn {
                    cfg = cfg + "rel_to\n" + rel.to.fn + "\n"
                }
            }
            let dp = dirPath.stringByAppendingPathComponent("state")
            NSFileManager.defaultManager().createDirectoryAtPath(dp, withIntermediateDirectories: false, attributes: nil, error: nil)
            let fp = dp.stringByAppendingPathComponent("_" + ent.fn + ".lrn")
            cfg.writeToFile(fp, atomically: false, encoding: NSUTF8StringEncoding, error: nil);
        }
    }
    func createTextTexture(text: NSString, fntName: String, fntSize: CGFloat = 14.0, fntCol: NSColor = NSColor.blackColor()) -> SKTexture{
        let font = NSFont(name: fntName, size: fntSize)
        let textAttributes: [String: AnyObject] =
        [    NSForegroundColorAttributeName : fntCol as AnyObject,
            NSFontAttributeName : font as! AnyObject
        ]
        let sz = text.sizeWithAttributes(textAttributes)
        let nsi:NSImage = NSImage(size: sz)
        nsi.lockFocus()
        NSColor.whiteColor().setFill()
        NSBezierPath.fillRect(NSRect(x: 0,y: 0,width: sz.width,height: sz.height))
        text.drawInRect(NSRect(x: 0,y: 0,width: sz.width,height: sz.height), withAttributes:textAttributes)
        nsi.unlockFocus()
        return SKTexture(image:nsi)
    }
    func createLrnNote(text: String, prefix : String = "note_") -> String {
        var fn = String(format: prefix + "%d.txt", auto_note_index)
        while NSFileManager.defaultManager().fileExistsAtPath(dirPath.stringByAppendingPathComponent(fn)) {
            auto_note_index = auto_note_index+1
            fn = String(format: prefix + "%d.txt", auto_note_index)
        }
        text.writeToFile(dirPath.stringByAppendingPathComponent(fn), atomically: false, encoding: NSUTF8StringEncoding, error: nil);
        return fn
    }
    func isLrnEntityFile(fn:String) -> Bool {
        if fn.hasSuffix("png") || fn.hasSuffix("jpg") || fn.hasSuffix("jpeg") {
            return true
        }
        else if fn.hasSuffix("txt") && (fn.rangeOfString("ocr") == nil) {
            return true
        }
        return false
    }
    func updateLrnEntityNote(ent: LrnEntity) {
        if ent.type == "text" {
            let tex = createTextTexture(ent.text, fntName:ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol)
            ent.node.setScale(ent.scl)
            (ent.node as! SKSpriteNode).size = NSSize(width: tex.size().width*ent.scl, height: tex.size().height*ent.scl)
            (ent.node as! SKSpriteNode).texture = tex
        }
    }
    func updateLrnEntityFromFile(fn: String, ent: LrnEntity) {
        if ent.type == "image" {
            let fp = dirPath.stringByAppendingPathComponent(fn)
            let img = NSImage(contentsOfFile: fp)
            let tex = SKTexture(image: img!)
            (ent.node as! SKSpriteNode).size = tex.size()
            (ent.node as! SKSpriteNode).texture = tex
            
        } else {
            let fp = dirPath.stringByAppendingPathComponent(fn)
            let txt = NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding, error: nil) as! String
            let tex = createTextTexture(txt, fntName: ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol)
            (ent.node as! SKSpriteNode).size = tex.size()
            (ent.node as! SKSpriteNode).texture = tex
        }
    }
    func addLrnEntityFromFile(fn: String, center: CGPoint, i:Int) -> Bool {
        var ent = LrnEntity()
        var pos = CGPoint(x:(center.x + CGFloat(i)*40.0), y:(center.y + CGFloat(i)*40.0))
        if (true)
        {
            let dp = dirPath.stringByAppendingPathComponent("state")
            let fp = dp.stringByAppendingPathComponent("_" + fn + ".lrn")
            if NSFileManager.defaultManager().fileExistsAtPath(fp) {
                let cfg = NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding, error: nil) as! String
                let lines = cfg.componentsSeparatedByString("\n")
                var li = 0
                var key = ""
                for line in lines {
                    if (li % 2 == 0) {
                        key = line
                    } else {
                        if (key == "pos.x") {
                            pos.x = CGFloat((line as NSString).floatValue)
                        } else if (key == "pos.y") {
                            pos.y = CGFloat((line as NSString).floatValue)
                        } else if (key == "scl") {
                            ent.scl = CGFloat((line as NSString).floatValue)
                        } else if (key == "fntSize") {
                            ent.fntSize = CGFloat((line as NSString).floatValue)
                        } else if (key == "fntName") {
                            ent.fntName = line
                        } else if (key == "fntCol") {
                            ent.fntCol = line == "red" ? NSColor.redColor() : NSColor.blackColor()
                        } else if (key == "rel_to") {
                            var pri = PreRelInfo(); pri.to = line; pri.resolved = false;
                            ent.load_rel_to.append(pri)
                        }
                    }
                    li++
                }
            }
        }
        if fn.hasSuffix("png") || fn.hasSuffix("jpg") || fn.hasSuffix("jpeg") {
            let fp = dirPath.stringByAppendingPathComponent(fn)
            let img = NSImage(contentsOfFile: fp)
            let tex = SKTexture(image: img!)
            let sprite = SKSpriteNode(texture: tex)
            ent.fn = fn; ent.fp = fp; ent.node = sprite; ent.type = "image";
        } else if fn.hasSuffix("txt") && (fn.rangeOfString("ocr") == nil) {
            let fp = dirPath.stringByAppendingPathComponent(fn)
            let txt = NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding, error: nil) as! String
            let sprite = SKSpriteNode(texture: createTextTexture(txt, fntName: ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol))
            ent.fn = fn; ent.fp = fp; ent.node = sprite; ent.type = "text";
            ent.text = txt;
            if (fn.hasPrefix("auto_note")) {
                let num = fn.componentsSeparatedByString("_")[2].componentsSeparatedByString(".")[0].toInt()
                if num >= self.auto_note_index { self.auto_note_index = num! + 1}
            }
            ent.scl = 1.0 // We use font size for this
        }
        if (ent.fn != "")
        {
            let attrs = NSFileManager.defaultManager().attributesOfItemAtPath(ent.fp, error:nil) as! [String: AnyObject]
            ent.modif = attrs[NSFileModificationDate] as! NSDate
            ent.id = id_gen; id_gen++;
            ent.node.position = pos
            ent.node.setScale(ent.scl)
            ent.node.zRotation = CGFloat(randf2(-0.015, 0.015))
            ent.node.name = ent.fn
            self.entities.append(ent)
            self.entities_by_fn[ent.fn] = ent
            self.root.addChild(ent.node)
            return true
        }
        return false
    }
    func refresh() {
        let fileManager = NSFileManager.defaultManager()
        let contents = fileManager.contentsOfDirectoryAtPath(dirPath, error: nil)
        if contents != nil {
            var newi = 0
            let files = contents as! [String]
            for fn in files {
                if (isLrnEntityFile(fn)) {
                    let fp = dirPath.stringByAppendingPathComponent(fn)
                    let attrs = fileManager.attributesOfItemAtPath(fp, error:nil) as! [String: AnyObject]
                    let modif = attrs[NSFileModificationDate] as! NSDate
                    let ent = entities_by_fn[fn]
                    if (ent != nil) {
                        if (ent!.modif != modif) {
                            updateLrnEntityFromFile(fn, ent:ent!)
                        }
                    } else {
                        addLrnEntityFromFile(fn, center:last_mouse_evt.locationInNode(self.root), i:newi)
                        newi++
                    }
                }
            }
        }
    }
    func paste() -> Bool {
        var did_paste = false
        let pasteboard = NSPasteboard.generalPasteboard()
        if let nofElements = pasteboard.pasteboardItems?.count {
            if nofElements > 0 {
                var strArr: Array<String> = []
                for element in pasteboard.pasteboardItems! {
                    if let str = element.stringForType("public.utf8-plain-text") {
                        strArr.append(str)
                    }
                }
                if strArr.count != 0
                {
                    for str in strArr {
                        createLrnNote(str)
                        did_paste = true
                    }
                }
                else
                {
                    let img = NSImage(pasteboard: NSPasteboard.generalPasteboard())
                    if (img != nil) {
                        var img_rep = NSImageRep()
                        for rep in img!.representations {
                            if rep is NSBitmapImageRep {
                                img_rep = rep as! NSImageRep
                            }
                        }
                        if img_rep is NSBitmapImageRep {
                            let data = (img_rep as! NSBitmapImageRep).representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:]) as NSData?
                            let df = NSDateFormatter()
                            df.dateStyle = .ShortStyle
                            df.timeStyle = .ShortStyle
                            let date = NSDate()
                            let date_str = df.stringFromDate(date).stringByReplacingOccurrencesOfString("/", withString: "-").stringByReplacingOccurrencesOfString(":", withString: ".")
                            let fp = dirPath.stringByAppendingPathComponent("paste_" + date_str + ".png")
                            data?.writeToFile(fp, atomically: true)
                            did_paste = true
                        }
                    }
                    
                }
            }
        }
        return did_paste
    }
    func createRel(from:LrnEntity, to:LrnEntity) {
        for erel in from.rel {
            if (erel.from.fn == from.fn && erel.from.fn == to.fn) ||
                (erel.from.fn == to.fn && erel.from.fn == from.fn)
            {
                return
            }
        }
        var rel = RelInfo(); rel.from = from; rel.to = to;
        from.rel.append(rel); rel.to.rel.append(rel);
    }
    func resolveRels(ent:LrnEntity) {
        for pri in ent.load_rel_to {
            if (pri.resolved == false) {
                createRel(ent, to: self.entities_by_fn[pri.to]!)
                pri.resolved = true
            }
        }
        ent.load_rel_to.removeAll(keepCapacity: false)
    }
    func resolveAllRels() {
        for ent in self.entities {
            resolveRels(ent)
        }
    }
    func updateRelNodePath(node:SKShapeNode, from:LrnEntity, to:LrnEntity) {
        func chooseRelPoints(pts1:[CGPoint], pts2:[CGPoint]) -> (CGPoint, CGPoint) {
            func distSq(p1:CGPoint, p2:CGPoint) -> CGFloat
            {
                return (p2.x-p1.x)*(p2.x-p1.x)+(p2.y-p1.y)*(p2.y-p1.y)
            }
            var min_1 = 0; var min_2 = 0; var min_dist = distSq(pts1[0], pts2[0])
            for (i1, pt1) in enumerate(pts1) {
                for (i2, pt2) in enumerate(pts2) {
                    if distSq(pt1, pt2) < min_dist {
                        min_dist = distSq(pt1, pt2); min_1 = i1; min_2 = i2;
                    }
                }
            }
            return (pts1[min_1], pts2[min_2])
        }
        func getRectRot(ent: LrnEntity) -> [CGPoint] {
            var sz1 =  (ent.node as! SKSpriteNode).size
            let szmul = ent.scl / (ent.scl + ent.node_scl_add)
            sz1.width = sz1.width*szmul; sz1.height = sz1.height*szmul;
            let rect1 = NSMakeRect(-sz1.width/2.0, -sz1.height/2.0, sz1.width, sz1.height)
            let rot1 = CGAffineTransformMakeRotation(ent.node.zRotation)
            var pts = [CGPoint](count:8, repeatedValue:CGPoint())
            var pp = CGPoint();
            pp = CGPoint(x:rect1.minX, y:rect1.minY); pts[0] = CGPointApplyAffineTransform(pp, rot1);
            pp = CGPoint(x:rect1.minX, y:rect1.maxY); pts[1] = CGPointApplyAffineTransform(pp, rot1);
            pp = CGPoint(x:rect1.maxX, y:rect1.minY); pts[2] = CGPointApplyAffineTransform(pp, rot1);
            pp = CGPoint(x:rect1.maxX, y:rect1.maxY); pts[3] = CGPointApplyAffineTransform(pp, rot1);
            pts[0] = CGPoint(x: pts[0].x + ent.node.position.x, y: pts[0].y + ent.node.position.y )
            pts[1] = CGPoint(x: pts[1].x + ent.node.position.x, y: pts[1].y + ent.node.position.y )
            pts[2] = CGPoint(x: pts[2].x + ent.node.position.x, y: pts[2].y + ent.node.position.y )
            pts[3] = CGPoint(x: pts[3].x + ent.node.position.x, y: pts[3].y + ent.node.position.y )
            pts[4] = CGPoint(x: (pts[0].x+pts[1].x)/2.0, y: (pts[0].y+pts[1].y)/2.0)
            pts[5] = CGPoint(x: (pts[2].x+pts[3].x)/2.0, y: (pts[2].y+pts[3].y)/2.0)
            pts[6] = CGPoint(x: (pts[0].x+pts[2].x)/2.0, y: (pts[0].y+pts[2].y)/2.0)
            pts[7] = CGPoint(x: (pts[1].x+pts[3].x)/2.0, y: (pts[1].y+pts[3].y)/2.0)
            return pts
        }
        let pts1 = getRectRot(from)
        let pts2 = getRectRot(to)
        let (rel_pt1, rel_pt2) = chooseRelPoints(pts1, pts2)
        let scl = 2.0 as CGFloat
        let pathToDraw:CGMutablePathRef = CGPathCreateMutable()
        CGPathMoveToPoint(pathToDraw, nil, rel_pt1.x/scl, rel_pt1.y/scl)
        CGPathAddLineToPoint(pathToDraw, nil, rel_pt2.x/scl, rel_pt2.y/scl)
        node.path = pathToDraw
        node.setScale(scl)
        
    }
    func updateRelNodes(ent: LrnEntity) {
        for rel in ent.rel {
            if (rel.node.name == "^-") {
                updateRelNodePath(rel.node, from: rel.from, to: rel.to)
            }
        }
    }
    func createRelNode(from:LrnEntity, to:LrnEntity) -> SKShapeNode {
        let node:SKShapeNode = SKShapeNode()
        updateRelNodePath(node, from: from, to: to)
        node.strokeColor = SKColor.redColor()
        node.name = "^-"
        return node
    }
    func createNodesFroRels(ent:LrnEntity) {
        for rel in ent.rel {
            if (rel.node.name != "^-") {
                rel.node = createRelNode(rel.from, to: rel.to)
                // http://sartak.org/2014/03/skshapenode-you-are-dead-to-me.html
                self.root.addChild(rel.node)
            }
        }
    }
    func createAllNodesForRels() {
        for ent in self.entities {
            createNodesFroRels(ent)
        }
    }
    func mainLoad() {
        let fileManager = NSFileManager.defaultManager()
        let dp = dirPath.stringByAppendingPathComponent("state")
        NSFileManager.defaultManager().createDirectoryAtPath(dp, withIntermediateDirectories: false, attributes: nil, error: nil)
        let contents = fileManager.contentsOfDirectoryAtPath(dirPath, error: nil)
        let center = CGPoint(x:self.size.width/2, y:self.size.height/2)
        var i : Int = 0
        self.rroot.name = "^rroot"
        self.addChild(rroot)
        self.root.name = "^root"
        self.rroot.addChild(root)
        self.note.node = SKLabelNode(fontNamed:"PilGI")
        self.note.node.fontSize = 38
        self.note.node.fontColor = SKColor.blackColor()
        self.note.node.position = center
        self.note.node.text = ""
        self.addChild(self.note.node)
        self.note.node.hidden = true
        if contents != nil {
            let files = contents as! [String]
            for fn in files {
                if addLrnEntityFromFile(fn, center:center, i:i) {
                    i++
                }
            }
        }
        resolveAllRels()
        createAllNodesForRels()
    }
    override func didMoveToView(view: SKView) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.beginWithCompletionHandler { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                if let url = openPanel.URL {
                    self.dirPath = url.path!
                }
            }
            if NSFileManager.defaultManager().fileExistsAtPath(self.dirPath) == false {
                NSApplication.sharedApplication().terminate(nil)
                return
            }
            else {
                self.mainLoad()
            }
        }
    }
    override func mouseDragged(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        if (self.drag_sel.name == nil) {
            self.drag_sel = self.nodeAtPoint(evt.locationInNode(self))
            if (self.drag_sel.name == "^rroot") {
                self.drag_sel = SKNode()
            }
        }
        let node = self.drag_sel
        if (evt.modifierFlags & .ShiftKeyMask != nil) {
            self.root.setScale(self.root.xScale * (1.0 + evt.deltaX/20.0) )
        }
        else {
            if (node.name != nil && !node.name!.hasPrefix("^")) {
                node.position = evt.locationInNode(node.parent)
                updateRelNodes(self.entities_by_fn[node.name!]!)
            } else {
                self.root.position = CGPoint(x: self.root.position.x + evt.deltaX, y: self.root.position.y - evt.deltaY)
            }
        }
    }
    override func keyDown(evt: NSEvent) {
        let scl_fac = 1.02 as CGFloat
        let fnt_scl_fac = 1.02 as CGFloat
        func handleRptUp(evt: NSEvent) {
            if let ent = self.sel_ent {
                if (ent.type == "text") {
                    ent.fntSize = ent.fntSize * fnt_scl_fac
                    self.sel.setScale( ent.scl)
                    updateLrnEntityNote(ent)
                    updateRelNodes(ent)
                } else {
                    ent.scl = ent.scl * scl_fac
                    self.sel.setScale( ent.scl)
                    updateRelNodes(ent)
                }
            }
        }
        func handleRptDown(evt: NSEvent) {
            if let ent = self.sel_ent {
                if (ent.type == "text") {
                    ent.fntSize = ent.fntSize / fnt_scl_fac
                    self.sel.setScale( ent.scl)
                    updateLrnEntityNote(ent)
                    updateRelNodes(ent)
                } else {
                    ent.scl = ent.scl / scl_fac
                    self.sel.setScale( ent.scl)
                    updateRelNodes(ent)
                }
            }
        }
        func handleLeft(evt: NSEvent) {
            if let ent = self.sel_ent {
                if (ent.type == "text") {
                    if (ent.fntCol == NSColor.blackColor()) {
                        ent.fntCol = NSColor.redColor()
                    } else {
                        ent.fntCol = NSColor.blackColor()
                    }
                    updateLrnEntityNote(ent)
                }
            }
        }
        func handleRight(evt: NSEvent) {
            if let ent = self.sel_ent {
                if (ent.type == "text") {
                    var ni = 0
                    for (i, ff) in enumerate(self.fntNames) {
                        if ent.fntName == ff {
                            ni = (i + 1) % self.fntNames.count
                        }
                    }
                    ent.fntName = self.fntNames[ni]
                    updateLrnEntityNote(ent)
                }
            }
        }
        self.last_evt_time = self.time; checkWake();
        if state == "note" {
        } else {
            if (evt.ARepeat) {
                switch(evt.keyCode) {
                case 126: handleRptUp(evt);
                case 125: handleRptDown(evt);
                case 124: evt;  // right
                case 123: evt;   // left
                default: evt;
                }
            }
            else {
                if evt.characters == "n" {
                    let fn = createLrnNote("note: ")
                    addLrnEntityFromFile(fn, center:last_mouse_evt.locationInNode(self.root), i:0)
                }
                else if evt.characters == "p" {
                    if (paste()) { refresh() }
                }
                else if evt.characters == "r" {
                    refresh()
                } else {
                    switch(evt.keyCode) {
                    case 124: handleRight(evt)
                    case 123: handleLeft(evt)
                    default: evt;
                    }
                }
            }
        }
    }
    override func mouseEntered(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        self.last_mouse_evt = evt
    }
    override func mouseMoved(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        self.last_mouse_evt = evt
    }
    func isEntityNode(node: SKNode) -> Bool {
        return node.name != nil && node.name != "" && !node.name!.hasPrefix("^")
    }
    func setSelNode(node: SKNode) {
        if self.sel != node {
            if let ent = self.sel_ent {
                ent.node_scl_add = 0.0
                self.sel.setScale( ent.scl +  ent.node_scl_add)
                self.sel.zPosition = 1
            }
            if isEntityNode(node) {
                self.sel = node
                self.sel_ent = self.entities_by_fn[self.sel.name!]
                if let ent = self.sel_ent {
                    self.sel_ent!.node_scl_add = 0.125*1.5
                    self.sel.setScale( ent.scl +  ent.node_scl_add)
                    self.sel.zPosition = 2
                }
            } else {
                self.sel = SKNode()
                self.sel_ent = nil
            }
        }
    }
    override func mouseDown(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
    }
    override func mouseUp(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        self.drag_sel = SKNode()
        let node = self.nodeAtPoint(evt.locationInNode(self))
        if (evt.modifierFlags & .ShiftKeyMask != nil) && isEntityNode(node) && isEntityNode(self.sel) {
            let from = self.sel; let to = node;
            var found = false
            if let fent = self.entities_by_fn[from.name!] {
                if let tent = self.entities_by_fn[to.name!] {
                    createRel(fent, to: tent)
                    createNodesFroRels(fent)
                }
            }
        }
        if (isEntityNode(node)) { setSelNode(node) }
    }
    func checkWake() {
        if (self.last_evt_time.distanceTo(self.time) > 0.5) {
            self.view!.paused = true
        }
        else {
            self.view!.paused = false
        }
    }
    override func update(currentTime: CFTimeInterval) {
        self.time = currentTime; checkWake();
        //if (self.sel.name != nil) && (isEntityNode(self.sel)) {
        //    println(self.convertPoint(CGPoint(x: 0,y: 0), fromNode: self.sel))
        //}
    }
}
