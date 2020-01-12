import Foundation

public struct LayoutConstraintGroup {
  public var constraints: [NSLayoutConstraint]
  public var isActive: Bool = false {
    didSet {
      constraints.forEach({ $0.isActive = isActive })
    }
  }
  
  public init() {
    self.constraints = []
  }
  
  public init(constraints: [NSLayoutConstraint]) {
    self.constraints = constraints
  }
  
  public init(constraints: NSLayoutConstraint...) {
    self.constraints = constraints
  }
  
  public mutating func removeAll() {
    constraints.removeAll()
  }
  
  public mutating func append(_ constraint: NSLayoutConstraint) {
    constraints.append(constraint)
  }
}
