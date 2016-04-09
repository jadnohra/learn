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
class RelInfo: Equatable {
    var id : Int = 0
    var from :LrnEntity = LrnEntity()
    var to :LrnEntity = LrnEntity()
    var node :SKShapeNode = SKShapeNode()
}
func ==(lhs: RelInfo, rhs: RelInfo) -> Bool
{
    return lhs.id == rhs.id
}
class LrnEntity: Equatable {
    var id : Int = 0
    var fn : String = ""
    var fp : String = ""
    var node : SKNode = SKNode()
    var sel_node : SKShapeNode = SKShapeNode()
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
    var fntColName : String = "black"
    var fntCol: NSColor = NSColor.blackColor()
}
func ==(lhs: LrnEntity, rhs: LrnEntity) -> Bool
{
    return lhs.id == rhs.id
}
class GameScene: SKScene {
    var dirPath = ""
    var sdirPath = ""
    let fntNames = ["PilGI", "Arial", "Deutsche Zierschrift"]
    let colNames = ["black":NSColor.blackColor(), "red":NSColor.redColor(), "magenta":NSColor.magentaColor(), "green":NSColor.greenColor(), "blue":NSColor.blueColor()]
    var id_gen :Int = 1
    var rel_id_gen: Int = 1
    var rroot : SKNode = SKNode()
    var root : SKNode = SKNode()
    var sel : SKNode = SKNode()
    var sel_ent : LrnEntity?
    var drag_sel : SKNode = SKNode()
    var entities = Array<LrnEntity>()
    var sel_entities = Array<LrnEntity>()
    var entities_by_fn = Dictionary<String, LrnEntity>()
    var state : String = ""
    var auto_note_index = 1
    var auto_paste_index = 1
    var last_mouse_evt = NSEvent()
    var time : CFTimeInterval = CFTimeInterval()
    var last_evt_time : CFTimeInterval = CFTimeInterval()
    var fcs_cpy : SKNode = SKNode()
    var fcs_cpy_orig : SKNode = SKNode()
    var drag_rect : SKShapeNode = SKShapeNode()
    var deferred = [""]
    var is_sel_dragging = false;
    var is_sel_moving = false;
    var sel_drag_from : NSPoint = NSPoint();
    var sel_drag_to : NSPoint = NSPoint();
    var sel_move_from : NSPoint = NSPoint();
    var started_sel_moving = false;
    func write() {
        let dp = sdirPath
        for ent in entities {
            var cfg = ""
            cfg = cfg + String(format: "pos.x\n%f\n", Float(ent.node.position.x))
            cfg = cfg + String(format: "pos.y\n%f\n", Float(ent.node.position.y))
            cfg = cfg + String(format: "scl\n%f\n", Float(ent.scl))
            cfg = cfg + String(format: "fntSize\n%f\n", Float(ent.fntSize))
            cfg = cfg + "fntName\n" + ent.fntName + "\n"
            cfg = cfg + "fntCol\n" + ent.fntColName + "\n"
            for rel in ent.rel {
                if rel.from.fn == ent.fn {
                    cfg = cfg + "rel_to\n" + rel.to.fn + "\n"
                }
            }
            let fp = (dp as NSString).stringByAppendingPathComponent("_" + ent.fn + ".lrn")
            do {
                try cfg.writeToFile(fp, atomically: false, encoding: NSUTF8StringEncoding)
            } catch _ {
            }
        }
        if (true)
        {
            var cfg = ""
            cfg = cfg + String(format: "pos.x\n%f\n", Float(root.position.x))
            cfg = cfg + String(format: "pos.y\n%f\n", Float(root.position.y))
            cfg = cfg + String(format: "scl\n%f\n", Float(root.xScale))
            let fp = (dp as NSString).stringByAppendingPathComponent("state_root.lrn")
            do {
                try cfg.writeToFile(fp, atomically: false, encoding: NSUTF8StringEncoding)
            } catch _ {
            };
        }
    }
    func createTextTexture(_text: NSString, fntName: String, fntSize: CGFloat = 14.0, fntCol: NSColor = NSColor.blackColor()) -> SKTexture{
        let font = NSFont(name: fntName, size: fntSize)
        let textAttributes: [String: AnyObject] =
        [    NSForegroundColorAttributeName : fntCol as AnyObject,
            NSFontAttributeName : font as! AnyObject
        ]
        let text = " " + _text.stringByReplacingOccurrencesOfString("\n", withString: " \n ") + " "
        let sz = text.sizeWithAttributes(textAttributes)
        let nsi:NSImage = NSImage(size: sz)
        nsi.lockFocus()
        NSColor.whiteColor().setFill()
        //NSBezierPath.fillRect(NSRect(x: 0,y: 0,width: sz.width,height: sz.height))
        NSBezierPath.strokeRect(NSRect(x: 0,y: 0,width: sz.width,height: sz.height))
        text.drawInRect(NSRect(x: 0,y: 0,width: sz.width,height: sz.height), withAttributes:textAttributes)
        nsi.unlockFocus()
        return SKTexture(image:nsi)
    }
    func createLrnNote(text: String, prefix : String = "note_") -> String {
        var fn = String(format: prefix + "%d.txt", auto_note_index)
        while NSFileManager.defaultManager().fileExistsAtPath((dirPath as NSString).stringByAppendingPathComponent(fn)) {
            auto_note_index = auto_note_index+1
            fn = String(format: prefix + "%d.txt", auto_note_index)
        }
        do {
            try text.writeToFile((dirPath as NSString).stringByAppendingPathComponent(fn), atomically: false, encoding: NSUTF8StringEncoding)
        } catch _ {
        };
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
    func deleteEntityFile(ent: LrnEntity) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(ent.fp)
        } catch _ {
        }
    }
    func updateLrnEntityNote(ent: LrnEntity) {
        if ent.type == "text" {
            let tex = createTextTexture(ent.text, fntName:ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol)
            ent.node.setScale(ent.scl)
            (ent.node as! SKSpriteNode).size = NSSize(width: tex.size().width*ent.scl, height: tex.size().height*ent.scl)
            (ent.node as! SKSpriteNode).texture = tex
        }
    }
    func fixText(txt: String) -> String {
        if txt.hasSuffix("\n") {
            return String(txt.characters.dropLast())
        }
        return txt
    }
    func updateLrnEntityFromFile(fn: String, ent: LrnEntity) {
        if ent.type == "image" {
            let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
            let img = NSImage(contentsOfFile: fp)
            let tex = SKTexture(image: img!)
            (ent.node as! SKSpriteNode).size = tex.size()
            (ent.node as! SKSpriteNode).texture = tex

        } else {
            let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
            let txt = fixText((try! NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding)) as String)
            ent.text = txt
            let tex = createTextTexture(ent.text, fntName: ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol)
            (ent.node as! SKSpriteNode).size = tex.size()
            (ent.node as! SKSpriteNode).texture = tex
        }
    }
    func addLrnEntityFromFile(fn: String, center: CGPoint, i:Int) -> Bool {
        let ent = LrnEntity()
        var pos = CGPoint(x:(center.x + CGFloat(i)*40.0), y:(center.y + CGFloat(i)*40.0))
        if (true)
        {
            let dp = (dirPath as NSString).stringByAppendingPathComponent("state")
            let fp = (dp as NSString).stringByAppendingPathComponent("_" + fn + ".lrn")
            if NSFileManager.defaultManager().fileExistsAtPath(fp) {
                let cfg = (try! NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding)) as String
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
                            if let colVal = self.colNames[line] {
                                ent.fntColName = line
                                ent.fntCol = self.colNames[ent.fntColName]!
                            } else {
                                ent.fntColName = line
                                ent.fntCol = self.colNames["black"]!
                            }
                        } else if (key == "rel_to") {
                            let pri = PreRelInfo(); pri.to = line; pri.resolved = false;
                            ent.load_rel_to.append(pri)
                        }
                    }
                    li++
                }
            }
        }
        if fn.hasSuffix("png") || fn.hasSuffix("jpg") || fn.hasSuffix("jpeg") {
            let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
            let img = NSImage(contentsOfFile: fp)
            let tex = SKTexture(image: img!)
            let sprite = SKSpriteNode(texture: tex)
            ent.fn = fn; ent.fp = fp; ent.node = sprite; ent.type = "image";
            if (fn.hasPrefix("paste_")) {
                let num = Int(fn.componentsSeparatedByString("_")[1].componentsSeparatedByString(".")[0])
                if num >= self.auto_paste_index { self.auto_paste_index = num! + 1}
            }
        } else if fn.hasSuffix("txt") && (fn.rangeOfString("ocr") == nil) {
            let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
            let txt = (try! NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding)) as String
            ent.text = fixText(txt);
            let sprite = SKSpriteNode(texture: createTextTexture(ent.text, fntName: ent.fntName, fntSize: ent.fntSize, fntCol: ent.fntCol))
            ent.fn = fn; ent.fp = fp; ent.node = sprite; ent.type = "text";
            if (fn.hasPrefix("auto_note")) {
                let num = Int(fn.componentsSeparatedByString("_")[2].componentsSeparatedByString(".")[0])
                if num >= self.auto_note_index { self.auto_note_index = num! + 1}
            }
            ent.scl = 1.0 // We use font size for this
        }
        if (ent.fn != "")
        {
            let attrs = (try! NSFileManager.defaultManager().attributesOfItemAtPath(ent.fp))
            ent.modif = attrs[NSFileModificationDate] as! NSDate
            ent.id = id_gen; id_gen++;
            ent.node.position = pos
            ent.node.setScale(ent.scl)
            //ent.node.zRotation = CGFloat(randf2(-0.01, 0.01))
            ent.node.name = ent.fn
            let bbr : CGFloat = 12.0
            let bb = SKPhysicsBody(circleOfRadius: bbr); bb.affectedByGravity = false; bb.mass = 0;
            ent.node.physicsBody = bb

            ent.sel_node = createCircleNode( CGPoint(x: 0,y: 0), rad: bbr, name: "^_sel_" + ent.node.name!, zPos: 1.5)
            ent.sel_node.fillColor = SKColor.redColor();
            //ent.node.addChild(ent.sel_node)

            self.entities.append(ent)
            self.entities_by_fn[ent.fn] = ent
            self.root.addChild(ent.node)

            return true
        }
        return false
    }
    func refresh() {
        let fileManager = NSFileManager.defaultManager()
        let contents = try? fileManager.contentsOfDirectoryAtPath(dirPath)
        if contents != nil {
            var newi = 0
            let files = contents
            for fn in files! {
                if (isLrnEntityFile(fn)) {
                    let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
                    let attrs = (try! fileManager.attributesOfItemAtPath(fp))
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
                                img_rep = rep
                            }
                        }
                        if img_rep is NSBitmapImageRep {
                            let data = (img_rep as! NSBitmapImageRep).representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:]) as NSData?
                            /*
                            let df = NSDateFormatter()
                            df.dateStyle = .ShortStyle
                            df.timeStyle = .ShortStyle
                            let date = NSDate()
                            let date_str = df.stringFromDate(date).stringByReplacingOccurrencesOfString("/", withString: "-").stringByReplacingOccurrencesOfString(":", withString: ".")
                            let fp = dirPath.stringByAppendingPathComponent("paste_" + date_str + ".png")
                            */
                            let prefix = "paste_"
                            var fn = String(format: prefix + "%d.png", auto_paste_index)
                            while NSFileManager.defaultManager().fileExistsAtPath((dirPath as NSString).stringByAppendingPathComponent(fn)) {
                                auto_paste_index = auto_paste_index+1
                                fn = String(format: prefix + "%d.png", auto_note_index)
                            }
                            let fp = (dirPath as NSString).stringByAppendingPathComponent(fn)
                            data?.writeToFile(fp, atomically: true)
                            did_paste = true
                        }
                    }

                }
            }
        }
        return did_paste
    }
    func createRel(from:LrnEntity, to:LrnEntity, delOnFound:Bool=false) -> Bool {
        for erel in from.rel {
            if (erel.from.fn == from.fn && erel.to.fn == to.fn) ||
                (erel.from.fn == to.fn && erel.to.fn == from.fn)
            {
                if delOnFound {
                    erel.node.removeFromParent()
                    from.rel.removeAtIndex( from.rel.indexOf(erel)! )
                    to.rel.removeAtIndex( to.rel.indexOf(erel)! )
                }
                return false
            }
        }
        let rel = RelInfo(); rel.id = self.rel_id_gen; self.rel_id_gen++; rel.from = from; rel.to = to;
        from.rel.append(rel); rel.to.rel.append(rel);
        return true
    }
    func resolveRels(ent:LrnEntity) {
        for pri in ent.load_rel_to {
            if (pri.resolved == false) {
                if let toEnt = self.entities_by_fn[pri.to] {
                    createRel(ent, to: toEnt)
                }
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
            var min_1 = 0; var min_2 = 0; var min_dist = distSq(pts1[0], p2: pts2[0])
            for (i1, pt1) in pts1.enumerate() {
                for (i2, pt2) in pts2.enumerate() {
                    if distSq(pt1, p2: pt2) < min_dist {
                        min_dist = distSq(pt1, p2: pt2); min_1 = i1; min_2 = i2;
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
        var is_outer = (pts2[0].x > pts1[2].x || pts2[2].x < pts1[0].x) && (pts2[0].y > pts1[1].y || pts2[1].y < pts1[0].y) as Bool
        let rpts1 = (is_outer) ? pts1 : Array(pts1[Range(start:4,end:8)])
        let rpts2 = (is_outer) ? pts2 : Array(pts2[Range(start:4,end:8)])
        let (rel_pt1, rel_pt2) = chooseRelPoints(rpts1, pts2: rpts2)
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
        sdirPath = (dirPath as NSString).stringByAppendingPathComponent("state")
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(sdirPath, withIntermediateDirectories: false, attributes: nil)
        } catch _ {
        }
        self.rroot.name = "^rroot"
        self.addChild(rroot)
        self.root.name = "^root"
        self.rroot.addChild(root)
        if (true) {
            let fp = (sdirPath as NSString).stringByAppendingPathComponent("state_root.lrn")
            if NSFileManager.defaultManager().fileExistsAtPath(fp) {
                let cfg = (try! NSString(contentsOfFile: fp, encoding: NSUTF8StringEncoding)) as String
                let lines = cfg.componentsSeparatedByString("\n")
                var li = 0
                var key = ""
                for line in lines {
                    if (li % 2 == 0) {
                        key = line
                    } else {
                        if (key == "pos.x") {
                            root.position.x = CGFloat((line as NSString).floatValue)
                        } else if (key == "pos.y") {
                            root.position.y = CGFloat((line as NSString).floatValue)
                        } else if (key == "scl") {
                            root.setScale( CGFloat((line as NSString).floatValue) )
                        }
                    }
                    li++
                }
            }
        }
        let contents = try? fileManager.contentsOfDirectoryAtPath(dirPath)
        let center = CGPoint(x:self.size.width/2, y:self.size.height/2)
        var i : Int = 0
        if contents != nil {
            let files = contents
            for fn in files! {
                if addLrnEntityFromFile(fn, center:center, i:i) {
                    i++
                }
            }
        }
        resolveAllRels()
        createAllNodesForRels()
        self.backgroundColor = NSColor.whiteColor()
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
        if self.is_sel_moving == false {
          if (self.drag_sel.name == nil) {
              self.drag_sel = self.nodeAtPoint(evt.locationInNode(self))
              if (self.drag_sel.name == "^rroot") {
                  self.drag_sel = SKNode()
              }
          }
          let node = self.drag_sel
          if (evt.modifierFlags.intersect(.ShiftKeyMask) != []) {
              self.root.setScale(self.root.xScale * (1.0 + evt.deltaX/20.0) )
          }
          else {
              if (node.name != nil && !node.name!.hasPrefix("^")) {
                  node.position = evt.locationInNode(node.parent!)
                  updateRelNodes(self.entities_by_fn[node.name!]!)
              } else {
                  self.root.position = CGPoint(x: self.root.position.x + evt.deltaX, y: self.root.position.y - evt.deltaY)
              }
          }
        }
        else {
          if self.started_sel_moving == false {
            self.started_sel_moving = true
            self.sel_move_from = evt.locationInNode(self.root)
          }
          let mp = evt.locationInNode(self.root)
          let dd = CGPoint(x: mp.x - self.sel_move_from.x, y: mp.y - self.sel_move_from.y)
          for ent in sel_entities {
            ent.node.position = CGPoint(x: ent.node.position.x + dd.x, y: ent.node.position.y + dd.y)
          }
          self.sel_move_from = mp
        }
    }
    override func keyUp(evt: NSEvent) {
        if evt.characters == "s" {
            if self.is_sel_dragging == true
            {
                self.is_sel_dragging = false
                self.is_sel_moving = true
                self.drag_rect.strokeColor = SKColor.redColor();
                self.started_sel_moving == false
                killDragRectNode()
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
                    var next = false
                    var ki = "black"
                    for (k, v) in self.colNames {
                        if next {
                            ki = k; next = false; break;
                        } else {
                            if ent.fntCol == v {
                                next = true
                            }
                        }
                    }
                    if next {
                        for (k, v) in self.colNames {
                            ki = k; break;
                        }
                    }
                    if let ccol = self.colNames[ent.fntColName] {
                        ent.fntColName = ki
                    }
                    ent.fntCol = self.colNames[ki]!
                    updateLrnEntityNote(ent)
                }
            }
        }
        func handleRight(evt: NSEvent) {
            if let ent = self.sel_ent {
                if (ent.type == "text") {
                    var ni = 0
                    for (i, ff) in self.fntNames.enumerate() {
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

                if evt.characters == "d" {
                    if isEntityNode(self.fcs_cpy_orig) {
                        killFcsNode()
                        deleteEntityFile(self.entities_by_fn[self.fcs_cpy_orig.name!]!)
                        self.fcs_cpy_orig.removeFromParent()
                    }
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
                else if evt.characters == "w" {
                    write()
                }
                else if evt.characters == "r" {
                    refresh()
                }
                else if evt.characters == "x" {
                    self.view!.paused = true
                }
                else if evt.characters == "s" {
                    if self.is_sel_dragging == false
                    {
                        self.sel_drag_from = last_mouse_evt.locationInNode(self);
                        self.sel_drag_to = last_mouse_evt.locationInNode(self);
                        self.is_sel_dragging = true;
                        setDragRectNode();
                    }
                } else if evt.characters == "m" {

                    let sceneRect = CGRectMake( -100, -100, 10000, 10000)

                    self.physicsWorld.enumerateBodiesInRect(sceneRect) {
                        (body: SKPhysicsBody!, stop: UnsafeMutablePointer<ObjCBool>) in
                          print (body.node!.name)
                        }
                }
                else {
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
        if self.view!.paused == true { return; }

        self.last_evt_time = self.time; checkWake();
        self.last_mouse_evt = evt
    }
    override func mouseMoved(evt: NSEvent) {
        if self.view!.paused == true { return; }

        if (self.started_sel_moving == true) {
          self.is_sel_moving = false
          self.started_sel_moving = false
          for ent in sel_entities {
            updateRelNodes(ent)
          }
          resetSelEntities(Array<SKNode>());
        }

        self.last_evt_time = self.time; checkWake();
        self.last_mouse_evt = evt
        self.deferred.append("killFcsNode"); //killFcsNode()

        if self.is_sel_dragging == true
        {
            self.sel_drag_to = last_mouse_evt.locationInNode(self)
            setDragRectNode()
            updateDragRectNode()
            if (true)
            {
                let sceneRect = CGRectMake(self.sel_drag_from.x, self.sel_drag_from.y, self.sel_drag_to.x-self.sel_drag_from.x, self.sel_drag_to.y-self.sel_drag_from.y)
                let sceneRect2 = CGRectMake(sceneRect.minX, sceneRect.minY, sceneRect.width, sceneRect.height)

                var sel_nodes = Array<SKNode>()
                self.physicsWorld.enumerateBodiesInRect(sceneRect2) {
                    (body: SKPhysicsBody!, stop: UnsafeMutablePointer<ObjCBool>) in
                    sel_nodes.append(body.node!)
                    //print (body.node!.name)
                }
                resetSelEntities(sel_nodes)
            }
        }
    }
    func isEntityNode(node: SKNode) -> Bool {
        return node.name != nil && node.name != "" && !node.name!.hasPrefix("^")
    }
    func setSelNode(node: SKNode) {
        let scl_add = CGFloat(0.0 * 0.125*1.5)
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
                    self.sel_ent!.node_scl_add = scl_add
                    self.sel.setScale( ent.scl +  ent.node_scl_add)
                    self.sel.zPosition = 2
                }
            } else {
                self.sel = SKNode()
                self.sel_ent = nil
            }
        }
    }
    func resetSelEntities(sel_nodes: Array<SKNode>) {
      for ent in self.sel_entities {
        ent.sel_node.removeFromParent()
      }
      sel_entities.removeAll();
      for node in sel_nodes {
        if isEntityNode(node) {
          let sel_ent = self.entities_by_fn[node.name!]!
          sel_ent.node.addChild(sel_ent.sel_node)
          sel_entities.append(sel_ent)
        }
      }
    }
    func killFcsNode() {
        self.fcs_cpy.removeFromParent()
        self.fcs_cpy = SKNode()
    }
    func setFcsNode(node: SKNode) {
        killFcsNode()
        self.fcs_cpy_orig = node
        self.fcs_cpy = node.copy() as! SKNode
        self.fcs_cpy.name = "^focus"
        self.fcs_cpy.position = CGPoint(x:self.size.width/2, y:self.size.height/2)
        self.fcs_cpy.setScale(1.0)
        self.fcs_cpy.zRotation = 0.0
        self.fcs_cpy.zPosition = 3.0
        self.addChild(self.fcs_cpy)
    }
    func killDragRectNode() {
        self.drag_rect.removeFromParent()
        self.drag_rect = SKShapeNode()
    }
    func createCircleNode(center: CGPoint, rad: CGFloat, name: String, zPos: CGFloat) -> SKShapeNode {
        let circ_node = SKShapeNode(circleOfRadius: rad)
        circ_node.strokeColor = SKColor.blackColor()
        circ_node.name = name
        circ_node.position = center
        circ_node.setScale(1.0)
        circ_node.zRotation = 0.0
        circ_node.zPosition = zPos
        return circ_node
    }
    func createRectNode(from: CGPoint, to: CGPoint, name: String, zPos: CGFloat) -> SKShapeNode {
        let rect_node = SKShapeNode(rectOfSize: CGSize(width: 1.0 * (to.x - from.x), height: 1.0*(to.y - from.y)))
        rect_node.strokeColor = SKColor.blackColor()
        rect_node.name = name
        rect_node.position = CGPoint( x: 0.5*(from.x+to.x), y: 0.5*(from.y+to.y))
        rect_node.setScale(1.0)
        rect_node.zRotation = 0.0
        rect_node.zPosition = zPos
        return rect_node
    }
    func setDragRectNode() {
        killDragRectNode()
        self.drag_rect = createRectNode(self.sel_drag_from, to: self.sel_drag_to, name: "^drag_rect", zPos: 2.0)
        self.drag_rect.lineWidth = 2.0
        self.addChild(self.drag_rect)
    }
    func updateDragRectNode() {
        if (self.is_sel_dragging)
        {
            setDragRectNode()
        }
        else
        {
            if (self.drag_rect.name == "^drag_rect")
            {
                killDragRectNode()
            }
        }
    }
    override func mouseDown(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        //self.mouse_is_down = true;
        if (evt.clickCount == 2) {
            killFcsNode()
            let dbl_sel = self.nodeAtPoint(evt.locationInNode(self))
            if isEntityNode(dbl_sel) {
                setFcsNode(dbl_sel)
            }
        }
    }
    override func mouseUp(evt: NSEvent) {
        self.last_evt_time = self.time; checkWake();
        //self.mouse_is_down = false;
        self.drag_sel = SKNode()
        let node = self.nodeAtPoint(evt.locationInNode(self))
        if (evt.modifierFlags.intersect(.ShiftKeyMask) != []) && isEntityNode(node) && isEntityNode(self.sel) {
            let from = self.sel; let to = node;
            var found = false
            if let fent = self.entities_by_fn[from.name!] {
                if let tent = self.entities_by_fn[to.name!] {
                    if (createRel(fent, to: tent, delOnFound: true)) {
                        createNodesFroRels(fent)
                    }
                }
            }
        }
        if (isEntityNode(node)) { setSelNode(node) }
    }
    //override func touchesBeganWithEvent(evt: NSEvent) {
    //    println("touches")
    //}
    func checkWake() {
        //if (self.last_evt_time.distanceTo(self.time) > 0.5) {
        //    self.view!.paused = true
        //}
        //else {
            self.view!.paused = false
        //}
    }
    override func update(currentTime: CFTimeInterval) {
        if (self.view!.paused == true) {return}
        self.time = currentTime; //checkWake();
        for (i,cmd) in self.deferred.enumerate() {
            if (cmd == "killFcsNode") {
                self.killFcsNode()
            }
        }
        self.deferred = []
        //if (self.sel.name != nil) && (isEntityNode(self.sel)) {
        //    println(self.convertPoint(CGPoint(x: 0,y: 0), fromNode: self.sel))
        //}
        //if (self.last_evt_time.distanceTo(self.time) > 0.5) {
        //    self.view!.paused = true
        //}
    }
}
