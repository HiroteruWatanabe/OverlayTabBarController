import Foundation
import UIKit

extension UIColor {
    static let butterflyHandle = UIColor(red: 209/255, green: 209/255, blue: 214/255, alpha: 1.0)
}

open class ButterflyHandle: UIView {
    
    private var pathLayer: CAShapeLayer!
    
    convenience public init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 34, height: 10))
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        isUserInteractionEnabled = false
        layer.sublayers?.forEach({ (layer) in
            layer.removeFromSuperlayer()
        })
        pathLayer = CAShapeLayer()
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = UIColor.butterflyHandle.cgColor
        pathLayer.lineCap = CAShapeLayerLineCap.round
        pathLayer.lineJoin = CAShapeLayerLineJoin.round
        pathLayer.lineWidth = 5
        pathLayer.path = isSelected ? selectedPath.cgPath : normalStatePath.cgPath
        layer.addSublayer(self.pathLayer)
    }
    
    private var normalStatePath: UIBezierPath {
        let bezierPath = UIBezierPath()
        bezierPath.move(to: .init(x: 1, y: 5))
        bezierPath.addLine(to: .init(x: 17, y: 10))
        bezierPath.addLine(to: .init(x: 33, y: 5))
        return bezierPath
    }
    
    private var selectedPath: UIBezierPath {
        let bezierPath = UIBezierPath()
        bezierPath.move(to: .init(x: 1, y: 5))
        bezierPath.addLine(to: .init(x: 17, y: 5))
        bezierPath.addLine(to: .init(x: 33, y: 5))
        return bezierPath
    }
    
    open var isSelected: Bool = false {
        didSet {
            let animation = CABasicAnimation.init(keyPath: "path")
            if isSelected {
                animation.fromValue = normalStatePath.cgPath
                animation.toValue = selectedPath.cgPath
            } else {
                animation.fromValue = selectedPath.cgPath
                animation.toValue = normalStatePath.cgPath
            }
            animation.duration = isSelected != oldValue ? 0.3 : 0
            animation.fillMode = CAMediaTimingFillMode.forwards
            animation.isRemovedOnCompletion = false
            pathLayer.add(animation, forKey: "animatePath")
        }
    }
    
    open func setSelected(_ isSelected: Bool, animated: Bool) {
        if animated {
            self.isSelected = isSelected
        } else {
            pathLayer.path = isSelected ? selectedPath.cgPath : normalStatePath.cgPath
        }
    }
}
